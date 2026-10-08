"""
Ethmar — climate lookup from GPS coordinates.

Given a latitude/longitude anywhere on Earth, this module returns everything the
recommender needs to know about that place:

    * monthly temperature and rainfall normals  -> NASA POWER
    * true ground elevation                     -> Open-Meteo (Copernicus DEM)
    * soil pH                                   -> SoilGrids (ISRIC)
    * current conditions                        -> OpenWeather

The design goal is that location is the only input. A user in Riyadh gets
Riyadh, a user in Kuwait gets Kuwait, a user in Lima gets Lima - no city table,
no hardcoded country logic.

Caching
-------
Climate normals change on a decadal scale, so they are cached on disk and
refreshed at most once every 30 days. Coordinates are rounded to one decimal
place (~11 km) before the cache key is built, so the whole of Saudi Arabia
collapses to a few hundred cells instead of one request per user.

Usage:
    python ml/scripts/climate.py
    python ml/scripts/climate.py 29.37 47.98
"""

from __future__ import annotations

import json
import os
import sys
import time
from dataclasses import dataclass, asdict
from datetime import datetime, timedelta
from pathlib import Path

import requests

ROOT = Path(__file__).resolve().parents[2]


def _load_env_file() -> None:
    """Read .env at the repo root so local runs see the API key."""
    env_path = ROOT / ".env"
    if not env_path.exists():
        return
    for line in env_path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        os.environ.setdefault(key.strip(), value.strip())


_load_env_file()

CACHE_DIR = ROOT / "data" / "external" / "climate_cache"
CACHE_MAX_AGE_DAYS = 30
# Bump when the meaning of cached values changes, so stale entries are refetched.
# Version 2: temperatures are means of daily highs/lows, not monthly extremes.
# Version 3: temperatures corrected from NASA grid-cell elevation to the
#            point's real elevation.
CACHE_VERSION = 3

NASA_HOST = "https://power.larc.nasa.gov"
NASA_DAILY_URL = NASA_HOST + "/api/temporal/daily/point"
NORMALS_START = "20050101"
NORMALS_END = "20241231"
ELEVATION_URL = "https://api.open-meteo.com/v1/elevation"
SOILGRIDS_HOST = "https://rest.isric.org"
SOILGRIDS_URL = SOILGRIDS_HOST + "/soilgrids/v2.0/properties/query"
OPENWEATHER_HOST = "https://api.openweathermap.org"
OPENWEATHER_URL = OPENWEATHER_HOST + "/data/2.5/weather"

TIMEOUT = 45
NASA_TIMEOUT = 150
USER_AGENT = "Ethmar-GraduationProject/0.1"

# SoilGrids masks built-up areas, so a city centre often has no pH value.
# These rings (in degrees, ~11 km per 0.1) are searched outward until one
# returns data.
SOIL_SEARCH_RINGS = (0.1, 0.25, 0.5)

# Standard environmental lapse rate: air cools about 6.5C per 1000 m of climb.
LAPSE_RATE_C_PER_M = 0.0065


# --------------------------------------------------------------------------- #
# Output shape
# --------------------------------------------------------------------------- #

@dataclass
class MonthClimate:
    month: int
    temp_high_c: float
    temp_low_c: float
    rain_mm: float


@dataclass
class ClimateProfile:
    latitude: float
    longitude: float
    monthly: list              # list[MonthClimate], index 0 = January
    annual_rain_mm: float
    annual_temp_min_c: float   # coldest month average
    annual_temp_max_c: float   # hottest month average
    soil_ph: float
    soil_ph_source: str
    elevation_m: float | None      # real ground elevation of the point
    grid_elevation_m: float | None # elevation NASA assumed for its grid cell
    temp_adjust_c: float           # added to every NASA temperature
    current_temp_c: float | None
    current_source: str
    fetched_at: str

    def for_month(self, month: int) -> MonthClimate:
        return self.monthly[month - 1]

    def month_window(self, month: int, span: int = 3) -> list:
        """The planting window: this month plus the next `span - 1`."""
        return [self.monthly[(month - 1 + offset) % 12] for offset in range(span)]

    def to_dict(self) -> dict:
        return asdict(self)

    @staticmethod
    def from_dict(data: dict) -> "ClimateProfile":
        data = dict(data)
        data["monthly"] = [MonthClimate(**m) for m in data["monthly"]]
        return ClimateProfile(**data)


# --------------------------------------------------------------------------- #
# Cache
# --------------------------------------------------------------------------- #

def _cache_key(latitude: float, longitude: float) -> str:
    """Round to one decimal so nearby users share a cache entry."""
    return f"{round(latitude, 1)}_{round(longitude, 1)}"


def _cache_path(latitude: float, longitude: float) -> Path:
    return CACHE_DIR / f"{_cache_key(latitude, longitude)}.json"


def _read_cache(latitude: float, longitude: float):
    path = _cache_path(latitude, longitude)
    if not path.exists():
        return None
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
        fetched = datetime.fromisoformat(payload["fetched_at"])
    except (json.JSONDecodeError, KeyError, ValueError):
        return None
    if payload.pop("cache_version", None) != CACHE_VERSION:
        return None
    if datetime.now() - fetched > timedelta(days=CACHE_MAX_AGE_DAYS):
        return None
    return ClimateProfile.from_dict(payload)


def _write_cache(profile: ClimateProfile) -> None:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    path = _cache_path(profile.latitude, profile.longitude)
    payload = {"cache_version": CACHE_VERSION, **profile.to_dict()}
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8")


# --------------------------------------------------------------------------- #
# NASA POWER — monthly climate normals
# --------------------------------------------------------------------------- #

def fetch_nasa_power(latitude: float, longitude: float):
    """
    Returns (12 months of temperature and rainfall normals, grid-cell
    elevation in metres), or (None, None).

    Built from 20 years of daily data rather than the climatology endpoint. The
    climatology T2M_MAX and T2M_MIN are the hottest and coldest readings ever
    seen in that month, not typical ones: for Riyadh they put January at 32C
    and -3C, while the mean daily high and low are about 22C and 8C. A grower
    lives with the daily means, so those are what each month reports.

    The values describe NASA's whole grid cell (about 50 km across) at that
    cell's average elevation, which is returned so the caller can correct for
    terrain; see `apply_elevation_correction`.
    """
    response = requests.get(
        NASA_DAILY_URL,
        params={
            "parameters": "T2M_MAX,T2M_MIN,PRECTOTCORR",
            "community": "AG",
            "latitude": latitude,
            "longitude": longitude,
            "start": NORMALS_START,
            "end": NORMALS_END,
            "format": "JSON",
        },
        headers={"User-Agent": USER_AGENT},
        timeout=NASA_TIMEOUT,
    )
    response.raise_for_status()
    payload = response.json()
    parameters = payload.get("properties", {}).get("parameter", {})
    fill_value = payload.get("header", {}).get("fill_value", -999.0)
    coordinates = payload.get("geometry", {}).get("coordinates") or []
    grid_elevation = float(coordinates[2]) if len(coordinates) > 2 else None

    tmax = parameters.get("T2M_MAX")
    tmin = parameters.get("T2M_MIN")
    rain = parameters.get("PRECTOTCORR") or {}

    if not tmax or not tmin:
        print("NASA POWER payload shape not understood.")
        print("parameter keys:", list(parameters.keys()))
        return None, None

    # Keys are 'YYYYMMDD'. Gather every valid day under its month.
    highs = [[] for _ in range(12)]
    lows = [[] for _ in range(12)]
    rain_totals = [0.0] * 12
    rain_years = [set() for _ in range(12)]

    for day, value in tmax.items():
        if value is not None and value != fill_value:
            highs[int(day[4:6]) - 1].append(float(value))
    for day, value in tmin.items():
        if value is not None and value != fill_value:
            lows[int(day[4:6]) - 1].append(float(value))
    for day, value in rain.items():
        if value is not None and value != fill_value:
            index = int(day[4:6]) - 1
            rain_totals[index] += float(value)
            rain_years[index].add(day[:4])

    monthly = []
    for index in range(12):
        if not highs[index] or not lows[index]:
            return None, None
        years = len(rain_years[index]) or 1
        monthly.append(MonthClimate(
            month=index + 1,
            temp_high_c=round(sum(highs[index]) / len(highs[index]), 1),
            temp_low_c=round(sum(lows[index]) / len(lows[index]), 1),
            rain_mm=round(rain_totals[index] / years, 1),
        ))

    return monthly, grid_elevation


# --------------------------------------------------------------------------- #
# Elevation — correct grid-cell temperatures to the real point
# --------------------------------------------------------------------------- #

def fetch_elevation(latitude: float, longitude: float, attempts: int = 3):
    """
    Ground elevation in metres from a 90 m terrain model, or None.

    The service fails now and then under load, so it is retried a few times
    before giving up.
    """
    for attempt in range(attempts):
        try:
            response = requests.get(
                ELEVATION_URL,
                params={"latitude": latitude, "longitude": longitude},
                headers={"User-Agent": USER_AGENT},
                timeout=TIMEOUT,
            )
            response.raise_for_status()
            values = response.json().get("elevation") or []
            if values and values[0] is not None:
                return float(values[0])
        except (requests.RequestException, ValueError, TypeError):
            pass
        if attempt < attempts - 1:
            time.sleep(1.5 * (attempt + 1))
    return None


def apply_elevation_correction(monthly: list, grid_elevation, elevation) -> float:
    """
    Shift every month's temperatures from the grid cell's elevation to the
    point's, in place, and return the shift applied.

    A NASA cell can mix a mountain town with the lowland beside it: Abha sits
    at 2,200 m inside a cell averaged at 1,200 m, which read 6-7C too warm.
    Flat places such as Riyadh barely move. With either elevation unknown the
    data is left as it is.
    """
    if grid_elevation is None or elevation is None:
        return 0.0
    # The sea has no ground to correct to; the terrain model reports it as 0
    # or below, which would wrongly warm a coastal cell.
    elevation = max(elevation, 0.0)
    shift = round((grid_elevation - elevation) * LAPSE_RATE_C_PER_M, 1)
    for month in monthly:
        month.temp_high_c = round(month.temp_high_c + shift, 1)
        month.temp_low_c = round(month.temp_low_c + shift, 1)
    return shift


# --------------------------------------------------------------------------- #
# SoilGrids — soil pH
# --------------------------------------------------------------------------- #

def _query_soil_ph(latitude: float, longitude: float):
    """pH at one point, or None when SoilGrids has no value there."""
    try:
        response = requests.get(
            SOILGRIDS_URL,
            params={
                "lon": longitude,
                "lat": latitude,
                "property": "phh2o",
                "depth": "0-5cm",
                "value": "mean",
            },
            headers={"User-Agent": USER_AGENT},
            timeout=TIMEOUT,
        )
        response.raise_for_status()
        layers = response.json().get("properties", {}).get("layers", [])
        for layer in layers:
            if layer.get("name") != "phh2o":
                continue
            for depth in layer.get("depths", []):
                mean = (depth.get("values") or {}).get("mean")
                if mean is not None:
                    # SoilGrids returns pH multiplied by 10, so 78 means 7.8.
                    return float(mean) / 10.0
    except (requests.RequestException, ValueError, KeyError, TypeError):
        pass
    return None


def fetch_soil_ph(latitude: float, longitude: float):
    """
    Topsoil pH at 0-5 cm.

    SoilGrids leaves built-up areas empty, so the centre of Riyadh has no
    value. When the point itself is empty, rings of four points are searched
    outward and the first ring with data gives the median. Falls back to a
    neutral 7.0 only when nothing is found, and says so in the source field
    rather than pretending the value was measured.
    """
    value = _query_soil_ph(latitude, longitude)
    if value is not None:
        return round(value, 2), "soilgrids"

    for radius in SOIL_SEARCH_RINGS:
        found = []
        for d_lat, d_lon in ((radius, 0), (-radius, 0), (0, radius), (0, -radius)):
            value = _query_soil_ph(latitude + d_lat, longitude + d_lon)
            if value is not None:
                found.append(value)
        if found:
            found.sort()
            middle = len(found) // 2
            median = found[middle] if len(found) % 2 else (found[middle - 1] + found[middle]) / 2
            return round(median, 2), f"soilgrids_nearby_{round(radius * 111)}km"

    return 7.0, "default"


# --------------------------------------------------------------------------- #
# OpenWeather — current conditions
# --------------------------------------------------------------------------- #

def fetch_current_temperature(latitude: float, longitude: float):
    """
    Current air temperature in Celsius, or (None, reason).

    Read from the environment so the key never appears in source. A missing key
    is not an error: the recommender works from climate normals alone and uses
    current temperature only as an extra signal.
    """
    api_key = os.environ.get("OPENWEATHER_API_KEY")
    if not api_key:
        return None, "no_api_key"

    try:
        response = requests.get(
            OPENWEATHER_URL,
            params={
                "lat": latitude,
                "lon": longitude,
                "appid": api_key,
                "units": "metric",
            },
            headers={"User-Agent": USER_AGENT},
            timeout=TIMEOUT,
        )
        if response.status_code != 200:
            return None, f"http_{response.status_code}"
        temperature = response.json().get("main", {}).get("temp")
        if temperature is None:
            return None, "no_temperature"
        return round(float(temperature), 1), "openweather"
    except (requests.RequestException, ValueError):
        return None, "error"


# --------------------------------------------------------------------------- #
# Public entry point
# --------------------------------------------------------------------------- #

def lookup(latitude: float, longitude: float, use_cache: bool = True,
           include_current: bool = True) -> ClimateProfile:
    """Return the climate profile for a coordinate, fetching and caching as needed."""
    if use_cache:
        cached = _read_cache(latitude, longitude)
        if cached is not None:
            # A default pH or a missing elevation is a placeholder, not a
            # measurement: retry it rather than serve it for the whole cache
            # lifetime.
            changed = False
            if cached.soil_ph_source == "default":
                soil_ph, ph_source = fetch_soil_ph(latitude, longitude)
                if ph_source != "default":
                    cached.soil_ph, cached.soil_ph_source = soil_ph, ph_source
                    changed = True
            if cached.elevation_m is None:
                elevation = fetch_elevation(latitude, longitude)
                if elevation is not None:
                    cached.elevation_m = elevation
                    cached.temp_adjust_c = apply_elevation_correction(
                        cached.monthly, cached.grid_elevation_m, elevation)
                    _refresh_annual(cached)
                    changed = True
            if changed:
                _write_cache(cached)
            if include_current:
                current, source = fetch_current_temperature(latitude, longitude)
                if current is not None:
                    cached.current_temp_c = current
                    cached.current_source = source
            return cached

    monthly, grid_elevation = fetch_nasa_power(latitude, longitude)
    if monthly is None:
        raise RuntimeError(
            f"NASA POWER returned no usable climate data for "
            f"{latitude}, {longitude}"
        )

    elevation = fetch_elevation(latitude, longitude)
    temp_adjust = apply_elevation_correction(monthly, grid_elevation, elevation)

    soil_ph, ph_source = fetch_soil_ph(latitude, longitude)

    current, current_source = (None, "skipped")
    if include_current:
        current, current_source = fetch_current_temperature(latitude, longitude)

    profile = ClimateProfile(
        latitude=latitude,
        longitude=longitude,
        monthly=monthly,
        annual_rain_mm=0.0,
        annual_temp_min_c=0.0,
        annual_temp_max_c=0.0,
        soil_ph=soil_ph,
        soil_ph_source=ph_source,
        elevation_m=elevation,
        grid_elevation_m=grid_elevation,
        temp_adjust_c=temp_adjust,
        current_temp_c=current,
        current_source=current_source,
        fetched_at=datetime.now().isoformat(timespec="seconds"),
    )
    _refresh_annual(profile)

    _write_cache(profile)
    return profile


def _refresh_annual(profile: ClimateProfile) -> None:
    """Recompute the yearly summary fields from the monthly values."""
    profile.annual_rain_mm = round(sum(m.rain_mm for m in profile.monthly), 1)
    profile.annual_temp_min_c = round(min(m.temp_low_c for m in profile.monthly), 1)
    profile.annual_temp_max_c = round(max(m.temp_high_c for m in profile.monthly), 1)


def _report(profile: ClimateProfile) -> None:
    print(f"location      : {profile.latitude}, {profile.longitude}")
    print(f"elevation     : {profile.elevation_m} m "
          f"(NASA cell {profile.grid_elevation_m} m, "
          f"temps shifted {profile.temp_adjust_c:+} C)")
    print(f"soil pH       : {profile.soil_ph} ({profile.soil_ph_source})")
    print(f"annual rain   : {profile.annual_rain_mm} mm")
    print(f"year temp     : {profile.annual_temp_min_c} to {profile.annual_temp_max_c} C")
    print(f"right now     : {profile.current_temp_c} C ({profile.current_source})")
    print()
    print(f"{'Month':<7}{'high':>7}{'low':>7}{'rain':>9}")
    for month in profile.monthly:
        print(f"{month.month:<7}{month.temp_high_c:>7}{month.temp_low_c:>7}{month.rain_mm:>9}")


if __name__ == "__main__":
    latitude = float(sys.argv[1]) if len(sys.argv) > 1 else 24.71
    longitude = float(sys.argv[2]) if len(sys.argv) > 2 else 46.67

    profile = lookup(latitude, longitude)
    _report(profile)
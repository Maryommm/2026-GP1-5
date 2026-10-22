"""
Ethmar - climate lookup from GPS coordinates.

This module takes a location (latitude and longitude) and returns the climate
information that the recommendation model needs for that place:

    * monthly temperature and rainfall averages  -> NASA POWER
    * ground elevation                          -> Open-Meteo (Copernicus DEM)
    * soil pH                                   -> SoilGrids (ISRIC)

The only input is the location, so the module works for any place in the
world.

Caching and privacy
-------------------
The location is first rounded to one decimal place (about 11 km), and all
data is fetched for the centre of that area. This has two benefits:
    * users who live close to each other share the same cache entry;
    * the user's exact location is never sent to the services or saved.
Climate averages change very slowly, so each result is reused for 30 days.


"""

from __future__ import annotations

import json
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from dataclasses import asdict, dataclass, fields
from datetime import datetime, timedelta
from pathlib import Path

import requests

ROOT = Path(__file__).resolve().parents[2]

CACHE_DIR = ROOT / "data" / "external" / "climate_cache"
CACHE_MAX_AGE_DAYS = 30
# The cache version is increased whenever the meaning of the saved values
# changes, so that old cache files are ignored and fetched again.

CACHE_VERSION = 4

NASA_DAILY_URL = "https://power.larc.nasa.gov/api/temporal/daily/point"
NORMALS_START = "20050101"   # 20 full years of daily data
NORMALS_END = "20241231"
ELEVATION_URL = "https://api.open-meteo.com/v1/elevation"
SOILGRIDS_URL = "https://rest.isric.org/soilgrids/v2.0/properties/query"

TIMEOUT = 45          # seconds, for the small requests
NASA_TIMEOUT = 150    # seconds, NASA returns 20 years of data in one response
USER_AGENT = "Ethmar-GraduationProject/0.1"

# SoilGrids has no data inside cities.
# When this happens we search around the point at these distances (in degrees,
# where 0.1 degree is about 11 km) and stop at the first distance with data.
SOIL_SEARCH_RINGS = (0.1, 0.25, 0.5)

# Air temperature drops by about 6.5 C for every 1000 m of height
# (the standard environmental lapse rate).
LAPSE_RATE_C_PER_M = 0.0065


# --------------------------------------------------------------------------- #
# Data classes
# --------------------------------------------------------------------------- #

@dataclass
class MonthClimate:
    """Average climate of one month of the year."""

    month: int            # 1 = January ... 12 = December
    temp_high_c: float    # average daily maximum temperature
    temp_low_c: float     # average daily minimum temperature
    rain_mm: float        # average total rainfall in the month


@dataclass
class ClimateProfile:
    """Everything the recommendation model needs to know about one location."""

    latitude: float
    longitude: float
    monthly: list                   # 12 MonthClimate objects, index 0 = January
    soil_ph: float
    soil_ph_source: str             # "soilgrids", "soilgrids_nearby_11km" (or 28km, 55km),
                                    # "default" (SoilGrids failed) or "not_fetched" (not needed yet)
    elevation_m: float | None       # real ground elevation of the point
    grid_elevation_m: float | None  # elevation that NASA used for its grid cell
    temp_adjust_c: float            # correction added to every NASA temperature
    fetched_at: str

    def to_dict(self) -> dict:
        return asdict(self)

    @staticmethod
    def from_dict(data: dict) -> "ClimateProfile":
        # Keep only the known fields, so that a cache file written by an older
        # version of this module can still be read.
        known = {f.name for f in fields(ClimateProfile)}
        data = {key: value for key, value in data.items() if key in known}
        data["monthly"] = [MonthClimate(**m) for m in data["monthly"]]
        return ClimateProfile(**data)


# --------------------------------------------------------------------------- #
# Cache
# --------------------------------------------------------------------------- #

def area_centre(latitude: float, longitude: float):
    """Round a location to one decimal place, the centre of its ~11 km area."""
    return round(latitude, 1), round(longitude, 1)


def _cache_key(latitude: float, longitude: float) -> str:
    latitude, longitude = area_centre(latitude, longitude)
    return f"{latitude}_{longitude}"


class FileCache:
    """
    Saves each profile as a JSON file in data/external/climate_cache/.
    Used when the scripts run on a computer. The server on Vercel
    (api/index.py) passes service.FirestoreCache instead, which saves the
    profiles in Firestore; any object with the same get() and set() methods
    can be used.
    """

    def get(self, key: str) -> dict | None:
        path = CACHE_DIR / f"{key}.json"
        if not path.exists():
            return None
        try:
            return json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            return None

    def set(self, key: str, data: dict) -> None:
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        path = CACHE_DIR / f"{key}.json"
        path.write_text(json.dumps(data, indent=2), encoding="utf-8")


def _read_cache(cache, latitude: float, longitude: float):
    """Return the cached profile, or None if it is missing, old or unreadable."""
    payload = cache.get(_cache_key(latitude, longitude))
    if not payload:
        return None
    payload = dict(payload)
    try:
        fetched = datetime.fromisoformat(payload["fetched_at"])
    except (KeyError, ValueError):
        return None
    if payload.pop("cache_version", None) != CACHE_VERSION:
        return None
    if datetime.now() - fetched > timedelta(days=CACHE_MAX_AGE_DAYS):
        return None
    return ClimateProfile.from_dict(payload)


def _write_cache(cache, profile: ClimateProfile) -> None:
    payload = {"cache_version": CACHE_VERSION, **profile.to_dict()}
    cache.set(_cache_key(profile.latitude, profile.longitude), payload)


# --------------------------------------------------------------------------- #
# NASA POWER - monthly temperature and rainfall
# --------------------------------------------------------------------------- #

def fetch_nasa_power(latitude: float, longitude: float):
    """
    Calculate the 12 monthly climate averages from 20 years of daily data.

    We use the daily data instead of NASA's ready-made monthly climatology,
    because the climatology values T2M_MAX and T2M_MIN are the highest and
    lowest temperatures ever recorded in each month. For Riyadh they give
    32 C and -3 C for January, while a normal January day is about 22 C and
    8 C. A plant experiences the normal days, so we average the daily values.

    Returns:
        (list of 12 MonthClimate, elevation of the NASA grid cell in metres),
        or (None, None) if the response cannot be used.
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

    # NASA returns the elevation of its grid cell as the third coordinate.
    coordinates = payload.get("geometry", {}).get("coordinates") or []
    grid_elevation = float(coordinates[2]) if len(coordinates) > 2 else None

    tmax = parameters.get("T2M_MAX")   # daily maximum temperature
    tmin = parameters.get("T2M_MIN")   # daily minimum temperature
    rain = parameters.get("PRECTOTCORR") or {}   # daily rainfall in mm

    if not tmax or not tmin:
        print("NASA POWER response does not contain temperature data.")
        print("parameter keys:", list(parameters.keys()))
        return None, None

    # Each key is a date in the form 'YYYYMMDD'. We group the valid days by
    # month and skip NASA's fill value, which marks a missing day.
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
        # Rain is summed over all years, so we divide by the number of years
        # to get the rainfall of an average month.
        years = len(rain_years[index]) or 1
        monthly.append(MonthClimate(
            month=index + 1,
            temp_high_c=round(sum(highs[index]) / len(highs[index]), 1),
            temp_low_c=round(sum(lows[index]) / len(lows[index]), 1),
            rain_mm=round(rain_totals[index] / years, 1),
        ))

    return monthly, grid_elevation


# --------------------------------------------------------------------------- #
# Elevation correction
# --------------------------------------------------------------------------- #

def fetch_elevation(latitude: float, longitude: float, attempts: int = 3):
    """
    Return the ground elevation in metres, or None if the service fails.

    The service sometimes fails when it is busy, so the request is repeated
    up to `attempts` times with a short wait in between.
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
    Correct the NASA temperatures from the grid cell height to the real height.

    NASA gives one value for a whole grid cell (about 50 km wide) at the
    average height of that cell. In mountain areas this can be far from the
    real height of the user: Abha is at about 2,200 m, but its NASA cell has
    an average height of about 1,200 m, so its temperatures were 6-7 C too
    warm. In flat areas such as Riyadh the correction is almost zero.

    The months are changed in place. If one of the two heights is unknown,
    nothing is changed.

    Returns:
        The correction in C that was added to every temperature.
    """
    if grid_elevation is None or elevation is None:
        return 0.0
    # Over the sea the terrain model gives 0 or a negative value, which would
    # make coastal places too warm, so the height is never taken below 0.
    elevation = max(elevation, 0.0)
    shift = round((grid_elevation - elevation) * LAPSE_RATE_C_PER_M, 1)
    for month in monthly:
        month.temp_high_c = round(month.temp_high_c + shift, 1)
        month.temp_low_c = round(month.temp_low_c + shift, 1)
    return shift


# --------------------------------------------------------------------------- #
# SoilGrids - soil pH
# --------------------------------------------------------------------------- #

def _query_soil_ph(latitude: float, longitude: float, attempts: int = 4):
    """
    Return the topsoil pH at one point, or None if there is no value.

    SoilGrids limits how many requests it accepts per minute when it is busy. In that case we wait
    and try again, so that a busy service is not mistaken for "no data",
    which would change the median of a search ring.
    """
    for attempt in range(attempts):
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
            if response.status_code == 429 or response.status_code >= 500:
                time.sleep(2.0 * (attempt + 1))
                continue
            response.raise_for_status()
            layers = response.json().get("properties", {}).get("layers", [])
            for layer in layers:
                if layer.get("name") != "phh2o":
                    continue
                for depth in layer.get("depths", []):
                    mean = (depth.get("values") or {}).get("mean")
                    if mean is not None:
                        # SoilGrids stores pH multiplied by 10 (78 means 7.8).
                        return float(mean) / 10.0
            return None
        except requests.Timeout:
            continue
        except (requests.RequestException, ValueError, KeyError, TypeError):
            return None
    return None


def fetch_soil_ph(latitude: float, longitude: float):
    """
    Return the topsoil pH (0-5 cm) and where the value came from.

    If the point itself has no value (for example in a city centre), four
    points around it are checked, first at about 11 km, then 28 km, then
    55 km. The four points of a ring are requested at the same time to save
    waiting. The median of the first ring that has data is used. If nothing
    is found, a neutral pH of 7.0 is returned with the source "default", so
    that it is clear the value was not measured.

    Returns:
        (pH, source)
    """
    value = _query_soil_ph(latitude, longitude)
    if value is not None:
        return round(value, 2), "soilgrids"

    for radius in SOIL_SEARCH_RINGS:
        points = [(latitude + d_lat, longitude + d_lon)
                  for d_lat, d_lon in ((radius, 0), (-radius, 0), (0, radius), (0, -radius))]
        with ThreadPoolExecutor(max_workers=len(points)) as pool:
            results = list(pool.map(lambda point: _query_soil_ph(*point), points))
        found = [value for value in results if value is not None]
        if found:
            found.sort()
            middle = len(found) // 2
            if len(found) % 2:
                median = found[middle]
            else:
                median = (found[middle - 1] + found[middle]) / 2
            return round(median, 2), f"soilgrids_nearby_{round(radius * 111)}km"

    return 7.0, "default"


# --------------------------------------------------------------------------- #
# Main function
# --------------------------------------------------------------------------- #

def lookup(latitude: float, longitude: float, cache=None,
           with_soil: bool = True) -> ClimateProfile:
    """
    Return the climate profile of a location.

    The location is rounded to the centre of its ~11 km area first. The cache is used when possible.
    Otherwise the services are called at the same time, the
    temperatures are corrected for elevation, and the result is saved in
    the cache.

    Parameters:
        cache      where profiles are saved; a FileCache by default.
        with_soil  False when the user grows in pots: the soil of the area
                   is not used, so the slow SoilGrids service is skipped and
                   soil_ph_source is "not_fetched". A later request with
                   with_soil=True for the same area fetches it then.

    Raises:
        ValueError if the latitude or longitude is out of range.
        RuntimeError if NASA POWER returns no usable data.
        requests.HTTPError if NASA POWER cannot be reached.
    """
    if not -90 <= latitude <= 90 or not -180 <= longitude <= 180:
        raise ValueError(f"invalid location: {latitude}, {longitude}")
    latitude, longitude = area_centre(latitude, longitude)
    cache = cache if cache is not None else FileCache()

    cached = _read_cache(cache, latitude, longitude)
    if cached is not None:
        # A default pH or a missing elevation means that a service failed
        # last time. We try again instead of keeping the placeholder for
        # the whole 30 days.
        changed = False
        if with_soil and cached.soil_ph_source in ("default", "not_fetched"):
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
                changed = True
        if changed:
            _write_cache(cache, cached)
        return cached

    # The services do not depend on each other, so they are called at the
    # same time. The total wait is the time of the slowest one.
    with ThreadPoolExecutor(max_workers=3) as pool:
        nasa_job = pool.submit(fetch_nasa_power, latitude, longitude)
        elevation_job = pool.submit(fetch_elevation, latitude, longitude)
        soil_job = pool.submit(fetch_soil_ph, latitude, longitude) if with_soil else None
        monthly, grid_elevation = nasa_job.result()
        elevation = elevation_job.result()
        soil_ph, ph_source = soil_job.result() if soil_job else (7.0, "not_fetched")

    if monthly is None:
        raise RuntimeError(
            f"NASA POWER returned no usable climate data for {latitude}, {longitude}"
        )
    temp_adjust = apply_elevation_correction(monthly, grid_elevation, elevation)

    profile = ClimateProfile(
        latitude=latitude,
        longitude=longitude,
        monthly=monthly,
        soil_ph=soil_ph,
        soil_ph_source=ph_source,
        elevation_m=elevation,
        grid_elevation_m=grid_elevation,
        temp_adjust_c=temp_adjust,
        fetched_at=datetime.now().isoformat(timespec="seconds"),
    )
    _write_cache(cache, profile)
    return profile


def _report(profile: ClimateProfile) -> None:
    """Print a profile as a small table, for manual checking."""
    print(f"location      : {profile.latitude}, {profile.longitude}")
    print(f"elevation     : {profile.elevation_m} m "
          f"(NASA cell {profile.grid_elevation_m} m, "
          f"temps shifted {profile.temp_adjust_c:+} C)")
    print(f"soil pH       : {profile.soil_ph} ({profile.soil_ph_source})")
    print()
    print(f"{'Month':<7}{'high':>7}{'low':>7}{'rain':>9}")
    for month in profile.monthly:
        print(f"{month.month:<7}{month.temp_high_c:>7}{month.temp_low_c:>7}{month.rain_mm:>9}")


if __name__ == "__main__":
    lat = float(sys.argv[1]) if len(sys.argv) > 1 else 24.71
    lon = float(sys.argv[2]) if len(sys.argv) > 2 else 46.67
    _report(lookup(lat, lon))

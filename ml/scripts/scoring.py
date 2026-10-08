"""
Ethmar — Smart Crop Recommendation engine.

Pure scoring module: takes a location's monthly climate, the user's growing
setup and a planting month, and returns a ranked list of crops, each with the
reason it was chosen and the months it is best planted in.

No Firebase, no Flutter, no network. Testable on its own, wrapped by a Cloud
Function later. The climate comes from ml/scripts/climate.py.

Design notes
------------
* The crop table is global and no country-specific rule lives in the code.
  Location-awareness comes only from the monthly climate, so the same code
  serves Riyadh, London and Sydney, and the southern hemisphere's seasons fall
  out of the data instead of being special-cased.
* Seasons, not years. A beginner asks "what can I plant now?". An annual is
  judged on the months between planting and harvest only: a tomato does not
  need to survive a Riyadh August if it is planted in February. Trees and
  shrubs stay in the ground, so they are judged on all twelve months.
* Temperature follows the ECOCROP model (Hijmans et al., 2001; dismo::ecocrop):
  each month's mean temperature is scored on a trapezoid that is 0 outside the
  absolute range, 1 inside the optimal range and linear in between. An annual
  takes its weakest month in the season, since one month outside the
  tolerable range ends the crop.
* Home growers irrigate, so too little rain is a watering warning, not a
  penalty. Too much rain cannot be undone and does lower the score.
* pH is adjustable in a pot, so a mismatch is a penalty plus a warning, never
  a gate.

Usage:
    python ml/scripts/scoring.py                 # Riyadh, this month
    python ml/scripts/scoring.py 51.51 -0.13 4   # London, April
"""

from __future__ import annotations

import json
import math
from dataclasses import dataclass, field
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
TABLE_PATH = ROOT / "data" / "processed" / "ethmar_recommendable.csv"
CONFIG_PATH = ROOT / "ml" / "artifacts" / "scoring_config.json"

DEFAULT_CONFIG = {
    "weights": {
        "temperature": 0.42, "soil_ph": 0.10, "rainfall": 0.08,
        "sunlight": 0.10, "water": 0.05, "popularity": 0.25,
    },
    "bands": {"excellent": 0.80, "good": 0.62, "marginal": 0.42},
    "penalties": {"alkaline_mismatch": 0.85, "imputed_ph": 0.98},
    "popularity": {"common": 1.0, "home_garden": 0.7, "other": 0.4},
    "season": {
        "default_annual_days": 120,
        "best_month_ratio": 0.85,
        "best_month_floor": 0.6,
        # A crop whose best month is within this many months counts as
        # "plant now": 2 means this month or next.
        "plant_now_months": 2,
    },
    # How far past ECOCROP's absolute limits a crop can still be grown with
    # shade cloth or a frost cover, and what such a month scores.
    "protection": {"heat_margin_c": 3.0, "cold_margin_c": 2.0, "month_score": 0.25},
}

MONTH_NAMES = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
               "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]


# --------------------------------------------------------------------------- #
# Inputs and outputs
# --------------------------------------------------------------------------- #

@dataclass
class Site:
    """
    The user's growing setup. These are the only things asked of the user;
    climate and soil come from their location.
    """

    sunlight: str = "full"         # full | partial | shade
    water: str = "medium"          # low | medium | high
    soil_texture: str = "medium"   # sandy | medium | clay
    ph: float | None = None        # overrides the location's soil pH (e.g. potting mix)


@dataclass
class Preferences:
    """Optional. None means 'no preference', not 'exclude'."""

    groups: list | None = None          # crop_group values, e.g. ["leafy_herb"]
    life_cycle: str | None = None       # annual | perennial
    max_height_m: float | None = None
    edible_parts: list | None = None

    def is_empty(self) -> bool:
        return not any([self.groups, self.life_cycle,
                        self.max_height_m, self.edible_parts])


@dataclass
class Recommendation:
    species: str
    common_name: str
    name_ar: str
    crop_group: str
    score: float               # how well it grows when planted in plant_month
    band: str
    status: str                # "now" (this month or next) | "later"
    plant_month: int           # nearest of best_months, 1-12
    months_until: int          # months from the request month to plant_month
    season_months: int
    best_months: list = field(default_factory=list)
    protection: list = field(default_factory=list)   # "shade" | "cover"
    reasons: list = field(default_factory=list)
    warnings: list = field(default_factory=list)

    def to_dict(self) -> dict:
        return {
            "species": self.species,
            "common_name": self.common_name,
            "name_ar": self.name_ar,
            "crop_group": self.crop_group,
            "score": round(self.score, 4),
            "band": self.band,
            "status": self.status,
            "plant_month": self.plant_month,
            "months_until": self.months_until,
            "season_months": self.season_months,
            "best_months": self.best_months,
            "protection": self.protection,
            "reasons": self.reasons,
            "warnings": self.warnings,
        }


# --------------------------------------------------------------------------- #
# Helpers
# --------------------------------------------------------------------------- #

def load_config(path: Path = CONFIG_PATH) -> dict:
    if path.exists():
        with open(path, encoding="utf-8") as handle:
            return json.load(handle)
    return DEFAULT_CONFIG


_TABLE_CACHE: dict = {}


def load_table(path: Path = TABLE_PATH) -> pd.DataFrame:
    """Read the crop table once per process; a Cloud Function reuses it warm."""
    key = str(path)
    if key not in _TABLE_CACHE:
        _TABLE_CACHE[key] = pd.read_csv(path)
    return _TABLE_CACHE[key]


def _value(row, column):
    """Read a cell, treating NaN and blank as missing."""
    if column not in row:
        return None
    value = row[column]
    if value is None:
        return None
    if isinstance(value, float) and pd.isna(value):
        return None
    if isinstance(value, str) and not value.strip():
        return None
    return value


def _number(row, column):
    value = _value(row, column)
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _text(row, column):
    value = _value(row, column)
    return None if value is None else str(value).strip().lower()


def _band(score: float, bands: dict) -> str:
    if score >= bands["excellent"]:
        return "excellent"
    if score >= bands["good"]:
        return "good"
    if score >= bands["marginal"]:
        return "marginal"
    return "poor"


def _mean_temp(month) -> float:
    return (month.temp_high_c + month.temp_low_c) / 2.0


# --------------------------------------------------------------------------- #
# Season
# --------------------------------------------------------------------------- #

def stays_in_ground(row) -> bool:
    """
    True for trees and shrubs, which live through every month of the year.

    Perennial herbs such as mint and parsley are not included: in hot or cold
    climates beginners grow them as seasonal pot plants, so they are judged
    like annuals on their growing season.
    """
    lifespan = _text(row, "ecocrop_lifespan") or _text(row, "life_cycle_raw") or ""
    form = _text(row, "ecocrop_life_form") or ""
    if "annual" in lifespan or "biennial" in lifespan:
        return False
    return "perennial" in lifespan and ("tree" in form or "shrub" in form)


def season_length(row, config: dict) -> int:
    """Months from planting to first harvest, from the shortest growing cycle."""
    if stays_in_ground(row):
        return 12
    gmin = _number(row, "ecocrop_gmin")
    days = gmin if gmin and gmin > 0 else config["season"]["default_annual_days"]
    return max(1, min(12, math.ceil(days / 30)))


def season_window(monthly: list, start_month: int, length: int) -> list:
    """The months of one growing season, wrapping past December."""
    return [monthly[(start_month - 1 + offset) % 12] for offset in range(length)]


# --------------------------------------------------------------------------- #
# Temperature
# --------------------------------------------------------------------------- #

def _temperature_limits(row, woody: bool):
    """(opt_min, opt_max, abs_min, abs_max, kill), or None without an optimum."""
    opt_min = _number(row, "ecocrop_temp_opt_min_c")
    opt_max = _number(row, "ecocrop_temp_opt_max_c")
    if opt_min is None or opt_max is None:
        return None
    abs_min = _number(row, "ecocrop_temp_abs_min_c")
    abs_max = _number(row, "ecocrop_temp_abs_max_c")
    kill = _number(row, "ecocrop_ktmp")
    abs_min = opt_min - 5 if abs_min is None else abs_min
    abs_max = opt_max + 5 if abs_max is None else abs_max
    if kill is None and not woody:
        kill = 0.0
    return opt_min, opt_max, abs_min, abs_max, kill


def protection_need(row, month, woody: bool, protection: dict) -> str | None:
    """
    "shade" or "cover" when the month is just past what the crop tolerates,
    close enough that a home grower can bridge it; None otherwise.

    ECOCROP's absolute limits describe an unprotected field. In a garden a
    lemon tree gets through a Riyadh July (mean 36C, limit 36C) under shade
    cloth, and seedlings get through a cold snap under a cover, as the first
    interviewee described doing. A small margin past each limit is therefore
    allowed, with a warning. Frost below the killing temperature is not
    bridgeable this way and stays a hard limit.
    """
    limits = _temperature_limits(row, woody)
    if limits is None:
        return None
    _, _, abs_min, abs_max, kill = limits
    if kill is not None and month.temp_low_c < kill:
        return None
    mean = _mean_temp(month)
    # Inclusive at the limit itself, where the trapezoid has already reached 0.
    if abs_max <= mean <= abs_max + protection["heat_margin_c"]:
        return "shade"
    if abs_min - protection["cold_margin_c"] <= mean <= abs_min:
        return "cover"
    return None


def month_temperature_score(row, month, woody: bool = False,
                            protection: dict | None = None) -> float:
    """
    ECOCROP trapezoid for one month: 0 outside the absolute range, 1 inside
    the optimal range, linear in between. A mean daily low below the killing
    temperature means regular frost, which ends the crop. A month just past
    the absolute range scores protection["month_score"] instead of 0; see
    `protection_need`.

    ECOCROP gives no killing temperature for about 40% of crops, shiso among
    them, which would let a frost-tender herb be planted into a London winter.
    When it is missing, a non-woody crop is assumed to die in a month whose
    mean night is below freezing. Hardy vegetables (cabbage, onion, garlic)
    carry their own sub-zero value and are unaffected; trees rely on their
    absolute minimum instead.
    """
    limits = _temperature_limits(row, woody)
    if limits is None:
        return 0.5
    opt_min, opt_max, abs_min, abs_max, kill = limits

    if kill is not None and month.temp_low_c < kill:
        return 0.0

    mean = _mean_temp(month)
    if mean <= abs_min or mean >= abs_max:
        if protection and protection_need(row, month, woody, protection):
            return protection["month_score"]
        return 0.0
    if mean < opt_min:
        return (mean - abs_min) / max(opt_min - abs_min, 0.1)
    if mean > opt_max:
        return (abs_max - mean) / max(abs_max - opt_max, 0.1)
    return 1.0


def season_temperature_score(row, window: list, perennial: bool,
                             protection: dict | None = None) -> float:
    """
    An annual takes its weakest month, since one month outside the tolerable
    range ends it. A tree takes the year's average, provided no month kills
    it: a date palm idles through a mild winter and is not lost because of it.
    """
    scores = [month_temperature_score(row, month, perennial, protection) for month in window]
    if perennial:
        return 0.0 if min(scores) == 0.0 else sum(scores) / len(scores)
    return min(scores)


def _month_list(months: list) -> str:
    return ", ".join(MONTH_NAMES[m - 1] for m in months)


def temperature_notes(row, window: list, perennial: bool, protection: dict):
    """
    Reasons, warnings and protection needs explaining the temperature score.
    Protection needs come back as codes ("shade", "cover") so the app can
    show its own icon and text for them.
    """
    limits = _temperature_limits(row, perennial)
    if limits is None:
        return [], [], []
    opt_min, opt_max = limits[0], limits[1]

    needs = {m.month: protection_need(row, m, perennial, protection) for m in window}
    shade = [m for m, need in needs.items() if need == "shade"]
    cover = [m for m, need in needs.items() if need == "cover"]
    cold = [m.month for m in window if _mean_temp(m) < opt_min and m.month not in cover]
    hot = [m.month for m in window if _mean_temp(m) > opt_max and m.month not in shade]

    warnings = []
    if shade:
        warnings.append(
            f"may need shading in {_month_list(shade)}: hotter than it can take "
            "in open sun - use shade cloth or move the pot indoors"
        )
    if cover:
        warnings.append(
            f"may need covering in {_month_list(cover)}: colder than it can take "
            "uncovered - use a frost cloth or bring the pot inside at night"
        )
    protect = (["shade"] if shade else []) + (["cover"] if cover else [])

    if not cold and not hot and not protect:
        return ["temperatures suit it for the whole season"], [], []

    if cold:
        warnings.append(f"cooler than it likes in {_month_list(cold)}; growth will slow")
    if hot:
        warnings.append(f"hotter than it likes in {_month_list(hot)}; give it afternoon shade")
    return [], warnings, protect


def best_planting_months(totals: dict, config: dict) -> list:
    """
    Planting months that give a near-best season, from {month: score}.
    Trees score the same every month, so they get every month or none.
    """
    if not totals:
        return []
    best = max(totals.values())
    cutoff = max(best * config["season"]["best_month_ratio"],
                 min(best, config["season"]["best_month_floor"]))
    return sorted(start for start, score in totals.items() if score >= cutoff)


def months_until(month: int, targets: list) -> int:
    """Months from `month` to the nearest month in `targets`, wrapping the year."""
    return min((target - month) % 12 for target in targets)


# --------------------------------------------------------------------------- #
# Other factors
# --------------------------------------------------------------------------- #

def score_rainfall(row, window: list):
    """
    Rain over the season (or the year, for trees) against the crop's need.

    Asymmetric on purpose: a dry place is fixed with a watering can and only
    earns a warning, while rain beyond the crop's tolerance cannot be removed
    and lowers the score.
    """
    opt_min = _number(row, "ecocrop_rain_opt_min_mm")
    opt_max = _number(row, "ecocrop_rain_opt_max_mm")
    abs_min = _number(row, "ecocrop_rain_abs_min_mm")
    abs_max = _number(row, "ecocrop_rain_abs_max_mm")
    if opt_min is None or opt_max is None:
        return 1.0, None, None

    # ECOCROP gives an annual's rain need per growing cycle and a tree's per
    # year, which is exactly what the window covers in each case.
    rain = sum(month.rain_mm for month in window)

    if rain > opt_max:
        ceiling = abs_max if abs_max and abs_max > opt_max else opt_max * 1.5
        score = max(0.0, 1.0 - (rain - opt_max) / max(ceiling - opt_max, 1.0))
        return score, None, "wetter than it likes; plant in raised beds or pots that drain"

    if rain >= opt_min:
        return 1.0, "natural rainfall covers its needs", None
    if abs_min is not None and rain < abs_min:
        return 1.0, None, "your area is too dry for it without regular watering"
    return 1.0, None, "needs watering between rains"


def score_soil_ph(row, ph: float, config: dict):
    """
    pH is adjustable, so a mismatch is a penalty plus a warning, never a gate.
    This keeps blueberry low in alkaline Riyadh without a special case.
    """
    opt_min = _number(row, "ecocrop_ph_opt_min")
    opt_max = _number(row, "ecocrop_ph_opt_max")
    abs_max = _number(row, "ecocrop_ph_abs_max")
    abs_min = _number(row, "ecocrop_ph_abs_min")

    if opt_min is None or opt_max is None:
        return 0.5, None, None
    if opt_min <= ph <= opt_max:
        return 1.0, "soil pH suits it", None

    width = max(opt_max - opt_min, 0.5)
    penalty = config["penalties"]["alkaline_mismatch"]

    if ph > opt_max:
        score = max(0.0, 1.0 - (ph - opt_max) / width)
        if abs_max is not None and ph > abs_max:
            return score * penalty, None, (
                "needs acidic soil; your soil is alkaline - grow it in a pot "
                "with potting mix or amend the soil"
            )
        return score, None, "prefers slightly more acidic soil than yours"

    score = max(0.0, 1.0 - (opt_min - ph) / width)
    if abs_min is not None and ph < abs_min:
        return score * penalty, None, "needs more alkaline soil than yours"
    return score, None, "prefers slightly more alkaline soil than yours"


def score_sunlight(row, site: Site):
    flags = {
        "full": _number(row, "light_full_sun"),
        "partial": _number(row, "light_partial_sun_shade"),
        "shade": _number(row, "light_full_shade"),
    }
    wanted = flags.get(site.sunlight)
    if wanted is None:
        return 0.6, None, None
    if wanted == 1:
        return 1.0, "tolerates your light level", None
    return 0.3, None, f"prefers different light than {site.sunlight} sun"


def score_water(row, site: Site):
    flags = {
        "low": _number(row, "water_dry"),
        "medium": _number(row, "water_moist"),
        "high": _number(row, "water_wet"),
    }
    wanted = flags.get(site.water)
    if wanted is None:
        return 0.6, None
    if wanted == 1:
        return 1.0, "watering needs fit your setup"
    return 0.35, None


def score_soil_texture(row, site: Site):
    flags = {
        "sandy": _number(row, "soil_light_sandy"),
        "medium": _number(row, "soil_medium"),
        "clay": _number(row, "soil_heavy_clay"),
    }
    if flags.get(site.soil_texture) == 0:
        return "your soil texture is not ideal for it"
    return None


def score_popularity(row, config: dict) -> float:
    """
    Prefer crops people actually grow at home. Without this a wild plant with
    a wide climate envelope outranks tomato, which is what a beginner wants.
    """
    values = config["popularity"]
    if _number(row, "is_common") == 1:
        return values["common"]
    if _number(row, "home_garden") == 1:
        return values["home_garden"]
    return values["other"]


# --------------------------------------------------------------------------- #
# Preferences
# --------------------------------------------------------------------------- #

def matches_preferences(row, preferences) -> bool:
    """
    Preferences filter candidates before scoring. Use them for taste, not
    survivability - anything climatic belongs in the scoring instead.
    """
    if preferences is None or preferences.is_empty():
        return True

    if preferences.groups:
        group = _text(row, "crop_group") or ""
        if group not in [g.lower() for g in preferences.groups]:
            return False

    if preferences.life_cycle:
        cycle = _text(row, "ecocrop_lifespan") or _text(row, "life_cycle_raw") or ""
        if preferences.life_cycle.lower() not in cycle:
            return False

    if preferences.max_height_m is not None:
        height = _number(row, "height_m")
        if height is not None and height > preferences.max_height_m:
            return False

    if preferences.edible_parts:
        parts = _text(row, "edible_parts_raw") or ""
        if not any(part.lower() in parts for part in preferences.edible_parts):
            return False

    return True


# --------------------------------------------------------------------------- #
# Main entry point
# --------------------------------------------------------------------------- #

def score_species(row, climate, month: int, site: Site, config: dict):
    """
    Score one crop for a location, as of `month`. Returns None only when the
    crop cannot be grown there in any month of the year.

    Every planting month is scored, which gives the months it is best planted
    in. A crop whose best month is now or next month is marked "now"; any
    other is marked "later" and carries a warning naming its month, so the
    user still sees the tomato in October and learns to plant it in February.

    `climate` is a ClimateProfile from climate.py, or anything with a
    12-item `monthly` list and a `soil_ph`.
    """
    weights = config["weights"]
    protection = config["protection"]
    reasons, warnings = [], []

    length = season_length(row, config)
    perennial = length == 12 and stays_in_ground(row)

    # Factors that do not depend on the planting month.
    ph = site.ph if site.ph is not None else climate.soil_ph
    ph_score, ph_reason, ph_warn = score_soil_ph(row, ph, config)
    sun_score, sun_reason, sun_warn = score_sunlight(row, site)
    water_score, water_reason = score_water(row, site)
    texture_warn = score_soil_texture(row, site)
    popularity = score_popularity(row, config)
    fixed = (ph_score * weights["soil_ph"]
             + sun_score * weights["sunlight"]
             + water_score * weights["water"]
             + popularity * weights["popularity"])
    factor = config["penalties"]["imputed_ph"] if _number(row, "ph_imputed") == 1 else 1.0

    def window_for(start: int) -> list:
        return (list(climate.monthly) if perennial
                else season_window(climate.monthly, start, length))

    # Score each planting month; a tree's year is the same whenever it starts.
    totals = {}
    starts = [1] if perennial else range(1, 13)
    for start in starts:
        window = window_for(start)
        temp_score = season_temperature_score(row, window, perennial, protection)
        if temp_score <= 0:
            continue
        rain_score, _, _ = score_rainfall(row, window)
        total = (fixed + temp_score * weights["temperature"]
                 + rain_score * weights["rainfall"]) * factor
        if total >= config["bands"]["marginal"]:
            totals[start] = total
    if perennial and totals:
        totals = {start: totals[1] for start in range(1, 13)}
    if not totals:
        return None

    best_months = best_planting_months(totals, config)
    wait = months_until(month, best_months)
    plant_month = (month - 1 + wait) % 12 + 1
    status = "now" if wait < config["season"]["plant_now_months"] else "later"
    score = totals[plant_month]

    if status == "later":
        warnings.append(
            f"best planted in {MONTH_NAMES[plant_month - 1]} "
            f"({wait} months from now)"
        )
    elif wait > 0:
        reasons.append(f"best planted next month ({MONTH_NAMES[plant_month - 1]})")

    # Explain the season the user would actually grow.
    window = window_for(plant_month)
    temp_reasons, temp_warnings, protect = temperature_notes(row, window, perennial, protection)
    reasons += temp_reasons
    warnings += temp_warnings
    _, rain_reason, rain_warn = score_rainfall(row, window)

    for reason in (rain_reason, ph_reason, sun_reason, water_reason):
        if reason:
            reasons.append(reason)
    for warning in (rain_warn, ph_warn, sun_warn, texture_warn):
        if warning:
            warnings.append(warning)

    return Recommendation(
        species=str(_value(row, "canonical_binomial") or ""),
        common_name=str(_value(row, "common_name") or ""),
        name_ar=str(_value(row, "name_ar") or ""),
        crop_group=str(_value(row, "crop_group") or ""),
        score=score,
        band=_band(score, config["bands"]),
        status=status,
        plant_month=plant_month,
        months_until=wait,
        season_months=length,
        best_months=best_months,
        protection=protect,
        reasons=reasons,
        warnings=warnings,
    )


def recommend(climate, month: int, site: Site | None = None, preferences=None,
              limit: int | None = None, table: pd.DataFrame | None = None,
              config: dict | None = None):
    """
    Every crop that can be grown at the location, as of `month`.

    Crops to plant now (this month or next) come first, best score first;
    then the rest, soonest planting month first. `limit` trims the list.
    """
    if not 1 <= month <= 12:
        raise ValueError(f"month must be 1-12, got {month}")
    config = config or load_config()
    site = site or Site()
    table = load_table() if table is None else table

    results = []
    for _, row in table.iterrows():
        if not matches_preferences(row, preferences):
            continue
        scored = score_species(row, climate, month, site, config)
        if scored is not None:
            results.append(scored)

    results.sort(key=lambda r: (r.status != "now", r.months_until if r.status != "now" else 0,
                                -r.score, r.species))
    return results if limit is None else results[:limit]


if __name__ == "__main__":
    import sys
    from datetime import date

    import climate as climate_lookup

    latitude = float(sys.argv[1]) if len(sys.argv) > 1 else 24.71
    longitude = float(sys.argv[2]) if len(sys.argv) > 2 else 46.67
    month = int(sys.argv[3]) if len(sys.argv) > 3 else date.today().month

    profile = climate_lookup.lookup(latitude, longitude, include_current=False)
    top = recommend(profile, month, Site(), limit=10)
    print(json.dumps({
        "location": [latitude, longitude],
        "month": MONTH_NAMES[month - 1],
        "soil_ph": profile.soil_ph,
        "results": [r.to_dict() for r in top],
    }, indent=2, ensure_ascii=False))

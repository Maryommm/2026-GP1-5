"""
Ethmar - Smart Crop Recommendation model.

This module compares the climate of the user's location with the growing
needs of every crop in our table, and returns the crops that can be grown
there. For each crop it also returns the best months to plant it, a score,
and the reasons and warnings behind that score.

The module does not call any web service. The climate comes from
ml/scripts/climate.py, so this file can be tested on its own and later be
called from a Firebase Cloud Function.

How the model works
-------------------
1. Seasons, not whole years. A user asks "what can I plant now?", so an
   annual crop is checked only on the months between planting and harvest.
   For example, a tomato planted in February does not need to survive the
   Riyadh summer. Trees and shrubs stay in the ground all year, so they are
   checked on all 12 months.
2. Temperature is scored with the ECOCROP method (Hijmans et al., 2001).
   For each month, the average temperature gets a score of 1 inside the
   crop's optimal range, 0 outside its absolute range, and a value between
   0 and 1 in between. An annual crop gets the score of its worst month,
   because one bad month is enough to lose the crop.
3. Other factors (soil pH, rainfall, sunlight, watering and how common the
   crop is in home gardens) are added as a weighted sum. The weights are in
   ml/artifacts/scoring_config.json.
4. Home growers can water their plants, so low rainfall only gives a
   watering warning. Too much rain cannot be removed, so it lowers the score.
5. The table and the rules are the same for every country. The difference
   between locations comes only from their climate data.

Usage:
    python ml/scripts/scoring.py                 # Riyadh, current month
    python ml/scripts/scoring.py 51.51 -0.13 4   # London, April
"""

from __future__ import annotations

import copy
import json
import math
from dataclasses import dataclass, field
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
TABLE_PATH = ROOT / "data" / "processed" / "ethmar_recommendable.csv"
CONFIG_PATH = ROOT / "ml" / "artifacts" / "scoring_config.json"

# Default settings. Any value in scoring_config.json replaces the one here.
DEFAULT_CONFIG = {
    # Weight of each factor in the final score (they add up to 1.0).
    "weights": {
        "temperature": 0.42, "soil_ph": 0.10, "rainfall": 0.08,
        "sunlight": 0.10, "water": 0.05, "popularity": 0.25,
    },
    # Minimum score for each band. Crops below "marginal" are not returned.
    "bands": {"excellent": 0.80, "good": 0.62, "marginal": 0.42},
    "penalties": {
        "alkaline_mismatch": 0.85,   # pH far outside the crop's range
        "imputed_ph": 0.98,          # the crop's pH range was estimated
    },
    # Popularity score: crops from our reviewed list, crops that ECOCROP
    # marks as grown in home gardens, and all other crops.
    "popularity": {"common": 1.0, "home_garden": 0.7, "other": 0.4},
    "season": {
        "default_annual_days": 120,  # growing days when the data has none
        "best_month_ratio": 0.85,    # a "best" month scores at least 85% of the top month
        "best_month_floor": 0.6,
        "plant_now_months": 2,       # 2 = "now" means this month or next month
    },
    # A crop may still be grown a little outside its temperature limits if
    # the user protects it with shade cloth or a frost cover.
    "protection": {"heat_margin_c": 3.0, "cold_margin_c": 2.0, "month_score": 0.25},
}

MONTH_NAMES = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
               "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

SUNLIGHT_VALUES = ("full", "partial", "shade")
WATER_VALUES = ("low", "medium", "high")
SOIL_TEXTURE_VALUES = ("sandy", "medium", "clay")


# --------------------------------------------------------------------------- #
# Inputs and outputs
# --------------------------------------------------------------------------- #

@dataclass
class Site:
    """
    The user's growing setup. This is the only information we ask the user
    for; the climate and soil pH come from their location.
    """

    sunlight: str = "full"         # full | partial | shade
    water: str = "medium"          # low | medium | high
    soil_texture: str = "medium"   # sandy | medium | clay
    ph: float | None = None        # replaces the location's pH (e.g. potting mix)

    def __post_init__(self):
        # The values will come from the mobile app, so we reject anything
        # unexpected instead of silently giving it a neutral score.
        if self.sunlight not in SUNLIGHT_VALUES:
            raise ValueError(f"sunlight must be one of {SUNLIGHT_VALUES}")
        if self.water not in WATER_VALUES:
            raise ValueError(f"water must be one of {WATER_VALUES}")
        if self.soil_texture not in SOIL_TEXTURE_VALUES:
            raise ValueError(f"soil_texture must be one of {SOIL_TEXTURE_VALUES}")
        if self.ph is not None and not 0 <= self.ph <= 14:
            raise ValueError("ph must be between 0 and 14")


@dataclass
class Preferences:
    """Optional filters chosen by the user. None means "no filter"."""

    groups: list | None = None          # crop_group values, e.g. ["leafy_herb"]
    life_cycle: str | None = None       # annual | perennial
    max_height_m: float | None = None
    edible_parts: list | None = None    # e.g. ["Fruit", "Leaves"]

    def is_empty(self) -> bool:
        return not any([self.groups, self.life_cycle,
                        self.max_height_m, self.edible_parts])


@dataclass
class Recommendation:
    """One crop in the result list."""

    species: str
    common_name: str
    name_ar: str
    crop_group: str
    score: float           # score when planted in plant_month (0 to 1)
    band: str              # excellent | good | marginal
    status: str            # "now" (this month or next) or "later"
    plant_month: int       # the nearest best month to plant, 1-12
    months_until: int      # months from the request month to plant_month
    season_months: int     # months from planting to first harvest
    best_months: list = field(default_factory=list)
    protection: list = field(default_factory=list)   # "shade" and/or "cover"
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
    """
    Read the settings file on top of the default settings, so a setting
    that is missing from the file keeps its default value.
    """
    config = copy.deepcopy(DEFAULT_CONFIG)
    if path.exists():
        with open(path, encoding="utf-8") as handle:
            for section, values in json.load(handle).items():
                if isinstance(values, dict):
                    config.setdefault(section, {}).update(values)
                else:
                    config[section] = values
    return config


_TABLE_CACHE: dict = {}


def load_table(path: Path = TABLE_PATH) -> pd.DataFrame:
    """Read the crop table only once, and reuse it for later requests."""
    key = str(path)
    if key not in _TABLE_CACHE:
        _TABLE_CACHE[key] = pd.read_csv(path)
    return _TABLE_CACHE[key]


def _value(row, column):
    """Read a cell, and return None if it is empty or missing."""
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
    """Read a cell as a float, or None."""
    value = _value(row, column)
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _text(row, column):
    """Read a cell as lower-case text, or None."""
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
    """Average temperature of a month, from its average high and low."""
    return (month.temp_high_c + month.temp_low_c) / 2.0


def _month_list(months: list) -> str:
    """Turn [1, 2] into 'Jan, Feb'."""
    return ", ".join(MONTH_NAMES[m - 1] for m in months)


# --------------------------------------------------------------------------- #
# Growing season
# --------------------------------------------------------------------------- #

def stays_in_ground(row) -> bool:
    """
    Return True for trees and shrubs, which stay in the ground all year.

    Perennial herbs such as mint and parsley return False. In very hot or
    very cold climates home growers usually grow them as seasonal pot plants,
    so we check them on their growing season like annual crops.
    """
    lifespan = _text(row, "ecocrop_lifespan") or _text(row, "life_cycle_raw") or ""
    form = _text(row, "ecocrop_life_form") or ""
    if "annual" in lifespan or "biennial" in lifespan:
        return False
    return "perennial" in lifespan and ("tree" in form or "shrub" in form)


def season_length(row, config: dict) -> int:
    """
    Number of months from planting to the first harvest (1 to 12).
    It uses the shortest growing cycle in ECOCROP (ecocrop_gmin, in days).
    """
    if stays_in_ground(row):
        return 12
    gmin = _number(row, "ecocrop_gmin")
    days = gmin if gmin and gmin > 0 else config["season"]["default_annual_days"]
    return max(1, min(12, math.ceil(days / 30)))


def season_window(monthly: list, start_month: int, length: int) -> list:
    """
    The months of one growing season. After December it continues from
    January, so a crop planted in November with 3 months gives Nov, Dec, Jan.
    """
    return [monthly[(start_month - 1 + offset) % 12] for offset in range(length)]


# --------------------------------------------------------------------------- #
# Temperature
# --------------------------------------------------------------------------- #

def _temperature_limits(row, woody: bool):
    """
    Return the crop's temperature limits as
    (opt_min, opt_max, abs_min, abs_max, kill), or None if there is no
    optimal range in the data.

    Missing values are filled as follows:
      * a missing absolute limit is set 5 C beyond the optimal limit;
      * a missing killing temperature is set to 0 C for non-woody crops.
        ECOCROP has no killing temperature for about 40% of the crops, and
        without this rule a frost-sensitive herb could be recommended for a
        cold winter. Hardy vegetables such as cabbage and onion have their
        own value below 0 C, so they are not affected. Trees use their
        absolute minimum instead.
    """
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
    Return "shade" or "cover" if the month is only a little outside what the
    crop can tolerate, so a home grower could still protect it. Otherwise
    return None.

    ECOCROP's absolute limits are for crops in an open field. At home, a
    lemon tree can survive a Riyadh July (average 36 C, limit 36 C) under
    shade cloth, and seedlings can survive a cold night under a cover, as
    the first interviewee described. We therefore allow a small margin past
    each limit, with a warning. Frost below the killing temperature cannot
    be handled this way, so it stays a hard limit.
    """
    limits = _temperature_limits(row, woody)
    if limits is None:
        return None
    _, _, abs_min, abs_max, kill = limits
    if kill is not None and month.temp_low_c < kill:
        return None
    mean = _mean_temp(month)
    # The limit itself is included, because the score there is already 0.
    if abs_max <= mean <= abs_max + protection["heat_margin_c"]:
        return "shade"
    if abs_min - protection["cold_margin_c"] <= mean <= abs_min:
        return "cover"
    return None


def month_temperature_score(row, month, woody: bool = False,
                            protection: dict | None = None) -> float:
    """
    Temperature score of one month, between 0 and 1 (ECOCROP method).

        score
          1 |        ___________
            |       /           \\
            |      /             \\
          0 |_____/               \\_____
               abs_min opt_min opt_max abs_max   (average temperature)

    The score is 0 if the average night is below the killing temperature.
    A month that needs shade or a cover (see `protection_need`) gets a small
    score instead of 0.
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


def season_temperature_score(row, window: list, woody: bool,
                             protection: dict | None = None) -> float:
    """
    Temperature score of a whole season.

    * Annual crops take the score of their worst month, because one month
      outside the crop's range is enough to lose it.
    * Trees take the average of the 12 months, as long as no month scores 0.
      A date palm grows slowly in a mild winter, but it is not lost, so a
      cool month should only lower its score.
    """
    scores = [month_temperature_score(row, month, woody, protection) for month in window]
    if woody:
        return 0.0 if min(scores) == 0.0 else sum(scores) / len(scores)
    return min(scores)


def temperature_notes(row, window: list, woody: bool, protection: dict):
    """
    Explain the temperature score of a season.

    Returns:
        (reasons, warnings, protection codes)
        The protection codes are "shade" and "cover". They are returned as
        codes so the app can show its own icon and translated text.
    """
    limits = _temperature_limits(row, woody)
    if limits is None:
        return [], [], []
    opt_min, opt_max = limits[0], limits[1]

    needs = {m.month: protection_need(row, m, woody, protection) for m in window}
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
    From {planting month: score}, return the months whose score is close to
    the best one. Trees have the same score in every month, so they get
    either all 12 months or none.
    """
    if not totals:
        return []
    best = max(totals.values())
    cutoff = max(best * config["season"]["best_month_ratio"],
                 min(best, config["season"]["best_month_floor"]))
    return sorted(start for start, score in totals.items() if score >= cutoff)


def months_until(month: int, targets: list) -> int:
    """
    Number of months from `month` to the nearest month in `targets`.
    It continues into the next year: from October (10) to February (2) is 4.
    """
    return min((target - month) % 12 for target in targets)


# --------------------------------------------------------------------------- #
# Other factors
# --------------------------------------------------------------------------- #

def score_rainfall(row, window: list):
    """
    Compare the rain in the season with the crop's needs.

    ECOCROP gives the rain need of an annual crop per growing cycle and of a
    tree per year, which is the same period as the window in both cases.

    The rule is not symmetric on purpose: low rain is solved by watering, so
    it only gives a warning, but too much rain cannot be removed, so it
    lowers the score.

    Returns:
        (score, reason or None, warning or None)
    """
    opt_min = _number(row, "ecocrop_rain_opt_min_mm")
    opt_max = _number(row, "ecocrop_rain_opt_max_mm")
    abs_min = _number(row, "ecocrop_rain_abs_min_mm")
    abs_max = _number(row, "ecocrop_rain_abs_max_mm")
    if opt_min is None or opt_max is None:
        return 1.0, None, None

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
    Compare the soil pH with the crop's range.

    pH can be changed (for example by using potting mix), so a mismatch
    lowers the score and gives a warning, but never removes the crop.

    Returns:
        (score, reason or None, warning or None)
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
    """Check if the crop accepts the user's light level (Permapeople flags)."""
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
    """Check if the crop accepts the user's watering level (Permapeople flags)."""
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
    """Return a warning if the crop does not like the user's soil type."""
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
    Give a higher score to crops that people really grow at home.

    Without this factor, a wild plant with a wide climate range would rank
    above a tomato, even though a beginner is looking for the tomato.
    """
    values = config["popularity"]
    if _number(row, "is_common") == 1:
        return values["common"]
    if _number(row, "home_garden") == 1:
        return values["home_garden"]
    return values["other"]


# --------------------------------------------------------------------------- #
# User filters
# --------------------------------------------------------------------------- #

def matches_preferences(row, preferences) -> bool:
    """
    Return True if the crop passes the user's filters. The filters are only
    for personal taste (for example "herbs only"); the climate is handled by
    the scoring.
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
# Main functions
# --------------------------------------------------------------------------- #

def score_species(row, climate, month: int, site: Site, config: dict):
    """
    Score one crop for one location.

    Every possible planting month is scored. From these scores we find the
    best months to plant the crop, and compare them with the current month:

      * if the nearest best month is this month or next month -> "now";
      * otherwise -> "later", with a warning that names the month.

    This way a user in October still sees the tomato, and learns that it is
    better planted in February.

    Parameters:
        row      one row of the crop table
        climate  a ClimateProfile from climate.py (12 months + soil_ph)
        month    the current month, 1-12
        site     the user's growing setup
        config   the settings from load_config()

    Returns:
        A Recommendation, or None if the crop cannot be grown at the
        location in any month of the year.
    """
    weights = config["weights"]
    protection = config["protection"]
    reasons, warnings = [], []

    length = season_length(row, config)
    woody = stays_in_ground(row)

    # These factors do not depend on the planting month.
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
        # Trees are checked on the whole year, annual crops on their season.
        if woody:
            return list(climate.monthly)
        return season_window(climate.monthly, start, length)

    # Score every planting month. For a tree the year is the same whatever
    # the start month, so it is calculated once and copied to all 12 months.
    totals = {}
    starts = [1] if woody else range(1, 13)
    for start in starts:
        window = window_for(start)
        temp_score = season_temperature_score(row, window, woody, protection)
        if temp_score <= 0:
            continue
        rain_score, _, _ = score_rainfall(row, window)
        total = (fixed + temp_score * weights["temperature"]
                 + rain_score * weights["rainfall"]) * factor
        if total >= config["bands"]["marginal"]:
            totals[start] = total
    if woody and totals:
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
            f"best planted in {MONTH_NAMES[plant_month - 1]} ({wait} months from now)"
        )
    elif wait > 0:
        reasons.append(f"best planted next month ({MONTH_NAMES[plant_month - 1]})")

    # The reasons and warnings describe the season the user will actually grow.
    window = window_for(plant_month)
    temp_reasons, temp_warnings, protect = temperature_notes(row, window, woody, protection)
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
    Return every crop that can be grown at the location.

    Order of the list:
      1. crops to plant now (this month or next), highest score first;
      2. crops to plant later, nearest planting month first.

    Parameters:
        climate      a ClimateProfile from climate.py
        month        the current month, 1-12
        site         the user's growing setup (default: Site())
        preferences  optional filters
        limit        return only the first `limit` crops (default: all)
        table, config  only needed for testing; loaded from files otherwise
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

    results.sort(key=lambda r: (r.status != "now",
                                r.months_until if r.status != "now" else 0,
                                -r.score, r.species))
    return results if limit is None else results[:limit]


if __name__ == "__main__":
    import sys
    from datetime import date

    import climate as climate_lookup

    lat = float(sys.argv[1]) if len(sys.argv) > 1 else 24.71
    lon = float(sys.argv[2]) if len(sys.argv) > 2 else 46.67
    current_month = int(sys.argv[3]) if len(sys.argv) > 3 else date.today().month

    profile = climate_lookup.lookup(lat, lon)
    top = recommend(profile, current_month, Site(), limit=10)
    print(json.dumps({
        "location": [lat, lon],
        "month": MONTH_NAMES[current_month - 1],
        "soil_ph": profile.soil_ph,
        "results": [r.to_dict() for r in top],
    }, indent=2, ensure_ascii=False))

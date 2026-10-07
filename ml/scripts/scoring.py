"""
Ethmar — Smart Crop Recommendation engine.

Pure scoring module: takes a location's climate plus optional user preferences
and returns a ranked list of species, each with the reason it was chosen.

No Firebase, no Flutter, no I/O. Testable on its own, wrapped by a Cloud
Function later.

Design notes
------------
* The species table is global. Nothing is removed for geographic reasons and no
  country-specific rules live in the code. Location-awareness comes from the
  match itself: a species whose envelope cannot tolerate the local climate
  scores low or is excluded by a gate.
* Matching is graded, not binary. A Riyadh user gets a short list of perfect
  matches plus a longer list of "possible with extra care" - not a wall of
  rejections. The `band` field carries that distinction.
* Hard gates are reserved for physical impossibilities (a species that cannot
  survive the local minimum temperature, or a clay-only plant in sand).
  Alkaline soil is a penalty with a warning, not a gate, because pH is
  adjustable by a home grower while winter temperature is not.

Usage:
    python ml/scripts/scoring.py
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
TABLE_PATH = ROOT / "data" / "processed" / "ethmar_recommendable.csv"
CONFIG_PATH = ROOT / "ml" / "artifacts" / "scoring_config.json"

DEFAULT_CONFIG = {
    "weights": {
        "temperature": 0.30, "rainfall": 0.15, "soil_ph": 0.12,
        "climate_zone": 0.15, "sunlight": 0.10, "water": 0.10,
        "life_cycle": 0.08,
    },
    "bands": {"excellent": 0.80, "good": 0.62, "marginal": 0.42},
    "hard_gates": {
        "absolute_temp": True, "min_rainfall": True,
        "soil_texture": True, "growing_days": True,
    },
    "penalties": {
        "alkaline_mismatch": 0.85, "no_climate_zone_data": 0.97,
        "imputed_ph": 0.98,
    },
    "defaults": {"imputed_ph_species": 6.5},
}


# --------------------------------------------------------------------------- #
# Inputs and outputs
# --------------------------------------------------------------------------- #

@dataclass
class Location:
    """
    Climate of where the user is planting. Every value is derived from GPS and
    a weather source - none of it is asked of the user, who is a beginner and
    would not know the answers.
    """

    temp_min_c: float          # coldest month average
    temp_max_c: float          # hottest month average
    rain_mm: float             # mean annual rainfall
    ph: float = 7.0            # inferred soil pH
    climate_zone: str | None = None   # Koppen code, e.g. "BWh"
    sunlight: str = "full"     # full | partial | shade
    water: str = "medium"      # low | medium | high
    soil_texture: str = "medium"   # sandy | medium | clay
    growing_days: int = 365    # season length available


@dataclass
class Preferences:
    """Optional. None means 'no preference', not 'exclude'."""

    categories: list | None = None
    life_cycle: str | None = None       # annual | perennial
    max_height_m: float | None = None
    edible_parts: list | None = None

    def is_empty(self) -> bool:
        return not any([self.categories, self.life_cycle,
                        self.max_height_m, self.edible_parts])


@dataclass
class Recommendation:
    species: str
    common_name: str
    category: str
    score: float
    band: str
    reasons: list = field(default_factory=list)
    warnings: list = field(default_factory=list)

    def to_dict(self) -> dict:
        return {
            "species": self.species,
            "common_name": self.common_name,
            "category": self.category,
            "score": round(self.score, 4),
            "band": self.band,
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


# --------------------------------------------------------------------------- #
# Scoring, one factor at a time
# --------------------------------------------------------------------------- #

def score_temperature(row, location: Location):
    """
    Two steps. Being inside the optimal band is full marks. Falling outside the
    absolute band is a hard gate, because no home-garden care changes winter
    minimum temperature.
    """
    opt_min = _number(row, "ecocrop_temp_opt_min_c")
    opt_max = _number(row, "ecocrop_temp_opt_max_c")
    abs_min = _number(row, "ecocrop_temp_abs_min_c")
    abs_max = _number(row, "ecocrop_temp_abs_max_c")

    if opt_min is None or opt_max is None:
        return 0.5, False, None, None

    if abs_min is not None and location.temp_min_c < abs_min:
        return 0.0, True, None, (
            f"cannot survive your coldest month ({location.temp_min_c:.0f}C, "
            f"needs at least {abs_min:.0f}C)"
        )
    if abs_max is not None and location.temp_max_c > abs_max:
        return 0.0, True, None, (
            f"cannot survive your hottest month ({location.temp_max_c:.0f}C, "
            f"tolerates up to {abs_max:.0f}C)"
        )

    if opt_min <= location.temp_min_c and location.temp_max_c <= opt_max:
        return 1.0, False, "grows in your temperature range all year", None

    width = max(opt_max - opt_min, 5.0)
    if location.temp_min_c < opt_min:
        gap = opt_min - location.temp_min_c
        detail = "prefers warmer nights than you get"
    else:
        gap = location.temp_max_c - opt_max
        detail = "prefers cooler days than you get"

    return max(0.0, 1.0 - gap / width), False, None, f"{detail}; may still grow"


def score_rainfall(row, location: Location):
    """
    Rainfall is what a home grower works around with irrigation, so a dry
    mismatch is a warning rather than a gate.
    """
    opt_min = _number(row, "ecocrop_rain_opt_min_mm")
    opt_max = _number(row, "ecocrop_rain_opt_max_mm")
    abs_min = _number(row, "ecocrop_rain_abs_min_mm")

    if opt_min is None or opt_max is None:
        return 0.5, False, None, None

    rain = location.rain_mm
    if opt_min <= rain <= opt_max:
        return 1.0, False, "rainfall suits it", None

    width = max(opt_max - opt_min, 200.0)
    if rain < opt_min:
        gap = opt_min - rain
        score = max(0.0, 1.0 - gap / width)
        if abs_min is not None and rain < abs_min * 0.5:
            return score, True, None, (
                "needs far more water than your area receives; "
                "only viable with heavy irrigation"
            )
        return score, False, None, "needs regular watering in your area"

    gap = rain - opt_max
    score = max(0.0, 1.0 - gap / width)
    return score, False, None, "your area is wetter than it prefers; ensure drainage"


def score_soil_ph(row, location: Location, config: dict):
    """
    pH is adjustable, so a mismatch is a penalty plus a warning, never a gate.
    This is what keeps blueberry out of Riyadh results without a special case:
    its envelope tops out below the local pH, so it scores low and carries an
    explicit warning.
    """
    opt_min = _number(row, "ecocrop_ph_opt_min")
    opt_max = _number(row, "ecocrop_ph_opt_max")
    abs_max = _number(row, "ecocrop_ph_abs_max")
    abs_min = _number(row, "ecocrop_ph_abs_min")

    if opt_min is None or opt_max is None:
        return 0.5, None, None

    ph = location.ph
    if opt_min <= ph <= opt_max:
        return 1.0, "soil pH suits it", None

    width = max(opt_max - opt_min, 0.5)
    penalty = config["penalties"]["alkaline_mismatch"]

    if ph > opt_max:
        gap = ph - opt_max
        score = max(0.0, 1.0 - gap / width)
        if abs_max is not None and ph > abs_max:
            return score * penalty, None, (
                "needs acidic soil; your soil is alkaline - grow it in a pot "
                "with potting mix or amend the soil"
            )
        return score, None, "prefers slightly more acidic soil than yours"

    gap = opt_min - ph
    score = max(0.0, 1.0 - gap / width)
    if abs_min is not None and ph < abs_min:
        return score * penalty, None, "needs more alkaline soil than yours"
    return score, None, "prefers slightly more alkaline soil than yours"


def score_climate_zone(row, location: Location, config: dict):
    zones = _text(row, "ecocrop_cliz")
    if not zones or not location.climate_zone:
        return 0.6 * config["penalties"]["no_climate_zone_data"], None

    if location.climate_zone.lower() in zones:
        return 1.0, "your climate type is in its natural range"
    return 0.5, None


def score_sunlight(row, location: Location):
    flags = {
        "full": _number(row, "light_full_sun"),
        "partial": _number(row, "light_partial_sun_shade"),
        "shade": _number(row, "light_full_shade"),
    }
    wanted = flags.get(location.sunlight)
    if wanted is None:
        return 0.6, None, None
    if wanted == 1:
        return 1.0, "tolerates your light level", None
    return 0.3, None, f"prefers different light than {location.sunlight} sun"


def score_water(row, location: Location):
    flags = {
        "low": _number(row, "water_dry"),
        "medium": _number(row, "water_moist"),
        "high": _number(row, "water_wet"),
    }
    wanted = flags.get(location.water)
    if wanted is None:
        return 0.6, None, None
    if wanted == 1:
        return 1.0, "watering needs fit your setup", None
    return 0.35, None, None


def score_soil_texture(row, location: Location):
    flags = {
        "sandy": _number(row, "soil_light_sandy"),
        "medium": _number(row, "soil_medium"),
        "clay": _number(row, "soil_heavy_clay"),
    }
    wanted = flags.get(location.soil_texture)
    if wanted is None:
        return 0.6, False, None
    if wanted == 1:
        return 1.0, False, None
    return 0.2, False, "your soil texture is not ideal for it"


def score_life_cycle(row, location: Location, preferences):
    """
    Season length against the species' growing-day range. A species needing more
    days than the season allows cannot finish, so this gates.
    """
    gmin = _number(row, "ecocrop_gmin")
    if gmin is None:
        score, gate = 0.6, False
    elif gmin <= location.growing_days:
        score, gate = 1.0, False
    else:
        score, gate = 0.0, True

    if preferences and preferences.life_cycle:
        actual = _text(row, "ecocrop_lifespan") or _text(row, "life_cycle_raw")
        if actual and preferences.life_cycle.lower() in actual:
            score = min(1.0, score + 0.15)

    return score, gate, None


# --------------------------------------------------------------------------- #
# Preferences
# --------------------------------------------------------------------------- #

def matches_preferences(row, preferences) -> bool:
    """
    Preferences filter candidates before scoring. Use them for taste, not
    survivability - anything geographic belongs in the gates instead.
    """
    if preferences is None or preferences.is_empty():
        return True

    if preferences.categories:
        category = _text(row, "ethmar_category") or ""
        if category not in [c.lower() for c in preferences.categories]:
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

def score_species(row, location: Location, config: dict, preferences=None):
    """Score one species. Returns None when a hard gate excludes it."""
    weights = config["weights"]
    gates_on = config["hard_gates"]

    reasons = []
    warnings = []

    temp_score, temp_gate, temp_reason, temp_warn = score_temperature(row, location)
    if temp_gate and gates_on["absolute_temp"]:
        return None
    if temp_reason:
        reasons.append(temp_reason)
    if temp_warn:
        warnings.append(temp_warn)

    rain_score, rain_gate, rain_reason, rain_warn = score_rainfall(row, location)
    if rain_gate and gates_on["min_rainfall"]:
        return None
    if rain_reason:
        reasons.append(rain_reason)
    if rain_warn:
        warnings.append(rain_warn)

    ph_score, ph_reason, ph_warn = score_soil_ph(row, location, config)
    if ph_reason:
        reasons.append(ph_reason)
    if ph_warn:
        warnings.append(ph_warn)

    zone_score, zone_reason = score_climate_zone(row, location, config)
    if zone_reason:
        reasons.append(zone_reason)

    sun_score, sun_reason, sun_warn = score_sunlight(row, location)
    if sun_reason:
        reasons.append(sun_reason)
    if sun_warn:
        warnings.append(sun_warn)

    water_score, water_reason, water_warn = score_water(row, location)
    if water_reason:
        reasons.append(water_reason)
    if water_warn:
        warnings.append(water_warn)

    texture_score, texture_gate, texture_warn = score_soil_texture(row, location)
    if texture_gate and gates_on["soil_texture"]:
        return None
    if texture_warn:
        warnings.append(texture_warn)

    cycle_score, cycle_gate, _ = score_life_cycle(row, location, preferences)
    if cycle_gate and gates_on["growing_days"]:
        return None

    total = (
        temp_score * weights["temperature"]
        + rain_score * weights["rainfall"]
        + ph_score * weights["soil_ph"]
        + zone_score * weights["climate_zone"]
        + sun_score * weights["sunlight"]
        + water_score * weights["water"]
        + cycle_score * weights["life_cycle"]
    )

    if _number(row, "ph_imputed") == 1:
        total *= config["penalties"]["imputed_ph"]

    band = _band(total, config["bands"])
    if band == "poor":
        return None

    if not reasons:
        reasons.append("broad tolerance; widely grown")

    return Recommendation(
        species=str(_value(row, "canonical_binomial") or ""),
        common_name=str(_value(row, "common_name") or ""),
        category=str(_value(row, "ethmar_category") or ""),
        score=total,
        band=band,
        reasons=reasons,
        warnings=warnings,
    )


def recommend(location: Location, preferences=None, limit: int = 10,
              table_path: Path = TABLE_PATH, config: dict = None):
    """Return the top `limit` species for a location, best first."""
    config = config or load_config()
    table = pd.read_csv(table_path)

    results = []
    for _, row in table.iterrows():
        if not matches_preferences(row, preferences):
            continue
        scored = score_species(row, location, config, preferences)
        if scored is not None:
            results.append(scored)

    results.sort(key=lambda r: (-r.score, r.species))
    return results[:limit]


def explain(location: Location, preferences=None, limit: int = 5) -> dict:
    """Debug helper: the ranked list plus how many candidates were filtered."""
    table = pd.read_csv(TABLE_PATH)
    candidates = sum(1 for _, row in table.iterrows()
                     if matches_preferences(row, preferences))
    top = recommend(location, preferences, limit=limit)

    return {
        "location": location.__dict__,
        "species_in_table": len(table),
        "after_preference_filter": candidates,
        "returned": len(top),
        "results": [r.to_dict() for r in top],
    }


if __name__ == "__main__":
    # Riyadh in October: hot days, cool nights, very dry, alkaline soil.
    riyadh = Location(
        temp_min_c=11.0, temp_max_c=43.0, rain_mm=110.0, ph=8.2,
        climate_zone="BWh", sunlight="full", water="medium",
        soil_texture="sandy",
    )
    kitchen = Preferences(categories=["vegetable", "herb", "fruit", "root_crop"])

    print(json.dumps(explain(riyadh, kitchen, limit=8), indent=2, ensure_ascii=False))

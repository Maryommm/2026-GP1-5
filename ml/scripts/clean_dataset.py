"""
Ethmar — dataset cleaning pipeline for the Smart Crop Recommendation System.

Reads the raw master dataset, applies normalization / classification / species
de-duplication, and writes two files:

    data/processed/ethmar_recommendable.csv  -> model-ready recommendation table
    data/processed/ethmar_reference.csv      -> lookup + chatbot reference table

The raw file is never modified. Re-run this script any time the logic changes
and the processed files are rebuilt from scratch.

Usage:
    python ml/scripts/clean_dataset.py
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

import pandas as pd

# --------------------------------------------------------------------------- #
# Paths
# --------------------------------------------------------------------------- #

ROOT = Path(__file__).resolve().parents[2]
RAW_PATH = ROOT / "data" / "raw" / "ethmar_master_dataset.csv"
PROCESSED_DIR = ROOT / "data" / "processed"
RECOMMENDABLE_PATH = PROCESSED_DIR / "ethmar_recommendable.csv"
REFERENCE_PATH = PROCESSED_DIR / "ethmar_reference.csv"

# --------------------------------------------------------------------------- #
# Column groups
# --------------------------------------------------------------------------- #

DROP_COLUMNS = [
    "width_m", "edit_count",
    "ecocrop_tox", "ecocrop_toxr", "medicinal_raw",
    "soil_ph_raw", "ph_min", "ph_max",
    "created", "last_updated", "extraction_timestamp",
    "ecocrop_match_note", "ecocrop_source",
    "is_duplicate_scientific_name", "scientific_name_duplicate_count",
    "master_scientific_name", "scientific_name_normalized",
]

NUMERIC_COLUMNS = [
    "hardiness_zone_min", "hardiness_zone_max", "height_m",
    "ecocrop_temp_opt_min_c", "ecocrop_temp_opt_max_c",
    "ecocrop_temp_abs_min_c", "ecocrop_temp_abs_max_c",
    "ecocrop_rain_opt_min_mm", "ecocrop_rain_opt_max_mm",
    "ecocrop_rain_abs_min_mm", "ecocrop_rain_abs_max_mm",
    "ecocrop_ph_opt_min", "ecocrop_ph_opt_max",
    "ecocrop_ph_abs_min", "ecocrop_ph_abs_max",
    "ecocrop_latopmn", "ecocrop_latopmx", "ecocrop_latmn", "ecocrop_latmx",
    "ecocrop_altitude_max_m", "ecocrop_ktmp",
    "ecocrop_gmin", "ecocrop_gmax", "permapeople_id",
]

BOOLEAN_COLUMNS = [
    "edible", "ethmar_relevant",
    "light_full_sun", "light_partial_sun_shade",
    "light_partial_shade", "light_full_shade",
    "water_dry", "water_moist", "water_wet",
    "soil_light_sandy", "soil_medium", "soil_heavy_clay",
]

FOOD_CATEGORY_MAP = [
    (re.compile(r"vegetables", re.I), "vegetable"),
    (re.compile(r"roots/tubers", re.I), "root_crop"),
    (re.compile(r"pulses", re.I), "legume"),
    (re.compile(r"cereals", re.I), "cereal"),
    (re.compile(r"fruits? & nuts", re.I), "fruit"),
    (re.compile(r"medicinals? & aromatic", re.I), "herb"),
]

NON_FOOD_CATEGORY = re.compile(
    r"forage/pasture|forest/wood|ornamentals?/turf|weed|materials|environmental|cover crop",
    re.I,
)

FOOD_USE_TOKENS = re.compile(
    r"food|edible|vegetable|fruit|culinary|spice|oil|beverage|starch|sugar|"
    r"flavou?r|nut|herb|salad|grain|cereal|legume|pulse|condiment",
    re.I,
)

NULL_TOKENS = {"", "na", "n/a", "null", "none", "nan"}

CONFIDENCE_RANK = {"high": 3, "low": 2, "none": 1}


# --------------------------------------------------------------------------- #
# Null / type helpers
# --------------------------------------------------------------------------- #

def _to_null(value):
    """
    Collapse every spelling of 'missing' into a single None.

    pandas turns blank CSV cells into float('nan'), and NaN is a float - so
    anything that treats a cell as text has to pass through here first, or
    len() / .lower() blow up on it.
    """
    if value is None:
        return None
    if isinstance(value, float) and pd.isna(value):
        return None
    try:
        if pd.isna(value):
            return None
    except (TypeError, ValueError):
        pass
    text = str(value).strip()
    return None if text.lower() in NULL_TOKENS else text


def _to_number(value):
    value = _to_null(value)
    if value is None:
        return None
    try:
        return float(value)
    except ValueError:
        cleaned = re.sub(r"[^0-9.\-]", "", value)
        try:
            return float(cleaned)
        except ValueError:
            return None


def _to_bool01(value):
    value = _to_null(value)
    if value is None:
        return None
    lowered = value.lower()
    if lowered in {"true", "1", "yes"}:
        return 1
    if lowered in {"false", "0", "no"}:
        return 0
    return None


# --------------------------------------------------------------------------- #
# Stage 1 — load + normalize
# --------------------------------------------------------------------------- #

def load_and_normalize(raw_path: Path) -> pd.DataFrame:
    """Read the raw CSV and coerce every column to its real type."""
    df = pd.read_csv(raw_path, dtype=str, keep_default_na=False)

    keep = [c for c in df.columns if c not in DROP_COLUMNS]
    df = df[keep].copy()

    for column in df.columns:
        if column in NUMERIC_COLUMNS:
            df[column] = df[column].map(_to_number)
        elif column in BOOLEAN_COLUMNS:
            df[column] = df[column].map(_to_bool01)
        else:
            df[column] = df[column].map(_to_null)

    df["_edible_raw"] = df["edible"].eq(1)
    return df


# --------------------------------------------------------------------------- #
# Stage 2 — edible evidence + classification
# --------------------------------------------------------------------------- #

def edible_evidence(row: pd.Series) -> str | None:
    """
    Return the strongest evidence that a plant is eaten, or None.

    Order matters: an explicit edible flag outranks a parts list, which
    outranks a free-text use note.

    Why this exists: the original Ethmar rule only fired on Permapeople rows.
    EcoCrop-only rows carry a category but often no edibility confirmation, and
    treating "EcoCrop calls it a vegetable" as proof of edibility let 389
    unconfirmed species into the recommendation table.
    """
    if row["_edible_raw"]:
        return "edible_flag"

    parts = _to_null(row.get("edible_parts_raw"))
    if parts and len(parts) > 2 and parts.lower() not in {"none", "no"}:
        return "edible_parts"

    uses = _to_null(row.get("edible_uses_raw"))
    if uses and FOOD_USE_TOKENS.search(uses):
        return "edible_uses"

    utility = _to_null(row.get("utility_raw"))
    if utility and FOOD_USE_TOKENS.search(utility):
        return "utility"

    return None


def classify(row: pd.Series) -> pd.Series:
    """
    Assign the Ethmar category, relevance flag, provenance and confidence.

      * original_rule    - row already carried a category; high confidence.
      * ecocrop_backfill - category from ecocrop_category AND edible evidence.
      * provisional      - category from ecocrop_category, no edible evidence.
                           Kept with low confidence for review, excluded from
                           the model table.
    """
    evidence = edible_evidence(row)

    original = _to_null(row.get("ethmar_category"))
    if original and original != "unknown":
        row["category_source"] = "original_rule"
        row["edible_evidence"] = evidence or "rule_only"
        row["category_confidence"] = "high"
        return row

    ecocrop_category = _to_null(row.get("ecocrop_category")) or ""
    if not ecocrop_category:
        row["category_source"] = "none"
        row["edible_evidence"] = evidence or "none"
        row["category_confidence"] = "none"
        return row

    assigned = None
    for pattern, category in FOOD_CATEGORY_MAP:
        if pattern.search(ecocrop_category):
            assigned = category
            break

    if assigned and evidence:
        row["ethmar_category"] = assigned
        row["ethmar_relevant"] = 1
        row["ethmar_rule_applied"] = (
            f"Backfilled from ecocrop_category ({assigned}) "
            f"with edible evidence: {evidence}"
        )
        row["category_source"] = "ecocrop_backfill"
        row["edible_evidence"] = evidence
        row["category_confidence"] = "high"
    elif assigned:
        row["ethmar_category"] = assigned
        row["ethmar_relevant"] = 1
        row["ethmar_rule_applied"] = (
            f"Provisional from ecocrop_category ({assigned}), "
            f"no edible evidence in record"
        )
        row["category_source"] = "ecocrop_backfill"
        row["edible_evidence"] = "none"
        row["category_confidence"] = "low"
    elif NON_FOOD_CATEGORY.search(ecocrop_category):
        row["ethmar_category"] = "non_productive"
        row["ethmar_relevant"] = 0
        row["ethmar_rule_applied"] = (
            f"Backfilled non-productive from ecocrop_category: {ecocrop_category}"
        )
        row["category_source"] = "ecocrop_backfill"
        row["edible_evidence"] = evidence or "none"
        row["category_confidence"] = "high"
    else:
        row["category_source"] = "none"
        row["edible_evidence"] = evidence or "none"
        row["category_confidence"] = "none"

    return row


# --------------------------------------------------------------------------- #
# Stage 3 — species-level merge
# --------------------------------------------------------------------------- #

def _first_non_null(series: pd.Series):
    for value in series:
        if value is not None and not (isinstance(value, float) and pd.isna(value)) and value != "":
            return value
    return None


def _merge_group(group: pd.DataFrame) -> pd.Series:
    """
    Collapse every row sharing a canonical binomial into one species record.

    Non-null values come from the first member that has one, which also fills
    gaps: a variety row often carries a height the plant row lacks.

    Edibility is OR-ed across the group. Taking the first non-null value was the
    original bug - the first row of a group frequently had an empty edible
    field, which silently stripped the flag from peach, fig and walnut.
    """
    merged = {}
    for column in group.columns:
        if column in {"_edible_raw", "variety_names", "merged_row_count"}:
            continue
        merged[column] = _first_non_null(group[column])

    evidence = [_to_null(v) for v in group["edible_evidence"]]
    evidence = [v for v in evidence if v and v != "none"]
    merged["edible_evidence"] = evidence[0] if evidence else "none"

    if group["_edible_raw"].any():
        merged["edible"] = 1
    elif group["edible"].eq(1).any():
        merged["edible"] = 1
    elif group["edible"].eq(0).all():
        merged["edible"] = 0
    else:
        merged["edible"] = 0 if group["edible"].eq(0).any() else None

    sources = [_to_null(v) for v in group["category_source"]]
    sources = [v for v in sources if v and v != "none"]
    merged["category_source"] = sources[0] if sources else "none"

    confidences = [v for v in (_to_null(c) for c in group["category_confidence"]) if v]
    if confidences:
        merged["category_confidence"] = max(
            confidences, key=lambda c: CONFIDENCE_RANK.get(c, 0)
        )
    else:
        merged["category_confidence"] = "none"

    names = set()
    for value in group["common_name"]:
        text = _to_null(value)
        if not text:
            continue
        for name in text.split(","):
            name = name.strip()
            if name:
                names.add(name)
    merged["variety_names"] = "; ".join(sorted(names)) or None
    merged["merged_row_count"] = len(group)

    if group["ethmar_relevant"].eq(1).any():
        merged["ethmar_relevant"] = 1
    elif group["ethmar_relevant"].eq(0).any():
        merged["ethmar_relevant"] = 0
    else:
        merged["ethmar_relevant"] = None

    return pd.Series(merged)


def merge_species(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df["_species_key"] = (
        df["canonical_binomial"].fillna(df["scientific_name"]).str.lower().str.strip()
    )
    df = df[df["_species_key"].notna() & (df["_species_key"] != "")]

    grouped = df.groupby("_species_key", sort=False).apply(_merge_group)
    grouped = grouped.reset_index(drop=True)
    return grouped


# --------------------------------------------------------------------------- #
# Stage 4 — split recommendable / reference
# --------------------------------------------------------------------------- #

def _has_climate(row: pd.Series) -> bool:
    """A plant is matchable against a location only with temperature + rain."""
    temp_ok = pd.notna(row["ecocrop_temp_opt_min_c"]) and pd.notna(
        row["ecocrop_temp_opt_max_c"]
    )
    rain_ok = pd.notna(row["ecocrop_rain_opt_min_mm"]) and pd.notna(
        row["ecocrop_rain_opt_max_mm"]
    )
    return bool(temp_ok and rain_ok)

ENVELOPE_PAIRS = [
    ("ecocrop_temp_opt_min_c", "ecocrop_temp_opt_max_c"),
    ("ecocrop_temp_abs_min_c", "ecocrop_temp_abs_max_c"),
    ("ecocrop_rain_opt_min_mm", "ecocrop_rain_opt_max_mm"),
    ("ecocrop_rain_abs_min_mm", "ecocrop_rain_abs_max_mm"),
    ("ecocrop_ph_opt_min", "ecocrop_ph_opt_max"),
    ("ecocrop_ph_abs_min", "ecocrop_ph_abs_max"),
    ("hardiness_zone_min", "hardiness_zone_max"),
    ("ecocrop_gmin", "ecocrop_gmax"),
]


def repair_envelopes(df: pd.DataFrame) -> pd.DataFrame:
    """
    Swap any inverted envelope pair and record what was changed.

    A source record with rain_opt_min=7000 and rain_opt_max=2000 would silently
    match every location, because the matcher compares against the bounds. One
    known case: Acorus calamus. Repairs are logged in repairs_applied rather
    than edited by hand, so the fix is visible and repeatable.
    """
    df = df.copy()
    df["repairs_applied"] = ""

    for low, high in ENVELOPE_PAIRS:
        if low not in df.columns or high not in df.columns:
            continue
        inverted = df[low].notna() & df[high].notna() & (df[low] > df[high])
        if inverted.any():
            df.loc[inverted, [low, high]] = df.loc[inverted, [high, low]].values
            for index in df.index[inverted]:
                note = df.at[index, "repairs_applied"]
                entry = f"swapped {low}/{high}"
                df.at[index, "repairs_applied"] = f"{note}; {entry}" if note else entry

    return df

def split_tables(df: pd.DataFrame):
    recommendable_rows, reference_rows = [], []
    reasons = {"no_climate": 0, "not_productive": 0, "no_edible_evidence": 0}
    ph_imputed = 0

    for _, row in df.iterrows():
        row = row.copy()
        productive = row["ethmar_relevant"] == 1
        edible_ok = row["edible"] == 1
        climate_ok = _has_climate(row)

        if productive and edible_ok and climate_ok:
            if pd.isna(row["ecocrop_ph_opt_min"]) or pd.isna(row["ecocrop_ph_opt_max"]):
                row["ecocrop_ph_opt_min"] = 6.0
                row["ecocrop_ph_opt_max"] = 7.0
                if pd.isna(row["ecocrop_ph_abs_min"]):
                    row["ecocrop_ph_abs_min"] = 5.5
                if pd.isna(row["ecocrop_ph_abs_max"]):
                    row["ecocrop_ph_abs_max"] = 8.0
                row["ph_imputed"] = 1
                ph_imputed += 1
            else:
                row["ph_imputed"] = 0
            recommendable_rows.append(row)
        else:
            if not climate_ok:
                reasons["no_climate"] += 1
            elif not productive:
                reasons["not_productive"] += 1
            else:
                reasons["no_edible_evidence"] += 1
            reference_rows.append(row)

    recommendable = pd.DataFrame(recommendable_rows).reset_index(drop=True)
    reference = pd.DataFrame(reference_rows).reset_index(drop=True)
    return recommendable, reference, reasons, ph_imputed


# --------------------------------------------------------------------------- #
# Stage 5 — report + write
# --------------------------------------------------------------------------- #

def print_report(raw_count, normalized, merged, recommendable, reference, reasons, ph_imputed):
    print("=" * 62)
    print("Ethmar cleaning pipeline")
    print("=" * 62)
    print(f"raw rows                : {raw_count}")
    print(f"after normalization     : {len(normalized)}  ({normalized.shape[1]} columns)")
    print(f"after species merge     : {len(merged)}")
    print(f"  recommendable         : {len(recommendable)}")
    print(f"  reference             : {len(reference)}")
    print(f"imputed pH              : {ph_imputed}")
    print("-" * 62)
    print("Reference exclusion reasons")
    for reason, count in reasons.items():
        print(f"  {reason:<22}: {count}")
    print("-" * 62)
    print("Recommendable - category distribution")
    for category, count in recommendable["ethmar_category"].value_counts().items():
        print(f"  {category:<22}: {count}")
    print("-" * 62)
    print("Recommendable - edible evidence")
    for evidence, count in recommendable["edible_evidence"].value_counts().items():
        print(f"  {evidence:<22}: {count}")
    print("=" * 62)


def main() -> int:
    if not RAW_PATH.exists():
        print(f"ERROR: raw dataset not found at {RAW_PATH}", file=sys.stderr)
        print("Place ethmar_master_dataset.csv in data/raw/ first.", file=sys.stderr)
        return 1

    PROCESSED_DIR.mkdir(parents=True, exist_ok=True)

    raw_count = sum(1 for _ in open(RAW_PATH, encoding="utf-8")) - 1
    df = load_and_normalize(RAW_PATH)
    normalized = df.copy()

    df = df.apply(classify, axis=1)
    merged = merge_species(df)
    merged = repair_envelopes(merged)


    recommendable, reference, reasons, ph_imputed = split_tables(merged)

    internal = {"_edible_raw", "_species_key"}
    recommendable = recommendable.drop(columns=[c for c in internal if c in recommendable])
    reference = reference.drop(columns=[c for c in internal if c in reference])

    recommendable.to_csv(RECOMMENDABLE_PATH, index=False)
    reference.to_csv(REFERENCE_PATH, index=False)

    print_report(raw_count, normalized, merged, recommendable, reference, reasons, ph_imputed)
    print(f"\nwritten: {RECOMMENDABLE_PATH}")
    print(f"written: {REFERENCE_PATH}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

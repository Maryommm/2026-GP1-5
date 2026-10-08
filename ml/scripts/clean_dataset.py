"""
Ethmar - dataset cleaning pipeline for the Smart Crop Recommendation model.

This script reads the raw master dataset (Permapeople + FAO ECOCROP), cleans
it, and writes two tables:

    data/processed/ethmar_recommendable.csv
        Crops that are edible, productive and have climate data. This is the
        table used by the recommendation model (scoring.py).

    data/processed/ethmar_reference.csv
        All other plants. They are kept for reference (for example for the
        chatbot), but they are never recommended.

Steps:
    1. Load the raw file and convert every column to its correct type.
    2. Decide if each plant is edible and give it an Ethmar category.
    3. Join records that are the same plant under two scientific names.
    4. Merge all rows of the same species into one row.
    5. Fix climate ranges where the minimum is larger than the maximum.
    6. Add the crop groups used by the app filter.
    7. Split the result into the two tables and print a report.

The raw file is never changed. Run the script again after any change to the
rules and both tables are built again from the beginning.

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
COMMON_CROPS_PATH = ROOT / "ml" / "artifacts" / "common_crops.csv"

# --------------------------------------------------------------------------- #
# Column groups
# --------------------------------------------------------------------------- #

# Columns that are not needed by the model or the app.
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

# Columns stored as 1 (yes), 0 (no) or empty (unknown).
BOOLEAN_COLUMNS = [
    "edible", "ethmar_relevant",
    "light_full_sun", "light_partial_sun_shade",
    "light_partial_shade", "light_full_shade",
    "water_dry", "water_moist", "water_wet",
    "soil_light_sandy", "soil_medium", "soil_heavy_clay",
]

# ECOCROP category text -> Ethmar category, checked in this order.
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

# Words in a "uses" text that show the plant is eaten.
FOOD_USE_TOKENS = re.compile(
    r"food|edible|vegetable|fruit|culinary|spice|oil|beverage|starch|sugar|"
    r"flavou?r|nut|herb|salad|grain|cereal|legume|pulse|condiment",
    re.I,
)

NULL_TOKENS = {"", "na", "n/a", "null", "none", "nan"}

CONFIDENCE_RANK = {"high": 3, "low": 2, "none": 1}


# --------------------------------------------------------------------------- #
# Type helpers
# --------------------------------------------------------------------------- #

def _to_null(value):
    """
    Turn every way of writing "missing" into None, and strip the text.

    pandas reads an empty CSV cell as float('nan'). Text functions such as
    .lower() fail on NaN, so every cell is passed through this function
    before it is used as text.
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
    """Convert a cell to float. Units such as '30 C' are removed first."""
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
    """Convert true/false text to 1/0, or None if unknown."""
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
# Step 1 - load and normalize
# --------------------------------------------------------------------------- #

def load_and_normalize(raw_path: Path) -> pd.DataFrame:
    """Read the raw CSV, drop unused columns and convert every column to its type."""
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

    # Keep the original edible flag, because the merge step needs it later.
    df["_edible_raw"] = df["edible"].eq(1)
    return df


# --------------------------------------------------------------------------- #
# Step 2 - edibility and category
# --------------------------------------------------------------------------- #

def edible_evidence(row: pd.Series) -> str | None:
    """
    Return the strongest proof that a plant is eaten, or None.

    The proofs are checked from strongest to weakest: the edible flag, then
    the list of edible parts, then the "uses" texts.

    This check is needed because many ECOCROP-only records have a food
    category but no proof of edibility. Treating the category alone as proof
    added 389 unconfirmed plants to the recommendation table.
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
    Give the row an Ethmar category, a relevance flag, and a note about where
    the category came from and how confident we are.

    category_source values:
      * original_rule    - the raw data already had a category (high confidence)
      * ecocrop_backfill - the category comes from ECOCROP's category text.
                           With edible proof the confidence is high; without
                           it the confidence is low, and the row will not
                           reach the recommendation table.
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
# Step 3 - join scientific-name synonyms
# --------------------------------------------------------------------------- #

BINOMIAL = re.compile(r"^([a-z]+) ([a-z][a-z-]+)$")

# Pairs that ECOCROP lists as synonyms but that are different plants.
# They were checked by hand and are never joined.
SYNONYM_BLOCKLIST = {
    ("allium porrum", "allium cepa"),         # leek is not onion
    ("mentha aquatica", "mentha piperita"),   # water mint is a parent of peppermint
}

# New scientific names that ECOCROP does not list as synonyms yet.
SYNONYM_ADDITIONS = {
    "salvia rosmarinus": "rosmarinus officinalis",   # rosemary, renamed in 2017
}


def _binomial(name) -> str | None:
    """Return the first two words of a scientific name in lower case, or None."""
    text = _to_null(name)
    if not text:
        return None
    words = text.lower().split()
    if len(words) < 2:
        return None
    candidate = f"{words[0]} {words[1]}"
    return candidate if BINOMIAL.match(candidate) else None


def synonym_map(df: pd.DataFrame) -> dict:
    """
    Build a map {Permapeople name: ECOCROP name} for plants that the two
    sources record under different scientific names.

    Example: Permapeople lists tomato as Solanum lycopersicum, while ECOCROP
    lists it as Lycopersicon esculentum, with Solanum lycopersicum as a
    synonym. Before this step, the Permapeople record had no climate data
    and the ECOCROP record had no edible flag, so tomato was missing from
    the recommendation table.

    Two rules keep different plants apart:
      * a synonym that is also an accepted ECOCROP name is skipped
        (ECOCROP lists Cucurbita maxima under C. moschata, but both are
        real species with their own records);
      * a synonym that belongs to more than one ECOCROP species is skipped.
    """
    has_ecocrop = df["ecocrop_scientific_name"].notna()
    accepted = {_binomial(v) for v in df.loc[has_ecocrop, "ecocrop_scientific_name"]}
    accepted |= {_binomial(v) for v in df.loc[has_ecocrop, "canonical_binomial"]}
    accepted.discard(None)

    claims: dict[str, set] = {}
    for target, synonyms in zip(df.loc[has_ecocrop, "canonical_binomial"],
                                df.loc[has_ecocrop, "ecocrop_synonyms"]):
        target = _binomial(target)
        text = _to_null(synonyms)
        if not target or not text:
            continue
        for synonym in text.split(","):
            name = _binomial(synonym)
            if name and name != target and name not in accepted:
                claims.setdefault(name, set()).add(target)

    mapping = {name: next(iter(targets))
               for name, targets in claims.items() if len(targets) == 1}
    for source, target in SYNONYM_BLOCKLIST:
        if mapping.get(source) == target:
            del mapping[source]
    for source, target in SYNONYM_ADDITIONS.items():
        if target in accepted:
            mapping[source] = target
    return mapping


def unify_synonyms(df: pd.DataFrame):
    """
    Give every row a species key. Rows without ECOCROP data whose name is a
    known synonym get the key of the matching ECOCROP species, so the merge
    step joins them.

    Returns:
        (dataframe with a "_species_key" column, list of joined name pairs)
    """
    df = df.copy()
    mapping = synonym_map(df)
    keys = df["canonical_binomial"].fillna(df["scientific_name"]).str.lower().str.strip()
    remapped = keys.map(mapping)
    use = df["ecocrop_scientific_name"].isna() & remapped.notna()
    df["_species_key"] = keys.where(~use, remapped)
    unified = sorted({(key, mapping[key]) for key in keys[use]})
    return df, unified


# --------------------------------------------------------------------------- #
# Step 4 - merge rows of the same species
# --------------------------------------------------------------------------- #

def _first_non_null(series: pd.Series):
    for value in series:
        if value is not None and not (isinstance(value, float) and pd.isna(value)) and value != "":
            return value
    return None


def _merge_group(group: pd.DataFrame) -> pd.Series:
    """
    Combine all rows of one species into a single row.

    For most columns we take the first value that is not empty. This also
    fills gaps, because a variety row often has a value (such as height)
    that the main plant row is missing.

    The edible flag is combined with OR: if any row says the plant is
    edible, the species is edible. Taking only the first value was wrong,
    because the first row often had an empty edible field, and peach, fig
    and walnut lost their edible flag that way.
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

    # Keep the names of all varieties, for example "Tomato; Roma; Cherry".
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
    """Group the rows by species key and merge each group into one row."""
    df = df.copy()
    if "_species_key" not in df.columns:
        df["_species_key"] = (
            df["canonical_binomial"].fillna(df["scientific_name"]).str.lower().str.strip()
        )
    df = df[df["_species_key"].notna() & (df["_species_key"] != "")]

    grouped = df.groupby("_species_key", sort=False).apply(_merge_group)
    return grouped.reset_index(drop=True)


# --------------------------------------------------------------------------- #
# Step 5 - fix inverted climate ranges
# --------------------------------------------------------------------------- #

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
    Swap any (min, max) pair where the minimum is larger than the maximum,
    and write what was changed in the "repairs_applied" column.

    For example, a record with rain_opt_min = 7000 and rain_opt_max = 2000
    would give wrong results for every location. One real case is Acorus
    calamus. The fix is done in code, not by hand, so it can be seen and
    repeated.
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


# --------------------------------------------------------------------------- #
# Step 6 - crop groups for the app
# --------------------------------------------------------------------------- #

CROP_GROUPS = ("leafy_herb", "fruiting", "root", "legume", "fruit_tree", "other")


def _parts(row) -> set:
    """The edible parts of a plant as a set, e.g. {"fruit", "leaves"}."""
    text = _to_null(row.get("edible_parts_raw")) or ""
    return {part.strip().lower() for part in text.split(",") if part.strip()}


def rule_crop_group(row) -> str:
    """
    Decide the crop group from the main reason the plant is grown.

    These are the groups used by the app filter, and the same groups we
    asked about in the questionnaire: leafy greens and herbs, fruiting
    vegetables, roots, legumes and fruit trees.

    We do not use ethmar_category for this, because it calls a plant a root
    crop whenever "Root" is anywhere in its edible parts, which is wrong for
    okra, pumpkin and celery. Here the fruit is checked first, then
    ECOCROP's roots/tubers label, and a root only counts when no leaves are
    listed.
    """
    category = _to_null(row.get("ethmar_category")) or ""
    ecocrop = (_to_null(row.get("ecocrop_category")) or "").lower()
    lifespan = (_to_null(row.get("ecocrop_lifespan")) or "").lower()
    form = (_to_null(row.get("ecocrop_life_form")) or "").lower()
    parts = _parts(row)
    woody = lifespan == "perennial" and ("tree" in form or "shrub" in form)

    if category in {"fruit_tree", "nut"}:
        return "fruit_tree"
    if category == "legume":
        return "legume"
    if "fruit" in parts:
        return "fruit_tree" if woody else "fruiting"
    if "roots/tubers" in ecocrop:
        return "root"
    if ("root" in parts or "tuber" in parts) and "leaves" not in parts:
        return "root"
    if category in {"herb", "vegetable"} or "leaves" in parts:
        return "leafy_herb"
    if "root" in parts:
        return "root"
    return "other"


def _load_common_crops() -> pd.DataFrame | None:
    """Read and check the reviewed list of common home crops."""
    if not COMMON_CROPS_PATH.exists():
        return None
    common = pd.read_csv(COMMON_CROPS_PATH, comment="#")
    unknown = set(common["crop_group"]) - set(CROP_GROUPS)
    if unknown:
        raise ValueError(f"unknown crop_group in {COMMON_CROPS_PATH.name}: {unknown}")
    duplicated = common["canonical_binomial"][common["canonical_binomial"].duplicated()]
    if len(duplicated):
        raise ValueError(f"duplicate crops in {COMMON_CROPS_PATH.name}: {list(duplicated)}")
    return common


def add_crop_groups(df: pd.DataFrame) -> pd.DataFrame:
    """
    Add four columns: crop_group, is_common, name_ar and home_garden.

    For the crops in ml/artifacts/common_crops.csv, the reviewed group,
    English name and Arabic name replace the automatic ones, and is_common
    is set to 1. The model uses is_common to rank common crops (such as
    tomato) above wild plants that need a similar climate.
    """
    df = df.copy()
    df["crop_group"] = df.apply(rule_crop_group, axis=1)
    df["is_common"] = 0
    df["name_ar"] = None

    common = _load_common_crops()
    if common is not None:
        lookup = common.set_index("canonical_binomial")
        match = df["canonical_binomial"].isin(lookup.index)
        names = df.loc[match, "canonical_binomial"]
        df.loc[match, "crop_group"] = names.map(lookup["crop_group"]).values
        df.loc[match, "name_ar"] = names.map(lookup["name_ar"]).values
        # Permapeople sometimes uses the Latin name as the common name
        # (for example "Cucumis melo"), so the reviewed English name is used.
        df.loc[match, "common_name"] = names.map(lookup["name_en"]).values
        df.loc[match, "is_common"] = 1

    prosy = df["ecocrop_prosy"].fillna("")
    df["home_garden"] = prosy.str.contains("home garden", case=False).astype(int)
    return df


def missing_common_crops(recommendable: pd.DataFrame) -> list:
    """Return the reviewed crops that are not in the recommendation table."""
    common = _load_common_crops()
    if common is None:
        return []
    return sorted(set(common["canonical_binomial"]) - set(recommendable["canonical_binomial"]))


# --------------------------------------------------------------------------- #
# Step 7 - split into the two tables
# --------------------------------------------------------------------------- #

def _has_climate(row: pd.Series) -> bool:
    """A plant can only be matched to a location if it has temperature and rain ranges."""
    temp_ok = pd.notna(row["ecocrop_temp_opt_min_c"]) and pd.notna(
        row["ecocrop_temp_opt_max_c"]
    )
    rain_ok = pd.notna(row["ecocrop_rain_opt_min_mm"]) and pd.notna(
        row["ecocrop_rain_opt_max_mm"]
    )
    return bool(temp_ok and rain_ok)


def split_tables(df: pd.DataFrame):
    """
    Put each species in the recommendation table or the reference table.

    A species is recommendable only if it is productive, edible and has
    climate data. If its pH range is missing, a neutral range (6.0-7.0) is
    used and ph_imputed is set to 1, so the model can lower its score a
    little.

    Returns:
        (recommendable, reference, counts of exclusion reasons, number of imputed pH)
    """
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
# Report and main
# --------------------------------------------------------------------------- #

def print_report(raw_count, normalized, merged, recommendable, reference, reasons,
                 ph_imputed, unified=(), missing=()):
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
    print("Recommendable - crop group")
    for group, count in recommendable["crop_group"].value_counts().items():
        print(f"  {group:<22}: {count}")
    print(f"  common (reviewed list): {int(recommendable['is_common'].sum())}")
    print("-" * 62)
    print("Recommendable - edible evidence")
    for evidence, count in recommendable["edible_evidence"].value_counts().items():
        print(f"  {evidence:<22}: {count}")
    print("-" * 62)
    print(f"Synonyms unified        : {len(unified)}")
    for source, target in unified:
        print(f"  {source} -> {target}")
    if missing:
        print("-" * 62)
        print("WARNING - reviewed common crops missing from recommendable:")
        for name in missing:
            print(f"  {name}")
    print("=" * 62)


def main() -> int:
    if not RAW_PATH.exists():
        print(f"ERROR: raw dataset not found at {RAW_PATH}", file=sys.stderr)
        print("Place ethmar_master_dataset.csv in data/raw/ first.", file=sys.stderr)
        return 1

    PROCESSED_DIR.mkdir(parents=True, exist_ok=True)

    df = load_and_normalize(RAW_PATH)
    raw_count = len(df)
    normalized = df.copy()

    df = df.apply(classify, axis=1)
    df, unified = unify_synonyms(df)
    merged = merge_species(df)
    merged = repair_envelopes(merged)
    merged = add_crop_groups(merged)

    recommendable, reference, reasons, ph_imputed = split_tables(merged)
    missing = missing_common_crops(recommendable)

    # Remove the helper columns before saving.
    internal = {"_edible_raw", "_species_key"}
    recommendable = recommendable.drop(columns=[c for c in internal if c in recommendable])
    reference = reference.drop(columns=[c for c in internal if c in reference])

    recommendable.to_csv(RECOMMENDABLE_PATH, index=False)
    reference.to_csv(REFERENCE_PATH, index=False)

    print_report(raw_count, normalized, merged, recommendable, reference, reasons,
                 ph_imputed, unified, missing)
    print(f"\nwritten: {RECOMMENDABLE_PATH}")
    print(f"written: {REFERENCE_PATH}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

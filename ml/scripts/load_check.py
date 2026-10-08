"""
Ethmar - quality checks for the cleaned recommendation table.

Run this script after clean_dataset.py. It checks that the table in
data/processed/ is safe for the recommendation model to use, and prints
PASS, WARN or FAIL for each check. The script ends with exit code 1 if any
check fails, so it can also be used in an automatic test.

Usage:
    python ml/scripts/load_check.py
"""

from __future__ import annotations

import sys
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
PROCESSED_DIR = ROOT / "data" / "processed"
RECOMMENDABLE_PATH = PROCESSED_DIR / "ethmar_recommendable.csv"
REFERENCE_PATH = PROCESSED_DIR / "ethmar_reference.csv"
COMMON_CROPS_PATH = ROOT / "ml" / "artifacts" / "common_crops.csv"

# Columns that scoring.py reads. Each one is checked for missing values.
MODEL_COLUMNS = [
    "ecocrop_temp_opt_min_c", "ecocrop_temp_opt_max_c",
    "ecocrop_temp_abs_min_c", "ecocrop_temp_abs_max_c", "ecocrop_ktmp",
    "ecocrop_rain_opt_min_mm", "ecocrop_rain_opt_max_mm",
    "ecocrop_rain_abs_min_mm", "ecocrop_rain_abs_max_mm",
    "ecocrop_ph_opt_min", "ecocrop_ph_opt_max",
    "ecocrop_ph_abs_min", "ecocrop_ph_abs_max",
    "ecocrop_gmin", "ecocrop_lifespan", "ecocrop_life_form",
    "light_full_sun", "light_partial_sun_shade", "light_full_shade",
    "water_dry", "water_moist", "water_wet",
    "soil_light_sandy", "soil_medium", "soil_heavy_clay",
    "crop_group", "is_common", "home_garden", "edible",
]

# Ranges that must have min <= max.
ORDERED_PAIRS = [
    ("ecocrop_temp_opt_min_c", "ecocrop_temp_opt_max_c"),
    ("ecocrop_temp_abs_min_c", "ecocrop_temp_abs_max_c"),
    ("ecocrop_rain_opt_min_mm", "ecocrop_rain_opt_max_mm"),
    ("ecocrop_rain_abs_min_mm", "ecocrop_rain_abs_max_mm"),
    ("ecocrop_ph_opt_min", "ecocrop_ph_opt_max"),
    ("ecocrop_ph_abs_min", "ecocrop_ph_abs_max"),
    ("ecocrop_gmin", "ecocrop_gmax"),
]

# Values outside these limits are probably data entry errors.
RANGES = {
    "ecocrop_temp_opt_min_c": (-15, 45),
    "ecocrop_temp_opt_max_c": (-5, 55),
    "ecocrop_temp_abs_min_c": (-40, 40),
    "ecocrop_temp_abs_max_c": (0, 60),
    "ecocrop_rain_opt_min_mm": (0, 5000),
    "ecocrop_rain_opt_max_mm": (50, 10000),
    "ecocrop_rain_abs_min_mm": (0, 4000),
    "ecocrop_rain_abs_max_mm": (100, 12000),
    "ecocrop_ph_opt_min": (2.5, 9.5),
    "ecocrop_ph_opt_max": (3.0, 10.0),
    "ecocrop_ph_abs_min": (2.0, 9.5),
    "ecocrop_ph_abs_max": (3.0, 10.5),
}

CROP_GROUPS = {"leafy_herb", "fruiting", "root", "legume", "fruit_tree", "other"}

PASS, WARN, FAIL = "PASS", "WARN", "FAIL"
_all_findings: list = []


def run_section(title: str, df: pd.DataFrame, *checks) -> None:
    """Run a group of checks, print the results and keep them for the summary."""
    findings: list = []

    def record(level: str, name: str, detail: str) -> None:
        findings.append((level, name, detail))

    for check in checks:
        check(df, record)

    print()
    print("=" * 74)
    print(title)
    print("=" * 74)
    for level, name, detail in findings:
        print(f"[{level}] {name:<40} {detail}")
    print("-" * 74)

    _all_findings.extend(findings)


def check_shape(df: pd.DataFrame, record) -> None:
    record(PASS, "shape", f"{len(df)} species x {df.shape[1]} columns")
    if len(df) == 0:
        record(FAIL, "empty table", "no rows loaded")


def check_duplicates(df: pd.DataFrame, record) -> None:
    count = int(df["canonical_binomial"].duplicated().sum())
    if count:
        record(FAIL, "duplicate species", f"{count} rows share a canonical_binomial")
    else:
        record(PASS, "duplicate species", "none")


def check_missing(df: pd.DataFrame, record) -> None:
    """How many rows have a value in each column that the model uses."""
    for column in MODEL_COLUMNS:
        if column not in df.columns:
            record(FAIL, "missing column", f"{column} is not in the table")
            continue
        coverage = 100 - df[column].isna().mean() * 100
        if coverage == 100:
            record(PASS, f"coverage {column}", "100%")
        elif coverage > 80:
            record(PASS, f"coverage {column}", f"{coverage:.1f}%")
        elif coverage > 40:
            record(WARN, f"coverage {column}", f"{coverage:.1f}% - sparse")
        else:
            record(WARN, f"coverage {column}", f"{coverage:.1f}% - mostly empty")


def check_envelopes(df: pd.DataFrame, record) -> None:
    """Every range must have min <= max (clean_dataset.py repairs this)."""
    for low, high in ORDERED_PAIRS:
        if low not in df.columns or high not in df.columns:
            continue
        both = df[[low, high]].dropna()
        inverted = both[both[low] > both[high]]
        if len(inverted):
            record(FAIL, f"envelope {low}", f"{len(inverted)} rows have min > max")
        else:
            record(PASS, f"envelope {low}", "all min <= max")


def check_ranges(df: pd.DataFrame, record) -> None:
    for column, (low, high) in RANGES.items():
        if column not in df.columns:
            continue
        values = df[column].dropna()
        outside = values[(values < low) | (values > high)]
        if len(outside):
            record(WARN, f"range {column}", f"{len(outside)} values outside [{low}, {high}]")
        else:
            record(PASS, f"range {column}", "within plausible bounds")


def check_classification(df: pd.DataFrame, record) -> None:
    """Every crop must be edible and have a valid crop group."""
    missing = int((df["edible"] != 1).sum())
    if missing:
        record(FAIL, "edible confirmation", f"{missing} species are not confirmed edible")
    else:
        record(PASS, "edible confirmation", "all species confirmed edible")

    invalid = sorted(set(df["crop_group"].dropna()) - CROP_GROUPS)
    if invalid or df["crop_group"].isna().any():
        record(FAIL, "crop group", f"invalid or empty values: {invalid}")
    else:
        record(PASS, "crop group", f"{df['crop_group'].nunique()} groups")

    low = int((df["category_confidence"] == "low").sum())
    if low:
        record(WARN, "category confidence", f"{low} low-confidence rows")
    else:
        record(PASS, "category confidence", "all high")

    record(PASS, "imputed pH", f"{int((df['ph_imputed'] == 1).sum())} species")


def check_common_crops(df: pd.DataFrame, record) -> None:
    """Every crop in the reviewed list must be in the table and have an Arabic name."""
    if not COMMON_CROPS_PATH.exists():
        record(WARN, "common crops", f"{COMMON_CROPS_PATH.name} not found")
        return
    common = pd.read_csv(COMMON_CROPS_PATH, comment="#")
    missing = sorted(set(common["canonical_binomial"]) - set(df["canonical_binomial"]))
    if missing:
        record(FAIL, "common crops present", f"missing: {missing}")
    else:
        record(PASS, "common crops present", f"all {len(common)} found")

    flagged = df[df["is_common"] == 1]
    no_arabic = int(flagged["name_ar"].isna().sum())
    if no_arabic:
        record(FAIL, "arabic names", f"{no_arabic} common crops have no Arabic name")
    else:
        record(PASS, "arabic names", f"{len(flagged)} common crops named")


def check_tolerance_profile(df: pd.DataFrame, record) -> None:
    """How many crops can stand a hot, dry, alkaline climate such as Riyadh."""
    heat = df["ecocrop_temp_abs_max_c"] >= 40
    arid = df["ecocrop_rain_abs_min_mm"] <= 250
    alkaline = df["ecocrop_ph_abs_max"] >= 8.0
    all_three = heat & arid & alkaline

    record(PASS, "tolerates >= 40C", f"{int(heat.sum())} species")
    record(PASS, "tolerates <= 250mm rain", f"{int(arid.sum())} species")
    record(PASS, "tolerates pH >= 8.0", f"{int(alkaline.sum())} species")
    level = PASS if int(all_three.sum()) >= 25 else WARN
    record(level, "all three (arid/hot/alkaline)", f"{int(all_three.sum())} species")


def summary() -> int:
    fails = [f for f in _all_findings if f[0] == FAIL]
    warns = [f for f in _all_findings if f[0] == WARN]
    passes = [f for f in _all_findings if f[0] == PASS]

    print()
    print("=" * 74)
    print(f"SUMMARY   pass={len(passes)}   warn={len(warns)}   fail={len(fails)}")
    print("=" * 74)

    for _, name, detail in fails:
        print(f"  FAIL  {name}: {detail}")
    for _, name, detail in warns:
        print(f"  WARN  {name}: {detail}")

    if not fails:
        print("\nNo blocking problems. The table is safe to use.")
    else:
        print(f"\n{len(fails)} blocking problem(s). Fix them before using the table.")
    return 1 if fails else 0


def main() -> int:
    if not RECOMMENDABLE_PATH.exists():
        print(f"ERROR: {RECOMMENDABLE_PATH} not found.", file=sys.stderr)
        print("Run ml/scripts/clean_dataset.py first.", file=sys.stderr)
        return 1

    df = pd.read_csv(RECOMMENDABLE_PATH)
    print(f"loaded {RECOMMENDABLE_PATH}")

    _all_findings.clear()

    run_section("TABLE INTEGRITY", df, check_shape, check_duplicates)
    run_section("MODEL COLUMN COVERAGE", df, check_missing)
    run_section("RANGE INTEGRITY", df, check_envelopes, check_ranges)
    run_section("CLASSIFICATION", df, check_classification, check_common_crops)
    run_section("CLIMATE TOLERANCE PROFILE", df, check_tolerance_profile)

    if REFERENCE_PATH.exists():
        ref = pd.read_csv(REFERENCE_PATH, low_memory=False)
        print()
        print(f"reference table: {len(ref)} species x {ref.shape[1]} columns")

    return summary()


if __name__ == "__main__":
    raise SystemExit(main())

"""
Ethmar — sanity checks for the cleaned recommendation tables.

Run this before any training or matching work. It answers one question: is the
data in data/processed/ actually safe to build on?

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

MATCHER_COLUMNS = [
    "ecocrop_temp_opt_min_c", "ecocrop_temp_opt_max_c",
    "ecocrop_temp_abs_min_c", "ecocrop_temp_abs_max_c",
    "ecocrop_rain_opt_min_mm", "ecocrop_rain_opt_max_mm",
    "ecocrop_rain_abs_min_mm", "ecocrop_rain_abs_max_mm",
    "ecocrop_ph_opt_min", "ecocrop_ph_opt_max",
    "ecocrop_ph_abs_min", "ecocrop_ph_abs_max",
    "ecocrop_cliz", "ecocrop_ktmp", "ecocrop_gmin", "ecocrop_gmax",
    "hardiness_zone_min", "hardiness_zone_max",
    "light_full_sun", "water_moist",
    "ethmar_category", "edible", "life_cycle_raw",
]

ORDERED_PAIRS = [
    ("ecocrop_temp_opt_min_c", "ecocrop_temp_opt_max_c"),
    ("ecocrop_temp_abs_min_c", "ecocrop_temp_abs_max_c"),
    ("ecocrop_rain_opt_min_mm", "ecocrop_rain_opt_max_mm"),
    ("ecocrop_rain_abs_min_mm", "ecocrop_rain_abs_max_mm"),
    ("ecocrop_ph_opt_min", "ecocrop_ph_opt_max"),
    ("ecocrop_ph_abs_min", "ecocrop_ph_abs_max"),
    ("hardiness_zone_min", "hardiness_zone_max"),
    ("ecocrop_gmin", "ecocrop_gmax"),
]

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
    "hardiness_zone_min": (1, 13),
    "hardiness_zone_max": (1, 13),
}

PASS, WARN, FAIL = "PASS", "WARN", "FAIL"
_all_findings: list = []


def run_section(title: str, df: pd.DataFrame, *checks) -> None:
    """Run a group of checks against df, print them, and keep findings."""
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
    for column in MATCHER_COLUMNS:
        if column not in df.columns:
            record(FAIL, "missing column", f"{column} absent from the table")
            continue
        rate = df[column].isna().mean() * 100
        coverage = 100 - rate
        if rate == 0:
            record(PASS, f"coverage {column}", "100%")
        elif rate < 20:
            record(PASS, f"coverage {column}", f"{coverage:.1f}%")
        elif rate < 60:
            record(WARN, f"coverage {column}", f"{coverage:.1f}% - sparse")
        else:
            record(WARN, f"coverage {column}", f"{coverage:.1f}% - mostly empty")


def check_envelopes(df: pd.DataFrame, record) -> None:
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


def check_category_and_evidence(df: pd.DataFrame, record) -> None:
    if "ethmar_category" in df.columns:
        unknown = int(df["ethmar_category"].isna().sum() + (df["ethmar_category"] == "unknown").sum())
        if unknown:
            record(WARN, "category assignment", f"{unknown} species unclassified")
        else:
            record(PASS, "category assignment", f"{df['ethmar_category'].nunique()} categories")

    if "edible" in df.columns:
        missing = int((df["edible"] != 1).sum())
        if missing:
            record(FAIL, "edible confirmation", f"{missing} species lack edibility")
        else:
            record(PASS, "edible confirmation", "all species confirmed edible")

    if "category_confidence" in df.columns:
        low = int((df["category_confidence"] == "low").sum())
        if low:
            record(WARN, "category confidence", f"{low} low-confidence rows in the model table")
        else:
            record(PASS, "category confidence", "all high")

    if "ph_imputed" in df.columns:
        record(PASS, "imputed pH", f"{int((df['ph_imputed'] == 1).sum())} species")


def check_tolerance_profile(df: pd.DataFrame, record) -> None:
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
        print("\nNo blocking problems. The table is safe to build on.")
    else:
        print(f"\n{len(fails)} blocking problem(s). Fix these before building the matcher.")
    return 1 if fails else 0


def main() -> int:
    if not RECOMMENDABLE_PATH.exists():
        print(f"ERROR: {RECOMMENDABLE_PATH} not found.", file=sys.stderr)
        print("Run ml/scripts/clean_dataset.py first.", file=sys.stderr)
        return 1

    df = pd.read_csv(RECOMMENDABLE_PATH)
    print(f"loaded {RECOMMENDABLE_PATH}")
    print(f"columns: {len(df.columns)}")

    _all_findings.clear()

    run_section("TABLE INTEGRITY", df, check_shape, check_duplicates)
    run_section("MATCHER COLUMN COVERAGE", df, check_missing)
    run_section("ENVELOPE INTEGRITY", df, check_envelopes, check_ranges)
    run_section("CLASSIFICATION", df, check_category_and_evidence)
    run_section("CLIMATE TOLERANCE PROFILE", df, check_tolerance_profile)

    if REFERENCE_PATH.exists():
        ref = pd.read_csv(REFERENCE_PATH)
        print()
        print(f"reference table: {len(ref)} species x {ref.shape[1]} columns")

    return summary()


if __name__ == "__main__":
    raise SystemExit(main())

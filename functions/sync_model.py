"""
Copy the recommendation model into the functions folder.

Firebase only uploads the functions/ folder, but the model lives in ml/ and
data/. This script copies the files the Cloud Function needs into
functions/ethmar_model/. That folder is a generated copy and is not saved in
Git; edit the originals in ml/ and data/, never the copies.

Note: the API that is used now runs on Vercel (api/index.py), which reads
the original files directly. This script is only needed for Firebase.

firebase.json runs this script automatically before every deploy. Run it by
hand before starting the emulator:
    python functions/sync_model.py
"""

import shutil
import sys
from pathlib import Path

FUNCTIONS_DIR = Path(__file__).resolve().parent
ROOT = FUNCTIONS_DIR.parent
TARGET = FUNCTIONS_DIR / "ethmar_model"

FILES = [
    ROOT / "ml" / "scripts" / "climate.py",
    ROOT / "ml" / "scripts" / "scoring.py",
    ROOT / "ml" / "scripts" / "service.py",
    ROOT / "ml" / "artifacts" / "scoring_config.json",
    ROOT / "data" / "processed" / "ethmar_recommendable.csv",
]


def main() -> int:
    missing = [str(path) for path in FILES if not path.exists()]
    if missing:
        print("ERROR: missing model files:", *missing, sep="\n  ", file=sys.stderr)
        print("Run ml/scripts/clean_dataset.py first.", file=sys.stderr)
        return 1

    TARGET.mkdir(exist_ok=True)
    for path in FILES:
        shutil.copy2(path, TARGET / path.name)
        print(f"copied {path.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

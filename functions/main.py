"""
Ethmar - Firebase Cloud Functions.

recommend_crops
---------------
A callable function that the Flutter app calls to get crop recommendations.
The user must be signed in with Firebase Authentication.

Request (all fields go in the data map of the call):
    latitude      number, required
    longitude     number, required
    month         1-12, required (the user's current month on the phone)
    sunlight      "full" | "partial" | "shade"     (default "full")
    water         "low" | "medium" | "high"         (default "medium")
    soil_texture  "sandy" | "medium" | "clay"       (default "medium")
    groups        list of crop groups to keep, e.g. ["leafy_herb"] (optional)
    limit         how many crops to return, 1-1000  (default 50)
    offset        how many crops to skip, for paging (default 0)

Response:
    month, location (centre of the ~11 km area), soil_ph,
    total (number of crops that can be grown), total_now,
    offset, results (list of crops, see scoring.Recommendation.to_dict)

The model code is copied into ethmar_model/ by sync_model.py.
"""

import sys
from pathlib import Path

from firebase_admin import firestore, initialize_app
from firebase_functions import https_fn, options

MODEL_DIR = Path(__file__).resolve().parent / "ethmar_model"
sys.path.insert(0, str(MODEL_DIR))

import climate  # noqa: E402  (imported after the path is set)
import scoring  # noqa: E402

initialize_app()

# me-central1 (Doha) is the same region as the project's Firestore database.
options.set_global_options(region="me-central1", max_instances=10)

CACHE_COLLECTION = "climate_cache"
DEFAULT_LIMIT = 50
MAX_LIMIT = 1000


class FirestoreCache:
    """
    Climate cache stored in Firestore, one document per ~11 km area.
    It has the same get() and set() methods as climate.FileCache.
    Only this function reads and writes the collection.
    """

    def __init__(self, client):
        self.collection = client.collection(CACHE_COLLECTION)

    def get(self, key: str):
        document = self.collection.document(key).get()
        return document.to_dict() if document.exists else None

    def set(self, key: str, data: dict) -> None:
        self.collection.document(key).set(data)


def _error(code, message: str):
    return https_fn.HttpsError(code=code, message=message)


def _number(data: dict, name: str) -> float:
    value = data.get(name)
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise _error(https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
                     f"{name} must be a number")
    return float(value)


def _integer(data: dict, name: str, default: int, low: int, high: int) -> int:
    value = data.get(name, default)
    if isinstance(value, bool) or not isinstance(value, int) or not low <= value <= high:
        raise _error(https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
                     f"{name} must be a whole number between {low} and {high}")
    return value


@https_fn.on_call(memory=options.MemoryOption.MB_512, timeout_sec=120)
def recommend_crops(req: https_fn.CallableRequest) -> dict:
    """Return the crops that can be grown at the user's location."""
    if req.auth is None:
        raise _error(https_fn.FunctionsErrorCode.UNAUTHENTICATED,
                     "You must be signed in to get recommendations.")

    data = req.data if isinstance(req.data, dict) else {}

    # 1. Read and check the request.
    latitude = _number(data, "latitude")
    longitude = _number(data, "longitude")
    if "month" not in data:
        raise _error(https_fn.FunctionsErrorCode.INVALID_ARGUMENT, "month is required")
    month = _integer(data, "month", 0, 1, 12)
    limit = _integer(data, "limit", DEFAULT_LIMIT, 1, MAX_LIMIT)
    offset = _integer(data, "offset", 0, 0, 100000)

    groups = data.get("groups")
    if groups is not None and (not isinstance(groups, list)
                               or not all(isinstance(g, str) for g in groups)):
        raise _error(https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
                     "groups must be a list of text values")

    try:
        site = scoring.Site(
            sunlight=data.get("sunlight", "full"),
            water=data.get("water", "medium"),
            soil_texture=data.get("soil_texture", "medium"),
        )
    except ValueError as exc:
        raise _error(https_fn.FunctionsErrorCode.INVALID_ARGUMENT, str(exc))

    # 2. Get the climate of the area (from the cache when possible).
    try:
        profile = climate.lookup(latitude, longitude,
                                 cache=FirestoreCache(firestore.client()))
    except ValueError as exc:
        raise _error(https_fn.FunctionsErrorCode.INVALID_ARGUMENT, str(exc))
    except Exception as exc:  # a climate service is down or too slow
        print(f"climate lookup failed for area {round(latitude, 1)}, "
              f"{round(longitude, 1)}: {exc!r}")
        raise _error(https_fn.FunctionsErrorCode.UNAVAILABLE,
                     "Climate data is not available right now. Please try again later.")

    # 3. Score the crops.
    results = scoring.recommend(
        profile, month, site,
        preferences=scoring.Preferences(groups=groups),
        table=scoring.load_table(MODEL_DIR / "ethmar_recommendable.csv"),
        config=scoring.load_config(MODEL_DIR / "scoring_config.json"),
    )

    return {
        "month": month,
        "location": {"latitude": profile.latitude, "longitude": profile.longitude},
        "soil_ph": profile.soil_ph,
        "total": len(results),
        "total_now": sum(1 for r in results if r.status == "now"),
        "offset": offset,
        "results": [r.to_dict() for r in results[offset:offset + limit]],
    }

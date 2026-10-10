"""
Ethmar - request handling for the recommendation API.

This module checks a request from the mobile app, runs the climate lookup
and the recommendation model, and builds the response. It does not depend on
any hosting platform, so the same code is used by:

    api/index.py         the server on Vercel (used now)
    functions/main.py    a Firebase Cloud Function (if the Blaze plan is enabled)

Request fields:
    latitude      number, required
    longitude     number, required
    month         1-12, required (the user's current month on the phone)
    sunlight      "full" | "partial" | "shade"     (default "full")
    water         "low" | "medium" | "high"         (default "medium")
    soil_texture  "sandy" | "medium" | "clay"       (default "medium")
    groups        list of crop groups to keep, e.g. ["leafy_herb"] (optional)
    limit         how many crops to return, 1-1000  (default 50)
    offset        how many crops to skip, for paging (default 0)

Response fields:
    month, location (centre of the ~11 km area), soil_ph,
    total (number of crops that can be grown), total_now,
    offset, results (list of crops, see scoring.Recommendation.to_dict)
"""

from __future__ import annotations

from pathlib import Path

import climate
import scoring

DEFAULT_LIMIT = 50
MAX_LIMIT = 1000
CACHE_COLLECTION = "climate_cache"


class FirestoreCache:
    """
    Climate cache stored in Firestore, one document per ~11 km area. It has
    the same get() and set() methods as climate.FileCache. Only the server
    reads and writes this collection; the Firestore security rules should
    block the app from it.

    Parameters:
        client  a Firestore client from firebase_admin.firestore.client()
    """

    def __init__(self, client):
        self.collection = client.collection(CACHE_COLLECTION)

    def get(self, key: str):
        document = self.collection.document(key).get()
        return document.to_dict() if document.exists else None

    def set(self, key: str, data: dict) -> None:
        self.collection.document(key).set(data)


class RequestError(Exception):
    """
    A problem with the request or with a climate service.

    status is one of: "INVALID_ARGUMENT" (the app sent a wrong value) or
    "UNAVAILABLE" (a climate service is down; the app can try again later).
    """

    def __init__(self, status: str, message: str):
        super().__init__(message)
        self.status = status
        self.message = message


def _invalid(message: str) -> RequestError:
    return RequestError("INVALID_ARGUMENT", message)


def _number(data: dict, name: str) -> float:
    value = data.get(name)
    # bool is a subclass of int in Python, so it is rejected on purpose.
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise _invalid(f"{name} must be a number")
    return float(value)


def _integer(data: dict, name: str, default: int, low: int, high: int) -> int:
    value = data.get(name, default)
    if isinstance(value, bool) or not isinstance(value, int) or not low <= value <= high:
        raise _invalid(f"{name} must be a whole number between {low} and {high}")
    return value


def recommend_crops(data, cache, model_dir: Path | None = None) -> dict:
    """
    Handle one recommendation request.

    Parameters:
        data       the request fields as a dict (see the top of this file)
        cache      where climate profiles are saved (FileCache or a Firestore cache)
        model_dir  folder that holds ethmar_recommendable.csv and
                   scoring_config.json; the default project files if None

    Returns:
        The response as a dict, ready to be sent as JSON.

    Raises:
        RequestError if the request is wrong or the climate data is not available.
    """
    if not isinstance(data, dict):
        raise _invalid("the request must be a JSON object")

    # 1. Read and check the request.
    latitude = _number(data, "latitude")
    longitude = _number(data, "longitude")
    if "month" not in data:
        raise _invalid("month is required")
    month = _integer(data, "month", 0, 1, 12)
    limit = _integer(data, "limit", DEFAULT_LIMIT, 1, MAX_LIMIT)
    offset = _integer(data, "offset", 0, 0, 100000)

    groups = data.get("groups")
    if groups is not None and (not isinstance(groups, list)
                               or not all(isinstance(g, str) for g in groups)):
        raise _invalid("groups must be a list of text values")

    try:
        site = scoring.Site(
            sunlight=data.get("sunlight", "full"),
            water=data.get("water", "medium"),
            soil_texture=data.get("soil_texture", "medium"),
        )
    except ValueError as exc:
        raise _invalid(str(exc))

    # 2. Get the climate of the area (from the cache when possible).
    try:
        profile = climate.lookup(latitude, longitude, cache=cache)
    except ValueError as exc:
        raise _invalid(str(exc))
    except Exception as exc:  # a climate service is down or too slow
        # Only the rounded area is logged, never the user's exact location.
        print(f"climate lookup failed for area {round(latitude, 1)}, "
              f"{round(longitude, 1)}: {exc!r}")
        raise RequestError("UNAVAILABLE",
                           "Climate data is not available right now. "
                           "Please try again later.")

    # 3. Score the crops.
    if model_dir is None:
        table, config = scoring.load_table(), scoring.load_config()
    else:
        table = scoring.load_table(model_dir / "ethmar_recommendable.csv")
        config = scoring.load_config(model_dir / "scoring_config.json")
    results = scoring.recommend(profile, month, site,
                                preferences=scoring.Preferences(groups=groups),
                                table=table, config=config)

    return {
        "month": month,
        "location": {"latitude": profile.latitude, "longitude": profile.longitude},
        "soil_ph": profile.soil_ph,
        "total": len(results),
        "total_now": sum(1 for r in results if r.status == "now"),
        "offset": offset,
        "results": [r.to_dict() for r in results[offset:offset + limit]],
    }

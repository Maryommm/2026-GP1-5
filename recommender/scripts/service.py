"""
Ethmar - request handling for the recommendation API.

This module checks a request from the mobile app, runs the climate lookup
and the recommendation model, and builds the response. It does not depend on
any hosting platform.

Request fields:
    latitude      number, required
    longitude     number, required
    month         1-12, required (the user's current month on the phone)
    planting      "pot" | "ground", required. Pots are filled with bought
                  potting soil, so pH 6.5 is used and the soil of the
                  area is not fetched. "ground" uses the soil pH of the area.
    sunlight      "full" | "partial" | "shade", required (hours of direct sun:
                  6 or more, 3 to 6, less than 3)
    water         "low" | "medium" | "high", required (how often the user will
                  water: weekly or less, a few times a week, daily)
    groups        list of crop groups to keep, e.g. ["leafy_herb"] (optional)
    limit         how many crops to return, 1-1000  (default 50)
    offset        how many crops to skip, for paging (default 0)

Response fields:
    month, location (centre of the ~11 km area),
    climate (this month's average temp_high_c, temp_low_c and rain_mm),
    planting, soil_ph (the pH used for scoring),
    total (number of crops that can be grown), total_now,
    offset, results (list of crops, see scoring.Recommendation.to_dict)
"""

from __future__ import annotations

import climate
import scoring

PLANTING_VALUES = ("pot", "ground")
# Bought potting soil is usually pH 5.5-6.5, whatever the soil of the area.
# 6.5 is the top of that range, close to neutral.
POT_SOIL_PH = 6.5

DEFAULT_LIMIT = 50
MAX_LIMIT = 1000
CACHE_COLLECTION = "climate_cache"


class FirestoreCache:
    """
    Climate cache stored in Firestore, one document per ~11 km area. Only the server
    reads and writes this collection.
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


def recommend_crops(data, cache) -> dict:
    """
    Handle one recommendation request.

    Parameters:
        data       the request fields as a dict (see the top of this file)
        cache      where climate profiles are saved (FileCache or a Firestore cache)

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

    # The user's setup is asked in the app before the recommendations, so
    # these fields are required instead of being guessed.
    planting = data.get("planting")
    if planting not in PLANTING_VALUES:
        raise _invalid('planting is required and must be "pot" or "ground"')
    for name in ("sunlight", "water"):
        if name not in data:
            raise _invalid(f"{name} is required")

    groups = data.get("groups")
    if groups is not None and (not isinstance(groups, list)
                               or not all(isinstance(g, str) for g in groups)):
        raise _invalid("groups must be a list of text values")

    try:
        site = scoring.Site(
            sunlight=data["sunlight"],
            water=data["water"],
            ph=POT_SOIL_PH if planting == "pot" else None,
        )
    except ValueError as exc:
        raise _invalid(str(exc))

    # 2. Get the climate of the area (from the cache when possible).
    try:
        profile = climate.lookup(latitude, longitude, cache=cache,
                                 with_soil=planting == "ground")
    except ValueError as exc:
        raise _invalid(str(exc))
    except Exception as exc:  # a climate service is down or too slow
        # Only the rounded area is logged, never the user's exact location.
        print(f"climate lookup failed for area {round(latitude, 1)}, "
              f"{round(longitude, 1)}: {exc!r}")
        raise RequestError("UNAVAILABLE",
                           "Climate data is not available right now. "
                           "Please try again later.")

    # 3. Score the crops (scoring.py loads the crop table and the settings).
    results = scoring.recommend(profile, month, site,
                                preferences=scoring.Preferences(groups=groups))

    this_month = profile.monthly[month - 1]
    return {
        "month": month,
        "location": {"latitude": profile.latitude, "longitude": profile.longitude},
        "climate": {
            "temp_high_c": round(this_month.temp_high_c, 1),
            "temp_low_c": round(this_month.temp_low_c, 1),
            "rain_mm": round(this_month.rain_mm, 1),
        },
        "planting": planting,
        "soil_ph": site.ph if site.ph is not None else profile.soil_ph,
        "total": len(results),
        "total_now": sum(1 for r in results if r.status == "now"),
        "offset": offset,
        "results": [r.to_dict() for r in results[offset:offset + limit]],
    }

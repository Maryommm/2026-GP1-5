"""
Ethmar - Firebase Cloud Functions (needs the Blaze plan).

This is a second way to host the recommendation API, kept ready in case the
project moves to the Firebase Blaze plan. The API that is used now runs on
Vercel (see api/index.py). Both call the same code in ml/scripts/service.py,
so the request and the response are the same.

recommend_crops is a callable function: the Flutter app calls it with
FirebaseFunctions.httpsCallable, and the user must be signed in.

The model code is copied into ethmar_model/ by sync_model.py.
"""

import sys
from pathlib import Path

from firebase_admin import firestore, initialize_app
from firebase_functions import https_fn, options

MODEL_DIR = Path(__file__).resolve().parent / "ethmar_model"
sys.path.insert(0, str(MODEL_DIR))

import service  # noqa: E402  (imported after the path is set)

initialize_app()

# me-central1 (Doha) is the same region as the project's Firestore database.
options.set_global_options(region="me-central1", max_instances=10)

ERROR_CODES = {
    "INVALID_ARGUMENT": https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
    "UNAVAILABLE": https_fn.FunctionsErrorCode.UNAVAILABLE,
}


@https_fn.on_call(memory=options.MemoryOption.MB_512, timeout_sec=120)
def recommend_crops(req: https_fn.CallableRequest) -> dict:
    """Return the crops that can be grown at the user's location."""
    if req.auth is None:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.UNAUTHENTICATED,
                                  "You must be signed in to get recommendations.")
    try:
        return service.recommend_crops(
            req.data,
            cache=service.FirestoreCache(firestore.client()),
            model_dir=MODEL_DIR,
        )
    except service.RequestError as error:
        raise https_fn.HttpsError(ERROR_CODES[error.status], error.message)

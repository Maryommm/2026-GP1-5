"""
Ethmar - recommendation API on Vercel.

The Flutter app sends a POST request to /api/recommend with a JSON body
(see ml/scripts/service.py for the fields) and the user's Firebase ID token:

    POST /api/recommend
    Authorization: Bearer <Firebase ID token>
    Content-Type: application/json

    {"latitude": 24.71, "longitude": 46.67, "month": 10}

Responses:
    200  the recommendations
    400  INVALID_ARGUMENT  - a wrong value in the request
    401  UNAUTHENTICATED   - missing or invalid sign-in token
    503  UNAVAILABLE       - a climate service is down; try again later
Errors have the form {"error": {"status": "...", "message": "..."}}.

We use Vercel because Firebase Cloud Functions need the Blaze plan. The
server still uses Firebase: Authentication to check the user, and Firestore
to save the climate cache. Both work on the free Spark plan.

Environment variables (set in the Vercel project settings, never in Git):
    FIREBASE_SERVICE_ACCOUNT  the service account key JSON, as one line

Run locally with the Firebase emulators (see README):
    python api/index.py
"""

import json
import os
import sys
from pathlib import Path

import firebase_admin
from firebase_admin import auth, credentials, firestore
from flask import Flask, jsonify, request
from werkzeug.exceptions import HTTPException

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "ml" / "scripts"))

import service  # noqa: E402  (imported after the path is set)

PROJECT_ID = "ethmar-95aaf"

app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"] = 16 * 1024   # requests are small JSON objects

HTTP_STATUS = {"INVALID_ARGUMENT": 400, "UNAUTHENTICATED": 401,
               "INTERNAL": 500, "UNAVAILABLE": 503}

_firestore_client = None


def _init_firebase() -> None:
    """
    Connect to Firebase once. In production the service account key comes
    from an environment variable. With the local emulators no key is needed,
    because the Firebase SDK talks to the emulators instead.
    """
    if firebase_admin._apps:
        return
    key = os.environ.get("FIREBASE_SERVICE_ACCOUNT")
    if key:
        firebase_admin.initialize_app(credentials.Certificate(json.loads(key)))
    elif os.environ.get("FIRESTORE_EMULATOR_HOST"):
        firebase_admin.initialize_app(options={"projectId": PROJECT_ID})
    else:
        raise RuntimeError("FIREBASE_SERVICE_ACCOUNT is not set")


def _firestore():
    """
    Return one Firestore client and reuse it. With the local emulator the
    client needs no real credentials, so anonymous ones are used.
    """
    global _firestore_client
    if _firestore_client is None:
        if os.environ.get("FIRESTORE_EMULATOR_HOST"):
            from google.auth.credentials import AnonymousCredentials
            from google.cloud import firestore as cloud_firestore
            _firestore_client = cloud_firestore.Client(
                project=PROJECT_ID, credentials=AnonymousCredentials())
        else:
            _firestore_client = firestore.client()
    return _firestore_client


def _error(status: str, message: str):
    return jsonify({"error": {"status": status, "message": message}}), HTTP_STATUS[status]


def _signed_in() -> bool:
    """Check the Firebase ID token in the Authorization header."""
    header = request.headers.get("Authorization", "")
    if not header.startswith("Bearer "):
        return False
    try:
        auth.verify_id_token(header[len("Bearer "):])
        return True
    except (ValueError, auth.InvalidIdTokenError, auth.ExpiredIdTokenError,
            auth.RevokedIdTokenError, auth.CertificateFetchError):
        return False


@app.post("/api/recommend")
def recommend():
    _init_firebase()
    if not _signed_in():
        return _error("UNAUTHENTICATED", "You must be signed in to get recommendations.")

    data = request.get_json(silent=True)
    try:
        result = service.recommend_crops(data, cache=service.FirestoreCache(_firestore()))
    except service.RequestError as exc:
        return _error(exc.status, exc.message)
    return jsonify(result)


@app.errorhandler(Exception)
def unexpected_error(exc):
    """
    Any error we did not expect is logged on the server and returned as JSON,
    so the app always receives the same error format. Normal HTTP errors
    (such as 404 for a wrong path, or 413 for a body that is too large) are
    returned as they are.
    """
    if isinstance(exc, HTTPException):
        return exc
    app.logger.exception("unexpected error: %r", exc)
    return _error("INTERNAL", "Something went wrong on the server.")


@app.get("/api/health")
def health():
    """A simple check that the server is running."""
    return jsonify({"status": "ok"})


if __name__ == "__main__":
    # Local testing only. Vercel imports `app` and runs it itself.
    app.run(port=8000)

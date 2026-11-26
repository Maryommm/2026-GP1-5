# Ethmar – إثمار
ETHMAR is a personal agricultural assistant application designed to help, organize, and motivate beginner home farmers globally.

This repository contains the complete source code of the project:

| Folder | What it is | Technology |
| --- | --- | --- |
| [ethmar/](ethmar/) | The mobile app | Flutter (Dart), Firebase Auth, Cloud Firestore |
| [api/](api/) | The recommendation API that the app calls | Python, Flask, deployed on Vercel |
| [recommender/](recommender/) | The data pipeline, the scoring model and the climate lookup | Python, pandas |
| [data/](data/) | The raw crop dataset and the cleaned tables | CSV |
| [workers/profile-images/](workers/profile-images/) | Upload service for profile pictures and Plant Journey photos | TypeScript, Cloudflare Workers, Cloudinary |
| [.github/workflows/](.github/workflows/) | A check that validates the crop table on every push | GitHub Actions |

The API, the Worker and the Firebase project are already deployed. To run
the app you only need the steps in section 1. Sections 2 to 4 are for working
on the other parts.

---

## Requirements

| Tool | Version used | Needed for |
| --- | --- | --- |
| [Flutter SDK](https://docs.flutter.dev/get-started/install) | 3.47 (Dart 3.13) | The app |
| Android Studio with an Android emulator, or an Android phone | Android SDK 35 | Running the app |
| [Python](https://www.python.org/downloads/) | 3.13 | The data pipeline and the API |
| [Node.js](https://nodejs.org/) | 20 or later | The photo Worker (optional) |
| [Firebase CLI](https://firebase.google.com/docs/cli) | latest | Deploying Firestore rules (optional) |

Check Flutter with `flutter doctor`. It should show no errors for Flutter and
the Android toolchain.

---

## 1. Run the mobile app

```bash
git clone https://github.com/Maryommm/2026-GP1-5.git
cd 2026-GP1-5/ethmar
flutter pub get
flutter run
```

- Start an Android emulator first, or connect a phone with USB debugging.
  `flutter devices` lists what is available.
- The Firebase configuration is already included
  (`android/app/google-services.json` and `lib/firebase_options.dart`), so the app
  connects to the project's Firebase without any extra setup.
- The device needs internet: sign-in, the recommendations and the fonts are
  loaded online.
- Recommendations use the device's location. On the emulator, set a location
  first (Extended controls `…` → Location → Set location). Otherwise the app
  says the location is unavailable.
- Sign up with a real email address: the app asks you to verify it before you
  log in.

In VS Code, open the `ethmar` folder, choose a device in the status bar and
press **F5**.


---

## 2. Data pipeline and recommender (Python)

The cleaned crop table that the API uses is already in
`data/processed/ethmar_recommendable.csv`. These steps rebuild it from the raw
dataset and check it.

From the repository root:

```bash
python -m venv .venv
# Windows:      .venv\Scripts\activate
# macOS/Linux:  source .venv/bin/activate

pip install -r requirements.txt -r recommender/requirements.txt
```

| Step | Command | What it does |
| --- | --- | --- |
| 1 | `python recommender/scripts/clean_dataset.py` | Reads `data/raw/ethmar_master_dataset.csv`, merges duplicate species, excludes plants that are not home-growable crops, and writes `data/processed/ethmar_recommendable.csv` and `ethmar_reference.csv` |
| 2 | `python recommender/scripts/load_check.py` | Validates the cleaned table. It ends with exit code 1 if it finds a blocking problem |
| 3 | `python recommender/scripts/scoring.py 24.71 46.67 11` | Prints the top 10 crops for a latitude, longitude and month (the example is Riyadh in November). It needs internet for the climate services |

The first run of step 3 for a place can take up to a minute, because it
downloads 20 years of NASA POWER climate data. The result is saved in
`data/external/climate_cache/`, and later runs for the same area are fast.

The scoring settings (weights, thresholds) are in
[recommender/knowledge/scoring_config.json](recommender/knowledge/scoring_config.json).
The list of commonly grown crops and the Arabic names are in the same folder.

---

## 3. Recommendation API (Flask on Vercel)

The API is deployed at `https://ethmar-lake.vercel.app`:

| Endpoint | Description |
| --- | --- |
| `GET /api/health` | Returns `{"status": "ok"}` when the server is running |
| `POST /api/recommend` | Returns the recommendations. Needs a Firebase ID token (`Authorization: Bearer <token>`), so it is called from the app |

The request and response formats are described at the top of
[api/index.py](api/index.py).

### Run it locally

The server needs a Firebase service account key to check sign-in tokens and
to use the Firestore climate cache. Create one in the Firebase console
(Project settings → Service accounts → Generate new private key). **Never
commit this file.**

```bash
# with the virtual environment from section 2 active
# macOS/Linux:
export FIREBASE_SERVICE_ACCOUNT="$(cat path/to/service-account.json)"
# Windows PowerShell:
$env:FIREBASE_SERVICE_ACCOUNT = Get-Content path\to\service-account.json -Raw

python api/index.py          # http://localhost:8000/api/health
```

To point the app at another server, pass its address when running the app:
`flutter run --dart-define=API_BASE_URL=https://your-server`. Android blocks
plain `http://` addresses by default, so a local server needs an HTTPS
tunnel.

### Deploy on Vercel

1. Import the repository in Vercel. The project root is the repository root;
   [vercel.json](vercel.json) sets up the function and its files.
2. In Settings → Environment Variables, add `FIREBASE_SERVICE_ACCOUNT` with the
   full JSON of the service account key.

---

## 4. Firebase and the photo Worker

**Firestore security rules** are in [ethmar/firestore.rules](ethmar/firestore.rules).
To deploy them:

```bash
cd ethmar
firebase login
firebase deploy --only firestore:rules --project ethmar-95aaf
```

**The photo Worker** has its own setup, tests and deployment steps in
[workers/profile-images/README.md](workers/profile-images/README.md):

```bash
cd workers/profile-images
npm install
npm run check        # type check and tests
```

---

## Continuous integration

[.github/workflows/crop-table-check.yml](.github/workflows/crop-table-check.yml)
runs `load_check.py` on every push and pull request. The check fails if the
crop table has a blocking problem.

# Ethmar – إثمار

Arabic / English gardening app for home farmers. The setup of the whole
project (API, data pipeline, photo Worker) is in the
[main README](../README.md).

## Run it

Requirements: Flutter 3.47 (Dart 3.13) and an Android emulator or phone.

```bash
flutter pub get
flutter run
```

In VS Code: open this `ethmar` folder, pick a device in the status bar, then
press **F5**.

- The Firebase configuration is included (`android/app/google-services.json`,
  `lib/firebase_options.dart`), so no Firebase setup is needed.
- The device needs internet (sign-in, recommendations, fonts).
- On the emulator, set a location (Extended controls → Location) before
  asking for recommendations.
- The app calls the deployed API by default. To use another server:
  `flutter run --dart-define=API_BASE_URL=https://your-server`.

Checks: `flutter analyze` and `flutter test`.

## Project map

```
lib/
  main.dart            app entry, Firebase, language and theme
  models/              plants, care schedules, daily tasks, streak, crops
  services/            Firebase, recommendation API, photos, notifications, location
  screens/             splash, welcome, sign up / log in, home, my plants, daily tasks,
                       virtual farm, crop recommendation, leaderboard, profile…
  widgets/             shared UI parts
  theme/               colors, fonts and text styles
  l10n/app_strings.dart  every sentence in Arabic and English
assets/                icons, images and crop pictures
firestore.rules        Firestore security rules
test/                  unit and widget tests
```

## Arabic & English

There is **one** set of screens. `app_strings.dart` holds every sentence in
both languages, and Flutter flips the whole layout to right-to-left when the
language is Arabic (back arrows, alignment, padding all mirror automatically).
Tap the language pill on the Welcome screen to switch.

To add a new sentence: add the same key to both the `en` and `ar` maps, then
add a getter in class `S`. (`flutter test` checks that both languages have
the same keys.)

## Character illustrations

Put them in `assets/images/` as **PNG with a transparent background**:

| File | Where it shows |
| --- | --- |
| `character_welcome.png` | Welcome hero |
| `character_signup.png` | Sign up header |
| `character_login.png` | Log in header |

Until a file exists, a placeholder "plant buddy" is drawn instead (you may see
an "Unable to load asset" note in the debug console – that's expected).
After adding images, stop the app and run it again (hot reload doesn't pick
up new asset files).

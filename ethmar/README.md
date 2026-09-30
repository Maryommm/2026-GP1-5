# Ethmar – إثمار

Friendly Arabic / English gardening app (IT496).
Screens so far: animated splash → welcome → sign up / log in → temporary home.

## Run it in VS Code

1. Install Flutter and the **Flutter** extension for VS Code (if you haven't).
2. Unzip this folder and open it in VS Code (**File → Open Folder… → ethmar**).
3. Open the terminal in VS Code (**Terminal → New Terminal**) and run:

   ```bash
   flutter create .
   flutter pub get
   ```

   `flutter create .` only adds the missing platform folders (android, ios, web…);
   it does **not** overwrite the code in `lib/`.
4. Start an emulator or plug in your phone, pick it from the bottom-right
   device list, then press **F5** (or run `flutter run`).

> The fonts are downloaded by the `google_fonts` package the first time the app
> runs, so the phone / emulator needs internet.

## Project map

```
lib/
  main.dart                  app entry, language + theme
  theme/app_colors.dart      Red Sea palette
  theme/app_theme.dart       fonts & text styles
  l10n/app_strings.dart      ALL text, Arabic + English
  l10n/locale_controller.dart  current language (Arabic by default)
  screens/                   splash, welcome, sign up, log in, home placeholder
  widgets/                   logo, buttons, text field, doodles, character…
assets/images/               put the character PNGs here
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
| `character_home.png` | Home placeholder |

Until a file exists, a placeholder "plant buddy" is drawn instead (you may see
an "Unable to load asset" note in the debug console – that's expected).
After adding images, stop the app and run it again (hot reload doesn't pick
up new asset files).

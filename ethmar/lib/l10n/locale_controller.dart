import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final ValueNotifier<Locale> appLocale = ValueNotifier(const Locale('ar'));

const _localeKey = 'app_language';
const _supported = ['ar', 'en'];

/// Restores the language saved on this device. Arabic when nothing is saved.
Future<void> loadSavedLocale() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_localeKey);
    if (code != null && _supported.contains(code)) {
      appLocale.value = Locale(code);
    }
  } catch (_) {
    // Keep the default language if storage is unavailable.
  }
}

/// Switches the app language right away and remembers it for next time.
Future<void> setAppLanguage(String code) async {
  if (!_supported.contains(code)) return;
  appLocale.value = Locale(code);
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, code);
  } catch (_) {
    // The language still changes for this session.
  }
}

void toggleLanguage() {
  setAppLanguage(appLocale.value.languageCode == 'ar' ? 'en' : 'ar');
}

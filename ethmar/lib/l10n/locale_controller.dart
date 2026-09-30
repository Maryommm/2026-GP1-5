import 'package:flutter/material.dart';

/// Holds the current app language. Arabic is the default.
/// Changing it rebuilds the whole app and flips the layout direction.
final ValueNotifier<Locale> appLocale = ValueNotifier(const Locale('ar'));

void toggleLanguage() {
  appLocale.value = appLocale.value.languageCode == 'ar'
      ? const Locale('en')
      : const Locale('ar');
}

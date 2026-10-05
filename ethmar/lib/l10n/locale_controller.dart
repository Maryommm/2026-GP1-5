import 'package:flutter/material.dart';

final ValueNotifier<Locale> appLocale = ValueNotifier(const Locale('ar'));

void toggleLanguage() {
  appLocale.value = appLocale.value.languageCode == 'ar'
      ? const Locale('en')
      : const Locale('ar');
}

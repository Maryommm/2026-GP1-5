import 'package:flutter/services.dart';

import 'app_colors.dart';

/// The system bars on the app's light pages: a see-through status bar with
/// dark icons.
const ethmarSystemBars = SystemUiOverlayStyle(
  statusBarColor: Color(0x00000000),
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemNavigationBarColor: AppColors.background,
  systemNavigationBarIconBrightness: Brightness.dark,
);

/// The same, but with light status bar icons for a dark page (the Virtual
/// Farm night sky).
final ethmarSystemBarsOnDark = ethmarSystemBars.copyWith(
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
);

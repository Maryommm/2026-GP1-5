import 'package:flutter/services.dart';

import 'app_colors.dart';

/// The status and navigation bars on the app's light pages: see-through
/// status bar with dark icons.
const ethmarSystemBars = SystemUiOverlayStyle(
  statusBarColor: Color(0x00000000),
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemNavigationBarColor: AppColors.background,
  systemNavigationBarIconBrightness: Brightness.dark,
);

/// The same, with light status bar icons, over a dark page (Virtual Farm's
/// night sky).
final ethmarSystemBarsOnDark = ethmarSystemBars.copyWith(
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
);

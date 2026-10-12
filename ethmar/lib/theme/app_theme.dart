import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Typography:
///  * Headings  -> Baloo Bhaijaan 2 (rounded, friendly, Arabic + English)
///  * Body / UI -> Readex Pro (soft, very readable, Arabic + English)
///  * Accent    -> Caveat handwriting in English, Baloo in Arabic
///                 (for the little coral "hand-written" lines)
class AppText {
  AppText._();

  static bool _isAr(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'ar';

  static TextStyle display(BuildContext context, {Color? color}) =>
      GoogleFonts.balooBhaijaan2(
        fontSize: 34,
        height: _isAr(context) ? 1.35 : 1.08,
        fontWeight: FontWeight.w700,
        color: color ?? AppColors.forest,
      );

  static TextStyle title(BuildContext context, {Color? color}) =>
      GoogleFonts.balooBhaijaan2(
        fontSize: 30,
        height: _isAr(context) ? 1.35 : 1.1,
        fontWeight: FontWeight.w700,
        color: color ?? AppColors.forest,
      );

  static TextStyle accent(BuildContext context, {Color? color, double? size}) {
    final c = color ?? AppColors.coralDark;
    return _isAr(context)
        ? GoogleFonts.balooBhaijaan2(
            fontSize: size ?? 21.0, fontWeight: FontWeight.w600, color: c, height: 1.3)
        : GoogleFonts.caveat(
            fontSize: (size ?? 21.0) + 5, fontWeight: FontWeight.w700, color: c, height: 1.1);
  }

  static TextStyle body(BuildContext context, {Color? color}) =>
      GoogleFonts.readexPro(
        fontSize: 15,
        height: 1.55,
        color: color ?? AppColors.textSecondary,
      );

  static TextStyle label(BuildContext context, {Color? color}) =>
      GoogleFonts.readexPro(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: color ?? AppColors.forest,
      );

  static TextStyle button(BuildContext context, {Color? color}) =>
      GoogleFonts.readexPro(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.onForest,
      );

  static TextStyle small(BuildContext context, {Color? color}) =>
      GoogleFonts.readexPro(
        fontSize: 13,
        color: color ?? AppColors.textSecondary,
      );
}

ThemeData buildEthmarTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.forest,
      primary: AppColors.forest,
      onPrimary: AppColors.onForest,
      secondary: AppColors.sea,
      tertiary: AppColors.coral,
      error: AppColors.error,
      surface: AppColors.surface,
    ),
    scaffoldBackgroundColor: AppColors.background,
    splashFactory: InkSparkle.splashFactory,
  );
  return base.copyWith(
    textTheme: GoogleFonts.readexProTextTheme(base.textTheme).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.forest,
      selectionColor: AppColors.forestTint,
      selectionHandleColor: AppColors.forest,
    ),
  );
}

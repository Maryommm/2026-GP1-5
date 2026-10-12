import 'package:flutter/material.dart';

/// Ethmar "Red Sea" palette.
///
/// Rule of thumb:
///  * [forest] is the brand colour: main buttons, titles, the logo.
///  * [sea] (turquoise) sets the mood: headers, chips, links.
///    Use [seaDark] whenever white text sits on top of it.
///  * [sun] and [coral] are small, happy touches only (badges, doodles,
///    hearts). Never use them for body text.
class AppColors {
  AppColors._();

  // Brand
  static const forest = Color(0xFF152C14);
  static const forestTint = Color(0xFFE3ECE0);
  static const forestDeep = Color(0xFF0B1A0B);

  // Red Sea turquoise
  static const sea = Color(0xFF00A896);
  static const seaDark = Color(0xFF00796D);
  static const seaDeep = Color(0xFF005F56);
  static const seaTint = Color(0xFFD6F3EF);

  // Sun
  static const sun = Color(0xFFFFC93C);
  static const sunTint = Color(0xFFFFF0C7);
  static const sunDark = Color(0xFF8A5A00);

  // Coral
  static const coral = Color(0xFFFF7759);
  static const coralTint = Color(0xFFFFE3DB);
  static const coralDark = Color(0xFFB5452B);

  // Neutrals
  static const background = Color(0xFFFFF7EC); // beach sand
  static const surface = Color(0xFFFFFFFF);
  static const backgroundAlt = Color(0xFFF3E6D0);
  static const border = Color(0xFFEADCC4);
  static const overlay = Color(0x80152C14); // forest @ 50%

  // Text
  static const textPrimary = forest;
  static const textSecondary = Color(0xFF5E5A4E);
  static const textHint = Color(0xFFA39C8A);
  static const onForest = Color(0xFFFFFFFF);

  // Status (colour + light background)
  static const success = Color(0xFF2E7D32);
  static const successTint = Color(0xFFE1F1E1);
  static const warning = Color(0xFFA35C00);
  static const warningTint = Color(0xFFFFEFD1);
  static const error = Color(0xFFC62828);
  static const errorTint = Color(0xFFFBE3E3);
  static const info = Color(0xFF2358A8);
  static const infoTint = Color(0xFFE0EAF8);
}

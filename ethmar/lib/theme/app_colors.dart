import 'package:flutter/material.dart';

/// Ethmar "Red Sea" palette.
///
/// Rule of thumb:
///  * [forest] is the brand colour: main buttons, icons, links, the logo.
///    Text uses [textPrimary] (soft black).
///  * [sea] (turquoise) sets the mood: headers, chips, links.
///    Use [seaDark] whenever white text sits on top of it.
///  * [earthBrown] is the branding accent (accent lines, doodles, slogan).
///  * [sun] and [coral] are small, happy touches only (badges, Log Out).
///    Never use them for body text.
class AppColors {
  AppColors._();

  // Brand
  static const forest = Color(0xFF152C14);
  static const forestTint = Color(0xFFE3ECE0);
  static const forestDeep = Color(0xFF0B1A0B);

  /// Soft light green for the Home feature cards.
  static const featureCard = Color(0xFFEEF4DA);

  /// Chevron colour on the Home feature cards (black at 87%).
  static const featureCardText = Color(0xDE000000);

  /// Earthy brown: the branding accent (Home slogan, accent lines under
  /// titles, the About tagline, the auth squiggle).
  static const earthBrown = Color(0xFF62472F);

  // Red Sea turquoise
  static const sea = Color(0xFF00A896);
  static const seaDark = Color(0xFF00796D);
  static const seaDeep = Color(0xFF005F56);
  static const seaTint = Color(0xFFD6F3EF);

  // Sun
  static const sun = Color(0xFFFFC93C);
  static const sunTint = Color(0xFFFFF0C7);
  static const sunDark = Color(0xFF8A5A00);

  // Coral: no longer a branding accent (use [earthBrown]). Kept only for
  // Log Out, the Fruit category, map store markers and small UI touches.
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
  static const textPrimary = Color(0xFF1C1C1C); // soft black
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

  // Toast icons (drawn in a white circle on the forest toast)
  static const toastSuccess = Color(0xFFE9B949);
  static const toastError = Color(0xFFD9534F);
  static const toastInfo = Color(0xFF387FC0);
}

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Text that comes in both languages (crop names, notes...).
class BiText {
  const BiText(this.en, this.ar);
  final String en;
  final String ar;

  String of(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;
}

/// Crop groups. Each one has its own colour so cards are easy to tell apart.
enum CropCategory {
  fruit(BiText('Fruit', 'فواكه'), Icons.apple_rounded, AppColors.coral,
      AppColors.coralTint, AppColors.coralDark),
  vegetable(BiText('Vegetable', 'خضروات'), Icons.eco_rounded,
      AppColors.success, AppColors.successTint, AppColors.success),
  herb(BiText('Herb', 'أعشاب'), Icons.spa_rounded, AppColors.sea,
      AppColors.seaTint, AppColors.seaDark),
  grain(BiText('Grain', 'حبوب'), Icons.grass_rounded, AppColors.sun,
      AppColors.sunTint, AppColors.sunDark),
  legume(BiText('Legume', 'بقوليات'), Icons.grain_rounded, AppColors.info,
      AppColors.infoTint, AppColors.info);

  const CropCategory(this.label, this.icon, this.color, this.tint, this.dark);

  final BiText label;
  final IconData icon;

  /// Card border.
  final Color color;

  /// Soft background for chips and the icon bubble.
  final Color tint;

  /// Text/icons on top of [tint].
  final Color dark;
}

/// One crop suggested by the recommendation model.
class CropRecommendation {
  const CropRecommendation({
    required this.name,
    required this.category,
    required this.reason,
    required this.minTemp,
    required this.maxTemp,
    required this.irrigation,
    required this.season,
    required this.daysToHarvest,
  });

  final BiText name;
  final CropCategory category;

  /// Short "why this crop" explanation.
  final BiText reason;

  /// Degrees Celsius.
  final int minTemp;
  final int maxTemp;

  final BiText irrigation;
  final BiText season;
  final int daysToHarvest;
}

/// What the model was given: the user's location and its current weather.
class GrowingConditions {
  const GrowingConditions({
    required this.city,
    required this.temperature,
    required this.humidity,
    required this.sky,
  });

  final BiText city;
  final int temperature;
  final int humidity;
  final BiText sky;
}

class CropRecommendationResult {
  const CropRecommendationResult({required this.conditions, required this.crops});
  final GrowingConditions conditions;
  final List<CropRecommendation> crops;
}

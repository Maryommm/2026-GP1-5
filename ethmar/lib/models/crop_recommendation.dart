import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class BiText {
  const BiText(this.en, this.ar);
  final String en;
  final String ar;

  String of(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;
}

enum CropCategory {
  fruit(
    BiText('Fruit', 'فواكه'),
    'assets/images/FRUITS.png',
    'assets/images/FRUITSicon.png',
    AppColors.coral,
    AppColors.coralTint,
    AppColors.coralDark,
  ),
  vegetable(
    BiText('Vegetable', 'خضروات'),
    'assets/images/VEGETABLES.png',
    'assets/images/VEGETABLESicon.png',
    AppColors.success,
    AppColors.successTint,
    AppColors.success,
  ),
  herb(
    BiText('Herb', 'أعشاب'),
    'assets/images/HERBS.png',
    'assets/images/HERBSicon.png',
    AppColors.sea,
    AppColors.seaTint,
    AppColors.seaDark,
  ),
  grain(
    BiText('Grain', 'حبوب'),
    'assets/images/GRAIN.png',
    'assets/images/GRAINicon.png',
    AppColors.sun,
    AppColors.sunTint,
    AppColors.sunDark,
  ),
  legume(
    BiText('Legume', 'بقوليات'),
    'assets/images/LEGUME.png',
    'assets/images/LEGUMEicon.png',
    AppColors.info,
    AppColors.infoTint,
    AppColors.info,
  );

  const CropCategory(
      this.label, this.image, this.iconImage, this.color, this.tint, this.dark);

  final BiText label;

  /// Pastel illustration of the category (transparent PNG).
  final String image;

  /// Full-colour icon version (transparent, artwork in the middle ~45%).
  final String iconImage;

  final Color color;
  final Color tint;
  final Color dark;
}

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
  final BiText reason;

  /// Degrees Celsius.
  final int minTemp;
  final int maxTemp;

  final BiText irrigation;
  final BiText season;
  final int daysToHarvest;
}

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
  const CropRecommendationResult({
    required this.conditions,
    required this.crops,
  });
  final GrowingConditions conditions;
  final List<CropRecommendation> crops;
}

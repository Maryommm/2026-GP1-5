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
  root(
    BiText('Root veg', 'خضار جذرية'),
    'assets/images/VEGETABLES.png',
    'assets/images/VEGETABLESicon.png',
    AppColors.warning,
    AppColors.warningTint,
    AppColors.warning,
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
  ),
  other(
    BiText('Other crops', 'محاصيل أخرى'),
    'assets/images/GRAIN.png',
    'assets/images/GRAINicon.png',
    AppColors.forest,
    AppColors.forestTint,
    AppColors.forest,
  );

  const CropCategory(
      this.label, this.image, this.iconImage, this.color, this.tint, this.dark);

  /// The category for the model's `crop_group` value.
  static CropCategory fromGroup(String group) => switch (group) {
        'fruit_tree' => fruit,
        'fruiting' => vegetable,
        'root' => root,
        'leafy_herb' => herb,
        'legume' => legume,
        _ => other,
      };

  final BiText label;

  /// Pastel illustration of the category (transparent PNG).
  final String image;

  /// Full-colour icon version (transparent, artwork in the middle ~45%).
  final String iconImage;

  final Color color;
  final Color tint;
  final Color dark;
}

/// How well a crop suits the user's area (the model's `band`).
enum MatchBand { excellent, good, fair }

/// One reason or warning from the model. The app writes its own English or
/// Arabic sentence from [code] and the months; [text] is the model's English
/// sentence, used only if the app doesn't know the code yet.
class ModelNote {
  const ModelNote({
    required this.code,
    this.month,
    this.months = const [],
    this.text = '',
  });

  factory ModelNote.fromJson(Map<String, dynamic> json) => ModelNote(
        code: json['code'] as String? ?? '',
        month: (json['month'] as num?)?.toInt(),
        months: _ints(json['months']),
        text: json['text'] as String? ?? '',
      );

  final String code;

  /// A single month (1-12), e.g. the month to plant in.
  final int? month;

  /// Months the note is about, e.g. the hot months that need shade.
  final List<int> months;
  final String text;
}

class CropRecommendation {
  const CropRecommendation({
    required this.name,
    required this.category,
    required this.band,
    this.score,
    required this.bestMonths,
    required this.minTemp,
    required this.maxTemp,
    required this.waterNeed,
    this.harvestDays,
    this.heightM,
    this.edibleParts = const [],
    this.reason,
    this.tip,
  });

  /// One item of the API's `results` list (see recommender/scripts/scoring.py).
  factory CropRecommendation.fromJson(Map<String, dynamic> json) {
    final details = (json['details'] as Map?)?.cast<String, dynamic>() ?? {};
    final optimal = _numbers(details['temp_optimal_c']);
    final survival = _numbers(details['temp_survival_c']);
    final temps = optimal.length == 2 ? optimal : survival;
    final harvest = _numbers(details['harvest_days']);
    final english = json['common_name'] as String? ?? '';
    final arabic = json['name_ar'] as String? ?? '';

    // Skipped notes: the planting months are already shown as "Best time",
    // and soil isn't talked about on the card. The next note is used instead.
    final reasons = _notes(json['reasons'])
        .where((n) => !_hiddenNotes.contains(n.code))
        .toList();
    final warnings = _notes(json['warnings'])
        .where((n) => !_hiddenNotes.contains(n.code))
        .toList();

    return CropRecommendation(
      name: BiText(english, arabic.isEmpty ? english : arabic),
      category: CropCategory.fromGroup(json['crop_group'] as String? ?? ''),
      score: (json['score'] as num?)?.toDouble(),
      band: switch (json['band']) {
        'excellent' => MatchBand.excellent,
        'good' => MatchBand.good,
        _ => MatchBand.fair,
      },
      bestMonths: _ints(json['best_months']),
      minTemp: temps.isNotEmpty ? temps.first.round() : null,
      maxTemp: temps.length == 2 ? temps.last.round() : null,
      waterNeed: [
        for (final w in (details['water_need'] as List? ?? const []))
          w.toString(),
      ],
      harvestDays: harvest.length == 2
          ? (min: harvest.first.round(), max: harvest.last.round())
          : null,
      heightM: (details['height_m'] as num?)?.toDouble(),
      edibleParts: [
        for (final p in (details['edible_parts'] as List? ?? const []))
          p.toString(),
      ],
      reason: reasons.isEmpty ? null : reasons.first,
      tip: warnings.isEmpty ? null : warnings.first,
    );
  }

  final BiText name;
  final CropCategory category;
  final MatchBand band;

  /// The model's score for this crop, 0 to 1 (null if the API sent none).
  final double? score;

  /// [score] as a whole percentage, e.g. 0.874 -> 87. Rounded down, so the
  /// number always agrees with the badge (0.796 is a fair match: 79%).
  int? get scorePercent => score == null
      ? null
      : (score!.clamp(0.0, 1.0) * 100).floor();

  /// Every good month to plant (1-12).
  final List<int> bestMonths;

  /// Best growing temperature in degrees Celsius.
  final int? minTemp;
  final int? maxTemp;

  /// Any of "low", "medium", "high".
  final List<String> waterNeed;

  /// Days from planting to harvest. For trees it's the fruiting season, so
  /// the screen shows the tree's height instead.
  final ({int min, int max})? harvestDays;
  final double? heightM;

  /// Lower-case parts you eat, e.g. "fruit", "leaves".
  final List<String> edibleParts;

  /// Why it suits the user's area (best reason from the model).
  final ModelNote? reason;

  /// The most important care warning, if any.
  final ModelNote? tip;
}

/// The user's area: this month's average climate (not today's weather).
class GrowingConditions {
  const GrowingConditions({
    required this.city,
    required this.month,
    required this.tempLow,
    required this.tempHigh,
    required this.rainMm,
  });

  final BiText city;

  /// 1-12.
  final int month;

  /// Average daily low and high this month, in degrees Celsius.
  final int tempLow;
  final int tempHigh;

  /// Average rain this month.
  final double rainMm;
}

class CropRecommendationResult {
  const CropRecommendationResult({
    required this.conditions,
    required this.crops,
    int? total,
    this.latitude = 0,
    this.longitude = 0,
  }) : _total = total;
  final GrowingConditions conditions;

  /// The first page of crops, best first.
  final List<CropRecommendation> crops;

  /// How many crops suit the area in all; more than [crops] when there are
  /// further pages to load.
  int get total => _total ?? crops.length;
  final int? _total;

  /// Where the crops were picked for, so the next pages use the same place.
  final double latitude;
  final double longitude;
}

/// Model notes the crop card never shows (see CropRecommendation.fromJson).
const _hiddenNotes = {
  // When to plant: shown as "Best time" instead.
  'plant_next_month', 'plant_later',
  // Soil.
  'ph_ok', 'soil_texture_mismatch',
  'needs_acidic_soil', 'prefers_more_acidic',
  'needs_alkaline_soil', 'prefers_more_alkaline',
};

List<int> _ints(Object? value) => [
      for (final v in (value as List? ?? const []))
        if (v is num) v.toInt(),
    ];

/// Numbers from a list such as `[15.0, 29.0]`; empty if any value is missing.
List<double> _numbers(Object? value) {
  final list = value as List? ?? const [];
  if (list.any((v) => v is! num)) return const [];
  return [for (final v in list) (v as num).toDouble()];
}

List<ModelNote> _notes(Object? value) => [
      for (final n in (value as List? ?? const []))
        if (n is Map) ModelNote.fromJson(n.cast<String, dynamic>()),
    ];

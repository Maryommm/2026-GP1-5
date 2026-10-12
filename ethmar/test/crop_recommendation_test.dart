import 'package:ethmar/l10n/app_strings.dart';
import 'package:ethmar/models/crop_recommendation.dart';
import 'package:flutter_test/flutter_test.dart';

// One item of the API's `results` list, as returned for Riyadh in October.
const _chickpea = {
  'species': 'cicer arietinum',
  'common_name': 'Chickpea',
  'name_ar': 'حمص',
  'crop_group': 'legume',
  'score': 1.0,
  'band': 'excellent',
  'status': 'now',
  'plant_month': 10,
  'months_until': 0,
  'season_months': 3,
  'best_months': [1, 2, 10, 11, 12],
  'protection': [],
  'reasons': [
    {'code': 'temp_ok', 'text': 'temperatures suit it for the whole season'},
  ],
  'warnings': [
    {'code': 'too_dry', 'text': 'your area is too dry for it'},
  ],
  'details': {
    'temp_optimal_c': [15.0, 29.0],
    'temp_survival_c': [7.0, 35.0],
    'water_need': ['low', 'medium'],
    'height_m': 0.6,
    'harvest_days': [90.0, 180.0],
    'edible_parts': ['leaves', 'seed'],
  },
};

void main() {
  final en = S(AppStrings.en);
  final ar = S(AppStrings.ar);

  test('maps an API result to the packet fields', () {
    final crop = CropRecommendation.fromJson(_chickpea);
    expect(crop.name.en, 'Chickpea');
    expect(crop.name.ar, 'حمص');
    expect(crop.category, CropCategory.legume);
    expect(crop.band, MatchBand.excellent);
    expect(crop.plantNow, isTrue);
    expect((crop.minTemp, crop.maxTemp), (15, 29));
    expect(crop.harvestDays, (min: 90, max: 180));
    expect(crop.reason?.code, 'temp_ok');
    expect(crop.tip?.code, 'too_dry');
  });

  test('missing values stay empty instead of failing', () {
    final crop = CropRecommendation.fromJson({
      'common_name': 'Mystery',
      'crop_group': 'other',
      'details': {
        'temp_optimal_c': [null, null],
        'harvest_days': [null, null],
      },
    });
    expect(crop.name.ar, 'Mystery');
    expect(crop.category, CropCategory.other);
    expect(crop.minTemp, isNull);
    expect(crop.harvestDays, isNull);
    expect(crop.reason, isNull);
  });

  test('month ranges wrap around the year', () {
    expect(en.monthRanges([1, 2, 10, 11, 12]), 'Oct–Feb');
    expect(ar.monthRanges([1, 2, 10, 11, 12]), 'أكتوبر–فبراير');
    expect(en.monthRanges([3, 6, 7, 8]), 'Mar, Jun–Aug');
    expect(en.monthRanges(List.generate(12, (i) => i + 1)), 'All year');
  });

  test('model notes are written in the app language', () {
    const shade = ModelNote(code: 'needs_shade', months: [6, 7, 8]);
    expect(ar.cropNote(shade), contains('يونيو–أغسطس'));
    expect(en.cropNote(shade), startsWith('Shade it in Jun–Aug'));
    // Unknown codes fall back to the model's English sentence.
    const unknown = ModelNote(code: 'new_code', text: 'model text');
    expect(ar.cropNote(unknown), 'model text');
    expect(ar.cropWater(['low', 'medium']), 'قليلة–متوسطة');
    expect(ar.cropParts(['leaves', 'seed']), 'الأوراق، البذور');
  });
}

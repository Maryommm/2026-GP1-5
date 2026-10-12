import '../models/crop_recommendation.dart';

/// Gets crop suggestions for the user's location and weather.
///
/// For now this returns sample data after a short pause so the screen can
/// be designed. Later: get the location + weather (Google APIs), send them
/// to the model, and map its answer into [CropRecommendationResult].
class CropRecommendationService {
  Future<CropRecommendationResult> recommend() async {
    await Future.delayed(const Duration(seconds: 3));
    return _sample;
  }

  static const _sample = CropRecommendationResult(
    conditions: GrowingConditions(
      city: BiText('Riyadh', 'الرياض'),
      temperature: 31,
      humidity: 22,
      sky: BiText('Sunny', 'مشمس'),
    ),
    crops: [
      CropRecommendation(
        name: BiText('Tomato', 'طماطم'),
        category: CropCategory.vegetable,
        reason: BiText(
          'Loves warm, sunny days like yours and grows well in pots.',
          'تحب الأيام الدافئة والمشمسة مثل جوّك، وتنمو بسهولة في الأصص.',
        ),
        minTemp: 18,
        maxTemp: 35,
        irrigation: BiText('Every 2–3 days', 'كل ٢–٣ أيام'),
        season: BiText('Autumn – Spring', 'الخريف – الربيع'),
        daysToHarvest: 75,
      ),
      CropRecommendation(
        name: BiText('Watermelon', 'بطيخ'),
        category: CropCategory.fruit,
        reason: BiText(
          'Thrives in heat and dry air, and needs lots of sun.',
          'ينمو جيدًا في الحر والجو الجاف، ويحتاج شمس كثيرة.',
        ),
        minTemp: 21,
        maxTemp: 38,
        irrigation: BiText('Every 3–4 days', 'كل ٣–٤ أيام'),
        season: BiText('Spring – Summer', 'الربيع – الصيف'),
        daysToHarvest: 85,
      ),
      CropRecommendation(
        name: BiText('Mint', 'نعناع'),
        category: CropCategory.herb,
        reason: BiText(
          'Easy to start with and handles warm weather in partial shade.',
          'سهل للمبتدئين ويتحمّل الجو الدافئ في الظل الجزئي.',
        ),
        minTemp: 15,
        maxTemp: 32,
        irrigation: BiText('Every day', 'كل يوم'),
        season: BiText('All year', 'طوال السنة'),
        daysToHarvest: 60,
      ),
      CropRecommendation(
        name: BiText('Okra', 'بامية'),
        category: CropCategory.vegetable,
        reason: BiText(
          'One of the best crops for hot, dry climates.',
          'من أفضل المحاصيل للمناخ الحار والجاف.',
        ),
        minTemp: 20,
        maxTemp: 40,
        irrigation: BiText('Every 2 days', 'كل يومين'),
        season: BiText('Spring – Summer', 'الربيع – الصيف'),
        daysToHarvest: 55,
      ),
      CropRecommendation(
        name: BiText('Millet', 'دخن'),
        category: CropCategory.grain,
        reason: BiText(
          'Needs little water and tolerates strong sun.',
          'يحتاج ماء قليل ويتحمّل الشمس القوية.',
        ),
        minTemp: 20,
        maxTemp: 38,
        irrigation: BiText('Once a week', 'مرة في الأسبوع'),
        season: BiText('Summer', 'الصيف'),
        daysToHarvest: 90,
      ),
      CropRecommendation(
        name: BiText('Cowpea', 'لوبيا'),
        category: CropCategory.legume,
        reason: BiText(
          'Heat-loving and feeds the soil for your next crop.',
          'تحب الحرارة وتغذّي التربة للمحصول القادم.',
        ),
        minTemp: 20,
        maxTemp: 36,
        irrigation: BiText('Every 3 days', 'كل ٣ أيام'),
        season: BiText('Spring – Summer', 'الربيع – الصيف'),
        daysToHarvest: 70,
      ),
    ],
  );
}

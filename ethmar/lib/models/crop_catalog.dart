import 'crop_recommendation.dart' show BiText, CropCategory;

/// A crop the user can add to their farm, with its picture in `assets/ethmar_crops/`.
/// ممكن تنشال بعدين اذا بنخليه ياخذ من الداتا بيس 
class CatalogCrop {
  const CatalogCrop(this.id, this.name, this.category);


  final String id;
  final BiText name;
  final CropCategory category;

  String get image => 'assets/ethmar_crops/$id.png';

  /// Whether the English or Arabic name contains [query], ignoring case,
  /// Arabic diacritics, letter variants (أ/ا, ة/ه, ى/ي) and a leading "ال".
  /// An empty query matches every crop.
  bool matches(String query) {
    final q = _searchForm(query);
    if (q.isEmpty) return true;
    return _searchForm(name.en).contains(q) || _searchForm(name.ar).contains(q);
  }
}

final _arabicMarks = RegExp('[ً-ْٰـ]');
final _spaces = RegExp(r'\s+');

/// [text] reduced to the form crop names are compared in.
String _searchForm(String text) => text
    .toLowerCase()
    .replaceAll(_arabicMarks, '')
    .replaceAll(RegExp('[أإآٱ]'), 'ا')
    .replaceAll('ة', 'ه')
    .replaceAll('ى', 'ي')
    .trim()
    .split(_spaces)
    .map((w) => w.length > 3 && w.startsWith('ال') ? w.substring(2) : w)
    .join(' ');

/// Shown when a plant's own picture can't be loaded.
const defaultPlantImage = 'assets/images/ethmar_sprout_pair.png';

/// The crop to choose when the user's plant isn't in the catalog. Its picture
/// goes in `assets/ethmar_crops/unknown.png`.
const unknownCropId = 'unknown';

/// Every crop that can be added, grouped by category.
const cropCatalog = [
  // Vegetables
  CatalogCrop('tomato', BiText('Tomato', 'طماطم'), CropCategory.vegetable),
  CatalogCrop('cucumber', BiText('Cucumber', 'خيار'), CropCategory.vegetable),
  CatalogCrop('bell_pepper',BiText('Bell pepper', 'فلفل رومي'),CropCategory.vegetable ),
  CatalogCrop('chili_pepper',BiText('Chili pepper', 'فلفل حار'),CropCategory.vegetable),
  CatalogCrop('eggplant',BiText('Eggplant', 'باذنجان'),CropCategory.vegetable),
  CatalogCrop('zucchini', BiText('Zucchini', 'كوسا'), CropCategory.vegetable),
  CatalogCrop('okra', BiText('Okra', 'بامية'), CropCategory.vegetable),
  CatalogCrop('pumpkin', BiText('Pumpkin', 'قرع'), CropCategory.vegetable),
  CatalogCrop('butternut_squash', BiText('Butternut squash', 'قرع عسلي'), CropCategory.vegetable),
  CatalogCrop('bottle_gourd', BiText('Bottle gourd', 'يقطين القناني'), CropCategory.vegetable),
  CatalogCrop('snake_gourd', BiText('Snake gourd', 'قرع الثعبان'), CropCategory.vegetable),
  CatalogCrop('wax_gourd', BiText('Wax gourd', 'قرع شمعي'), CropCategory.vegetable),
  CatalogCrop('loofah', BiText('Loofah', 'لوف'), CropCategory.vegetable),
  CatalogCrop('chayote', BiText('Chayote', 'شايوت'), CropCategory.vegetable),
  CatalogCrop('tomatillo', BiText('Tomatillo', 'توماتيلو'), CropCategory.vegetable),
  CatalogCrop('artichoke', BiText('Artichoke', 'خرشوف'), CropCategory.vegetable),
  CatalogCrop('asparagus', BiText('Asparagus', 'هليون'), CropCategory.vegetable),
  CatalogCrop('cabbage', BiText('Cabbage', 'ملفوف'), CropCategory.vegetable),
  CatalogCrop('lettuce', BiText('Lettuce', 'خس'), CropCategory.vegetable),
  CatalogCrop('spinach', BiText('Spinach', 'سبانخ'), CropCategory.vegetable),
  CatalogCrop('malabar_spinach', BiText('Malabar spinach', 'سبانخ مالابار'), CropCategory.vegetable),
  CatalogCrop('new_zealand_spinach', BiText('New Zealand spinach', 'سبانخ نيوزيلندية'), CropCategory.vegetable),
  CatalogCrop('water_spinach', BiText('Water spinach', 'سبانخ مائية'), CropCategory.vegetable),
  CatalogCrop('arugula', BiText('Arugula', 'جرجير'), CropCategory.vegetable),
  CatalogCrop('watercress', BiText('Watercress', 'جرجير الماء'), CropCategory.vegetable),
  CatalogCrop('mustard_greens', BiText('Mustard greens', 'أوراق الخردل'), CropCategory.vegetable),
  CatalogCrop('chicory', BiText('Chicory', 'هندباء'), CropCategory.vegetable),
  CatalogCrop('purslane', BiText('Purslane', 'رجلة'), CropCategory.vegetable),
  CatalogCrop('celery', BiText('Celery', 'كرفس'), CropCategory.vegetable),
  CatalogCrop('leek', BiText('Leek', 'كراث'), CropCategory.vegetable),
  CatalogCrop('welsh_onion', BiText('Welsh onion', 'بصل أخضر'), CropCategory.vegetable),
  CatalogCrop('rhubarb', BiText('Rhubarb', 'راوند'), CropCategory.vegetable),
  // Root vegetables
  CatalogCrop('potato', BiText('Potato', 'بطاطس'), CropCategory.root),
  CatalogCrop('sweet_potato', BiText('Sweet potato', 'بطاطا حلوة'), CropCategory.root),
  CatalogCrop('carrot', BiText('Carrot', 'جزر'), CropCategory.root),
  CatalogCrop('onion', BiText('Onion', 'بصل'), CropCategory.root),
  CatalogCrop('garlic', BiText('Garlic', 'ثوم'), CropCategory.root),
  CatalogCrop('beetroot', BiText('Beetroot', 'شمندر'), CropCategory.root),
  CatalogCrop('radish', BiText('Radish', 'فجل'), CropCategory.root),
  CatalogCrop('turnip', BiText('Turnip', 'لفت'), CropCategory.root),
  CatalogCrop('ginger', BiText('Ginger', 'زنجبيل'), CropCategory.root),
  CatalogCrop('parsnip', BiText('Parsnip', 'جزر أبيض'), CropCategory.root),
  CatalogCrop('horseradish', BiText('Horseradish', 'فجل حار'), CropCategory.root),
  CatalogCrop('taro', BiText('Taro', 'قلقاس'), CropCategory.root),
  CatalogCrop('cassava', BiText('Cassava', 'كسافا'), CropCategory.root),
  CatalogCrop('jerusalem_artichoke', BiText('Jerusalem artichoke', 'طرطوفة'), CropCategory.root),
  CatalogCrop('jicama', BiText('Jicama', 'جيكاما'), CropCategory.root),
  CatalogCrop('tiger_nut', BiText('Tiger nut', 'حب العزيز'), CropCategory.root),
  // Legumes
  CatalogCrop('broad_bean', BiText('Broad bean', 'فول'), CropCategory.legume),
  CatalogCrop('chickpea', BiText('Chickpea', 'حمص'), CropCategory.legume),
  CatalogCrop('lentil', BiText('Lentil', 'عدس'), CropCategory.legume),
  CatalogCrop('cowpea', BiText('Cowpea', 'لوبيا'), CropCategory.legume),
  CatalogCrop('green_bean', BiText('Green bean', 'فاصوليا خضراء'), CropCategory.legume),
  CatalogCrop('lima_bean', BiText('Lima bean', 'فاصوليا ليما'), CropCategory.legume),
  CatalogCrop('mung_bean', BiText('Mung bean', 'ماش'), CropCategory.legume),
  CatalogCrop('pea', BiText('Pea', 'بازلاء'), CropCategory.legume),
  CatalogCrop('peanut', BiText('Peanut', 'فول سوداني'), CropCategory.legume),
  CatalogCrop('soybean', BiText('Soybean', 'فول الصويا'), CropCategory.legume),
  // Fruits
  CatalogCrop('date_palm', BiText('Date palm', 'نخلة'), CropCategory.fruit),
  CatalogCrop('strawberry', BiText('Strawberry', 'فراولة'), CropCategory.fruit),
  CatalogCrop('watermelon', BiText('Watermelon', 'بطيخ'), CropCategory.fruit),
  CatalogCrop('lemon_tree',BiText('Lemon tree', 'شجرة ليمون'),CropCategory.fruit),
  CatalogCrop('orange_tree',BiText('Orange tree', 'شجرة برتقال'),CropCategory.fruit),
  CatalogCrop('mango_tree',BiText('Mango tree', 'شجرة مانجو'),CropCategory.fruit),
  CatalogCrop('fig_tree', BiText('Fig tree', 'شجرة تين'), CropCategory.fruit),
  CatalogCrop('pomegranate_tree',BiText('Pomegranate tree', 'شجرة رمان'),CropCategory.fruit),
  CatalogCrop('grape_vine', BiText('Grape vine', 'عنب'), CropCategory.fruit),
  CatalogCrop('guava_tree',BiText('Guava tree', 'شجرة جوافة'),CropCategory.fruit),
  CatalogCrop('apple_tree',BiText('Apple tree', 'شجرة تفاح'),CropCategory.fruit),
  CatalogCrop('peach_tree',BiText('Peach tree', 'شجرة خوخ'),CropCategory.fruit),
  CatalogCrop('banana', BiText('Banana', 'موز'), CropCategory.fruit),
  CatalogCrop('papaya', BiText('Papaya', 'بابايا'), CropCategory.fruit),
  // Herbs
  CatalogCrop('mint', BiText('Mint', 'نعناع'), CropCategory.herb),
  CatalogCrop('basil', BiText('Basil', 'ريحان'), CropCategory.herb),
  CatalogCrop('parsley', BiText('Parsley', 'بقدونس'), CropCategory.herb),
  CatalogCrop('coriander', BiText('Coriander', 'كزبرة'), CropCategory.herb),
  CatalogCrop('rosemary', BiText('Rosemary', 'إكليل الجبل'), CropCategory.herb),
  CatalogCrop('thyme', BiText('Thyme', 'زعتر'), CropCategory.herb),
  CatalogCrop('saffron', BiText('Saffron', 'زعفران'), CropCategory.herb),
  CatalogCrop('licorice', BiText('Licorice', 'عرق السوس'), CropCategory.herb),
  // Grains
  CatalogCrop('corn', BiText('Corn', 'ذرة'), CropCategory.grain),
  // Anything else
  CatalogCrop(unknownCropId, BiText('Unknown plant', 'نبتة غير معروفة'), CropCategory.other),
];

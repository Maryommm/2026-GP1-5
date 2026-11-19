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
  CatalogCrop('melon', BiText('Melon', 'شمام'), CropCategory.fruit),
  CatalogCrop('olive_tree', BiText('Olive tree', 'شجرة زيتون'), CropCategory.fruit),
  CatalogCrop('mulberry_tree', BiText('Mulberry tree', 'شجرة توت'), CropCategory.fruit),
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
  CatalogCrop('prickly_pear', BiText('Prickly pear', 'تين شوكي'), CropCategory.fruit),
  // Nut trees (their nuts are fruits)
  CatalogCrop('almond', BiText('Almond', 'لوز'), CropCategory.fruit),
  CatalogCrop('pistachio', BiText('Pistachio', 'فستق حلبي'), CropCategory.fruit),
  CatalogCrop('walnut', BiText('Walnut', 'جوز'), CropCategory.fruit),
  CatalogCrop('hazelnut', BiText('Hazelnut', 'بندق'), CropCategory.fruit),
  CatalogCrop('cashew', BiText('Cashew', 'كاجو'), CropCategory.fruit),
  CatalogCrop('macadamia', BiText('Macadamia', 'مكاديميا'), CropCategory.fruit),
  CatalogCrop('chestnut', BiText('Sweet chestnut', 'كستناء'), CropCategory.fruit),
  // Herbs
  CatalogCrop('mint', BiText('Mint', 'نعناع'), CropCategory.herb),
  CatalogCrop('basil', BiText('Basil', 'ريحان'), CropCategory.herb),
  CatalogCrop('parsley', BiText('Parsley', 'بقدونس'), CropCategory.herb),
  CatalogCrop('coriander', BiText('Coriander', 'كزبرة'), CropCategory.herb),
  CatalogCrop('rosemary', BiText('Rosemary', 'إكليل الجبل'), CropCategory.herb),
  CatalogCrop('thyme', BiText('Thyme', 'زعتر'), CropCategory.herb),
  CatalogCrop('dill', BiText('Dill', 'شبت'), CropCategory.herb),
  CatalogCrop('fenugreek', BiText('Fenugreek', 'حلبة'), CropCategory.herb),
  CatalogCrop('sage', BiText('Sage', 'مريمية'), CropCategory.herb),
  CatalogCrop('saffron', BiText('Saffron', 'زعفران'), CropCategory.herb),
  CatalogCrop('licorice', BiText('Licorice', 'عرق السوس'), CropCategory.herb),
  CatalogCrop('lavender', BiText('Lavender', 'خزامى'), CropCategory.herb),
  // Grains and seed crops
  CatalogCrop('corn', BiText('Corn', 'ذرة'), CropCategory.grain),
  CatalogCrop('wheat', BiText('Wheat', 'قمح'), CropCategory.grain),
  CatalogCrop('barley', BiText('Barley', 'شعير'), CropCategory.grain),
  CatalogCrop('oats', BiText('Oats', 'شوفان'), CropCategory.grain),
  CatalogCrop('rye', BiText('Rye', 'جاودار'), CropCategory.grain),
  CatalogCrop('sorghum', BiText('Sorghum', 'ذرة رفيعة'), CropCategory.grain),
  CatalogCrop('pearl_millet', BiText('Pearl millet', 'دخن'), CropCategory.grain),
  CatalogCrop('buckwheat', BiText('Buckwheat', 'حنطة سوداء'), CropCategory.grain),
  CatalogCrop('quinoa', BiText('Quinoa', 'كينوا'), CropCategory.grain),
  CatalogCrop('flax', BiText('Flax', 'كتان'), CropCategory.grain),
  CatalogCrop('safflower', BiText('Safflower', 'عصفر'), CropCategory.grain),
  // Not in the list (first, so it's easy to find): the user picks its category when adding it (see
  // FarmPlant.category). [CropCategory.other] is only its default.
  CatalogCrop(unknownCropId, BiText('Unknown plant', 'نبتة غير معروفة'), CropCategory.other),
  // Other plants: not grown to eat, but popular with beginners. Sugarcane
  // is eaten, but fits no other category.
  CatalogCrop('sugarcane', BiText('Sugarcane', 'قصب السكر'), CropCategory.other),
  CatalogCrop('aloe_vera', BiText('Aloe vera', 'ألوفيرا'), CropCategory.other),
  CatalogCrop('jasmine', BiText('Jasmine', 'ياسمين'), CropCategory.other),
  CatalogCrop('bougainvillea', BiText('Bougainvillea', 'جهنمية'), CropCategory.other),
  CatalogCrop('desert_rose_adenium', BiText('Desert rose', 'وردة الصحراء'), CropCategory.other),
  CatalogCrop('oleander', BiText('Oleander', 'دفلة'), CropCategory.other),
  CatalogCrop('plumbago', BiText('Plumbago', 'ياسمين أزرق'), CropCategory.other),
  CatalogCrop('marigold', BiText('Marigold', 'قطيفة'), CropCategory.other),
  CatalogCrop('zinnia', BiText('Zinnia', 'زينيا'), CropCategory.other),
  CatalogCrop('african_violet', BiText('African violet', 'بنفسج أفريقي'), CropCategory.other),
  CatalogCrop('orchid', BiText('Orchid', 'أوركيد'), CropCategory.other),
  CatalogCrop('anthurium', BiText('Anthurium', 'أنثوريوم'), CropCategory.other),
  CatalogCrop('begonia', BiText('Begonia', 'بيغونيا'), CropCategory.other),
  CatalogCrop('peace_lily', BiText('Peace lily', 'زنبق السلام'), CropCategory.other),
  CatalogCrop('bird_of_paradise', BiText('Bird of paradise', 'عصفور الجنة'), CropCategory.other),
  CatalogCrop('monstera', BiText('Monstera', 'مونستيرا'), CropCategory.other),
  CatalogCrop('philodendron_birkin', BiText('Philodendron Birkin', 'فيلوديندرون بيركين'), CropCategory.other),
  CatalogCrop('zz_plant', BiText('ZZ plant', 'زاميا'), CropCategory.other),
  CatalogCrop('rubber_plant', BiText('Rubber plant', 'نبتة المطاط'), CropCategory.other),
  CatalogCrop('dumb_cane_dieffenbachia', BiText('Dumb cane', 'ديفنباخيا'), CropCategory.other),
  CatalogCrop('dracaena_marginata', BiText('Dracaena marginata', 'دراسينا'), CropCategory.other),
  CatalogCrop('yucca_cane', BiText('Yucca cane', 'يوكا'), CropCategory.other),
  CatalogCrop('croton', BiText('Croton', 'كروتون'), CropCategory.other),
  CatalogCrop('calathea', BiText('Calathea', 'كالاثيا'), CropCategory.other),
  CatalogCrop('prayer_plant', BiText('Prayer plant', 'نبتة الصلاة'), CropCategory.other),
  CatalogCrop('spider_plant', BiText('Spider plant', 'نبتة العنكبوت'), CropCategory.other),
  CatalogCrop('chinese_money_plant', BiText('Chinese money plant', 'نبتة المال الصينية'), CropCategory.other),
  CatalogCrop('jade_plant', BiText('Jade plant', 'نبتة اليشم'), CropCategory.other),
  CatalogCrop('string_of_pearls', BiText('String of pearls', 'عقد اللؤلؤ'), CropCategory.other),
  CatalogCrop('haworthia', BiText('Haworthia', 'هاورثيا'), CropCategory.other),
  CatalogCrop('golden_barrel_cactus', BiText('Golden barrel cactus', 'صبار البرميل الذهبي'), CropCategory.other),
  CatalogCrop('saguaro_cactus', BiText('Saguaro cactus', 'صبار ساغوارو'), CropCategory.other),
  CatalogCrop('english_ivy', BiText('English ivy', 'لبلاب'), CropCategory.other),
  CatalogCrop('boston_fern', BiText('Boston fern', 'سرخس بوسطن'), CropCategory.other),
  CatalogCrop('lucky_bamboo', BiText('Lucky bamboo', 'خيزران الحظ'), CropCategory.other),
  CatalogCrop('parlor_palm', BiText('Parlor palm', 'نخلة الصالون'), CropCategory.other),
  CatalogCrop('dwarf_fan_palm', BiText('Dwarf fan palm', 'نخلة المروحة القزمة'), CropCategory.other),
  CatalogCrop('fountain_grass', BiText('Fountain grass', 'عشب النافورة'), CropCategory.other),
];

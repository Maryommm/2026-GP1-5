import 'crop_recommendation.dart' show BiText, CropCategory;

/// A crop the user can add to their farm, with its picture in
/// `assets/ethmar_crops/`.
class CatalogCrop {
  const CatalogCrop(this.id, this.name, this.category);

  /// Also the picture's file name, e.g. 'tomato'.
  final String id;
  final BiText name;
  final CropCategory category;

  String get image => 'assets/ethmar_crops/$id.png';
}

/// Every crop that can be added, grouped by category.
// TODO(backend): Load the crop list from the database if it should be
//   editable without an app update.
const cropCatalog = [
  // Vegetables
  CatalogCrop('tomato', BiText('Tomato', 'طماطم'), CropCategory.vegetable),
  CatalogCrop('cucumber', BiText('Cucumber', 'خيار'), CropCategory.vegetable),
  CatalogCrop(
    'bell_pepper',
    BiText('Bell pepper', 'فلفل رومي'),
    CropCategory.vegetable,
  ),
  CatalogCrop(
    'chili_pepper',
    BiText('Chili pepper', 'فلفل حار'),
    CropCategory.vegetable,
  ),
  CatalogCrop(
    'eggplant',
    BiText('Eggplant', 'باذنجان'),
    CropCategory.vegetable,
  ),
  CatalogCrop('zucchini', BiText('Zucchini', 'كوسا'), CropCategory.vegetable),
  CatalogCrop('okra', BiText('Okra', 'بامية'), CropCategory.vegetable),
  CatalogCrop('potato', BiText('Potato', 'بطاطس'), CropCategory.vegetable),
  CatalogCrop('pumpkin', BiText('Pumpkin', 'قرع'), CropCategory.vegetable),
  // Fruits
  CatalogCrop('date_palm', BiText('Date palm', 'نخلة'), CropCategory.fruit),
  CatalogCrop('strawberry', BiText('Strawberry', 'فراولة'), CropCategory.fruit),
  CatalogCrop('watermelon', BiText('Watermelon', 'بطيخ'), CropCategory.fruit),
  CatalogCrop(
    'lemon_tree',
    BiText('Lemon tree', 'شجرة ليمون'),
    CropCategory.fruit,
  ),
  CatalogCrop(
    'orange_tree',
    BiText('Orange tree', 'شجرة برتقال'),
    CropCategory.fruit,
  ),
  CatalogCrop(
    'mango_tree',
    BiText('Mango tree', 'شجرة مانجو'),
    CropCategory.fruit,
  ),
  CatalogCrop('fig_tree', BiText('Fig tree', 'شجرة تين'), CropCategory.fruit),
  CatalogCrop(
    'pomegranate_tree',
    BiText('Pomegranate tree', 'شجرة رمان'),
    CropCategory.fruit,
  ),
  CatalogCrop('grape_vine', BiText('Grape vine', 'عنب'), CropCategory.fruit),
  CatalogCrop(
    'guava_tree',
    BiText('Guava tree', 'شجرة جوافة'),
    CropCategory.fruit,
  ),
  CatalogCrop(
    'apple_tree',
    BiText('Apple tree', 'شجرة تفاح'),
    CropCategory.fruit,
  ),
  CatalogCrop(
    'peach_tree',
    BiText('Peach tree', 'شجرة خوخ'),
    CropCategory.fruit,
  ),
  CatalogCrop('banana', BiText('Banana', 'موز'), CropCategory.fruit),
  CatalogCrop('papaya', BiText('Papaya', 'بابايا'), CropCategory.fruit),
  // Herbs
  CatalogCrop('mint', BiText('Mint', 'نعناع'), CropCategory.herb),
  CatalogCrop('basil', BiText('Basil', 'ريحان'), CropCategory.herb),
  CatalogCrop('parsley', BiText('Parsley', 'بقدونس'), CropCategory.herb),
  CatalogCrop('coriander', BiText('Coriander', 'كزبرة'), CropCategory.herb),
  CatalogCrop('rosemary', BiText('Rosemary', 'إكليل الجبل'), CropCategory.herb),
  CatalogCrop('thyme', BiText('Thyme', 'زعتر'), CropCategory.herb),
  // Grains
  CatalogCrop('corn', BiText('Corn', 'ذرة'), CropCategory.grain),
];

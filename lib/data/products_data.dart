import '../models/product.dart';

const String _imageBase = 'assets/images/products';

/// The shop owner that legacy/seed products belong to once migrated into
/// Supabase — see scripts/seed_supabase.dart.
const String defaultShopOwnerId = 's1';

final List<Product> productsData = [
  Product(
    id: 'p1',
    name: 'Murukku',
    category: ProductCategory.snacks,
    price: 120,
    unit: '250g pack',
    imagePath: '$_imageBase/murukku.jpg',
    description:
        'Crunchy spiral snack made from rice flour and urad dal flour, fried fresh.',
    shopOwnerId: defaultShopOwnerId,
  ),
  Product(
    id: 'p2',
    name: 'Banana Chips',
    category: ProductCategory.snacks,
    price: 90,
    unit: '200g pack',
    imagePath: '$_imageBase/banana_chips.jpg',
    description:
        'Thin, crispy fried raw banana slices seasoned with turmeric and salt.',
    shopOwnerId: defaultShopOwnerId,
  ),
  Product(
    id: 'p3',
    name: 'Madras Mixture',
    category: ProductCategory.snacks,
    price: 110,
    unit: '250g pack',
    imagePath: '$_imageBase/madras_mixture.jpg',
    description: 'A spicy, crunchy mix of sev, peanuts, and crispy lentils.',
    shopOwnerId: defaultShopOwnerId,
  ),
  Product(
    id: 'p4',
    name: 'Ragi Cookies',
    category: ProductCategory.snacks,
    price: 140,
    unit: '200g pack',
    imagePath: '$_imageBase/ragi_cookies.jpg',
    description:
        'Wholesome, crumbly cookies made with finger millet (ragi) flour and jaggery.',
    shopOwnerId: defaultShopOwnerId,
  ),
  Product(
    id: 'p5',
    name: 'Mysore Pak',
    category: ProductCategory.sweets,
    price: 180,
    unit: '250g box',
    imagePath: '$_imageBase/mysore_pak.jpg',
    description:
        'A rich, melt-in-the-mouth sweet made from gram flour, ghee, and sugar.',
    shopOwnerId: defaultShopOwnerId,
  ),
  Product(
    id: 'p6',
    name: 'Badam Milk',
    category: ProductCategory.sweets,
    price: 150,
    unit: '500ml bottle',
    imagePath: '$_imageBase/badam_milk.jpg',
    description:
        'Traditional chilled almond milk, slow-simmered with saffron and cardamom.',
    shopOwnerId: defaultShopOwnerId,
  ),
  Product(
    id: 'p7',
    name: 'Peanut Chikki',
    category: ProductCategory.sweets,
    price: 100,
    unit: '200g pack',
    imagePath: '$_imageBase/peanut_chikki.jpg',
    description: 'Crunchy jaggery brittle loaded with roasted peanuts.',
    shopOwnerId: defaultShopOwnerId,
  ),
  Product(
    id: 'p8',
    name: 'Ribbon Pakoda',
    category: ProductCategory.snacks,
    price: 130,
    unit: '200g pack',
    imagePath: '$_imageBase/ribbon_pakoda.jpg',
    description:
        'Crispy ribbon-shaped gram flour strips, lightly spiced and fried.',
    shopOwnerId: defaultShopOwnerId,
  ),
];

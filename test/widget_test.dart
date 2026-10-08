import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gruhini_foods/data/orders_data.dart';
import 'package:gruhini_foods/data/products_data.dart';
import 'package:gruhini_foods/main.dart';
import 'package:gruhini_foods/models/cart_item.dart';
import 'package:gruhini_foods/models/order.dart';
import 'package:gruhini_foods/models/product.dart';
import 'package:gruhini_foods/screens/checkout/order_placed_screen.dart';
import 'package:gruhini_foods/screens/invoice_screen.dart';
import 'package:gruhini_foods/screens/order_details_screen.dart';
import 'package:gruhini_foods/screens/order_tracking_screen.dart';
import 'package:gruhini_foods/screens/product_details_screen.dart';
import 'package:gruhini_foods/state/auth_provider.dart';
import 'package:gruhini_foods/state/business_settings_provider.dart';
import 'package:gruhini_foods/state/cart_provider.dart';
import 'package:gruhini_foods/state/orders_provider.dart';
import 'package:gruhini_foods/state/reviews_provider.dart';
import 'package:gruhini_foods/state/products_provider.dart';
import 'package:gruhini_foods/models/business_settings.dart';
import 'package:gruhini_foods/utils/delivery_fee.dart';
import 'package:gruhini_foods/widgets/product_image_picker.dart';

// A real, minimal 1x1 transparent PNG so Image.memory can actually decode it
// in tests (arbitrary byte sequences fail decoding and report an error).
final Uint8List _kTestPngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUAAQAAAAA=',
);

Future<void> _loginAsCustomer(
  WidgetTester tester, {
  List<Product>? seedProducts,
}) async {
  // Use a realistic mobile portrait viewport so the 2-column product grid
  // lays out the way it would on a phone, instead of the default desktop-ish
  // test surface where most grid items would be scrolled offstage.
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(const GruhiniFoodsApp());
  await tester.pumpAndSettle();

  // There's no real Supabase in this test environment, so ProductsProvider's
  // normal Supabase-backed load() always comes back empty - seed it directly
  // when a test needs the Home grid to show real products.
  if (seedProducts != null) {
    Provider.of<ProductsProvider>(
      tester.element(find.byType(MaterialApp)),
      listen: false,
    ).seedForTest(seedProducts);
    await tester.pumpAndSettle();
  }

  await tester.tap(find.text('I am a Customer'));
  await tester.pumpAndSettle();

  // The real login_or_create_customer RPC needs a live Supabase connection
  // this test environment doesn't have - simulate a successful login
  // directly instead, same reasoning as _loginAsAdmin below. LoginScreen
  // itself pops on a real successful login (see its _submit()), so do the
  // same here since this bypasses that screen's own pop.
  final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
  Provider.of<AuthProvider>(
    tester.element(find.byType(MaterialApp)),
    listen: false,
  ).simulateCustomerLoginForTest(name: 'Asha Rao', phone: '9876543210');
  navigator.pop();
  await tester.pumpAndSettle();
}

Future<void> _loginAsAdmin(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(const GruhiniFoodsApp());
  await tester.pumpAndSettle();

  await tester.tap(find.text('Shop Owner / Admin'));
  await tester.pumpAndSettle();

  // The real authenticate_admin RPC needs a live Supabase connection this
  // test environment doesn't have - simulate a successful login directly
  // instead (there's no dev-credential bypass in the login form itself
  // anymore, by design - see AuthProvider.loginAsStaff). StaffLoginScreen
  // itself pops on a real successful login (see its _submit()) to reveal
  // AuthGate's now-updated base content - do the same here since this
  // bypasses that screen's own pop.
  final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
  Provider.of<AuthProvider>(
    tester.element(find.byType(MaterialApp)),
    listen: false,
  ).simulateAdminLoginForTest(username: 'admin');
  navigator.pop();
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App opens to the role selection screen when logged out', (
    tester,
  ) async {
    await tester.pumpWidget(const GruhiniFoodsApp());
    await tester.pumpAndSettle();

    expect(find.text('Welcome Back!'), findsOneWidget);
    expect(find.text('I am a Customer'), findsOneWidget);
    // Shop Owner and Admin share one combined staff login option.
    expect(find.text('Shop Owner / Admin'), findsOneWidget);
  });

  testWidgets('Customer can log in and reach the bottom navigation tabs', (
    tester,
  ) async {
    await _loginAsCustomer(tester);

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Cart'), findsOneWidget);
    expect(find.text('Orders'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Asha Rao'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Log out'), 100);
    expect(find.text('Log out'), findsOneWidget);
  });

  testWidgets(
    'Home screen shows category chips for Snacks, Sweets and Pickles',
    (tester) async {
      await _loginAsCustomer(tester);

      expect(find.text('Snacks'), findsWidgets);
      expect(find.text('Sweets'), findsWidgets);

      // The category chip row scrolls horizontally and the 390px test
      // viewport doesn't fit all 4 chips at once - scroll it into view
      // rather than assuming it's already built/visible.
      await tester.dragUntilVisible(
        find.text('Pickles'),
        find.byWidgetPredicate(
          (w) => w is ListView && w.scrollDirection == Axis.horizontal,
        ),
        const Offset(-100, 0),
      );
      expect(find.text('Pickles'), findsWidgets);
    },
  );

  testWidgets('Adding a product shows it in the cart with the correct total', (
    tester,
  ) async {
    await _loginAsCustomer(tester, seedProducts: productsData);

    final firstProduct = productsData.first;
    // ProductCard's initial add control is a plain "+" pill, not an
    // Icons.add IconButton (see lib/widgets/product_card.dart _AddButton).
    await tester.ensureVisible(find.text('+').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('+').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cart'));
    await tester.pumpAndSettle();

    expect(find.text('Your cart is empty'), findsNothing);
    expect(find.text(firstProduct.name), findsOneWidget);
    expect(find.text('Proceed to Checkout'), findsOneWidget);
  });

  testWidgets(
    'Admin dashboard and orders screens render seeded orders without error',
    (tester) async {
      await _loginAsAdmin(tester);

      // There's no real Supabase in this test environment, so
      // OrdersProvider's normal Supabase-backed load() always comes back
      // empty - seed it directly so the orders list has something to render.
      Provider.of<OrdersProvider>(
        tester.element(find.byType(MaterialApp)),
        listen: false,
      ).seedForTest(ordersData);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Dashboard'), findsWidgets);

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: find.byType(Drawer), matching: find.text('Orders')),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('#'), findsWidgets);
    },
  );

  testWidgets('Admin can logout via the sidebar with a confirmation dialog', (
    tester,
  ) async {
    await _loginAsAdmin(tester);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('Logout'), findsOneWidget);
    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();

    expect(find.text('Are you sure you want to logout?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Logout'), findsOneWidget);

    // Cancel should dismiss the dialog and leave the admin logged in.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Are you sure you want to logout?'), findsNothing);
    expect(find.text('Dashboard'), findsWidgets);

    // Now actually confirm logout.
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Logout'));
    await tester.pumpAndSettle();

    expect(find.text('Staff Login'), findsOneWidget);
    expect(find.text('Dashboard'), findsNothing);

    // Back navigation must never reveal the dashboard again: pop everything
    // the Navigator will let us, and confirm the dashboard stays gone.
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    while (await navigator.maybePop()) {
      await tester.pumpAndSettle();
    }
    expect(find.text('Dashboard'), findsNothing);
  });

  testWidgets(
    'Admin sidebar is permanently visible (no drawer) on wide/desktop layouts',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const GruhiniFoodsApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Shop Owner / Admin'));
      await tester.pumpAndSettle();
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      Provider.of<AuthProvider>(
        tester.element(find.byType(MaterialApp)),
        listen: false,
      ).simulateAdminLoginForTest(username: 'admin');
      navigator.pop();
      await tester.pumpAndSettle();

      // The sidebar (with all 5 sections + Logout) should already be on
      // screen; no hamburger menu needed to reveal it.
      expect(find.byIcon(Icons.menu), findsNothing);
      expect(find.text('Products'), findsWidgets);
      expect(find.text('Settings'), findsWidgets);
      expect(find.text('Logout'), findsOneWidget);

      await tester.tap(find.text('Logout'));
      await tester.pumpAndSettle();
      expect(find.text('Are you sure you want to logout?'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Logout'));
      await tester.pumpAndSettle();

      expect(find.text('Staff Login'), findsOneWidget);
      expect(find.text('Dashboard'), findsNothing);
    },
  );

  testWidgets('Orders screen renders seeded short-id orders without error', (
    tester,
  ) async {
    await _loginAsCustomer(tester);

    // ordersData's orders belong to phone 9876543210, matching the customer
    // logged in above - the Orders tab only ever shows the logged-in
    // customer's own orders (see lib/screens/orders_screen.dart).
    Provider.of<OrdersProvider>(
      tester.element(find.byType(MaterialApp)),
      listen: false,
    ).seedForTest(ordersData);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Orders'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Order #'), findsWidgets);
  });

  testWidgets(
    'Home shows an Order Again row for products from past orders',
    (tester) async {
      await _loginAsCustomer(tester, seedProducts: productsData);

      final reorderedProduct = productsData.first;
      Provider.of<OrdersProvider>(
        tester.element(find.byType(MaterialApp)),
        listen: false,
      ).seedForTest([
        Order(
          id: 'o1',
          customerName: 'Asha Rao',
          customerPhone: '9876543210',
          deliveryAddress: '12 MG Road, Bengaluru - 560001',
          items: [
            OrderLineItem(
              productName: reorderedProduct.name,
              price: reorderedProduct.price,
              quantity: 2,
              productId: reorderedProduct.id,
            ),
          ],
          total: reorderedProduct.price * 2,
          placedAt: DateTime(2026, 6, 18),
          shopOwnerId: reorderedProduct.shopOwnerId,
          status: OrderStatus.delivered,
          paymentVerified: true,
        ),
      ]);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Order Again'), findsOneWidget);
      // Appears in both the Order Again row and the main catalog grid below.
      expect(find.text(reorderedProduct.name), findsWidgets);
    },
  );

  testWidgets(
    'Home grid shows at least 4 compact product cards without scrolling',
    (tester) async {
      await _loginAsCustomer(tester, seedProducts: productsData);

      // The header chrome (search bar, promo banner, category chips) above
      // the grid takes up a good chunk of a 390x844 viewport, so a 2-column
      // grid realistically fits ~2 rows (4 cards) before needing to scroll.
      final cardFinder = find.byType(Card);
      expect(cardFinder.evaluate().length, greaterThanOrEqualTo(4));

      final cardHeight = tester.getSize(cardFinder.first).height;
      expect(cardHeight, greaterThanOrEqualTo(180));
      expect(cardHeight, lessThanOrEqualTo(260));
    },
  );

  testWidgets('Searching filters the product grid instantly', (tester) async {
    await _loginAsCustomer(tester, seedProducts: productsData);

    // Murukku is the first seeded product, so it's always on-screen without
    // scrolling; Mysore Pak (further down the grid) only needs to be visible
    // once the search has narrowed the grid down to just itself.
    expect(find.text('Murukku'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Mysore');
    await tester.pump();

    expect(find.text('Mysore Pak'), findsOneWidget);
    expect(find.text('Murukku'), findsNothing);
  });

  testWidgets('Filter chips narrow products down to a single category', (
    tester,
  ) async {
    await _loginAsCustomer(tester, seedProducts: productsData);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Sweets'));
    await tester.pumpAndSettle();

    final sweetNames = productsData
        .where((p) => p.category == ProductCategory.sweets)
        .map((p) => p.name);
    final snackNames = productsData
        .where((p) => p.category == ProductCategory.snacks)
        .map((p) => p.name);

    for (final name in sweetNames) {
      expect(find.text(name), findsOneWidget);
    }
    for (final name in snackNames) {
      expect(find.text(name), findsNothing);
    }
  });

  testWidgets('Dark mode toggle in Profile switches the app theme', (
    tester,
  ) async {
    await _loginAsCustomer(tester);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Dark mode'), findsOneWidget);

    final materialAppBefore = tester.widget<MaterialApp>(
      find.byType(MaterialApp),
    );
    expect(materialAppBefore.themeMode, ThemeMode.light);

    await tester.tap(find.widgetWithText(SwitchListTile, 'Dark mode'));
    await tester.pumpAndSettle();

    final materialAppAfter = tester.widget<MaterialApp>(
      find.byType(MaterialApp),
    );
    expect(materialAppAfter.themeMode, ThemeMode.dark);
  });

  testWidgets(
    'Customer can add a delivery address from the Profile screen',
    (tester) async {
      await _loginAsCustomer(tester);

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      expect(find.text('+91 9876543210'), findsOneWidget);
      // No address saved yet - the fresh test customer never set one.
      expect(find.text('Not set'), findsOneWidget);

      await tester.tap(find.text('Delivery address'));
      await tester.pumpAndSettle();
      expect(find.text('My Addresses'), findsWidgets);
      expect(find.text('Add Address'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'House / Flat / Floor No.'),
        '12',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Street / Colony / Area'),
        'MG Road',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'City'),
        'Bengaluru',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Pincode'),
        '560001',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save Address'));
      await tester.pumpAndSettle();

      // Back on the Profile screen with the freshly saved address showing.
      expect(find.text('Delivery address'), findsOneWidget);
      expect(find.textContaining('MG Road'), findsOneWidget);
    },
  );

  testWidgets(
    'Customer can delete their account from the Profile screen',
    (tester) async {
      await _loginAsCustomer(tester);

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      final auth = Provider.of<AuthProvider>(
        tester.element(find.byType(MaterialApp)),
        listen: false,
      );
      expect(auth.role, AppRole.customer);

      await tester.scrollUntilVisible(find.text('Delete account'), 100);
      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('This cannot be undone. Continue?'),
        findsOneWidget,
      );

      // Cancel first - must leave the account untouched.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(auth.role, AppRole.customer);

      // Now actually confirm.
      await tester.scrollUntilVisible(find.text('Delete account'), 100);
      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(auth.role, AppRole.none);
      expect(auth.customerPhone, isEmpty);
      // Back at role selection - the account is gone, not just logged out
      // of a still-existing one.
      expect(find.text('Welcome Back!'), findsOneWidget);
    },
  );

  test('Product catalog contains items across Snacks and Sweets', () {
    final categories = productsData.map((p) => p.category).toSet();
    expect(categories, {ProductCategory.snacks, ProductCategory.sweets});
  });

  test(
    'Product catalog includes at least 8 products for a fuller home grid',
    () {
      expect(productsData.length, greaterThanOrEqualTo(8));
      final names = productsData.map((p) => p.name).toSet();
      expect(
        names,
        containsAll([
          'Murukku',
          'Banana Chips',
          'Madras Mixture',
          'Mysore Pak',
          'Ragi Cookies',
          'Badam Milk',
          'Peanut Chikki',
          'Ribbon Pakoda',
        ]),
      );
    },
  );

  test('Every product has a non-empty asset image path', () {
    for (final product in productsData) {
      expect(product.imagePath, startsWith('assets/images/products/'));
    }
  });

  test(
    'ProductsProvider.updateProduct mutates the existing instance in place',
    () async {
      final provider = ProductsProvider()..seedForTest(productsData);
      final original = provider.products.first;

      // updateProduct's final write goes to Supabase, which isn't available
      // in this test environment - only the synchronous in-place field
      // mutation (this test's actual subject) happens before that point, so
      // the resulting network error is expected and ignored.
      await provider
          .updateProduct(
            original.id,
            name: 'Updated Name',
            category: original.category,
            price: 999,
            unit: original.unit,
            imagePath: original.imagePath,
            description: original.description,
          )
          .catchError((_) {});

      // Same object reference: anything already holding this Product (a cart
      // line item, an open details screen) sees the update automatically.
      expect(provider.products.first, same(original));
      expect(original.name, 'Updated Name');
      expect(original.price, 999);
    },
  );

  test(
    'ProductsProvider seeds independent copies, not shared catalog instances',
    () {
      final providerA = ProductsProvider()..seedForTest(productsData);
      providerA
          .updateProduct(
            providerA.products.first.id,
            name: 'Mutated In Provider A',
            category: providerA.products.first.category,
            price: providerA.products.first.price,
            unit: providerA.products.first.unit,
            imagePath: providerA.products.first.imagePath,
            description: providerA.products.first.description,
          )
          .catchError((_) {});

      // A fresh provider (as created on every login) must not see the edit:
      // it should reflect the pristine catalog, not a polluted shared
      // instance - and the static seed data itself must stay untouched too.
      final providerB = ProductsProvider()..seedForTest(productsData);
      expect(providerB.products.first.name, isNot('Mutated In Provider A'));
      expect(productsData.first.name, isNot('Mutated In Provider A'));
    },
  );

  testWidgets('ProductImagePicker shows the picked image preview immediately', (
    tester,
  ) async {
    Uint8List? capturedBytes;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => ProductImagePicker(
              imageBytes: capturedBytes,
              imagePath: '',
              pickImage: () async => _kTestPngBytes,
              onImagePicked: (bytes) => setState(() => capturedBytes = bytes),
            ),
          ),
        ),
      ),
    );

    // No image yet: placeholder icon and the "Click to change" hint.
    expect(find.byIcon(Icons.add_photo_alternate_outlined), findsOneWidget);
    expect(find.text('Click to change'), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is Image && w.image is MemoryImage),
      findsNothing,
    );

    await tester.tap(find.byIcon(Icons.camera_alt));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate((w) => w is Image && w.image is MemoryImage),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.add_photo_alternate_outlined), findsNothing);
  });

  testWidgets('An admin-updated product name propagates to Home and Cart', (
    tester,
  ) async {
    await _loginAsCustomer(tester, seedProducts: productsData);

    final productsProvider = Provider.of<ProductsProvider>(
      tester.element(find.byType(MaterialApp)),
      listen: false,
    );
    final target = productsProvider.products.first;

    // Add it to the cart first, under its original name.
    // ProductCard's initial add control is a plain "+" pill, not an
    // Icons.add IconButton (see lib/widgets/product_card.dart _AddButton).
    await tester.ensureVisible(find.text('+').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('+').first);
    await tester.pumpAndSettle();
    expect(find.text(target.name), findsWidgets);

    // Real edits go through updateProduct(), which only notifies listeners
    // once its Supabase write succeeds - there's no live backend here, so
    // that write can never succeed. Mutate the shared Product instance
    // directly instead (exactly what updateProduct does internally) and
    // trigger the rebuild it would normally trigger on success.
    target.name = 'Murukku Deluxe';
    productsProvider.notifyForTest();
    await tester.pumpAndSettle();

    // Home grid now shows the new name.
    expect(find.text('Murukku Deluxe'), findsWidgets);

    // The cart line item (added before the name changed) shows it too,
    // because updateProduct mutated the very same Product instance the
    // cart already holds a reference to.
    await tester.tap(find.text('Cart'));
    await tester.pumpAndSettle();
    expect(find.text('Murukku Deluxe'), findsOneWidget);
  });

  testWidgets(
    'Product Details screen renders an admin-picked image via ProductImage',
    (tester) async {
      final product = productsData.first.copy()..imageBytes = _kTestPngBytes;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => CartProvider()),
            ChangeNotifierProvider(create: (_) => ProductsProvider()),
            ChangeNotifierProvider(create: (_) => ReviewsProvider()),
          ],
          child: MaterialApp(home: ProductDetailsScreen(product: product)),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate((w) => w is Image && w.image is MemoryImage),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Checkout wizard navigates Cart -> Delivery Address -> Order Summary -> '
    'Payment Method -> UPI Payment -> Payment Confirmation without runtime errors',
    (tester) async {
      await _loginAsCustomer(tester);

      // There's no real Supabase in this test environment, so the product
      // catalog never loads via the Home screen grid - add directly to the
      // running app's CartProvider instance instead, using the static seed
      // data (which doesn't depend on a network call) as the product.
      final cartProvider = Provider.of<CartProvider>(
        tester.element(find.byType(MaterialApp)),
        listen: false,
      );
      cartProvider.add(productsData.first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cart'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Proceed to Checkout'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Delivery Address'), findsWidgets);

      // The customer signed up without a saved address (address collection
      // now happens here, not at login), so the form must be filled in.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'House / Flat / Floor No.'),
        '12',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Street / Colony / Area'),
        'MG Road',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'City'),
        'Bengaluru',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Pincode'),
        '560001',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save & Continue'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Order Summary'), findsWidgets);

      await tester.tap(find.text('Continue to Payment'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Payment Method'), findsWidgets);

      // Direct UPI app payment is Android-only; this test runs on the host
      // platform, so only the QR flow's button is shown.
      await tester.tap(find.text('Scan QR Code'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Pay via UPI'), findsWidgets);

      await tester.tap(find.text('I Have Paid'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Confirm Payment'), findsWidgets);

      // No real Supabase in this test environment, so submitting can't
      // succeed - the important thing is that the failure surfaces as a
      // friendly SnackBar, not an uncaught exception/red screen.
      await tester.tap(find.text('Submit Order'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Could not place order'), findsOneWidget);
    },
  );

  group('OrderDetailsScreen action buttons match the order status', () {
    Order buildOrder({
      required OrderStatus status,
      bool paymentVerified = false,
    }) {
      return Order(
        id: 'o1',
        customerName: 'Asha Rao',
        customerPhone: '9876543210',
        deliveryAddress: '12 MG Road, Bengaluru - 560001',
        items: const [
          OrderLineItem(productName: 'Murukku', price: 120, quantity: 2),
        ],
        total: 240,
        placedAt: DateTime(2026, 6, 18),
        shopOwnerId: 's1',
        status: status,
        paymentVerified: paymentVerified,
      );
    }

    Future<void> pumpOrderDetails(WidgetTester tester, Order order) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => OrdersProvider()),
          ],
          child: MaterialApp(home: OrderDetailsScreen(order: order)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'Payment Verification (unverified) shows Verify/Reject Payment',
      (tester) async {
        await pumpOrderDetails(
          tester,
          buildOrder(status: OrderStatus.paymentVerification),
        );

        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(find.text('Verify Payment'), 200);
        expect(
          find.widgetWithText(FilledButton, 'Verify Payment'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(OutlinedButton, 'Reject Payment'),
          findsOneWidget,
        );
        expect(find.text('Accept Order'), findsNothing);
      },
    );

    testWidgets('Payment Verification (verified) shows Accept Order', (
      tester,
    ) async {
      await pumpOrderDetails(
        tester,
        buildOrder(
          status: OrderStatus.paymentVerification,
          paymentVerified: true,
        ),
      );

      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Accept Order'), 200);
      expect(find.widgetWithText(FilledButton, 'Accept Order'), findsOneWidget);
      expect(find.text('Verify Payment'), findsNothing);
    });

    testWidgets('Accepted shows Start Preparing', (tester) async {
      await pumpOrderDetails(tester, buildOrder(status: OrderStatus.accepted));

      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Start Preparing'), 200);
      expect(
        find.widgetWithText(FilledButton, 'Start Preparing'),
        findsOneWidget,
      );
    });

    testWidgets('Preparing shows Mark Out for Delivery', (tester) async {
      await pumpOrderDetails(tester, buildOrder(status: OrderStatus.preparing));

      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Mark Out for Delivery'), 200);
      expect(
        find.widgetWithText(FilledButton, 'Mark Out for Delivery'),
        findsOneWidget,
      );
    });

    testWidgets('Out for Delivery shows Mark Delivered', (tester) async {
      await pumpOrderDetails(
        tester,
        buildOrder(status: OrderStatus.outForDelivery),
      );

      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Mark Delivered'), 200);
      expect(
        find.widgetWithText(FilledButton, 'Mark Delivered'),
        findsOneWidget,
      );
    });

    testWidgets('Delivered and Cancelled show no action buttons', (
      tester,
    ) async {
      await pumpOrderDetails(tester, buildOrder(status: OrderStatus.delivered));
      expect(tester.takeException(), isNull);
      expect(find.byType(FilledButton), findsNothing);

      await pumpOrderDetails(tester, buildOrder(status: OrderStatus.cancelled));
      expect(tester.takeException(), isNull);
      expect(find.byType(FilledButton), findsNothing);
    });
  });

  testWidgets(
    'OrderTrackingScreen lists every ordered item with its name and quantity',
    (tester) async {
      final order = Order(
        id: 'o1',
        customerName: 'Asha Rao',
        customerPhone: '9876543210',
        deliveryAddress: '12 MG Road, Bengaluru - 560001',
        items: const [
          OrderLineItem(productName: 'Murukku', price: 120, quantity: 2),
          OrderLineItem(productName: 'Banana Chips', price: 90, quantity: 1),
        ],
        total: 330,
        placedAt: DateTime(2026, 6, 18),
        shopOwnerId: 's1',
        status: OrderStatus.preparing,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => OrdersProvider()),
          ],
          child: MaterialApp(home: OrderTrackingScreen(order: order)),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Order Items'), findsOneWidget);
      expect(find.text('Murukku x2'), findsOneWidget);
      expect(find.text('Banana Chips x1'), findsOneWidget);
    },
  );

  testWidgets(
    'OrderPlacedScreen animates in the success checkmark and order summary',
    (tester) async {
      final order = Order(
        id: 'o1',
        customerName: 'Asha Rao',
        customerPhone: '9876543210',
        deliveryAddress: '12 MG Road, Bengaluru - 560001',
        items: const [
          OrderLineItem(productName: 'Murukku', price: 120, quantity: 2),
        ],
        total: 240,
        placedAt: DateTime(2026, 6, 18),
        shopOwnerId: 's1',
        paymentVerified: true,
      );

      await tester.pumpWidget(
        MaterialApp(home: OrderPlacedScreen(orders: [order])),
      );

      // Mid-animation: the checkmark/content shouldn't error out before the
      // AnimationController finishes settling.
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Order Placed!'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);
      expect(find.text('View My Orders'), findsOneWidget);
      expect(find.text('Continue Shopping'), findsOneWidget);
    },
  );

  testWidgets(
    'InvoiceScreen renders an itemized bill with total and payment status',
    (tester) async {
      final order = Order(
        id: 'o1',
        customerName: 'Asha Rao',
        customerPhone: '9876543210',
        deliveryAddress: '12 MG Road, Bengaluru - 560001',
        items: const [
          OrderLineItem(productName: 'Murukku', price: 120, quantity: 2),
          OrderLineItem(productName: 'Banana Chips', price: 90, quantity: 1),
        ],
        total: 330,
        placedAt: DateTime(2026, 6, 18),
        shopOwnerId: 's1',
        paymentMethod: 'razorpay',
        paymentVerified: true,
        transactionId: 'pay_test123',
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => BusinessSettingsProvider()),
          ],
          child: MaterialApp(home: InvoiceScreen(order: order)),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('ORDER INVOICE'), findsOneWidget);
      expect(find.text('#${order.shortId}'), findsOneWidget);
      expect(find.text('Murukku'), findsOneWidget);
      expect(find.text('₹240'), findsOneWidget);
      expect(find.text('₹330'), findsOneWidget);
      expect(find.text('Paid'), findsOneWidget);
      expect(find.text('Online (Razorpay)'), findsOneWidget);
      expect(find.text('pay_test123'), findsOneWidget);
    },
  );

  group('OrdersProvider.buildOrderForTest field mapping', () {
    // buildOrderForTest exposes exactly the field-mapping logic placeOrder()
    // uses internally, without requiring a live Supabase connection - see
    // lib/state/orders_provider.dart.
    List<CartItem> cartItems() => [
      CartItem(product: productsData.first, quantity: 2),
    ];

    test(
      'Razorpay path (preVerified) marks payment verified with razorpay metadata',
      () {
        final order = OrdersProvider().buildOrderForTest(
          id: 'o1',
          customerName: 'Asha Rao',
          customerPhone: '9876543210',
          deliveryAddress: '12 MG Road, Bengaluru - 560001',
          shopOwnerId: productsData.first.shopOwnerId,
          items: cartItems(),
          paymentMethod: 'razorpay',
          transactionId: 'pay_test123',
          razorpayOrderId: 'order_test123',
          preVerified: true,
        );

        expect(order.paymentMethod, 'razorpay');
        expect(order.paymentStatus, PaymentStatus.verified);
        expect(order.paymentVerified, isTrue);
        expect(order.verifiedBy, 'razorpay');
        expect(order.verifiedAt, isNotNull);
        expect(order.transactionId, 'pay_test123');
        expect(order.razorpayOrderId, 'order_test123');
        // Never skips straight to accepted - the shop owner still gets an
        // explicit "Accept Order" step (see OrderDetailsScreen).
        expect(order.status, OrderStatus.paymentVerification);
      },
    );

    test(
      'Manual path (defaults) leaves payment unverified, same as before Razorpay',
      () {
        final order = OrdersProvider().buildOrderForTest(
          id: 'o2',
          customerName: 'Asha Rao',
          customerPhone: '9876543210',
          deliveryAddress: '12 MG Road, Bengaluru - 560001',
          shopOwnerId: productsData.first.shopOwnerId,
          items: cartItems(),
        );

        expect(order.paymentMethod, 'upi');
        expect(order.paymentStatus, PaymentStatus.pending);
        expect(order.paymentVerified, isFalse);
        expect(order.verifiedBy, isNull);
        expect(order.verifiedAt, isNull);
        expect(order.razorpayOrderId, isNull);
        expect(order.status, OrderStatus.paymentVerification);
      },
    );
  });

  group('calculateDeliveryFee', () {
    const settings = BusinessSettings(
      businessName: 'Gruhini Foods',
      supportPhone: '',
      upiId: '',
      upiQrUrl: '',
      deliveryFee: 40,
      freeDeliveryAbove: 500,
    );

    test('charges the flat fee below the free-delivery threshold', () {
      expect(calculateDeliveryFee(499, settings), 40);
    });

    test('waives the fee at exactly the free-delivery threshold', () {
      expect(calculateDeliveryFee(500, settings), 0);
    });

    test('waives the fee above the free-delivery threshold', () {
      expect(calculateDeliveryFee(1000, settings), 0);
    });

    test('charges the flat fee when no free-delivery threshold is set', () {
      const noThreshold = BusinessSettings(
        businessName: 'Gruhini Foods',
        supportPhone: '',
        upiId: '',
        upiQrUrl: '',
        deliveryFee: 40,
      );
      expect(calculateDeliveryFee(100000, noThreshold), 40);
    });

    test('is free by default (before an admin configures anything)', () {
      const defaults = BusinessSettings(
        businessName: 'Gruhini Foods',
        supportPhone: '',
        upiId: '',
        upiQrUrl: '',
      );
      expect(calculateDeliveryFee(10, defaults), 0);
    });
  });

  group('isPincodeServiceable', () {
    test('delivers everywhere when no pincodes are configured', () {
      const settings = BusinessSettings(
        businessName: 'Gruhini Foods',
        supportPhone: '',
        upiId: '',
        upiQrUrl: '',
      );
      expect(isPincodeServiceable('560001', settings), isTrue);
      expect(isPincodeServiceable('', settings), isTrue);
    });

    test('only allows configured pincodes once the list is populated', () {
      const settings = BusinessSettings(
        businessName: 'Gruhini Foods',
        supportPhone: '',
        upiId: '',
        upiQrUrl: '',
        serviceablePincodes: ['560001', '560002'],
      );
      expect(isPincodeServiceable('560001', settings), isTrue);
      expect(isPincodeServiceable('560099', settings), isFalse);
    });
  });

  group('OrdersProvider.canCustomerCancel', () {
    // Mirrors the published refunds policy: cancellable only while still in
    // Payment Verification, since once a shop owner accepts, food is being
    // prepared fresh to order.
    Order orderWithStatus(OrderStatus status) => OrdersProvider()
        .buildOrderForTest(
          id: 'o1',
          customerName: 'Asha Rao',
          customerPhone: '9876543210',
          deliveryAddress: '12 MG Road, Bengaluru - 560001',
          shopOwnerId: productsData.first.shopOwnerId,
          items: [CartItem(product: productsData.first, quantity: 1)],
          paymentMethod: 'razorpay',
        )
      ..status = status;

    test('allows cancelling while payment is still being verified', () {
      final provider = OrdersProvider();
      expect(
        provider.canCustomerCancel(
          orderWithStatus(OrderStatus.paymentVerification),
        ),
        isTrue,
      );
    });

    test('blocks cancelling once the order has been accepted or later', () {
      final provider = OrdersProvider();
      for (final status in [
        OrderStatus.accepted,
        OrderStatus.preparing,
        OrderStatus.outForDelivery,
        OrderStatus.delivered,
        OrderStatus.cancelled,
      ]) {
        expect(
          provider.canCustomerCancel(orderWithStatus(status)),
          isFalse,
          reason: '$status must not be customer-cancellable',
        );
      }
    });
  });

  group('CartProvider.addFromOrder (Reorder)', () {
    test('matches by productId and adds the ordered quantity', () {
      final cart = CartProvider();
      final murukku = productsData.first;
      final result = cart.addFromOrder([
        OrderLineItem(
          productName: murukku.name,
          price: murukku.price,
          quantity: 3,
          productId: murukku.id,
        ),
      ], productsData);

      expect(result.addedCount, 1);
      expect(result.unavailable, isEmpty);
      expect(cart.quantityOf(murukku.id), 3);
    });

    test(
      'falls back to matching by productName when productId is null '
      '(orders placed before that field existed)',
      () {
        final cart = CartProvider();
        final murukku = productsData.first;
        final result = cart.addFromOrder([
          OrderLineItem(
            productName: murukku.name,
            price: murukku.price,
            quantity: 1,
          ),
        ], productsData);

        expect(result.addedCount, 1);
        expect(cart.quantityOf(murukku.id), 1);
      },
    );

    test(
      'skips and reports a product that no longer exists in the catalog',
      () {
        final cart = CartProvider();
        final result = cart.addFromOrder([
          const OrderLineItem(
            productName: 'Discontinued Snack',
            price: 50,
            quantity: 1,
            productId: 'no-such-id',
          ),
        ], productsData);

        expect(result.addedCount, 0);
        expect(result.unavailable, ['Discontinued Snack']);
        expect(cart.items, isEmpty);
      },
    );

    test('skips and reports a product that is currently out of stock', () {
      final cart = CartProvider();
      final outOfStock = productsData.first.copy()..inStock = false;
      final result = cart.addFromOrder([
        OrderLineItem(
          productName: outOfStock.name,
          price: outOfStock.price,
          quantity: 1,
          productId: outOfStock.id,
        ),
      ], [outOfStock, ...productsData.skip(1)]);

      expect(result.addedCount, 0);
      expect(result.unavailable, [outOfStock.name]);
    });

    test('adds available items and reports unavailable ones together', () {
      final cart = CartProvider();
      final available = productsData.first;
      final result = cart.addFromOrder([
        OrderLineItem(
          productName: available.name,
          price: available.price,
          quantity: 2,
          productId: available.id,
        ),
        const OrderLineItem(
          productName: 'Discontinued Snack',
          price: 50,
          quantity: 1,
          productId: 'no-such-id',
        ),
      ], productsData);

      expect(result.addedCount, 1);
      expect(result.unavailable, ['Discontinued Snack']);
      expect(cart.quantityOf(available.id), 2);
    });
  });
}

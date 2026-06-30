import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gruiny_foods/data/products_data.dart';
import 'package:gruiny_foods/main.dart';
import 'package:gruiny_foods/models/order.dart';
import 'package:gruiny_foods/models/product.dart';
import 'package:gruiny_foods/screens/order_details_screen.dart';
import 'package:gruiny_foods/screens/product_details_screen.dart';
import 'package:gruiny_foods/state/auth_provider.dart';
import 'package:gruiny_foods/state/cart_provider.dart';
import 'package:gruiny_foods/state/orders_provider.dart';
import 'package:gruiny_foods/state/products_provider.dart';
import 'package:gruiny_foods/widgets/product_image_picker.dart';

// A real, minimal 1x1 transparent PNG so Image.memory can actually decode it
// in tests (arbitrary byte sequences fail decoding and report an error).
final Uint8List _kTestPngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUAAQAAAAA=',
);

Future<void> _loginAsCustomer(WidgetTester tester) async {
  // Use a realistic mobile portrait viewport so the 2-column product grid
  // lays out the way it would on a phone, instead of the default desktop-ish
  // test surface where most grid items would be scrolled offstage.
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(const GruinyFoodsApp());
  await tester.pumpAndSettle();

  await tester.tap(find.text('I am a Customer'));
  await tester.pumpAndSettle();

  await tester.enterText(
    find.widgetWithText(TextFormField, 'Name'),
    'Asha Rao',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Phone Number'),
    '9876543210',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Address Line 1'),
    '12 MG Road',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'City'),
    'Bengaluru',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Postal Code'),
    '560001',
  );

  await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
  await tester.pumpAndSettle();
}

Future<void> _loginAsAdmin(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(const GruinyFoodsApp());
  await tester.pumpAndSettle();

  await tester.tap(find.text('I am Admin'));
  await tester.pumpAndSettle();

  await tester.enterText(
    find.widgetWithText(TextFormField, 'Username'),
    'admin',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Password'),
    'admin123',
  );

  await tester.tap(find.widgetWithText(FilledButton, 'Login'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App opens to the role selection screen when logged out', (
    tester,
  ) async {
    await tester.pumpWidget(const GruinyFoodsApp());
    await tester.pumpAndSettle();

    expect(find.text('Welcome Back!'), findsOneWidget);
    expect(find.text('I am a Customer'), findsOneWidget);
    expect(find.text('I am a Shop Owner'), findsOneWidget);
    expect(find.text('I am Admin'), findsOneWidget);
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
    await tester.scrollUntilVisible(find.text('Logout'), 100);
    expect(find.text('Logout'), findsOneWidget);
  });

  testWidgets(
    'Home screen shows category chips for Snacks, Sweets and Pickles',
    (tester) async {
      await _loginAsCustomer(tester);

      expect(find.text('Snacks'), findsWidgets);
      expect(find.text('Sweets'), findsWidgets);
      expect(find.text('Pickles'), findsWidgets);
    },
  );

  testWidgets('Adding a product shows it in the cart with the correct total', (
    tester,
  ) async {
    await _loginAsCustomer(tester);

    final firstProduct = productsData.first;
    await tester.ensureVisible(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cart'));
    await tester.pumpAndSettle();

    expect(find.text('Your cart is empty.'), findsNothing);
    expect(find.text(firstProduct.name), findsOneWidget);
    expect(find.text('Proceed to Checkout'), findsOneWidget);
  });

  testWidgets(
    'Admin dashboard and orders screens render seeded orders without error',
    (tester) async {
      await _loginAsAdmin(tester);

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

    expect(find.text('Gruhini Foods Admin'), findsOneWidget);
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

      await tester.pumpWidget(const GruinyFoodsApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('I am Admin'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Username'),
        'admin',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'admin123',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Login'));
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

      expect(find.text('Gruhini Foods Admin'), findsOneWidget);
      expect(find.text('Dashboard'), findsNothing);
    },
  );

  testWidgets('Orders screen renders seeded short-id orders without error', (
    tester,
  ) async {
    await _loginAsCustomer(tester);

    await tester.tap(find.text('Orders'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Order #'), findsWidgets);
  });

  testWidgets(
    'Home grid shows at least 6 compact product cards without scrolling',
    (tester) async {
      await _loginAsCustomer(tester);

      final cardFinder = find.byType(Card);
      expect(cardFinder.evaluate().length, greaterThanOrEqualTo(6));

      final cardHeight = tester.getSize(cardFinder.first).height;
      expect(cardHeight, greaterThanOrEqualTo(180));
      expect(cardHeight, lessThanOrEqualTo(260));
    },
  );

  testWidgets('Searching filters the product grid instantly', (tester) async {
    await _loginAsCustomer(tester);

    expect(find.text('Mysore Pak'), findsOneWidget);
    expect(find.text('Murukku'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Mysore');
    await tester.pump();

    expect(find.text('Mysore Pak'), findsOneWidget);
    expect(find.text('Murukku'), findsNothing);
  });

  testWidgets('Filter chips narrow products down to a single category', (
    tester,
  ) async {
    await _loginAsCustomer(tester);

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

    expect(find.text('Dark Mode'), findsOneWidget);

    final materialAppBefore = tester.widget<MaterialApp>(
      find.byType(MaterialApp),
    );
    expect(materialAppBefore.themeMode, ThemeMode.light);

    await tester.tap(find.widgetWithText(SwitchListTile, 'Dark Mode'));
    await tester.pumpAndSettle();

    final materialAppAfter = tester.widget<MaterialApp>(
      find.byType(MaterialApp),
    );
    expect(materialAppAfter.themeMode, ThemeMode.dark);
  });

  testWidgets('Customer can edit phone and address from the Profile screen', (
    tester,
  ) async {
    await _loginAsCustomer(tester);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Address'), findsOneWidget);
    expect(find.text('12 MG Road, Bengaluru - 560001'), findsOneWidget);
    expect(find.text('9876543210'), findsOneWidget);

    // Edit the phone number.
    await tester.tap(
      find.widgetWithIcon(IconButton, Icons.edit_outlined).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Edit Phone Number'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Phone Number'),
      '9999999999',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('9999999999'), findsOneWidget);
    expect(find.text('9876543210'), findsNothing);

    // Edit the address.
    await tester.tap(find.widgetWithIcon(IconButton, Icons.edit_outlined).last);
    await tester.pumpAndSettle();
    expect(find.text('Edit Address'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Address'),
      '45 Anna Salai, Chennai',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('45 Anna Salai, Chennai'), findsOneWidget);
    expect(find.text('12 MG Road, Bengaluru - 560001'), findsNothing);
  });

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
    () {
      final provider = ProductsProvider();
      final original = provider.products.first;

      provider.updateProduct(
        original.id,
        name: 'Updated Name',
        category: original.category,
        price: 999,
        unit: original.unit,
        imagePath: original.imagePath,
        description: original.description,
        imageBytes: _kTestPngBytes,
      );

      // Same object reference: anything already holding this Product (a cart
      // line item, an open details screen) sees the update automatically.
      expect(provider.products.first, same(original));
      expect(original.name, 'Updated Name');
      expect(original.price, 999);
      expect(original.imageBytes, _kTestPngBytes);
    },
  );

  test(
    'ProductsProvider seeds independent copies, not shared catalog instances',
    () {
      final providerA = ProductsProvider();
      providerA.updateProduct(
        providerA.products.first.id,
        name: 'Mutated In Provider A',
        category: providerA.products.first.category,
        price: providerA.products.first.price,
        unit: providerA.products.first.unit,
        imagePath: providerA.products.first.imagePath,
        description: providerA.products.first.description,
      );

      // A fresh provider (as created on every login) must not see the edit:
      // it should reflect the pristine catalog, not a polluted shared instance.
      final providerB = ProductsProvider();
      expect(providerB.products.first.name, isNot('Mutated In Provider A'));
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

  testWidgets(
    'Admin Products screen shows an Edit button per product, opening a dialog with an image picker',
    (tester) async {
      await _loginAsAdmin(tester);

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.text('Products'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit_outlined), findsWidgets);

      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();

      expect(find.text('Edit Product'), findsOneWidget);
      expect(find.text('Click to change'), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Update Product'),
        findsOneWidget,
      );

      // Editing the other fields and saving (without touching the photo)
      // should still work and not require a new image.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Murukku Deluxe',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Update Product'));
      await tester.pumpAndSettle();

      expect(find.text('Murukku Deluxe'), findsOneWidget);
    },
  );

  testWidgets('An admin-updated product image propagates to Home and Cart', (
    tester,
  ) async {
    await _loginAsCustomer(tester);

    final productsProvider = Provider.of<ProductsProvider>(
      tester.element(find.byType(MaterialApp)),
      listen: false,
    );
    final target = productsProvider.products.first;

    bool hasMemoryImage() => find
        .byWidgetPredicate((w) => w is Image && w.image is MemoryImage)
        .evaluate()
        .isNotEmpty;

    // Add it to the cart first, while it still has its original photo.
    await tester.ensureVisible(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();
    expect(hasMemoryImage(), isFalse);

    productsProvider.updateProduct(
      target.id,
      name: target.name,
      category: target.category,
      price: target.price,
      unit: target.unit,
      imagePath: target.imagePath,
      description: target.description,
      imageBytes: _kTestPngBytes,
    );
    await tester.pumpAndSettle();

    // Home grid now shows the new photo.
    expect(hasMemoryImage(), isTrue);

    // The cart line item (added before the image changed) shows it too,
    // because updateProduct mutated the very same Product instance the
    // cart already holds a reference to.
    await tester.tap(find.text('Cart'));
    await tester.pumpAndSettle();
    expect(hasMemoryImage(), isTrue);
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

      // The customer signed up with an address, so it's offered as a saved
      // address rather than requiring the form to be filled in again.
      await tester.tap(find.text('Save & Continue'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Order Summary'), findsWidgets);

      await tester.tap(find.text('Continue to Payment'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Payment Method'), findsWidgets);

      await tester.tap(find.text('Continue to Pay'));
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
}

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/admin/admin_customers_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/admin_login_screen.dart';
import 'screens/admin/admin_orders_screen.dart';
import 'screens/admin/admin_products_screen.dart';
import 'screens/admin/admin_settings_screen.dart';
import 'screens/admin/admin_shop_owners_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/home_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/profile_screen.dart';
import 'state/auth_provider.dart';
import 'state/cart_provider.dart';
import 'state/customers_provider.dart';
import 'state/orders_provider.dart';
import 'state/products_provider.dart';
import 'state/shop_owners_provider.dart';
import 'state/theme_provider.dart';
import 'widgets/admin_sidebar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  runApp(const GruinyFoodsApp());
}

/// Brand color used throughout the app's UI.
const _brandColor = Color(0xFF7B1E26);

ThemeData _buildTheme(Brightness brightness) {
  final colorScheme = ColorScheme.fromSeed(seedColor: _brandColor, brightness: brightness);

  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    scaffoldBackgroundColor: colorScheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colorScheme.surface,
      indicatorColor: colorScheme.primaryContainer,
      elevation: 1,
    ),
    chipTheme: ChipThemeData(
      selectedColor: colorScheme.primary,
      backgroundColor: colorScheme.surfaceContainerHighest,
      side: BorderSide.none,
    ),
  );
}

class GruinyFoodsApp extends StatelessWidget {
  const GruinyFoodsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..load()),
        ChangeNotifierProvider(create: (_) => ProductsProvider()..load()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => OrdersProvider()..load()),
        ChangeNotifierProvider(create: (_) => CustomersProvider()..load()),
        ChangeNotifierProvider(create: (_) => ShopOwnersProvider()..load()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()..load()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) => MaterialApp(
          title: 'Gruhiniy Foods',
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: themeProvider.themeMode,
          home: const AuthGate(),
        ),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    switch (auth.role) {
      case AppRole.customer:
        return const CustomerRootScreen();
      case AppRole.headAdmin:
      case AppRole.shopOwner:
        return const AdminRootScreen();
      case AppRole.none:
        return const LoginScreen();
    }
  }
}

class CustomerRootScreen extends StatefulWidget {
  const CustomerRootScreen({super.key});

  @override
  State<CustomerRootScreen> createState() => _CustomerRootScreenState();
}

class _CustomerRootScreenState extends State<CustomerRootScreen> {
  int _selectedIndex = 0;

  void _goToCart() => setState(() => _selectedIndex = 1);

  @override
  Widget build(BuildContext context) {
    final cartCount = context.watch<CartProvider>().itemCount;

    final screens = [
      HomeScreen(onCartTap: _goToCart),
      const CartScreen(),
      const OrdersScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        height: 64,
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
            icon: Badge(
              label: Text('$cartCount'),
              isLabelVisible: cartCount > 0,
              child: const Icon(Icons.shopping_cart_outlined),
            ),
            label: 'Cart',
          ),
          const NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Orders'),
          const NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}

class AdminRootScreen extends StatefulWidget {
  const AdminRootScreen({super.key});

  @override
  State<AdminRootScreen> createState() => _AdminRootScreenState();
}

class _AdminRootScreenState extends State<AdminRootScreen> {
  static const _wideLayoutBreakpoint = 700.0;

  int _selectedIndex = 0;

  static const _headAdminTitles = ['Dashboard', 'Products', 'Orders', 'Customers', 'Shop Owners', 'Settings'];
  static const _headAdminScreens = [
    AdminDashboardScreen(),
    AdminProductsScreen(),
    AdminOrdersScreen(),
    AdminCustomersScreen(),
    AdminShopOwnersScreen(),
    AdminSettingsScreen(),
  ];

  static const _shopOwnerTitles = ['Dashboard', 'Products', 'Orders', 'Settings'];
  static const _shopOwnerScreens = [
    AdminDashboardScreen(),
    AdminProductsScreen(),
    AdminOrdersScreen(),
    AdminSettingsScreen(),
  ];

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Push the Admin Login screen *before* clearing auth state: this screen
    // (the admin dashboard) is what AuthGate swaps away from the moment the
    // role changes to `none`, so its context would no longer be safely
    // usable for navigation afterwards.
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
    );
    await context.read<AuthProvider>().logout();
  }

  @override
  Widget build(BuildContext context) {
    final isHeadAdmin = context.watch<AuthProvider>().role == AppRole.headAdmin;
    final titles = isHeadAdmin ? _headAdminTitles : _shopOwnerTitles;
    final screens = isHeadAdmin ? _headAdminScreens : _shopOwnerScreens;
    final selectedIndex = _selectedIndex.clamp(0, titles.length - 1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideLayoutBreakpoint;

        if (isWide) {
          return Scaffold(
            appBar: AppBar(title: Text(titles[selectedIndex])),
            body: Row(
              children: [
                SizedBox(
                  width: 240,
                  child: AdminSidebar(
                    titles: titles,
                    selectedIndex: selectedIndex,
                    onItemSelected: (index) => setState(() => _selectedIndex = index),
                    onLogout: _confirmLogout,
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: screens[selectedIndex]),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: Text(titles[selectedIndex])),
          drawer: Drawer(
            child: AdminSidebar(
              titles: titles,
              selectedIndex: selectedIndex,
              onItemSelected: (index) {
                setState(() => _selectedIndex = index);
                Navigator.of(context).pop();
              },
              onLogout: () {
                Navigator.of(context).pop();
                _confirmLogout();
              },
            ),
          ),
          body: screens[selectedIndex],
        );
      },
    );
  }
}

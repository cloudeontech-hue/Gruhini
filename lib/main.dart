import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'utils/app_colors.dart';
import 'utils/app_typography.dart';
import 'screens/admin/admin_customers_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/admin_login_screen.dart';
import 'screens/admin/admin_orders_screen.dart';
import 'screens/admin/admin_products_screen.dart';
import 'screens/admin/admin_settings_screen.dart';
import 'screens/admin/admin_shop_owners_screen.dart';
import 'screens/auth/role_selection_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/home_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/shop_owner/shop_owner_dashboard_screen.dart';
import 'screens/shop_owner/shop_owner_orders_screen.dart';
import 'screens/shop_owner/shop_owner_products_screen.dart';
import 'screens/shop_owner/shop_owner_profile_screen.dart';
import 'screens/splash_screen.dart';
import 'state/auth_provider.dart';
import 'state/business_settings_provider.dart';
import 'state/cart_provider.dart';
import 'state/customers_provider.dart';
import 'state/navigation_provider.dart';
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

ThemeData _buildTheme(Brightness brightness) {
  final isLight = brightness == Brightness.light;

  // Pin primary to exactly #7B1826 in LIGHT mode — that's the brand color
  // against cream backgrounds. In DARK mode, forcing the same dark maroon
  // would sit on an already-dark surface with poor contrast, so we let
  // Material's seed algorithm generate its own accessible, brand-hued tone
  // for dark backgrounds instead.
  final colorScheme = isLight
      ? ColorScheme.fromSeed(
          seedColor: AppColors.brand,
          brightness: brightness,
        ).copyWith(primary: AppColors.brand, onPrimary: Colors.white)
      : ColorScheme.fromSeed(
          seedColor: AppColors.brand,
          brightness: brightness,
        );

  // accent == AppColors.brand in light mode (exact brand color on cream);
  // == colorScheme.primary in dark mode (an accessible tint of the same
  // brand hue against dark surfaces). Every "branded" element below should
  // use `accent`, never AppColors.brand directly, so dark mode stays readable.
  final accent = isLight ? AppColors.brand : colorScheme.primary;

  final base = ThemeData(brightness: brightness);
  final textTheme = buildAppTextTheme(base.textTheme);

  // Cream/off-white surfaces in light mode (lifted from the logo's cloth
  // backdrop); dark mode keeps Material's generated tonal surfaces so
  // contrast and accessibility aren't compromised.
  final scaffoldBg = isLight ? AppColors.cream : colorScheme.surface;
  final cardBg = isLight ? Colors.white : colorScheme.surfaceContainerLow;
  final fieldBg = isLight
      ? AppColors.creamDark.withValues(alpha: 0.55)
      : colorScheme.surfaceContainerHighest;
  final outlineSoft = isLight
      ? AppColors.creamLine
      : colorScheme.outlineVariant;

  const cardRadius = 16.0;
  const fieldRadius = 12.0;
  const sheetRadius = 24.0;

  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    textTheme: textTheme,
    scaffoldBackgroundColor: scaffoldBg,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: scaffoldBg,
      foregroundColor: colorScheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: accent),
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: colorScheme.onSurface,
        fontSize: 18,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: isLight ? 1 : 0,
      shadowColor: AppColors.brand.withValues(alpha: 0.12),
      surfaceTintColor: Colors.transparent,
      color: cardBg,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardRadius),
        side: isLight
            ? BorderSide(color: outlineSoft, width: 1)
            : BorderSide.none,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: fieldBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: textTheme.bodyMedium,
      hintStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(fieldRadius),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(fieldRadius),
        borderSide: BorderSide(color: accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(fieldRadius),
        borderSide: BorderSide(color: colorScheme.error, width: 1.2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 48),
        backgroundColor: accent,
        foregroundColor: isLight ? Colors.white : colorScheme.onPrimary,
        elevation: 0,
        textStyle: textTheme.labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(fieldRadius),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        foregroundColor: accent,
        textStyle: textTheme.labelLarge,
        side: BorderSide(color: accent),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(fieldRadius),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accent,
        textStyle: textTheme.labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(fieldRadius),
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: accent),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: cardBg,
      indicatorColor: isLight
          ? AppColors.goldLight
          : colorScheme.primary.withValues(alpha: 0.24),
      surfaceTintColor: Colors.transparent,
      elevation: isLight ? 2 : 1,
      shadowColor: AppColors.brand.withValues(alpha: 0.10),
      height: 64,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => textTheme.labelSmall?.copyWith(
          color: states.contains(WidgetState.selected)
              ? accent
              : colorScheme.onSurfaceVariant,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w500,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? accent
              : colorScheme.onSurfaceVariant,
        ),
      ),
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: cardBg,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(
          right: Radius.circular(sheetRadius),
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: cardBg,
      surfaceTintColor: Colors.transparent,
      elevation: 4,
      shadowColor: AppColors.brand.withValues(alpha: 0.18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: colorScheme.onSurface,
      ),
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: cardBg,
      surfaceTintColor: Colors.transparent,
      elevation: 4,
      modalElevation: 6,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(sheetRadius)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.brandDark,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(fieldRadius),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: accent,
      textColor: colorScheme.onSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(fieldRadius),
      ),
    ),
    dividerTheme: DividerThemeData(color: outlineSoft, thickness: 1, space: 1),
    chipTheme: ChipThemeData(
      selectedColor: accent,
      backgroundColor: fieldBg,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      labelStyle: textTheme.labelSmall?.copyWith(color: colorScheme.onSurface),
      secondaryLabelStyle: textTheme.labelSmall?.copyWith(
        color: isLight ? Colors.white : colorScheme.onPrimary,
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? accent : null,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? accent.withValues(alpha: 0.4)
            : null,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: accent),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.brandDark,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: textTheme.bodySmall?.copyWith(color: Colors.white),
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
        ChangeNotifierProvider(
          create: (_) => BusinessSettingsProvider()..load(),
        ),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
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

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _minTimeElapsed = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _minTimeElapsed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isLoaded || !_minTimeElapsed) {
      return const SplashScreen();
    }

    switch (auth.role) {
      case AppRole.customer:
        return const CustomerRootScreen();
      case AppRole.shopOwner:
        return const ShopOwnerRootScreen();
      case AppRole.headAdmin:
        return const AdminRootScreen();
      case AppRole.none:
        return const RoleSelectionScreen();
    }
  }
}

class CustomerRootScreen extends StatelessWidget {
  const CustomerRootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cartCount = context.watch<CartProvider>().itemCount;
    final navigation = context.watch<NavigationProvider>();
    final selectedIndex = navigation.customerTabIndex;

    final screens = [
      HomeScreen(
        onCartTap: () => context.read<NavigationProvider>().goToCart(),
      ),
      const CartScreen(),
      const OrdersScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: screens[selectedIndex],
      bottomNavigationBar: NavigationBar(
        height: 64,
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              navigation.goToHome();
              break;
            case 1:
              navigation.goToCart();
              break;
            case 2:
              navigation.goToOrders();
              break;
            default:
              navigation.goToProfile();
          }
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Badge(
              label: Text('$cartCount'),
              isLabelVisible: cartCount > 0,
              child: const Icon(Icons.shopping_cart_outlined),
            ),
            label: 'Cart',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Orders',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class ShopOwnerRootScreen extends StatefulWidget {
  const ShopOwnerRootScreen({super.key});

  @override
  State<ShopOwnerRootScreen> createState() => _ShopOwnerRootScreenState();
}

class _ShopOwnerRootScreenState extends State<ShopOwnerRootScreen> {
  int _selectedIndex = 0;

  void _goToOrders() => setState(() => _selectedIndex = 2);

  @override
  Widget build(BuildContext context) {
    final screens = [
      ShopOwnerDashboardScreen(onViewAllOrders: _goToOrders),
      const ShopOwnerProductsScreen(),
      const ShopOwnerOrdersScreen(),
      const ShopOwnerProfileScreen(),
    ];

    return Scaffold(
      body: screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        height: 64,
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            label: 'Products',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
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

  // AdminRootScreen is only ever built for AppRole.headAdmin (see AuthGate
  // below) - shop owners get the separate, mobile-tailored
  // ShopOwnerRootScreen instead.
  static const _titles = [
    'Dashboard',
    'Products',
    'Orders',
    'Customers',
    'Shop Owners',
    'Settings',
  ];
  static const _screens = [
    AdminDashboardScreen(),
    AdminProductsScreen(),
    AdminOrdersScreen(),
    AdminCustomersScreen(),
    AdminShopOwnersScreen(),
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
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AdminLoginScreen()));
    await context.read<AuthProvider>().logout();
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _selectedIndex.clamp(0, _titles.length - 1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideLayoutBreakpoint;

        if (isWide) {
          return Scaffold(
            appBar: AppBar(title: Text(_titles[selectedIndex])),
            body: Row(
              children: [
                SizedBox(
                  width: 240,
                  child: AdminSidebar(
                    titles: _titles,
                    selectedIndex: selectedIndex,
                    onItemSelected: (index) =>
                        setState(() => _selectedIndex = index),
                    onLogout: _confirmLogout,
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: _screens[selectedIndex]),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: Text(_titles[selectedIndex])),
          drawer: Drawer(
            child: AdminSidebar(
              titles: _titles,
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
          body: _screens[selectedIndex],
        );
      },
    );
  }
}

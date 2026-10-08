import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../models/product.dart';
import '../state/auth_provider.dart';
import '../state/cart_provider.dart';
import '../state/orders_provider.dart';
import '../state/products_provider.dart';
import '../utils/app_colors.dart';
import '../widgets/empty_state.dart';
import '../widgets/product_card.dart';
import 'kitchens_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onCartTap;

  const HomeScreen({super.key, this.onCartTap});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _query = '';
  ProductCategory? _selectedCategory;

  // Voice search. The controller exists so dictated text can be written
  // back into the field the customer is looking at, not just into _query.
  final _searchController = TextEditingController();
  final _speech = stt.SpeechToText();
  bool _isListening = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Starts (or stops) voice input for the search field. Handles the three
  /// ways this can fail on a real device - permission refused, no speech
  /// recognition service installed, and the engine erroring mid-listen -
  /// with a plain message rather than leaving the mic stuck "on".
  Future<void> _toggleVoiceSearch() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final available = await _speech.initialize(
      onStatus: (status) {
        // 'done'/'notListening' arrive when the engine stops on its own
        // (silence timeout), so the mic icon has to reset itself too.
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _isListening = false);
        }
      },
      onError: (_) {
        if (mounted) setState(() => _isListening = false);
      },
    );

    if (!available) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Voice search isn\'t available on this device. Please type instead.',
          ),
        ),
      );
      return;
    }

    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) {
        setState(() {
          _query = result.recognizedWords;
          _searchController.text = result.recognizedWords;
          _searchController.selection = TextSelection.fromPosition(
            TextPosition(offset: _searchController.text.length),
          );
        });
      },
    );
  }

  /// The customer's most recently ordered products, most-recent-first and
  /// deduplicated, capped at 8 - matched against the live catalog (not the
  /// order's own snapshot) so price/stock/name always reflect what's
  /// current, same principle as [reorderInto]. Orders placed before
  /// [OrderLineItem.productId] existed are skipped, same as reorderInto's
  /// fallback-by-name doesn't apply here since this needs a [Product], not
  /// just a name match.
  List<Product> _reorderProducts(
    List<Product> products,
    OrdersProvider ordersProvider,
    String customerPhone,
  ) {
    final productsById = {for (final p in products) p.id: p};
    final seenIds = <String>{};
    final result = <Product>[];

    for (final order in ordersProvider.orders) {
      if (order.customerPhone != customerPhone) continue;
      for (final item in order.items) {
        final productId = item.productId;
        if (productId == null || seenIds.contains(productId)) continue;
        final product = productsById[productId];
        if (product == null || !product.inStock) continue;
        seenIds.add(productId);
        result.add(product);
        if (result.length >= 8) return result;
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final productsProvider = context.watch<ProductsProvider>();
    final cartCount = context.watch<CartProvider>().itemCount;
    final ordersProvider = context.watch<OrdersProvider>();
    final customerPhone = context.watch<AuthProvider>().customerPhone;

    if (!productsProvider.isLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final products = productsProvider.products;
    // Restores a cart persisted from a previous session, now that the
    // catalog is loaded (needed to match saved productIds back to real
    // Product objects). No-ops after the first successful call - see
    // CartProvider.restoreFromCatalog.
    unawaited(context.read<CartProvider>().restoreFromCatalog(products));
    final reorderProducts = _reorderProducts(
      products,
      ordersProvider,
      customerPhone,
    );

    final filtered = products.where((p) {
      final matchesQuery = p.name.toLowerCase().contains(_query.toLowerCase());
      final matchesCategory =
          _selectedCategory == null || p.category == _selectedCategory;
      return matchesQuery && matchesCategory;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 52,
        title: const Text('Gruhini Foods'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const KitchensScreen()),
            ),
            tooltip: 'Browse by Kitchen',
            icon: const Icon(Icons.storefront_outlined),
          ),
          IconButton(
            onPressed: widget.onCartTap,
            tooltip: 'Cart',
            icon: Badge(
              label: Text('$cartCount'),
              isLabelVisible: cartCount > 0,
              child: const Icon(Icons.shopping_cart_outlined),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: SizedBox(
              height: 48,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: _isListening
                      ? 'Listening...'
                      : 'Search snacks, sweets, pickles...',
                  hintStyle: Theme.of(context).textTheme.bodyMedium,
                  prefixIcon: Icon(
                    Icons.search,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      size: 20,
                      // Turns brand-red while live so it's obvious the mic
                      // is actually open.
                      color: _isListening
                          ? AppColors.brand
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    tooltip: _isListening
                        ? 'Stop voice search'
                        : 'Search by voice',
                    onPressed: _toggleVoiceSearch,
                  ),
                  filled: true,
                  fillColor: AppColors.creamDark.withValues(alpha: 0.6),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: _PromoBanner(),
          ),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: ProductCategory.values.length + 1,
              separatorBuilder: (context, index) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _CategoryChip(
                    icon: Icons.apps,
                    label: 'All',
                    selected: _selectedCategory == null,
                    onSelected: () => setState(() => _selectedCategory = null),
                  );
                }
                final category = ProductCategory.values[index - 1];
                return _CategoryChip(
                  icon: _categoryIcons[category]!,
                  label: category.label,
                  selected: _selectedCategory == category,
                  onSelected: () =>
                      setState(() => _selectedCategory = category),
                );
              },
            ),
          ),
          if (reorderProducts.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Order Again',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            SizedBox(
              height: 205,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: reorderProducts.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) => SizedBox(
                  width: 150,
                  child: ProductCard(product: reorderProducts[index]),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Popular Products',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const EmptyState(
                    icon: Icons.search_off,
                    title: 'No items found',
                    subtitle: 'Try a different search term or category.',
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      // Widen the grid on tablet/desktop/web instead of
                      // stretching 2 cards across the full available width.
                      final width = constraints.maxWidth;
                      final crossAxisCount = width >= 1100
                          ? 5
                          : width >= 860
                          ? 4
                          : width >= 600
                          ? 3
                          : 2;
                      return GridView.count(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.74,
                        children: filtered
                            .map((p) => ProductCard(product: p))
                            .toList(),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PromoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 96,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [AppColors.brand, AppColors.brandDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Freshly Homemade',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Just for You!',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.goldLight,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 64,
            height: 64,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: ClipOval(
              child: Container(
                color: Colors.white,
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _categoryIcons = {
  ProductCategory.snacks: Icons.cookie_outlined,
  ProductCategory.sweets: Icons.cake_outlined,
  ProductCategory.pickles: Icons.eco_outlined,
};

class _CategoryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _CategoryChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      avatar: Icon(icon, size: 16),
      showCheckmark: false,
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}

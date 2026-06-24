import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../state/cart_provider.dart';
import '../state/products_provider.dart';
import '../widgets/product_card.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onCartTap;

  const HomeScreen({super.key, this.onCartTap});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _query = '';
  ProductCategory? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final productsProvider = context.watch<ProductsProvider>();
    final cartCount = context.watch<CartProvider>().itemCount;

    if (!productsProvider.isLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final products = productsProvider.products;

    final filtered = products.where((p) {
      final matchesQuery = p.name.toLowerCase().contains(_query.toLowerCase());
      final matchesCategory = _selectedCategory == null || p.category == _selectedCategory;
      return matchesQuery && matchesCategory;
    }).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        toolbarHeight: 52,
        title: const Text('Gruhini Foods', style: TextStyle(fontSize: 18)),
        actions: [
          IconButton(
            onPressed: widget.onCartTap,
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
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search snacks, sweets, pickles...',
                  hintStyle: const TextStyle(fontSize: 14),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                  onSelected: () => setState(() => _selectedCategory = category),
                );
              },
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('No items found.'))
                : GridView.count(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.74,
                    children: filtered.map((p) => ProductCard(product: p)).toList(),
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
      label: Text(label, style: const TextStyle(fontSize: 13)),
      selected: selected,
      onSelected: (_) => onSelected(),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}

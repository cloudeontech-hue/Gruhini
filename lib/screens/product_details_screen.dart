import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../models/review.dart';
import '../state/cart_provider.dart';
import '../state/products_provider.dart';
import '../state/reviews_provider.dart';
import '../utils/formatters.dart';
import '../widgets/product_image.dart';
import '../widgets/responsive_center.dart';
import '../widgets/star_rating.dart';
import 'checkout/delivery_address_screen.dart';

class ProductDetailsScreen extends StatelessWidget {
  final Product product;

  const ProductDetailsScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final quantity = cart.quantityOf(product.id);
    context.watch<ProductsProvider>();
    final reviewsProvider = context.watch<ReviewsProvider>();
    final ratingSummary = reviewsProvider.summaryFor(product.id);
    unawaited(reviewsProvider.loadReviewsFor(product.id));
    final reviews = reviewsProvider.reviewsFor(product.id);

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      bottomNavigationBar: quantity > 0
          ? SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  border: Border(
                    top: BorderSide(color: colorScheme.outlineVariant),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${cart.itemCount} item${cart.itemCount == 1 ? '' : 's'} in cart',
                          style: textTheme.bodyMedium,
                        ),
                        const Spacer(),
                        Text(
                          formatPrice(cart.total),
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const DeliveryAddressScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.shopping_cart_checkout),
                      label: const Text('Proceed to Checkout'),
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            title: Text(product.name),
            flexibleSpace: FlexibleSpaceBar(
              background: ProductImage(product: product),
            ),
          ),
          SliverToBoxAdapter(
            child: ResponsiveCenter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      product.name,
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Price / unit
                    Text(
                      '${formatPrice(product.price)} / ${product.unit}',
                      style: textTheme.titleLarge?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Description
                    if (product.description.isNotEmpty)
                      Text(
                        product.description,
                        style: textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(height: 16),
                    // Tags
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text(product.category.label)),
                        Chip(label: Text(product.unit)),
                        Chip(
                          label: Text(
                            product.inStock ? 'In Stock' : 'Out of Stock',
                          ),
                          backgroundColor: product.inStock
                              ? colorScheme.primaryContainer
                              : colorScheme.errorContainer,
                          labelStyle: TextStyle(
                            color: product.inStock
                                ? colorScheme.onPrimaryContainer
                                : colorScheme.onErrorContainer,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _RatingsSection(
                      summary: ratingSummary,
                      reviews: reviews,
                    ),
                    const SizedBox(height: 24),
                    // Cart controls
                    if (!product.inStock)
                      Text(
                        'This item is currently out of stock.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.error,
                        ),
                      )
                    else if (quantity == 0)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => cart.add(product),
                          icon: const Icon(Icons.shopping_cart_outlined),
                          label: const Text('Add to Cart'),
                        ),
                      )
                    else
                      Row(
                        children: [
                          _StepBtn(
                            label: '−',
                            onTap: () => cart.decrement(product.id),
                            colorScheme: colorScheme,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              '$quantity',
                              style: textTheme.titleLarge,
                            ),
                          ),
                          _StepBtn(
                            label: '+',
                            onTap: () => cart.add(product),
                            colorScheme: colorScheme,
                          ),
                          const Spacer(),
                          Text(
                            formatPrice(product.price * quantity),
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _StepBtn({
    required this.label,
    required this.onTap,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label == '+' ? 'Increase quantity' : 'Decrease quantity',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colorScheme.primary,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: colorScheme.onPrimary,
              fontSize: 22,
              height: 1,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

/// Average rating + individual reviews for one product. Shows nothing at
/// all (not even an empty-state message) when there are zero reviews yet -
/// an unrated new product shouldn't read as broken or incomplete, it just
/// hasn't accumulated reviews.
class _RatingsSection extends StatelessWidget {
  final ProductRatingSummary? summary;
  final List<Review> reviews;

  const _RatingsSection({required this.summary, required this.reviews});

  @override
  Widget build(BuildContext context) {
    if (summary == null) return const SizedBox.shrink();
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              '${summary!.averageRating}',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StarRatingDisplay(rating: summary!.averageRating, size: 16),
                Text(
                  '${summary!.reviewCount} review${summary!.reviewCount == 1 ? '' : 's'}',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Reviews load asynchronously (a separate query from the
        // aggregate summary above), so the average can be visible before
        // the individual review list has arrived.
        for (final review in reviews) _ReviewTile(review: review),
      ],
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final Review review;

  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final date = review.createdAt;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                review.customerName,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              StarRatingDisplay(rating: review.rating.toDouble(), size: 12),
              const Spacer(),
              Text(
                '${date.day}/${date.month}/${date.year}',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(review.comment, style: textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

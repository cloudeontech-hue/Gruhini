import 'package:flutter/foundation.dart';

import '../models/review.dart';
import '../services/supabase_client.dart';

class ReviewsProvider extends ChangeNotifier {
  final List<Review> _reviews = [];
  final Map<String, ProductRatingSummary> _summaries = {};
  final Set<String> _loadedReviewsFor = {};
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  Future<void> load() async {
    try {
      final summaryRows = await supabase.from('product_rating_summary').select();
      _summaries
        ..clear()
        ..addEntries(
          summaryRows.map(ProductRatingSummary.fromMap).map(
            (s) => MapEntry(s.productId, s),
          ),
        );
    } catch (error) {
      debugPrint('Could not load product ratings: $error');
    }
    _isLoaded = true;
    notifyListeners();
  }

  /// Rating summary for one product, or null if it has no reviews yet -
  /// callers use this to decide whether to show a star badge at all.
  ProductRatingSummary? summaryFor(String productId) => _summaries[productId];

  /// Reviews already fetched for [productId] via [loadReviewsFor] - empty
  /// until that's been called, since the full review text/list is only
  /// needed on the product details screen, not the grid.
  List<Review> reviewsFor(String productId) =>
      _reviews.where((r) => r.productId == productId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Safe to call from build() on every rebuild (e.g. ProductDetailsScreen)
  /// - only actually fetches once per product per app session, same
  /// one-shot-guard idea as CartProvider.restoreFromCatalog.
  Future<void> loadReviewsFor(String productId) async {
    if (_loadedReviewsFor.contains(productId)) return;
    _loadedReviewsFor.add(productId);
    try {
      final rows = await supabase
          .from('reviews')
          .select()
          .eq('product_id', productId)
          .order('created_at', ascending: false);
      _reviews.removeWhere((r) => r.productId == productId);
      _reviews.addAll(rows.map(Review.fromMap));
      notifyListeners();
    } catch (error) {
      debugPrint('Could not load reviews for $productId: $error');
    }
  }

  /// True if this order/product pair has already been reviewed - checked
  /// against Supabase directly (not the possibly-empty local [_reviews]
  /// cache) since the customer's own past reviews for products they
  /// haven't opened the details page for would never have been fetched
  /// into that cache.
  Future<bool> hasReviewed({
    required String orderId,
    required String productId,
  }) async {
    try {
      final existing = await supabase
          .from('reviews')
          .select('id')
          .eq('order_id', orderId)
          .eq('product_id', productId)
          .maybeSingle();
      return existing != null;
    } catch (error) {
      debugPrint('Could not check existing review: $error');
      return false;
    }
  }

  /// Submits one review. The unique(order_id, product_id) constraint
  /// (supabase/migrations/20260915115600_product_reviews.sql) is the real guard against
  /// double-submission - [hasReviewed] is only a UI convenience to avoid
  /// showing an already-rated item as rateable in the first place.
  Future<void> submitReview({
    required String orderId,
    required String productId,
    required String customerPhone,
    required String customerName,
    required int rating,
    String comment = '',
  }) async {
    final row = await supabase
        .from('reviews')
        .insert({
          'product_id': productId,
          'order_id': orderId,
          'customer_phone': customerPhone,
          'customer_name': customerName,
          'rating': rating,
          'comment': comment.trim(),
        })
        .select()
        .single();

    _reviews.insert(0, Review.fromMap(row));

    // Refresh just this product's aggregate rather than reloading every
    // summary - keeps the star badge on the grid accurate immediately
    // after submitting, without a full re-fetch.
    try {
      final summaryRow = await supabase
          .from('product_rating_summary')
          .select()
          .eq('product_id', productId)
          .maybeSingle();
      if (summaryRow != null) {
        _summaries[productId] = ProductRatingSummary.fromMap(summaryRow);
      }
    } catch (error) {
      debugPrint('Could not refresh rating summary for $productId: $error');
    }

    notifyListeners();
  }
}

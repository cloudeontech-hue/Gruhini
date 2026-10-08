class Review {
  final String id;
  final String productId;
  final String orderId;
  final String customerPhone;
  final String customerName;
  final int rating;
  final String comment;
  final DateTime createdAt;

  const Review({
    required this.id,
    required this.productId,
    required this.orderId,
    required this.customerPhone,
    required this.customerName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory Review.fromMap(Map<String, dynamic> map) => Review(
    id: map['id'] as String,
    productId: map['product_id'] as String,
    orderId: map['order_id'] as String,
    customerPhone: map['customer_phone'] as String,
    customerName: map['customer_name'] as String,
    rating: map['rating'] as int,
    comment: (map['comment'] as String?) ?? '',
    createdAt: DateTime.parse(map['created_at'] as String),
  );
}

/// Aggregate rating for one product - backed by the `product_rating_summary`
/// view (supabase/migrations/20260915115600_product_reviews.sql) rather than computed client
/// side from every review row.
class ProductRatingSummary {
  final String productId;
  final double averageRating;
  final int reviewCount;

  const ProductRatingSummary({
    required this.productId,
    required this.averageRating,
    required this.reviewCount,
  });

  factory ProductRatingSummary.fromMap(Map<String, dynamic> map) =>
      ProductRatingSummary(
        productId: map['product_id'] as String,
        averageRating: (map['average_rating'] as num).toDouble(),
        reviewCount: map['review_count'] as int,
      );
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/order.dart';
import '../state/reviews_provider.dart';
import 'star_rating.dart';

/// Full-screen dialog letting a customer rate each item of a delivered
/// order. Items from orders placed before [OrderLineItem.productId]
/// existed can't be matched to a real product and are skipped entirely
/// (same fallback boundary as Reorder - see lib/utils/reorder.dart).
Future<void> showRateOrderDialog(BuildContext context, Order order) {
  return showDialog<void>(
    context: context,
    builder: (_) => _RateOrderDialog(order: order),
  );
}

class _RateOrderDialog extends StatefulWidget {
  final Order order;

  const _RateOrderDialog({required this.order});

  @override
  State<_RateOrderDialog> createState() => _RateOrderDialogState();
}

class _RateOrderDialogState extends State<_RateOrderDialog> {
  bool _isCheckingExisting = true;
  bool _isSubmitting = false;

  /// productId -> already reviewed for this order. Checked once up front
  /// so an already-rated item shows as done instead of offering to
  /// overwrite it (the unique(order_id, product_id) constraint would
  /// reject a second submission anyway, but pre-checking avoids the
  /// confusing "why did my rating fail" case).
  final Map<String, bool> _alreadyReviewed = {};
  final Map<String, int> _ratings = {};
  final Map<String, TextEditingController> _comments = {};

  List<OrderLineItem> get _rateableItems =>
      widget.order.items.where((i) => i.productId != null).toList();

  @override
  void initState() {
    super.initState();
    _checkExisting();
  }

  @override
  void dispose() {
    for (final c in _comments.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _checkExisting() async {
    final reviewsProvider = context.read<ReviewsProvider>();
    for (final item in _rateableItems) {
      final productId = item.productId!;
      _alreadyReviewed[productId] = await reviewsProvider.hasReviewed(
        orderId: widget.order.id,
        productId: productId,
      );
      _comments[productId] = TextEditingController();
    }
    if (mounted) setState(() => _isCheckingExisting = false);
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    final reviewsProvider = context.read<ReviewsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    var submittedCount = 0;
    for (final item in _rateableItems) {
      final productId = item.productId!;
      final rating = _ratings[productId];
      if (rating == null || _alreadyReviewed[productId] == true) continue;
      try {
        await reviewsProvider.submitReview(
          orderId: widget.order.id,
          productId: productId,
          customerPhone: widget.order.customerPhone,
          customerName: widget.order.customerName,
          rating: rating,
          comment: _comments[productId]?.text ?? '',
        );
        submittedCount++;
      } catch (error) {
        debugPrint('Could not submit review for $productId: $error');
      }
    }

    if (!mounted) return;
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          submittedCount > 0
              ? 'Thanks for your feedback!'
              : 'Could not submit your rating. Please try again.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rateable = _rateableItems;

    return AlertDialog(
      title: const Text('Rate your order'),
      content: SizedBox(
        width: 400,
        child: _isCheckingExisting
            ? const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              )
            : rateable.isEmpty
            ? const Text(
                'Items from this order can\'t be rated individually.',
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final item in rateable) _itemRow(context, item),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        if (!_isCheckingExisting && rateable.isNotEmpty)
          FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Submit'),
          ),
      ],
    );
  }

  Widget _itemRow(BuildContext context, OrderLineItem item) {
    final productId = item.productId!;
    final alreadyReviewed = _alreadyReviewed[productId] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.productName,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          if (alreadyReviewed)
            Text(
              'You\'ve already rated this item.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          else ...[
            StarRatingInput(
              rating: _ratings[productId] ?? 0,
              size: 28,
              onChanged: (value) =>
                  setState(() => _ratings[productId] = value),
            ),
            TextField(
              controller: _comments[productId],
              decoration: const InputDecoration(
                hintText: 'Add a comment (optional)',
                isDense: true,
              ),
              maxLines: 2,
            ),
          ],
        ],
      ),
    );
  }
}

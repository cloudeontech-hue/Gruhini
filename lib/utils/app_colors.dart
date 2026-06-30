import 'package:flutter/material.dart';

import '../models/order.dart';

/// Single source of truth for all brand and semantic colors, extracted from
/// the Gruhini Foods logo (deep maroon bowl, cream cloth backdrop, golden
/// fried-snack tones). Every screen should use these — never raw Colors.*
/// calls.
class AppColors {
  AppColors._();

  /// Primary brand maroon — use via colorScheme.primary in themed widgets.
  static const brand = Color(0xFF7B1826);
  static const brandDark = Color(0xFF4A0F18);

  // ── Cream / off-white, lifted from the logo's cloth backdrop ──────────
  static const cream = Color(0xFFFFF8EF);
  static const creamDark = Color(0xFFF3E6D3);
  static const creamLine = Color(0xFFE9D9C2);

  // ── Gold / turmeric accent, lifted from the logo's fried-snack tones ──
  static const gold = Color(0xFFC8923C);
  static const goldLight = Color(0xFFF1DFB8);
  static const goldDark = Color(0xFF8F661F);

  // ── Order status semantic colors ────────────────────────────────────────
  static const statusPending = Color(0xFFE65100); // deep orange
  static const statusActive = Color(0xFF1565C0); // blue
  static const statusDelivered = Color(0xFF2E7D32); // green
  static const statusCancelled = Color(0xFFC62828); // red

  static Color statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.paymentVerification:
        return statusPending;
      case OrderStatus.accepted:
      case OrderStatus.preparing:
      case OrderStatus.outForDelivery:
        return statusActive;
      case OrderStatus.delivered:
        return statusDelivered;
      case OrderStatus.cancelled:
        return statusCancelled;
    }
  }
}

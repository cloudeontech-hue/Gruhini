import 'package:flutter/material.dart';

/// Branded splash shown by [AuthGate] while the app's providers (auth role,
/// products, orders, etc.) are still loading on launch.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.rice_bowl, size: 64, color: colorScheme.onPrimary),
            const SizedBox(height: 16),
            Text(
              'Gruhini Foods',
              style: TextStyle(
                color: colorScheme.onPrimary,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Homemade with love, delivered with care.',
              style: TextStyle(color: colorScheme.onPrimary.withValues(alpha: 0.85), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

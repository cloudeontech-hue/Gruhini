import 'package:flutter/material.dart';

/// Caps content width on tablet/desktop/web so dense lists of cards (and
/// fixed-width summary panels) don't stretch into unreadably long rows —
/// content stays centered with generous gutters instead. No-op (full width)
/// below [maxWidth].
///
/// Uses [LayoutBuilder] + [SizedBox] (not [Align]/[ConstrainedBox]) so the
/// resulting width is always tight — children relying on
/// `CrossAxisAlignment.stretch` or `Expanded` continue to work correctly.
class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveCenter({super.key, required this.child, this.maxWidth = 720});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth.clamp(0, maxWidth).toDouble()
            : maxWidth;
        return Center(
          child: SizedBox(width: width, child: child),
        );
      },
    );
  }
}

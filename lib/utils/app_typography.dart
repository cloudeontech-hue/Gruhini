import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Builds the app's text theme:
/// - **Poppins** — display, headlines, titles, labels (buttons, nav, chips)
/// - **Inter**   — body, descriptions, forms, captions, helper text
///
/// Both fonts are loaded via google_fonts so they work on all platforms
/// (web, mobile, desktop) without bundling font files manually.
TextTheme buildAppTextTheme(TextTheme base) {
  TextStyle poppins(TextStyle? s) => GoogleFonts.poppins(textStyle: s);
  TextStyle inter(TextStyle? s) => GoogleFonts.inter(textStyle: s);

  return base.copyWith(
    // ── Poppins: headings ──────────────────────────────────────────────
    displayLarge: poppins(base.displayLarge),
    displayMedium: poppins(base.displayMedium),
    displaySmall: poppins(base.displaySmall),
    headlineLarge: poppins(base.headlineLarge),
    headlineMedium: poppins(base.headlineMedium),
    headlineSmall: poppins(
      base.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
    ),

    // ── Poppins: titles (product names, card headers, section labels) ──
    titleLarge: poppins(base.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
    titleMedium: poppins(
      base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    ),
    titleSmall: poppins(base.titleSmall?.copyWith(fontWeight: FontWeight.w500)),

    // ── Poppins: labels (buttons, navigation, chips) ───────────────────
    labelLarge: poppins(base.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
    labelMedium: poppins(
      base.labelMedium?.copyWith(fontWeight: FontWeight.w500),
    ),
    labelSmall: poppins(base.labelSmall),

    // ── Inter: body text, descriptions, forms, captions ───────────────
    bodyLarge: inter(base.bodyLarge),
    bodyMedium: inter(base.bodyMedium),
    bodySmall: inter(base.bodySmall),
  );
}

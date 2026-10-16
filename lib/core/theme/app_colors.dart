import 'package:flutter/material.dart';

/// Central colour palette for Oxen Energies Stock.
///
/// Values are derived from the brand logo (deep brand blue + green + teal).
/// See `docs/DESIGN_SYSTEM.md` for the full rationale and usage rules.
class AppColors {
  const AppColors._();

  // Brand — deep blue (primary) from the logo.
  static const Color primary = Color(0xFF0A2A66);
  static const Color primaryDeep = Color(0xFF071C45);
  static const Color primarySoft = Color(0xFFE8EEF9);

  // Brand — green accents from the logo.
  static const Color accent = Color(0xFF1E8E3E);
  static const Color accentBright = Color(0xFF3FBF1F);
  static const Color accentSoft = Color(0xFFE7F4EA);
  static const Color teal = Color(0xFF14544F);

  // Secondary / dark surfaces.
  static const Color navy = Color(0xFF0B1220);
  static const Color navySoft = Color(0xFF17233B);

  // Status.
  static const Color success = Color(0xFF1E8E3E);
  static const Color successSoft = Color(0xFFE7F4EA);
  static const Color danger = Color(0xFFC62828);
  static const Color dangerSoft = Color(0xFFFCE9E9);
  static const Color info = Color(0xFF1565C0);
  static const Color infoSoft = Color(0xFFE8F0FC);
  static const Color infoLight = Color(0xFF6AA9FF);
  static const Color warning = Color(0xFFC77700);
  static const Color warningSoft = Color(0xFFFFF3DC);

  // Surfaces.
  static const Color background = Color(0xFFF4F6FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF9FAFC);
  static const Color border = Color(0xFFE4E8F0);
  static const Color divider = Color(0xFFEFF1F6);

  // Text.
  static const Color textPrimary = Color(0xFF0F1A2B);
  static const Color textSecondary = Color(0xFF5B6675);
  static const Color textMuted = Color(0xFF98A1B0);
  static const Color textOnDark = Color(0xFFFFFFFF);

  /// Vivid brand blue used for hero/summary cards (white text on top).
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1B4FA0), Color(0xFF0A2A66)],
  );

  /// Dark surface gradient used by headers, login hero and toasts.
  static const LinearGradient navyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0B1220), Color(0xFF12224A)],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2FA34E), Color(0xFF1E8E3E)],
  );
}

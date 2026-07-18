import 'package:flutter/material.dart';

/// Zentrale Design-Tokens. Alle Screens beziehen Farben, Radien und
/// Textstile von hier statt aus verstreuten Hex-Literalen.
abstract final class AppTheme {
  // --- Flächen ---
  static const Color bg = Color(0xFF000000); // OLED-Schwarz
  static const Color surface = Color(0xFF161616); // Karten
  static const Color surfaceHigh = Color(0xFF1F1F1F); // angehobene Karten
  static const Color surfaceLow = Color(0xFF0D0D0D); // Sheets
  static final Color hairline = Colors.white.withValues(alpha: 0.08);

  // --- Akzent ---
  static const Color accent = Color(0xFFFF6B00);
  static const Color danger = Color(0xFFFF4444);
  static const Color ok = Color(0xFF4CAF50);

  // --- Text ---
  static const Color textPrimary = Colors.white;
  static final Color textSecondary = Colors.white.withValues(alpha: 0.72);
  static final Color textMuted = Colors.white.withValues(alpha: 0.55);
  static final Color textFaint = Colors.white.withValues(alpha: 0.38);

  // --- Radien ---
  static const double radiusLg = 28;
  static const double radiusMd = 16;
  static const double radiusSm = 12;

  // --- Typografie ---
  /// Athletische Display-Schrift (Scoreboard-Charakter) für große Zahlen
  /// und Phasen-/Titel-Labels.
  static const String displayFont = 'BebasNeue';

  static const TextStyle display = TextStyle(
    fontFamily: displayFont,
    color: textPrimary,
    height: 1,
  );

  /// Kleines Versal-Label (Eyebrow) über Zahlen und Sektionen.
  static TextStyle eyebrow = TextStyle(
    fontSize: 12,
    letterSpacing: 3,
    fontWeight: FontWeight.w600,
    color: textFaint,
  );
}

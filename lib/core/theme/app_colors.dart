import 'package:flutter/material.dart';

class AppColors {
  // Primary Palette (Midnight Blue - High Modern)
  static const Color primary = Color(0xFF3B82F6); // Electric Blue
  static const Color primaryDark = Color(0xFF1E40AF); // Deep Sea Blue
  static const Color secondary = Color(0xFF6366F1); // Indigo Accent

  // Neutral Palette (Sleek Slate & Glass)
  static const Color background = Color(0xFF0F172A); // Deep Slate
  static const Color surface = Color(0xFF1E293B); // Lighter Slate
  static const Color border = Color(0xFF334155); // Slate Border

  // Text Palette
  static const Color textPrimary = Color(0xFFF8FAFC); // Pure Frost
  static const Color textSecondary = Color(0xFF94A3B8); // Slate Mist
  static const Color textMuted = Color(0xFF64748B); // Faded Slate

  // Status Colors
  static const Color success = Color(0xFF10B981); // Emerald
  static const Color error = Color(0xFFEF4444); // Rose
  static const Color warning = Color(0xFFF59E0B); // Amber

  // Gradients
  static const Gradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient woodGradient = LinearGradient(
    colors: [Color(0xFF0F172A), Color(0xFF1E293B)], // Modern Slate Gradient
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const Gradient glassGradient = LinearGradient(
    colors: [
      Colors.white12,
      Colors.white10,
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

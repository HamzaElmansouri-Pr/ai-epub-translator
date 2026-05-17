import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        onPrimary: Color(0xFF1A1612),
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
        error: AppColors.error,
      ),

      // Typography
      textTheme: TextTheme(
        displayLarge: GoogleFonts.crimsonPro(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
          letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.crimsonPro(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        bodyLarge: GoogleFonts.crimsonPro(
          fontSize: 18,
          height: 1.5,
          color: AppColors.textPrimary,
        ),
        bodyMedium: GoogleFonts.cormorantGaramond(
          fontSize: 16,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
        labelLarge: GoogleFonts.montserrat(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: AppColors.primary,
        ),
      ),

      // Components
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.crimsonPro(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.background,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 10,
      ),
    );
  }
}

extension LineHeight on TextStyle {
  TextStyle withHeight(double height) => copyWith(height: height);
}

extension TextStyleHelpers on TextStyle {
  double get lineHeight => height ?? 1.2;
}

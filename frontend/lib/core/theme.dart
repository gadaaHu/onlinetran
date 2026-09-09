import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── App Color Tokens ────────────────────────────────────────────────────────
class AppColors {
  // Brand gradient
  static const violet = Color(0xFF7C3AED);
  static const indigo = Color(0xFF4F46E5);
  static const cyan = Color(0xFF06B6D4);
  static const emerald = Color(0xFF10B981);
  static const amber = Color(0xFFF59E0B);
  static const rose = Color(0xFFF43F5E);

  // Gradient shorthands
  static const primaryGradient = LinearGradient(
    colors: [violet, indigo],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const heroGradientDark = LinearGradient(
    colors: [Color(0xFF0D0D1A), Color(0xFF1A1040), Color(0xFF0D1B2A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const accentGradient = LinearGradient(
    colors: [indigo, cyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Dark surface palette
  static const darkBg = Color(0xFF09090F);
  static const darkSurface = Color(0xFF111118);
  static const darkCard = Color(0xFF18181F);
  static const darkElevated = Color(0xFF1F1F2E);
  static const darkBorder = Color(0xFF2A2A3A);

  // Light surface palette
  static const lightBg = Color(0xFFF8F7FF);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightBorder = Color(0xFFE8E5FF);
}

// ─── Text Styles ─────────────────────────────────────────────────────────────
class AppTextStyles {
  static TextStyle displayLarge(Color color) => GoogleFonts.inter(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: -1.2,
        height: 1.1,
      );

  static TextStyle headlineLarge(Color color) => GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: -0.8,
        height: 1.2,
      );

  static TextStyle headlineMedium(Color color) => GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: -0.5,
      );

  static TextStyle titleLarge(Color color) => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: -0.3,
      );

  static TextStyle bodyLarge(Color color) => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.6,
      );

  static TextStyle bodySmall(Color color) => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.5,
      );

  static TextStyle labelMedium(Color color) => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 0.5,
      );
}

// ─── App Theme ────────────────────────────────────────────────────────────────
class AppTheme {
  static const primaryColor = AppColors.indigo;

  static final lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: AppColors.indigo,
      secondary: AppColors.violet,
      tertiary: AppColors.cyan,
      surface: AppColors.lightSurface,
      onSurface: const Color(0xFF0F0F1A),
      surfaceContainerHighest: const Color(0xFFF0EEFF),
      outline: AppColors.lightBorder,
      outlineVariant: const Color(0xFFE0DEFF),
      error: AppColors.rose,
    ),
    scaffoldBackgroundColor: AppColors.lightBg,
    textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.lightSurface,
      foregroundColor: Color(0xFF0F0F1A),
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.lightSurface,
      indicatorColor: AppColors.indigo.withValues(alpha: 0.12),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return GoogleFonts.inter(
          fontSize: 11,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected ? AppColors.indigo : const Color(0xFF6B7280),
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? AppColors.indigo : const Color(0xFF9CA3AF),
          size: 22,
        );
      }),
    ),
    cardTheme: CardThemeData(
      color: AppColors.lightCard,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.lightBorder, width: 1),
      ),
      elevation: 0,
      shadowColor: AppColors.indigo.withValues(alpha: 0.08),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF5F3FF),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.lightBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.lightBorder, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.indigo, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      hintStyle: GoogleFonts.inter(
        fontSize: 14,
        color: const Color(0xFF9CA3AF),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.indigo.withValues(alpha: 0.10),
      labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
      side: const BorderSide(color: AppColors.lightBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );

  static final darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: AppColors.indigo,
      secondary: AppColors.violet,
      tertiary: AppColors.cyan,
      surface: AppColors.darkSurface,
      onSurface: Colors.white,
      surfaceContainerHighest: AppColors.darkCard,
      outline: AppColors.darkBorder,
      outlineVariant: AppColors.darkBorder,
      error: AppColors.rose,
    ),
    scaffoldBackgroundColor: AppColors.darkBg,
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkSurface,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.darkSurface,
      indicatorColor: AppColors.indigo.withValues(alpha: 0.2),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return GoogleFonts.inter(
          fontSize: 11,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected ? AppColors.indigo : const Color(0xFF6B7280),
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? AppColors.indigo : const Color(0xFF6B7280),
          size: 22,
        );
      }),
    ),
    cardTheme: CardThemeData(
      color: AppColors.darkCard,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.darkBorder, width: 1),
      ),
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkElevated,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.darkBorder, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.indigo, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      hintStyle: GoogleFonts.inter(
        fontSize: 14,
        color: const Color(0xFF6B7280),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.indigo.withValues(alpha: 0.15),
      labelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.indigo),
      side: const BorderSide(color: AppColors.darkBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}

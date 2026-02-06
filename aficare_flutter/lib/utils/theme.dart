import 'package:flutter/material.dart';

class AfiCareTheme {
  // Brand Colors - Warm Orange Theme
  static const Color primaryGreen = Color(0xFFE85D04);  // Warm Orange (keeping variable name for compatibility)
  static const Color primaryGreenLight = Color(0xFFFF8C42);  // Light Orange
  static const Color primaryGreenDark = Color(0xFFD62828);  // Deep Red-Orange
  static const Color secondaryGreen = Color(0xFFF77F00);  // Amber Orange
  static const Color accentGreen = Color(0xFFFFAA5C);  // Soft Orange

  // Role Colors
  static const Color patientColor = Color(0xFFE85D04);  // Orange for patients
  static const Color doctorColor = Color(0xFF1D3557);  // Navy Blue for doctors
  static const Color primaryBlue = Color(0xFF1D3557);  // Navy Blue
  static const Color nurseColor = Color(0xFF457B9D);  // Steel Blue for nurses
  static const Color adminColor = Color(0xFF6D597A);  // Muted Purple for admin

  // Triage Colors (keeping medical standards)
  static const Color emergencyRed = Color(0xFFB71C1C);  // Deep Red
  static const Color urgentOrange = Color(0xFFE65100);  // Dark Orange
  static const Color lessUrgentYellow = Color(0xFFFFA000);  // Amber
  static const Color nonUrgentGreen = Color(0xFF2E7D32);  // Green (safe)

  // Light Theme
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryGreen,
      primary: primaryGreen,
      secondary: primaryGreenLight,
      brightness: Brightness.light,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryGreen,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardTheme(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryGreen,
        side: const BorderSide(color: primaryGreen),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey.shade100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryGreen, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryGreen,
      foregroundColor: Colors.white,
    ),
  );

  // Dark Theme
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryGreen,
      primary: primaryGreenLight,
      secondary: accentGreen,
      brightness: Brightness.dark,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.grey.shade900,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardTheme(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryGreenLight,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
  );
}

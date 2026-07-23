import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AfiCareTheme {
  AfiCareTheme._();

  // ─── Color Palette (Navy Blue Hybrid) ───────────────────────────────
  // Core brand
  static const Color ink = Color(0xFF0D1B2A);        // Near-black navy (primary text)
  static const Color canopy = Color(0xFF1D3557);      // Navy Blue (primary brand)
  static const Color canopy2 = Color(0xFF264A73);     // Medium navy (hover/secondary)
  static const Color canopyDark = Color(0xFF152A45);  // Deep navy (dark surfaces)

  // Accent
  static const Color marigold = Color(0xFFE8A33D);    // Warm gold (accent, CTAs)
  static const Color marigold2 = Color(0xFFD6912E);   // Darker gold (hover)

  // Semantic
  static const Color clay = Color(0xFFB8503F);        // Terracotta (urgent, notifications)
  static const Color sage = Color(0xFF7FA98D);        // Muted sage (positive indicators)

  // Surfaces
  static const Color mist = Color(0xFFF1F4F8);        // Light blue-grey (app background)
  static const Color paper = Color(0xFFFBFCFD);       // Cool white (page background)
  static const Color white = Color(0xFFFFFFFF);       // Pure white (cards)

  // Text
  static const Color slate = Color(0xFF5B6B7B);       // Blue-grey (secondary text)
  static const Color line = Color(0xFFDCE3ED);        // Light blue-grey (borders)

  // Backward-compat aliases (old code references these)
  static const Color primaryGreen = canopy;
  static const Color primaryGreenLight = Color(0xFF457B9D);
  static const Color primaryGreenDark = canopyDark;
  static const Color secondaryGreen = Color(0xFF457B9D);
  static const Color accentGreen = Color(0xFF64B5F6);

  // Role Colors
  static const Color patientColor = canopy;
  static const Color doctorColor = canopy;
  static const Color primaryBlue = canopy;
  static const Color nurseColor = Color(0xFF457B9D);
  static const Color adminColor = Color(0xFF6D597A);

  // Triage Colors
  static const Color emergencyRed = Color(0xFFB71C1C);
  static const Color urgentOrange = Color(0xFFE65100);
  static const Color lessUrgentYellow = Color(0xFFFFA000);
  static const Color nonUrgentGreen = Color(0xFF2E7D32);

  // Dark mode surfaces (provider)
  static const Color darkShell = Color(0xFF0D1B2A);
  static const Color darkSurface = Color(0xFF162D4A);
  static const Color darkBorder = Color(0x14FFFFFF);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFF93A8B8);
  static const Color darkSidebarText = Color(0xFFA9BDB6);

  // ─── Typography ─────────────────────────────────────────────────────

  static TextStyle _displayLarge() => GoogleFonts.fraunces(
    fontSize: 56, fontWeight: FontWeight.w700, color: ink, height: 1.1,
  );
  static TextStyle _displayMedium() => GoogleFonts.fraunces(
    fontSize: 38, fontWeight: FontWeight.w700, color: ink, height: 1.15,
  );
  static TextStyle _displaySmall() => GoogleFonts.fraunces(
    fontSize: 30, fontWeight: FontWeight.w600, color: ink, height: 1.2,
  );
  static TextStyle _headlineLarge() => GoogleFonts.fraunces(
    fontSize: 26, fontWeight: FontWeight.w600, color: ink, height: 1.25,
  );
  static TextStyle _headlineMedium() => GoogleFonts.fraunces(
    fontSize: 22, fontWeight: FontWeight.w600, color: ink, height: 1.3,
  );
  static TextStyle _headlineSmall() => GoogleFonts.fraunces(
    fontSize: 19, fontWeight: FontWeight.w600, color: ink, height: 1.35,
  );
  static TextStyle _titleLarge() => GoogleFonts.ibmPlexSans(
    fontSize: 17, fontWeight: FontWeight.w600, color: ink, height: 1.4,
  );
  static TextStyle _titleMedium() => GoogleFonts.ibmPlexSans(
    fontSize: 15, fontWeight: FontWeight.w600, color: ink, height: 1.4,
  );
  static TextStyle _titleSmall() => GoogleFonts.ibmPlexSans(
    fontSize: 14, fontWeight: FontWeight.w500, color: ink, height: 1.4,
  );
  static TextStyle _bodyLarge() => GoogleFonts.ibmPlexSans(
    fontSize: 16, fontWeight: FontWeight.w400, color: ink, height: 1.5,
  );
  static TextStyle _bodyMedium() => GoogleFonts.ibmPlexSans(
    fontSize: 14, fontWeight: FontWeight.w400, color: ink, height: 1.5,
  );
  static TextStyle _bodySmall() => GoogleFonts.ibmPlexSans(
    fontSize: 13, fontWeight: FontWeight.w400, color: slate, height: 1.5,
  );
  static TextStyle _labelLarge() => GoogleFonts.ibmPlexSans(
    fontSize: 14, fontWeight: FontWeight.w500, color: ink, height: 1.4,
  );
  static TextStyle _labelMedium() => GoogleFonts.ibmPlexSans(
    fontSize: 12, fontWeight: FontWeight.w500, color: slate, height: 1.4,
  );
  static TextStyle _labelSmall() => GoogleFonts.ibmPlexMono(
    fontSize: 11, fontWeight: FontWeight.w500, color: slate, height: 1.4,
  );

  static TextTheme _lightTextTheme() => TextTheme(
    displayLarge: _displayLarge(),
    displayMedium: _displayMedium(),
    displaySmall: _displaySmall(),
    headlineLarge: _headlineLarge(),
    headlineMedium: _headlineMedium(),
    headlineSmall: _headlineSmall(),
    titleLarge: _titleLarge(),
    titleMedium: _titleMedium(),
    titleSmall: _titleSmall(),
    bodyLarge: _bodyLarge(),
    bodyMedium: _bodyMedium(),
    bodySmall: _bodySmall(),
    labelLarge: _labelLarge(),
    labelMedium: _labelMedium(),
    labelSmall: _labelSmall(),
  );

  // ─── Light Theme ────────────────────────────────────────────────────

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: mist,
    textTheme: _lightTextTheme(),
    colorScheme: const ColorScheme.light(
      primary: canopy,
      onPrimary: white,
      secondary: Color(0xFF457B9D),
      onSecondary: white,
      tertiary: marigold,
      onTertiary: white,
      surface: white,
      onSurface: ink,
      surfaceContainerHighest: mist,
      outline: line,
      outlineVariant: line,
      error: clay,
      onError: white,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: canopy,
      foregroundColor: white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.ibmPlexSans(
        fontSize: 17, fontWeight: FontWeight.w600, color: white,
      ),
    ),
    cardTheme: CardTheme(
      elevation: 0,
      color: white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: line, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: canopy,
        foregroundColor: white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.ibmPlexSans(
          fontSize: 14, fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: canopy,
        side: const BorderSide(color: canopy, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.ibmPlexSans(
          fontSize: 14, fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: canopy,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.ibmPlexSans(
          fontSize: 14, fontWeight: FontWeight.w500,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: paper,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: canopy, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: clay),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: GoogleFonts.ibmPlexSans(
        fontSize: 14, color: slate.withValues(alpha: 0.6),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: canopy,
      foregroundColor: white,
      elevation: 2,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: white,
      selectedItemColor: canopy,
      unselectedItemColor: slate,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      selectedLabelStyle: GoogleFonts.ibmPlexSans(fontSize: 10, fontWeight: FontWeight.w600),
      unselectedLabelStyle: GoogleFonts.ibmPlexSans(fontSize: 10, fontWeight: FontWeight.w500),
    ),
    dividerTheme: const DividerThemeData(
      color: line, thickness: 1, space: 1,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: mist,
      side: const BorderSide(color: line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      labelStyle: GoogleFonts.ibmPlexSans(fontSize: 12, fontWeight: FontWeight.w500),
    ),
    dialogTheme: DialogTheme(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      backgroundColor: white,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      backgroundColor: white,
    ),
  );

  // ─── Dark Theme ─────────────────────────────────────────────────────

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkShell,
    textTheme: _lightTextTheme().apply(
      bodyColor: darkTextPrimary,
      displayColor: darkTextPrimary,
    ),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF64B5F6),
      onPrimary: darkShell,
      secondary: Color(0xFF457B9D),
      onSecondary: white,
      tertiary: marigold,
      onTertiary: darkShell,
      surface: darkSurface,
      onSurface: darkTextPrimary,
      surfaceContainerHighest: Color(0xFF1E3A5F),
      outline: darkBorder,
      outlineVariant: darkBorder,
      error: Color(0xFFEF5350),
      onError: white,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: darkSurface,
      foregroundColor: darkTextPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.ibmPlexSans(
        fontSize: 17, fontWeight: FontWeight.w600, color: darkTextPrimary,
      ),
    ),
    cardTheme: CardTheme(
      elevation: 0,
      color: darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: darkBorder, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF64B5F6),
        foregroundColor: darkShell,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.ibmPlexSans(
          fontSize: 14, fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF64B5F6), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: GoogleFonts.ibmPlexSans(
        fontSize: 14, color: darkTextSecondary,
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: darkSurface,
      selectedItemColor: const Color(0xFF64B5F6),
      unselectedItemColor: darkTextSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      selectedLabelStyle: GoogleFonts.ibmPlexSans(fontSize: 10, fontWeight: FontWeight.w600),
      unselectedLabelStyle: GoogleFonts.ibmPlexSans(fontSize: 10, fontWeight: FontWeight.w500),
    ),
    dividerTheme: const DividerThemeData(
      color: darkBorder, thickness: 1, space: 1,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: darkSurface,
      side: const BorderSide(color: darkBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      labelStyle: GoogleFonts.ibmPlexSans(fontSize: 12, fontWeight: FontWeight.w500),
    ),
    dialogTheme: DialogTheme(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      backgroundColor: darkSurface,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      backgroundColor: darkSurface,
    ),
  );

  // ─── High Contrast Theme ────────────────────────────────────────────

  static ThemeData highContrastTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.highContrastLight(
      primary: Colors.black,
      secondary: Colors.black,
      surface: Colors.white,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.black,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardTheme(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Colors.black, width: 2),
      ),
      color: Colors.white,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Colors.black, width: 2),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.black,
        side: const BorderSide(color: Colors.black, width: 3),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    iconTheme: const IconThemeData(color: Colors.black, size: 28),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
      bodyMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: Colors.black),
    ),
  );
}

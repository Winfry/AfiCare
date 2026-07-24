import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Builds the full [ThemeData] for light and dark mode from the
/// centralised [AppColors] palette.
class AppTheme {
  AppTheme._();

  // ── Shared defaults ─────────────────────────────────────────────────
  static const double cardRadius   = 16;
  static const double inputRadius  = 12;
  static const double buttonRadius = 12;
  static const double chipRadius   = 20;
  static const double pageRadius   = 24;

  // ── Light theme ─────────────────────────────────────────────────────
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.pageBackground,
    );

    final colorScheme = ColorScheme.light(
      primary:       AppColors.canopy,
      primaryContainer: AppColors.canopyPale,
      onPrimary:     Colors.white,
      secondary:     AppColors.marigold,
      onSecondary:   Colors.white,
      surface:       AppColors.cardBackground,
      onSurface:     AppColors.textPrimary,
      error:         AppColors.clay,
      onError:       Colors.white,
    );

    return base.copyWith(
      colorScheme: colorScheme,

      // ── Text theme ────────────────────────────────────────────────
      textTheme: const TextTheme(
        displayLarge:  TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.5),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        headlineMedium:TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        titleLarge:    TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        titleMedium:   TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        bodyLarge:     TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.textPrimary),
        bodyMedium:    TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
        bodySmall:     TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textMuted),
        labelLarge:    TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        labelSmall:    TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textMuted),
      ),

      // ── Elevated button ──────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.canopy,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Outlined button ──────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.canopy,
          side: const BorderSide(color: AppColors.canopy),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
        ),
      ),

      // ── Text button ──────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.canopy,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),

      // ── Input decoration ─────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(fontSize: 14, color: AppColors.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(color: AppColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(color: AppColors.canopy, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(color: AppColors.clay),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(color: AppColors.clay, width: 1.5),
        ),
      ),

      // ── Card ─────────────────────────────────────────────────────
      cardTheme: CardTheme(
        color: AppColors.cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: const BorderSide(color: AppColors.borderSubtle, width: 0.5),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── Checkbox ─────────────────────────────────────────────────
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.canopy;
          return Colors.transparent;
        }),
        side: const BorderSide(color: AppColors.borderSubtle, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      // ── Switch ───────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return AppColors.steelLight;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.canopy;
          return AppColors.mistBackground;
        }),
      ),

      // ── Divider ──────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.borderSubtle,
        thickness: 0.5,
        space: 0,
      ),

      // ── Snackbar ─────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.deepNavy,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),

      // ── Chip ─────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.mistBackground,
        labelStyle: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        side: const BorderSide(color: AppColors.borderSubtle),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(chipRadius),
        ),
      ),

      // ── Navigation bar (bottom) ──────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AppColors.canopyPale,
        elevation: 2,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppColors.canopy : AppColors.textMuted,
          );
        }),
      ),

      // ── Navigation rail (tablet / desktop) ───────────────────────
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AppColors.canopyPale,
        selectedIconTheme: IconThemeData(color: AppColors.canopy),
        unselectedIconTheme: IconThemeData(color: AppColors.textMuted),
      ),

      // ── Dialog ───────────────────────────────────────────────────
      dialogTheme: DialogTheme(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(pageRadius),
        ),
      ),

      // ── Bottom sheet ─────────────────────────────────────────────
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(pageRadius)),
        ),
      ),
    );
  }

  // ── Dark theme ──────────────────────────────────────────────────────
  static ThemeData get dark {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBackground,
    );

    final colorScheme = ColorScheme.dark(
      primary:       AppColors.canopyLight,
      primaryContainer: AppColors.canopyDark,
      onPrimary:     Colors.white,
      secondary:     AppColors.marigold,
      onSecondary:   AppColors.deepNavy,
      surface:       AppColors.darkCard,
      onSurface:     Colors.white,
      error:         AppColors.clayLight,
      onError:       AppColors.deepNavy,
    );

    return base.copyWith(
      colorScheme: colorScheme,

      textTheme: const TextTheme(
        displayLarge:  TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white),
        headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
        headlineMedium:TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
        titleLarge:    TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
        titleMedium:   TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
        bodyLarge:     TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: Colors.white70),
        bodyMedium:    TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: Colors.white54),
        bodySmall:     TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.white38),
        labelLarge:    TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
        labelSmall:    TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white38),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputFillDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(fontSize: 14, color: Colors.white38),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(color: AppColors.canopyLight, width: 1.5),
        ),
      ),

      cardTheme: CardTheme(
        color: AppColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: const BorderSide(color: AppColors.darkBorder, width: 0.5),
        ),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.canopyLight;
          return Colors.transparent;
        }),
        side: const BorderSide(color: AppColors.darkBorder, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.darkCard,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.darkCard,
        indicatorColor: AppColors.canopyDark,
        elevation: 2,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppColors.canopyLight : Colors.white38,
          );
        }),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.darkBorder,
        thickness: 0.5,
        space: 0,
      ),

      dialogTheme: DialogTheme(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(pageRadius),
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(pageRadius)),
        ),
      ),
    );
  }
}

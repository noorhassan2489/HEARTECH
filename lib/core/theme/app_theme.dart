import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ============================================================================
// HEARTECH DESIGN SYSTEM — Single source of truth for all visual styling
// ============================================================================

/// All app colors. No hex values anywhere else in the codebase.
class HearTechColors {
  HearTechColors._();

  // Brand / Primary
  static const Color deepTeal = Color(0xFF007B7B);
  static const Color mediumTeal = Color(0xFF00A3A3);
  static const Color paleTeal = Color(0xFFE0F5F5);

  // Risk levels
  static const Color coralRed = Color(0xFFFF6B6B);
  static const Color warmOrange = Color(0xFFE67E22);
  static const Color green = Color(0xFF27AE60);

  // Role accent
  static const Color purple = Color(0xFF8E44AD);

  // Neutral
  static const Color background = Color(0xFFF4F8F9);
  static const Color white = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1A2E35);
  static const Color textSecondary = Color(0xFF6B8E99);
  static const Color divider = Color(0xFFD0E8EC);

  // Derived
  static const Color deepTealDark = Color(0xFF005F5F);
  static const Color error = Color(0xFFE53935);
  static const Color overlay = Color(0x33000000);

  /// Returns the colour for a risk level string.
  static Color riskColor(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'high':
        return coralRed;
      case 'medium':
        return warmOrange;
      case 'low':
        return green;
      default:
        return textSecondary;
    }
  }
}

/// All text styles. Uses Nunito via Google Fonts.
class HearTechTextStyles {
  HearTechTextStyles._();

  static TextStyle _nunito({
    required double fontSize,
    required FontWeight fontWeight,
    Color color = HearTechColors.textPrimary,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.nunito(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  // Screen titles — Nunito Bold 24sp
  static TextStyle screenTitle({Color? color}) => _nunito(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: color ?? HearTechColors.textPrimary,
      );

  // Section headers — Nunito SemiBold 18sp
  static TextStyle sectionHeader({Color? color}) => _nunito(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: color ?? HearTechColors.textPrimary,
      );

  // Body text — Nunito Regular 14sp
  static TextStyle body({Color? color}) => _nunito(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: color ?? HearTechColors.textPrimary,
      );

  // Captions — Nunito Light 12sp
  static TextStyle caption({Color? color}) => _nunito(
        fontSize: 12,
        fontWeight: FontWeight.w300,
        color: color ?? HearTechColors.textSecondary,
      );

  // Buttons — Nunito Bold 16sp
  static TextStyle button({Color? color}) => _nunito(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: color ?? HearTechColors.white,
      );

  // Big numbers — Nunito ExtraBold 48sp (risk score)
  static TextStyle bigNumber({Color? color}) => _nunito(
        fontSize: 48,
        fontWeight: FontWeight.w800,
        color: color ?? HearTechColors.deepTeal,
      );

  // Handover code — Nunito ExtraBold 28sp
  static TextStyle handoverCode({Color? color}) => _nunito(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: color ?? HearTechColors.textPrimary,
        letterSpacing: 4,
      );

  // App bar title
  static TextStyle appBarTitle({Color? color}) => _nunito(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: color ?? HearTechColors.white,
      );

  // Small bold labels
  static TextStyle label({Color? color}) => _nunito(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: color ?? HearTechColors.textSecondary,
      );

  // Subtitle
  static TextStyle subtitle({Color? color}) => _nunito(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: color ?? HearTechColors.textSecondary,
      );
}

/// Border radii and shadows used across the app.
class HearTechDecorations {
  HearTechDecorations._();

  // Border radii
  static const double cardRadius = 20.0;
  static const double buttonRadius = 16.0;
  static const double inputRadius = 14.0;
  static const double badgeRadius = 50.0;
  static const double smallRadius = 8.0;

  static BorderRadius cardBorderRadius = BorderRadius.circular(cardRadius);
  static BorderRadius buttonBorderRadius = BorderRadius.circular(buttonRadius);
  static BorderRadius inputBorderRadius = BorderRadius.circular(inputRadius);
  static BorderRadius badgeBorderRadius = BorderRadius.circular(badgeRadius);

  // Shadows
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: HearTechColors.deepTeal.withValues(alpha: 0.06),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> subtleShadow = [
    BoxShadow(
      color: HearTechColors.deepTeal.withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  // Card decoration
  static BoxDecoration cardDecoration = BoxDecoration(
    color: HearTechColors.white,
    borderRadius: cardBorderRadius,
    boxShadow: cardShadow,
  );

  // Padding
  static const double screenPadding = 16.0;
  static const double cardPadding = 16.0;
  static const double sectionSpacing = 24.0;

  // Button height
  static const double buttonHeight = 56.0;
}

/// The main ThemeData for HearTech.
class HearTechTheme {
  HearTechTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: HearTechColors.background,
      primaryColor: HearTechColors.deepTeal,
      colorScheme: const ColorScheme.light(
        primary: HearTechColors.deepTeal,
        secondary: HearTechColors.mediumTeal,
        surface: HearTechColors.white,
        error: HearTechColors.coralRed,
        onPrimary: HearTechColors.white,
        onSecondary: HearTechColors.white,
        onSurface: HearTechColors.textPrimary,
        onError: HearTechColors.white,
      ),

      // App Bar
      appBarTheme: AppBarTheme(
        backgroundColor: HearTechColors.deepTeal,
        foregroundColor: HearTechColors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: HearTechTextStyles.appBarTitle(),
        iconTheme: const IconThemeData(color: HearTechColors.white),
      ),

      // Cards
      cardTheme: CardThemeData(
        color: HearTechColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: HearTechDecorations.cardBorderRadius,
        ),
        margin: EdgeInsets.zero,
      ),

      // Primary button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: HearTechColors.deepTeal,
          foregroundColor: HearTechColors.white,
          minimumSize: const Size(double.infinity, HearTechDecorations.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: HearTechDecorations.buttonBorderRadius,
          ),
          textStyle: HearTechTextStyles.button(),
          elevation: 0,
        ),
      ),

      // Secondary / outlined button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: HearTechColors.deepTeal,
          minimumSize: const Size(double.infinity, HearTechDecorations.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: HearTechDecorations.buttonBorderRadius,
          ),
          side: const BorderSide(color: HearTechColors.deepTeal, width: 1.5),
          textStyle: HearTechTextStyles.button(color: HearTechColors.deepTeal),
          elevation: 0,
        ),
      ),

      // Text button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: HearTechColors.deepTeal,
          textStyle: HearTechTextStyles.body(color: HearTechColors.deepTeal),
        ),
      ),

      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: HearTechColors.paleTeal,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: HearTechDecorations.inputBorderRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: HearTechDecorations.inputBorderRadius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: HearTechDecorations.inputBorderRadius,
          borderSide: const BorderSide(color: HearTechColors.deepTeal, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: HearTechDecorations.inputBorderRadius,
          borderSide: const BorderSide(color: HearTechColors.coralRed, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: HearTechDecorations.inputBorderRadius,
          borderSide: const BorderSide(color: HearTechColors.coralRed, width: 1.5),
        ),
        floatingLabelStyle: HearTechTextStyles.caption(color: HearTechColors.deepTeal),
        labelStyle: HearTechTextStyles.body(color: HearTechColors.textSecondary),
        hintStyle: HearTechTextStyles.body(color: HearTechColors.textSecondary),
        errorStyle: HearTechTextStyles.caption(color: HearTechColors.coralRed),
        prefixIconColor: HearTechColors.deepTeal,
        suffixIconColor: HearTechColors.textSecondary,
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: HearTechColors.divider,
        thickness: 1,
        space: 0,
      ),

      // Bottom nav
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: HearTechColors.white,
        selectedItemColor: HearTechColors.deepTeal,
        unselectedItemColor: HearTechColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: HearTechTextStyles.caption(color: HearTechColors.deepTeal),
        unselectedLabelStyle: HearTechTextStyles.caption(),
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: HearTechColors.textPrimary,
        contentTextStyle: HearTechTextStyles.body(color: HearTechColors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HearTechDecorations.smallRadius),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: HearTechColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: HearTechDecorations.cardBorderRadius,
        ),
        titleTextStyle: HearTechTextStyles.sectionHeader(),
        contentTextStyle: HearTechTextStyles.body(),
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: HearTechColors.paleTeal,
        selectedColor: HearTechColors.deepTeal,
        labelStyle: HearTechTextStyles.caption(),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HearTechDecorations.badgeRadius),
        ),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),

      // Floating action button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: HearTechColors.deepTeal,
        foregroundColor: HearTechColors.white,
        elevation: 4,
      ),

      // Tab bar
      tabBarTheme: TabBarThemeData(
        labelColor: HearTechColors.deepTeal,
        unselectedLabelColor: HearTechColors.textSecondary,
        indicatorColor: HearTechColors.deepTeal,
        labelStyle: HearTechTextStyles.subtitle(color: HearTechColors.deepTeal),
        unselectedLabelStyle: HearTechTextStyles.subtitle(),
      ),

      // Progress indicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: HearTechColors.deepTeal,
        linearTrackColor: HearTechColors.paleTeal,
      ),
    );
  }
}

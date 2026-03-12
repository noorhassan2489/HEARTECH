import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// HearTech Design System — All tokens consumed from here.
class AppTheme {
  AppTheme._();

  // ─── 1. COLOR PALETTE ───────────────────────────────────────────────
  static const Color primaryTeal      = Color(0xFF007B7B); // Deep Teal — brand
  static const Color primaryLight     = Color(0xFF00A3A3); // Medium Teal — hover
  static const Color primaryPale      = Color(0xFFE0F5F5); // Pale Teal — card bg
  static const Color accentCoral      = Color(0xFFFF6B6B); // Coral Red — risk
  static const Color accentGreen      = Color(0xFF27AE60); // Green — success
  static const Color accentYellow     = Color(0xFFF2994A); // Yellow/Orange — medium risk
  static const Color background       = Color(0xFFF4F8F9); // Off-white blue-grey
  static const Color surface          = Color(0xFFFFFFFF); // Cards/modals
  static const Color textPrimary      = Color(0xFF1A2E35); // Deep Navy
  static const Color textSecondary = Color(0xFF6B8E99);
  static const Color dividerColor  = Color(0xFFD0E8EC);
  static const Color roleBg        = Color(0xFF99E2E6); // Role selection bg

  // Legacy aliases (backward compat with existing screens)
  static const Color primaryColor = primaryTeal;
  static const Color bgOffWhite   = background;
  static const Color surfaceWhite = surface;
  static const Color textDark     = textPrimary;
  static const Color textGrey     = textSecondary;
  static const Color alertCoral   = accentCoral;
  static const Color safeGreen    = accentGreen;
  static const Color lightMint    = Color(0xFF83C5BE);

  // ─── 2. TYPOGRAPHY (Nunito) ─────────────────────────────────────────
  static TextStyle get display => GoogleFonts.nunito(
    fontSize: 32, fontWeight: FontWeight.w800, color: textPrimary,
  );

  static TextStyle get heading1 => GoogleFonts.nunito(
    fontSize: 24, fontWeight: FontWeight.w700, color: textPrimary,
  );

  static TextStyle get heading2 => GoogleFonts.nunito(
    fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary,
  );

  static TextStyle get bodyText => GoogleFonts.nunito(
    fontSize: 14, fontWeight: FontWeight.w400, color: textPrimary,
  );

  static TextStyle get caption => GoogleFonts.nunito(
    fontSize: 12, fontWeight: FontWeight.w300, color: textSecondary,
  );

  static TextStyle get buttonText => GoogleFonts.nunito(
    fontSize: 16, fontWeight: FontWeight.w700, color: surface,
  );

  static TextStyle get subtitle => GoogleFonts.nunito(
    fontSize: 14, fontWeight: FontWeight.w400, color: textSecondary,
  );

  // ─── 3. CARD DECORATIONS ───────────────────────────────────────────
  static BoxDecoration get primaryCard => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.06),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );

  static BoxDecoration get premiumCard => BoxDecoration(
    color: Colors.white.withValues(alpha: 0.95),
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: Colors.white, width: 1.5),
    boxShadow: [
      BoxShadow(
        color: primaryTeal.withValues(alpha: 0.08),
        blurRadius: 24,
        offset: const Offset(0, 10),
      ),
    ],
  );

  static BoxDecoration get cardDecoration => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  );

  static const BoxDecoration premiumBackground = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF4F9F9), Color(0xFFE0F2F1)],
    ),
  );

  // ─── 4. BUTTON STYLES ──────────────────────────────────────────────
  static ButtonStyle get primaryButton => ElevatedButton.styleFrom(
    backgroundColor: primaryTeal,
    foregroundColor: Colors.white,
    elevation: 0,
    minimumSize: const Size(double.infinity, 56),
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    textStyle: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700),
  );

  static ButtonStyle get secondaryButton => OutlinedButton.styleFrom(
    foregroundColor: primaryTeal,
    side: const BorderSide(color: primaryTeal, width: 1.5),
    minimumSize: const Size(double.infinity, 56),
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    textStyle: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700),
  );

  // ─── 5. INPUT DECORATION ───────────────────────────────────────────
  static InputDecoration inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.nunito(color: textSecondary, fontSize: 14),
      prefixIcon: Icon(icon, color: primaryTeal, size: 22),
      filled: true,
      fillColor: primaryPale.withValues(alpha: 0.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: dividerColor, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primaryTeal, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: accentCoral, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: accentCoral, width: 2),
      ),
    );
  }

  // ─── 6. FULL THEME DATA ────────────────────────────────────────────
  static ThemeData get themeData => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: background,
    primaryColor: primaryTeal,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryTeal,
      primary: primaryTeal,
      secondary: primaryLight,
      surface: surface,
      error: accentCoral,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      iconTheme: const IconThemeData(color: textPrimary),
      titleTextStyle: heading2,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: primaryButton),
    outlinedButtonTheme: OutlinedButtonThemeData(style: secondaryButton),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dividerColor: dividerColor,
    textTheme: TextTheme(
      displayLarge: display,
      headlineLarge: heading1,
      headlineMedium: heading2,
      bodyLarge: bodyText,
      bodySmall: caption,
      labelLarge: buttonText,
    ),
  );

  // ─── 7. RISK LEVEL HELPERS ─────────────────────────────────────────
  static Color riskColor(String level) {
    switch (level.toLowerCase()) {
      case 'high':   return accentCoral;
      case 'medium': return accentYellow;
      case 'low':    return accentGreen;
      default:       return textSecondary;
    }
  }

  static String riskLabel(int score) {
    if (score >= 67) return 'High';
    if (score >= 34) return 'Medium';
    return 'Low';
  }
}

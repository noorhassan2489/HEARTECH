import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // 1. MASTER COLORS
  static const Color primaryTeal = Color(0xFF006D77); // Deep medical teal
  static const Color lightMint = Color(0xFF83C5BE); // Soft accents
  static const Color bgOffWhite = Color(0xFFF8F9FA); // App background
  static const Color surfaceWhite = Color(0xFFFFFFFF); // Card backgrounds
  static const Color textDark = Color(0xFF2B2D42); // Primary text (Navy/Black)
  static const Color textGrey = Color(0xFF8D99AE); // Subtitles
  static const Color alertCoral = Color(0xFFE29578); // High risk / Warnings
  static const Color safeGreen = Color(0xFF2A9D8F); // Low risk / Success

  // 2. MASTER TYPOGRAPHY (Using Google Fonts - Poppins for modern tech feel)
  static TextStyle heading1 = GoogleFonts.poppins(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: textDark,
  );

  static TextStyle heading2 = GoogleFonts.poppins(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: textDark,
  );

  static TextStyle bodyText = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: textDark,
  );

  static TextStyle subtitle = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textGrey,
  );

  // 3. MASTER DECORATIONS (For Cards & Containers)
  static BoxDecoration primaryCard = BoxDecoration(
    color: surfaceWhite,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  );

  // Sleek 2026 Gradient for the background
  static const BoxDecoration premiumBackground = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFF4F9F9),
        Color(0xFFE0F2F1),
      ], // Soft, premium teal-tinted white
    ),
  );

  // Glowing Card Decoration
  static BoxDecoration premiumCard = BoxDecoration(
    color: Colors.white.withOpacity(0.9),
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: Colors.white, width: 2),
    boxShadow: [
      BoxShadow(
        color: primaryTeal.withOpacity(0.08),
        blurRadius: 24,
        offset: const Offset(0, 10),
      ),
    ],
  );

  // 4. MASTER BUTTON STYLES
  static ButtonStyle primaryButton = ElevatedButton.styleFrom(
    backgroundColor: primaryTeal,
    foregroundColor: Colors.white,
    elevation: 0,
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
  );

  // 5. MASTER INPUT FIELDS (For Login, Create Profile, etc.)
  static InputDecoration inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: textGrey),
      prefixIcon: Icon(icon, color: primaryTeal),
      filled: true,
      fillColor: surfaceWhite,
      contentPadding: const EdgeInsets.all(16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryTeal, width: 2),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Pure Black & Dark Surfaces
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF0B0E14);
  static const Color surfaceElevated = Color(0xFF121824);
  static const Color surfaceCard = Color(0xFF161F2E);
  static const Color surfaceHighlight = Color(0xFF1E293B);

  // Neon Blue Accents
  static const Color primaryBlue = Color(0xFF007AFF);
  static const Color accentNeonBlue = Color(0xFF00E5FF);
  static const Color electricCyan = Color(0xFF00F0FF);
  static const Color primaryGlow = Color(0x33007AFF);

  // High-contrast Grayscale & Typography
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textDisabled = Color(0xFF475569);

  // Borders & Dividers
  static const Color borderSubtle = Color(0xFF1E293B);
  static const Color borderGlow = Color(0xFF007AFF);

  // Status
  static const Color favoriteRed = Color(0xFFFF2A55);
  static const Color errorRed = Color(0xFFFF453A);

  // Gradients
  static const LinearGradient neonBlueGradient = LinearGradient(
    colors: [primaryBlue, accentNeonBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [surfaceElevated, surface],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primaryBlue,
      canvasColor: surface,
      cardColor: surfaceElevated,
      dividerColor: borderSubtle,
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleLarge: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        bodyMedium: GoogleFonts.inter(
          color: textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: GoogleFonts.inter(
          color: textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w400,
        ),
      ),
      colorScheme: const ColorScheme.dark(
        primary: primaryBlue,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFF003B80),
        onPrimaryContainer: Colors.white,
        secondary: accentNeonBlue,
        onSecondary: Colors.black,
        secondaryContainer: Color(0xFF004455),
        onSecondaryContainer: Colors.white,
        surface: surface,
        onSurface: textPrimary,
        surfaceContainerHighest: surfaceCard,
        onSurfaceVariant: textSecondary,
        outline: borderSubtle,
        outlineVariant: borderSubtle,
        error: errorRed,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: background,
        elevation: 0,
        indicatorColor: primaryBlue.withValues(alpha: 0.18),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: accentNeonBlue, size: 24);
          }
          return const IconThemeData(color: textMuted, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: accentNeonBlue,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            );
          }
          return const TextStyle(
            color: textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          );
        }),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 3.5,
        activeTrackColor: primaryBlue,
        inactiveTrackColor: borderSubtle,
        thumbColor: accentNeonBlue,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.5, elevation: 3),
        overlayColor: primaryBlue.withValues(alpha: 0.2),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
      ),
    );
  }
}

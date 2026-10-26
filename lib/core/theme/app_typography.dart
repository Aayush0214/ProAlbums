import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography System extracted from DESIGN_1.md (Plus Jakarta Sans)
/// and DESIGN_2.md (Inter & JetBrains Mono)
///
/// FONT BUNDLING (do this at release time, NO code change needed):
/// 1. Download the .ttf files of Plus Jakarta Sans, Inter, JetBrains Mono.
/// 2. Put them in `assets/google_fonts/` and list that folder under
///    `flutter: assets:` in pubspec.yaml.
/// 3. The google_fonts package automatically prefers a bundled file whose
///    name matches (e.g. `Inter-Regular.ttf`) over a network download.
/// Optionally set `GoogleFonts.config.allowRuntimeFetching = false;` in main()
/// afterwards so the app never touches the network for fonts.
abstract final class AppTypography {
  /// Builds the full Material 3 TextTheme for Light & Dark modes
  static TextTheme buildTextTheme({
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    return TextTheme(
      // =======================================================================
      // DISPLAY & HEADLINES (Plus Jakarta Sans - DESIGN_1.md)
      // =======================================================================
      // display: 40px, weight 700, lineHeight 48px (1.2), letterSpacing -0.03em
      displayLarge: GoogleFonts.plusJakartaSans(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        height: 48 / 40,
        letterSpacing: -1.2,
        color: primaryTextColor,
      ),
      // headline-xl: 34px, weight 700, lineHeight 40px (DESIGN_2.md)
      displayMedium: GoogleFonts.plusJakartaSans(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        height: 40 / 34,
        letterSpacing: -0.8,
        color: primaryTextColor,
      ),
      // display-mobile: 32px, weight 700, lineHeight 38px, letterSpacing -0.025em
      displaySmall: GoogleFonts.plusJakartaSans(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 38 / 32,
        letterSpacing: -0.8,
        color: primaryTextColor,
      ),

      // headline-lg / headline-xl-mobile: 28px, weight 700, lineHeight 34px
      // (also used as the AppBar title, see AppTheme)
      headlineLarge: GoogleFonts.plusJakartaSans(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 34 / 28,
        letterSpacing: -0.56,
        color: primaryTextColor,
      ),
      // headline-md: 22px, weight 600, lineHeight 28px
      headlineMedium: GoogleFonts.plusJakartaSans(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 28 / 22,
        letterSpacing: -0.33,
        color: primaryTextColor,
      ),
      // headline-sm: 18px, weight 600, lineHeight 24px
      headlineSmall: GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 24 / 18,
        letterSpacing: -0.18,
        color: primaryTextColor,
      ),

      // =======================================================================
      // TITLES & BODY (Inter - DESIGN_2.md & DESIGN_1.md)
      // =======================================================================
      titleLarge: GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 26 / 20,
        letterSpacing: -0.2,
        color: primaryTextColor,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 22 / 16,
        letterSpacing: -0.1,
        color: primaryTextColor,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 20 / 14,
        color: primaryTextColor,
      ),

      // body-lg: 16px, weight 400, lineHeight 24px
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
        letterSpacing: -0.08,
        color: primaryTextColor,
      ),
      // body-md: 14px, weight 400, lineHeight 20px
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
        color: primaryTextColor,
      ),
      // body-sm: 12px, weight 400, lineHeight 16px (Subtitles & Item Counts)
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 16 / 12,
        letterSpacing: 0.12,
        color: secondaryTextColor,
      ),

      // =======================================================================
      // LABELS & BUTTONS (Plus Jakarta Sans / Inter)
      // =======================================================================
      // label-lg: 14px, weight 600, lineHeight 18px
      labelLarge: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 18 / 14,
        letterSpacing: 0.07,
        color: primaryTextColor,
      ),
      // label-md: 12px, weight 600, lineHeight 16px
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 16 / 12,
        letterSpacing: 0.12,
        color: primaryTextColor,
      ),
      // label-sm: 11px, weight 500, lineHeight 14px
      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 14 / 11,
        letterSpacing: 0.22,
        color: secondaryTextColor,
      ),
    );
  }

  // ===========================================================================
  // MONOSPACE STYLES (JetBrains Mono - DESIGN_2.md for EXIF & Video Durations)
  // ===========================================================================

  /// Used for EXIF camera readouts (ISO, Shutter Speed, 3840x2160, File Size)
  /// Spec: label-mono -> 11px, weight 500, lineHeight 14px + tabular figures
  static TextStyle labelMono({Color? color}) {
    return GoogleFonts.jetBrainsMono(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      height: 14 / 11,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  /// Used for Video Thumbnail Duration Badges ("00:39", "01:03", "4K", "RAW")
  /// Spec: badge-timestamp -> 10px, weight 500, lineHeight 12px + tabular figures
  static TextStyle badgeTimestamp({Color color = Colors.white}) {
    return GoogleFonts.jetBrainsMono(
      fontSize: 10,
      fontWeight: FontWeight.w500,
      height: 12 / 10,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }
}

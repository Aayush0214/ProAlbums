import 'package:flutter/material.dart';

/// Master Color Tokens extracted from Stitch Design System (DESIGN_1.md & DESIGN_2.md)
///
/// RULE: raw `AppColors.*` values are used ONLY inside the theme files
/// (app_theme.dart / this file). Widgets should read colors through
/// `context.colorScheme` or `context.colors` so light/dark switching works
/// automatically. The only exception is the "semantic" tokens at the bottom
/// (cleanup red, trash purple, ...) which are identical in both themes.
abstract final class AppColors {
  // ===========================================================================
  // LIGHT THEME TOKENS (DESIGN_1.md & DESIGN_2.md Light Specs)
  // ===========================================================================
  static const Color lightBackground = Color(0xFFF9F9FF);
  static const Color lightCanvasPure = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF9F9FF);
  static const Color lightSurfaceDim = Color(0xFFD3DAEA);
  static const Color lightSurfaceBright = Color(0xFFF9F9FF);

  // Surface Containers (Cards, Grouped Settings, Search Bars, Modals)
  static const Color lightSurfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color lightSurfaceContainerLow = Color(0xFFF0F3FF);
  static const Color lightSurfaceContainer = Color(0xFFE7EEFE);
  static const Color lightSurfaceContainerHigh = Color(0xFFE2E8F8);
  static const Color lightSurfaceContainerHighest = Color(0xFFDCE2F3);

  // Neutral Slate Tiers (From DESIGN_2.md Light Mode)
  static const Color lightCardAlt = Color(0xFFF8FAFC);
  static const Color lightPillSurface = Color(0xFFF1F5F9);

  // Text & Iconography (Light)
  static const Color lightOnSurface = Color(0xFF151C27);
  static const Color lightOnSurfaceVariant = Color(0xFF414755);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightOutline = Color(0xFF717786);
  static const Color lightOutlineVariant = Color(0xFFC1C6D7);
  static const Color lightDividerSubtle = Color(0xFFE5E7EB);

  // Primary & Accents (Light)
  static const Color lightPrimary = Color(0xFF0058BC);
  static const Color lightPrimaryContainer = Color(0xFF0070EB);
  static const Color lightOnPrimary = Color(0xFFFFFFFF);
  static const Color lightOnPrimaryContainer = Color(0xFFFEFCFF);
  static const Color lightElectricBlue = Color(0xFF007AFF);

  // Secondary & Tertiary (Light)
  static const Color lightSecondary = Color(0xFF575E70);
  static const Color lightOnSecondary = Color(0xFFFFFFFF);
  static const Color lightSecondaryContainer = Color(0xFFD9DFF5);
  static const Color lightOnSecondaryContainer = Color(0xFF5C6274);

  static const Color lightTertiary = Color(0xFF9E3D00);
  static const Color lightOnTertiary = Color(0xFFFFFFFF);
  static const Color lightTertiaryContainer = Color(0xFFC64F00);
  static const Color lightOnTertiaryContainer = Color(0xFFFFFBFF);

  // Error (Light)
  static const Color lightError = Color(0xFFBA1A1A);
  static const Color lightOnError = Color(0xFFFFFFFF);
  static const Color lightErrorContainer = Color(0xFFFFDAD6);
  static const Color lightOnErrorContainer = Color(0xFF93000A);

  // Inverse (Light)
  static const Color lightInverseSurface = Color(0xFF2A313D);
  static const Color lightInverseOnSurface = Color(0xFFEBF1FF);
  static const Color lightInversePrimary = Color(0xFFADC6FF);

  // ===========================================================================
  // DARK THEME TOKENS (DESIGN_2.md Dark Specs)
  // ===========================================================================
  static const Color darkBackground = Color(0xFF0B1326);
  static const Color darkCanvasObsidian = Color(0xFF020617); // True AMOLED / Deepest Slate
  static const Color darkSurface = Color(0xFF0B1326);
  static const Color darkSurfaceDim = Color(0xFF0B1326);
  static const Color darkSurfaceBright = Color(0xFF31394D);

  // Surface Containers (Dark Cards, Settings Group, Bottom Sheets)
  static const Color darkSurfaceContainerLowest = Color(0xFF060E20);
  static const Color darkSurfaceContainerLow = Color(0xFF131B2E);
  static const Color darkSurfaceContainer = Color(0xFF171F33);
  static const Color darkSurfaceContainerHigh = Color(0xFF222A3D);
  static const Color darkSurfaceContainerHighest = Color(0xFF2D3449);

  // Neutral Slate Tiers (From DESIGN_2.md Dark Mode)
  static const Color darkCardAlt = Color(0xFF0F172A);
  static const Color darkPillSurface = Color(0xFF1E293B);

  // Text & Iconography (Dark)
  static const Color darkOnSurface = Color(0xFFDAE2FD);
  static const Color darkOnSurfaceVariant = Color(0xFFC1C6D7);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkOutline = Color(0xFF8B90A0);
  static const Color darkOutlineVariant = Color(0xFF414755);
  static const Color darkDividerSubtle = Color(0x1AFFFFFF); // rgba(255, 255, 255, 0.10)

  // Primary & Accents (Dark)
  static const Color darkPrimary = Color(0xFFADC6FF);
  static const Color darkPrimaryContainer = Color(0xFF4B8EFF);
  static const Color darkOnPrimary = Color(0xFF002E69);
  static const Color darkOnPrimaryContainer = Color(0xFF00285C);
  static const Color darkCobaltCyan = Color(0xFF38BDF8);

  // Secondary & Tertiary (Dark)
  static const Color darkSecondary = Color(0xFFB7C8E1);
  static const Color darkOnSecondary = Color(0xFF213145);
  static const Color darkSecondaryContainer = Color(0xFF3A4A5F);
  static const Color darkOnSecondaryContainer = Color(0xFFA9BAD3);

  static const Color darkTertiary = Color(0xFF7BD0FF);
  static const Color darkOnTertiary = Color(0xFF00354A);
  static const Color darkTertiaryContainer = Color(0xFF009BD1);
  static const Color darkOnTertiaryContainer = Color(0xFF002D40);

  // Error (Dark)
  static const Color darkError = Color(0xFFFFB4AB);
  static const Color darkOnError = Color(0xFF690005);
  static const Color darkErrorContainer = Color(0xFF93000A);
  static const Color darkOnErrorContainer = Color(0xFFFFDAD6);

  // Inverse (Dark)
  static const Color darkInverseSurface = Color(0xFFDAE2FD);
  static const Color darkInverseOnSurface = Color(0xFF283044);
  static const Color darkInversePrimary = Color(0xFF005BC1);

  // ===========================================================================
  // SHARED / SEMANTIC / OVERLAY TOKENS (For Albums, Viewer & Badges)
  // ===========================================================================
  /// Frosted Glass Nav Bar & Top AppBar Overlays
  static const Color lightGlassSurface = Color(0xB8FFFFFF); // rgba(255, 255, 255, 0.72)
  static const Color darkGlassSurface = Color(0xBF0F172A); // rgba(15, 23, 42, 0.75)

  /// Media Thumbnail Badges (00:39, 4K, HDR)
  static const Color mediaBadgeFill = Color(0x99000000); // rgba(0, 0, 0, 0.60)
  static const Color mediaBadgeText = Color(0xFFFFFFFF);
  static const Color mediaScrimTop = Color(0xA6000000); // rgba(0, 0, 0, 0.65)

  /// Utility Row Semantic Accents (Albums Tab & Storage Bar)
  static const Color cleanupCoralRed = Color(0xFFEF4444); // Cleanup Suggestions Broom Icon
  static const Color trashPurple = Color(0xFFA855F7); // Recently Deleted Trash Icon
  static const Color vaultEmerald = Color(0xFF10B981); // Encrypted / Safe Status
  static const Color favoriteHeartRed = Color(0xFFF43F5E); // Favorite Heart Active

  /// Storage Breakdown Multi-Segment Bar Colors
  static const Color storagePhotos = Color(0xFF007AFF);
  static const Color storageVideos = Color(0xFF8B5CF6);
  static const Color storageScreenshots = Color(0xFF06B6D4);
  static const Color storageTrash = Color(0xFFF43F5E);
  static const Color storageOther = Color(0xFF64748B);
}

/// Custom ThemeExtension so every screen can access Stitch's exact surface &
/// glass tokens that Material's ColorScheme has no slot for.
///
/// WHY an extension (and not just ColorScheme)? ColorScheme only has fixed
/// slots. Things like "glass surface", "pill surface" or "accent tinted
/// surface" are app-specific, so they live here. Because it is part of
/// ThemeData, it switches automatically between light and dark.
@immutable
class AppColorExtension extends ThemeExtension<AppColorExtension> {
  final Color canvasPure;
  final Color surfaceContainerLowest;
  final Color surfaceContainerLow;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color surfaceContainerHighest;
  final Color cardAlt;
  final Color pillSurface;
  final Color glassSurface;
  final Color glassBorder;
  final Color textPrimary;
  final Color textSecondary;
  final Color dividerSubtle;
  final Color activeAccent;
  final Color accentTintedSurface;

  const AppColorExtension({
    required this.canvasPure,
    required this.surfaceContainerLowest,
    required this.surfaceContainerLow,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.surfaceContainerHighest,
    required this.cardAlt,
    required this.pillSurface,
    required this.glassSurface,
    required this.glassBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.dividerSubtle,
    required this.activeAccent,
    required this.accentTintedSurface,
  });

  static const light = AppColorExtension(
    canvasPure: AppColors.lightCanvasPure,
    surfaceContainerLowest: AppColors.lightSurfaceContainerLowest,
    surfaceContainerLow: AppColors.lightSurfaceContainerLow,
    surfaceContainer: AppColors.lightSurfaceContainer,
    surfaceContainerHigh: AppColors.lightSurfaceContainerHigh,
    surfaceContainerHighest: AppColors.lightSurfaceContainerHighest,
    cardAlt: AppColors.lightCardAlt,
    pillSurface: AppColors.lightPillSurface,
    glassSurface: AppColors.lightGlassSurface,
    glassBorder: Color(0x0F0F172A), // rgba(15, 23, 42, 0.06)
    textPrimary: AppColors.lightOnSurface,
    textSecondary: AppColors.lightTextSecondary,
    dividerSubtle: AppColors.lightDividerSubtle,
    activeAccent: AppColors.lightElectricBlue,
    accentTintedSurface: Color(0x1A007AFF), // rgba(0, 122, 255, 0.10)
  );

  static const dark = AppColorExtension(
    canvasPure: AppColors.darkCanvasObsidian,
    surfaceContainerLowest: AppColors.darkSurfaceContainerLowest,
    surfaceContainerLow: AppColors.darkSurfaceContainerLow,
    surfaceContainer: AppColors.darkSurfaceContainer,
    surfaceContainerHigh: AppColors.darkSurfaceContainerHigh,
    surfaceContainerHighest: AppColors.darkSurfaceContainerHighest,
    cardAlt: AppColors.darkCardAlt,
    pillSurface: AppColors.darkPillSurface,
    glassSurface: AppColors.darkGlassSurface,
    glassBorder: Color(0x1FFFFFFF), // rgba(255, 255, 255, 0.12)
    textPrimary: AppColors.darkTextPrimary,
    textSecondary: AppColors.darkTextSecondary,
    dividerSubtle: AppColors.darkDividerSubtle,
    activeAccent: AppColors.darkCobaltCyan,
    accentTintedSurface: Color(0x33007AFF), // rgba(0, 122, 255, 0.20)
  );

  @override
  AppColorExtension copyWith({
    Color? canvasPure,
    Color? surfaceContainerLowest,
    Color? surfaceContainerLow,
    Color? surfaceContainer,
    Color? surfaceContainerHigh,
    Color? surfaceContainerHighest,
    Color? cardAlt,
    Color? pillSurface,
    Color? glassSurface,
    Color? glassBorder,
    Color? textPrimary,
    Color? textSecondary,
    Color? dividerSubtle,
    Color? activeAccent,
    Color? accentTintedSurface,
  }) {
    return AppColorExtension(
      canvasPure: canvasPure ?? this.canvasPure,
      surfaceContainerLowest: surfaceContainerLowest ?? this.surfaceContainerLowest,
      surfaceContainerLow: surfaceContainerLow ?? this.surfaceContainerLow,
      surfaceContainer: surfaceContainer ?? this.surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh ?? this.surfaceContainerHigh,
      surfaceContainerHighest: surfaceContainerHighest ?? this.surfaceContainerHighest,
      cardAlt: cardAlt ?? this.cardAlt,
      pillSurface: pillSurface ?? this.pillSurface,
      glassSurface: glassSurface ?? this.glassSurface,
      glassBorder: glassBorder ?? this.glassBorder,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      dividerSubtle: dividerSubtle ?? this.dividerSubtle,
      activeAccent: activeAccent ?? this.activeAccent,
      accentTintedSurface: accentTintedSurface ?? this.accentTintedSurface,
    );
  }

  /// lerp() is what Flutter calls while animating between light <-> dark.
  @override
  AppColorExtension lerp(ThemeExtension<AppColorExtension>? other, double t) {
    if (other is! AppColorExtension) return this;
    return AppColorExtension(
      canvasPure: Color.lerp(canvasPure, other.canvasPure, t)!,
      surfaceContainerLowest: Color.lerp(surfaceContainerLowest, other.surfaceContainerLowest, t)!,
      surfaceContainerLow: Color.lerp(surfaceContainerLow, other.surfaceContainerLow, t)!,
      surfaceContainer: Color.lerp(surfaceContainer, other.surfaceContainer, t)!,
      surfaceContainerHigh: Color.lerp(surfaceContainerHigh, other.surfaceContainerHigh, t)!,
      surfaceContainerHighest: Color.lerp(surfaceContainerHighest, other.surfaceContainerHighest, t)!,
      cardAlt: Color.lerp(cardAlt, other.cardAlt, t)!,
      pillSurface: Color.lerp(pillSurface, other.pillSurface, t)!,
      glassSurface: Color.lerp(glassSurface, other.glassSurface, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      dividerSubtle: Color.lerp(dividerSubtle, other.dividerSubtle, t)!,
      activeAccent: Color.lerp(activeAccent, other.activeAccent, t)!,
      accentTintedSurface: Color.lerp(accentTintedSurface, other.accentTintedSurface, t)!,
    );
  }
}

/// Convenient BuildContext extension for quick access in UI widgets:
/// Usage: `context.colors.surfaceContainerLow` or `context.colors.activeAccent`
extension AppThemeContextExtension on BuildContext {
  /// WHY the fallback changed: the old code fell back to the DARK extension
  /// even in light mode. The fallback now follows the current brightness.
  AppColorExtension get colors {
    final theme = Theme.of(this);
    return theme.extension<AppColorExtension>() ??
        (theme.brightness == Brightness.dark
            ? AppColorExtension.dark
            : AppColorExtension.light);
  }

  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  TextTheme get textTheme => Theme.of(this).textTheme;
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}

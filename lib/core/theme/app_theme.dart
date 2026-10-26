import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/core/theme/app_typography.dart';

/// All ThemeData of the app lives here.
///
/// Structure:
///  1. Public, cached themes  -> lightTheme / darkTheme / darkAmoledTheme
///  2. Private ColorSchemes   -> raw Stitch tokens mapped to Material slots
///  3. `_build()`             -> ONE builder shared by every theme
///
/// WHY one builder? Earlier, light and dark had ~100 duplicated lines. If a
/// radius or a font changed, we had to edit twice and could forget one. Now a
/// component theme is written once and automatically reads the right colors
/// from `scheme` (Material slots) and `ext` (our custom Stitch tokens).
abstract final class AppTheme {
  // ===========================================================================
  // 1. PUBLIC THEMES
  // ===========================================================================
  // WHY `static final` and not `static ThemeData get`?
  // A getter runs every time it is read and builds a brand new ThemeData
  // (and all TextStyles) each time. `static final` is built lazily ONCE and
  // then reused, so MaterialApp rebuilds stay cheap.

  static final ThemeData lightTheme = _build(
    scheme: _lightScheme,
    ext: AppColorExtension.light,
    scaffoldColor: AppColors.lightBackground,
    overlay: _lightOverlay,
    sheetColor: AppColors.lightSurfaceContainerLowest,
    switchThumbOn: Colors.white,
    switchThumbOff: AppColors.lightOutline,
    switchTrackOn: AppColors.lightElectricBlue,
  );

  static final ThemeData darkTheme = _build(
    scheme: _darkScheme,
    ext: AppColorExtension.dark,
    scaffoldColor: AppColors.darkBackground,
    overlay: _darkOverlay,
    sheetColor: AppColors.darkSurfaceContainer,
    switchThumbOn: AppColors.darkOnPrimary,
    switchThumbOff: AppColors.darkOutline,
    switchTrackOn: AppColors.darkPrimary,
  );

  /// Optional "Pure black / AMOLED" look for a Settings toggle later.
  /// Same as dark, but background uses the deepest Stitch slate.
  static final ThemeData darkAmoledTheme = _build(
    scheme: _darkScheme.copyWith(surface: AppColors.darkCanvasObsidian),
    ext: AppColorExtension.dark,
    scaffoldColor: AppColors.darkCanvasObsidian,
    overlay: _darkOverlay,
    sheetColor: AppColors.darkSurfaceContainer,
    switchThumbOn: AppColors.darkOnPrimary,
    switchThumbOff: AppColors.darkOutline,
    switchTrackOn: AppColors.darkPrimary,
  );

  // ===========================================================================
  // 2. COLOR SCHEMES + STATUS BAR STYLES
  // ===========================================================================
  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.lightPrimary,
    onPrimary: AppColors.lightOnPrimary,
    primaryContainer: AppColors.lightPrimaryContainer,
    onPrimaryContainer: AppColors.lightOnPrimaryContainer,
    secondary: AppColors.lightSecondary,
    onSecondary: AppColors.lightOnSecondary,
    secondaryContainer: AppColors.lightSecondaryContainer,
    onSecondaryContainer: AppColors.lightOnSecondaryContainer,
    tertiary: AppColors.lightTertiary,
    onTertiary: AppColors.lightOnTertiary,
    tertiaryContainer: AppColors.lightTertiaryContainer,
    onTertiaryContainer: AppColors.lightOnTertiaryContainer,
    error: AppColors.lightError,
    onError: AppColors.lightOnError,
    errorContainer: AppColors.lightErrorContainer,
    onErrorContainer: AppColors.lightOnErrorContainer,
    surface: AppColors.lightSurface,
    onSurface: AppColors.lightOnSurface,
    onSurfaceVariant: AppColors.lightOnSurfaceVariant,
    outline: AppColors.lightOutline,
    outlineVariant: AppColors.lightOutlineVariant,
    inverseSurface: AppColors.lightInverseSurface,
    onInverseSurface: AppColors.lightInverseOnSurface,
    inversePrimary: AppColors.lightInversePrimary,
    surfaceTint: AppColors.lightPrimary,
    surfaceDim: AppColors.lightSurfaceDim,
    surfaceBright: AppColors.lightSurfaceBright,
    surfaceContainerLowest: AppColors.lightSurfaceContainerLowest,
    surfaceContainerLow: AppColors.lightSurfaceContainerLow,
    surfaceContainer: AppColors.lightSurfaceContainer,
    surfaceContainerHigh: AppColors.lightSurfaceContainerHigh,
    surfaceContainerHighest: AppColors.lightSurfaceContainerHighest,
  );

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.darkPrimary,
    onPrimary: AppColors.darkOnPrimary,
    primaryContainer: AppColors.darkPrimaryContainer,
    onPrimaryContainer: AppColors.darkOnPrimaryContainer,
    secondary: AppColors.darkSecondary,
    onSecondary: AppColors.darkOnSecondary,
    secondaryContainer: AppColors.darkSecondaryContainer,
    onSecondaryContainer: AppColors.darkOnSecondaryContainer,
    tertiary: AppColors.darkTertiary,
    onTertiary: AppColors.darkOnTertiary,
    tertiaryContainer: AppColors.darkTertiaryContainer,
    onTertiaryContainer: AppColors.darkOnTertiaryContainer,
    error: AppColors.darkError,
    onError: AppColors.darkOnError,
    errorContainer: AppColors.darkErrorContainer,
    onErrorContainer: AppColors.darkOnErrorContainer,
    surface: AppColors.darkSurface,
    onSurface: AppColors.darkOnSurface,
    onSurfaceVariant: AppColors.darkOnSurfaceVariant,
    outline: AppColors.darkOutline,
    outlineVariant: AppColors.darkOutlineVariant,
    inverseSurface: AppColors.darkInverseSurface,
    onInverseSurface: AppColors.darkInverseOnSurface,
    inversePrimary: AppColors.darkInversePrimary,
    surfaceTint: AppColors.darkPrimary,
    surfaceDim: AppColors.darkSurfaceDim,
    surfaceBright: AppColors.darkSurfaceBright,
    surfaceContainerLowest: AppColors.darkSurfaceContainerLowest,
    surfaceContainerLow: AppColors.darkSurfaceContainerLow,
    surfaceContainer: AppColors.darkSurfaceContainer,
    surfaceContainerHigh: AppColors.darkSurfaceContainerHigh,
    surfaceContainerHighest: AppColors.darkSurfaceContainerHighest,
  );

  // WHY transparent bars? A gallery looks best edge-to-edge (media behind the
  // status bar / gesture bar). `ContrastEnforced: false` stops Android from
  // adding its own grey scrim behind the transparent navigation bar.
  static final SystemUiOverlayStyle _lightOverlay = SystemUiOverlayStyle.dark.copyWith(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
  );

  static final SystemUiOverlayStyle _darkOverlay = SystemUiOverlayStyle.light.copyWith(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
  );

  // ===========================================================================
  // 3. SHARED BUILDER
  // ===========================================================================
  static ThemeData _build({
    required ColorScheme scheme,
    required AppColorExtension ext,
    required Color scaffoldColor,
    required SystemUiOverlayStyle overlay,
    required Color sheetColor, // sheets & dialogs use a different tier per mode
    required Color switchThumbOn,
    required Color switchThumbOff,
    required Color switchTrackOn,
  }) {
    final textTheme = AppTypography.buildTextTheme(
      primaryTextColor: ext.textPrimary,
      secondaryTextColor: ext.textSecondary,
    );

    OutlineInputBorder pill(Color color, [double width = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(9999), // pill-shaped search / PIN field
      borderSide: BorderSide(color: color, width: width),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme, // brightness is taken from the scheme
      textTheme: textTheme,
      scaffoldBackgroundColor: scaffoldColor,
      extensions: [ext],
      iconTheme: IconThemeData(color: scheme.onSurface, size: 24),

      // ---- AppBar --------------------------------------------------------
      // WHY titleTextStyle comes from textTheme: a hard-coded TextStyle has no
      // fontFamily, so titles would show the system font instead of Plus
      // Jakarta Sans. headlineLarge is already 28px / w700 / -0.56 spacing,
      // exactly what the old hard-coded style tried to copy.
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: overlay,
        iconTheme: IconThemeData(color: scheme.onSurface, size: 22),
        actionsIconTheme: IconThemeData(color: scheme.onSurface, size: 22),
        titleTextStyle: textTheme.headlineLarge,
      ),

      // ---- Bottom navigation (Photos / Albums / For You / Search) ---------
      // Matches the Stitch nav: translucent surface-container-lowest (80%),
      // blur is added by GlassContainer in the shell, active = primary color,
      // inactive = onSurfaceVariant, no indicator pill.
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        elevation: 0,
        backgroundColor: scheme.surfaceContainerLowest.withValues(alpha: 0.8),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
          size: 24,
          color: states.contains(WidgetState.selected)
              ? ext.activeAccent
              : ext.textSecondary,
        )),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall!.copyWith(
            color: selected ? ext.activeAccent : ext.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          );
        }),
      ),

      // ---- Cards (album tiles, grouped settings) --------------------------
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: ext.dividerSubtle, width: 1),
        ),
      ),

      // ---- Bottom sheets (viewer "More", album picker) --------------------
      bottomSheetTheme: BottomSheetThemeData(
        surfaceTintColor: Colors.transparent,
        backgroundColor: sheetColor,
        modalBackgroundColor: sheetColor,
        showDragHandle: true,
        dragHandleColor: scheme.outlineVariant,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      // ---- Dialogs (confirm delete, empty trash) --------------------------
      dialogTheme: DialogThemeData(
        backgroundColor: sheetColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyMedium,
      ),

      // ---- Overflow "⋮" menu (Zoom in, Browsing order, Settings...) -------
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: textTheme.bodyLarge,
      ),

      // ---- Snackbar ("Moved to Recently deleted · UNDO") ------------------
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        actionTextColor: scheme.inversePrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // ---- Settings rows ---------------------------------------------------
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: ext.textPrimary,
        titleTextStyle: textTheme.bodyLarge,
        subtitleTextStyle: textTheme.bodySmall,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),

      dividerTheme: DividerThemeData(
        space: 1,
        thickness: 0.8,
        color: ext.dividerSubtle,
      ),

      // ---- Text fields (search bar, PIN field) ----------------------------
      // NOTE: if `flutter analyze` says InputDecorationTheme is deprecated in
      // your Flutter version, rename it to InputDecorationThemeData (same
      // parameters).
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        hintStyle: textTheme.bodyMedium?.copyWith(color: ext.textSecondary),
        prefixIconColor: ext.textSecondary,
        suffixIconColor: ext.textSecondary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: pill(ext.dividerSubtle),
        enabledBorder: pill(ext.dividerSubtle),
        focusedBorder: pill(ext.activeAccent, 1.5),
        // WHY error borders: the PIN screen needs a visible "wrong PIN" state.
        errorBorder: pill(scheme.error),
        focusedErrorBorder: pill(scheme.error, 1.5),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: ext.activeAccent,
        selectionHandleColor: ext.activeAccent,
        selectionColor: ext.accentTintedSurface,
      ),

      // ---- Switch (Settings toggles) --------------------------------------
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected) ? switchThumbOn : switchThumbOff;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? switchTrackOn
              : scheme.surfaceContainerHighest;
        }),
      ),

      // ---- Round selection badge on thumbnails (multi-select) -------------
      checkboxTheme: CheckboxThemeData(
        shape: const CircleBorder(),
        side: WidgetStateBorderSide.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return BorderSide(
            color: selected ? ext.activeAccent : ext.textSecondary,
            width: 1.5,
          );
        }),
        fillColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? ext.activeAccent
              : Colors.transparent;
        }),
        // surface color gives good contrast on both the blue (light) and the
        // cyan (dark) accent; plain white is hard to see on cyan.
        checkColor: WidgetStatePropertyAll(scheme.surface),
      ),

      // ---- Chips (search suggestions, filters) ----------------------------
      chipTheme: ChipThemeData(
        backgroundColor: ext.pillSurface,
        selectedColor: ext.accentTintedSurface,
        side: BorderSide(color: ext.dividerSubtle),
        shape: const StadiumBorder(),
        labelStyle: textTheme.labelLarge,
      ),

      // ---- Video seek bar & scan progress ---------------------------------
      sliderTheme: SliderThemeData(
        trackHeight: 3,
        activeTrackColor: ext.activeAccent,
        inactiveTrackColor: ext.surfaceContainerHighest,
        thumbColor: ext.activeAccent,
        overlayColor: ext.accentTintedSurface,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: ext.activeAccent,
        linearTrackColor: ext.surfaceContainerHighest,
        circularTrackColor: Colors.transparent,
      ),
    );
  }
}

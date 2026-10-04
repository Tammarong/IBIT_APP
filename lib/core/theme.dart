import 'package:flutter/material.dart';

/// IBIT Rooms design tokens. Usage rules live in `.claude/skills/design`.
abstract final class AppColors {
  // Brand
  /// ITD navy: text, primary actions and selected states.
  static const ink = Color(0xFF192F59);

  /// ITD orange. Decoration only (brand bars, dots); too light for text.
  static const orange = Color(0xFFF47B17);

  /// Orange that passes contrast for text and icons on light surfaces.
  static const accent = Color(0xFFB84F0E);
  static const accentTint = Color(0xFFFFF0E3);

  // Neutrals
  /// Page background; cards sit on it in [surface].
  static const canvas = Color(0xFFF4F6FA);
  static const surface = Color(0xFFFFFFFF);

  /// Quiet fills: placeholders, disabled controls, secondary pills.
  static const panel = Color(0xFFEEF1F6);

  /// Soft navy fill for highlighted (not selected) content.
  static const navyTint = Color(0xFFE5EBF5);
  static const line = Color(0xFFDCE2EA);

  /// Secondary text. Lowest-contrast colour allowed for text.
  static const muted = Color(0xFF5E6877);

  // Status
  static const available = Color(0xFF287A56);
  static const availableTint = Color(0xFFE8F3EC);
  static const reserved = Color(0xFF8A97A8);
  static const past = Color(0xFFE3E8EF);
  static const danger = Color(0xFF9C3E28);
  static const dangerTint = Color(0xFFFFEDE8);
  static const dangerLine = Color(0xFFE6B8AE);
}

abstract final class AppSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  /// Horizontal padding of every screen.
  static const gutter = 20.0;
}

abstract final class AppRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
}

const _fontFamily = 'Mitr';

TextTheme _textTheme(TextTheme base) => base
    .merge(
      const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w600,
          height: 1.2,
          letterSpacing: -0.6,
        ),
        headlineMedium: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          height: 1.2,
          letterSpacing: -0.4,
        ),
        headlineSmall: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          height: 1.25,
          letterSpacing: -0.2,
        ),
        titleLarge: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.35,
          letterSpacing: 0,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.4,
          letterSpacing: 0,
        ),
        bodyLarge: TextStyle(fontSize: 16, height: 1.5, letterSpacing: 0),
        bodyMedium: TextStyle(fontSize: 14, height: 1.5, letterSpacing: 0),
        bodySmall: TextStyle(fontSize: 12.5, height: 1.45, letterSpacing: 0),
        labelLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        labelMedium: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        labelSmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    )
    // Applied last so no style can fall back to the platform font.
    .apply(
      fontFamily: _fontFamily,
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    );

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.ink).copyWith(
    primary: AppColors.ink,
    onPrimary: Colors.white,
    primaryContainer: AppColors.navyTint,
    onPrimaryContainer: AppColors.ink,
    secondary: AppColors.accent,
    onSecondary: Colors.white,
    secondaryContainer: AppColors.accentTint,
    onSecondaryContainer: AppColors.accent,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.muted,
    surfaceContainerLowest: AppColors.surface,
    surfaceContainerLow: AppColors.surface,
    surfaceContainer: AppColors.surface,
    surfaceContainerHigh: AppColors.surface,
    surfaceContainerHighest: AppColors.panel,
    outline: const Color(0xFFB4BECB),
    outlineVariant: AppColors.line,
    error: AppColors.danger,
    onError: Colors.white,
    errorContainer: AppColors.dangerTint,
    onErrorContainer: AppColors.danger,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: _fontFamily,
  );
  final text = _textTheme(base.textTheme);
  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.md + 2),
  );
  OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md + 2),
        borderSide: BorderSide(color: color, width: width),
      );
  bool selected(Set<WidgetState> states) =>
      states.contains(WidgetState.selected);
  bool disabled(Set<WidgetState> states) =>
      states.contains(WidgetState.disabled);

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.canvas,
    textTheme: text,
    primaryTextTheme: _textTheme(base.primaryTextTheme),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.canvas,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleMedium!.copyWith(fontSize: 17),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.line,
      thickness: 1,
      space: 1,
    ),
    chipTheme: ChipThemeData(
      showCheckmark: false,
      color: WidgetStateProperty.resolveWith(
        (states) => selected(states)
            ? AppColors.ink
            : disabled(states)
            ? AppColors.panel
            : AppColors.surface,
      ),
      side: WidgetStateBorderSide.resolveWith(
        (states) => BorderSide(
          color: selected(states) ? AppColors.ink : AppColors.line,
        ),
      ),
      labelStyle: text.labelMedium!.copyWith(
        fontSize: 14,
        color: WidgetStateColor.resolveWith(
          (states) => selected(states)
              ? Colors.white
              : disabled(states)
              ? AppColors.muted
              : AppColors.ink,
        ),
      ),
      iconTheme: const IconThemeData(size: 18, color: AppColors.ink),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.panel,
        disabledForegroundColor: AppColors.muted,
        minimumSize: const Size(64, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: text.labelLarge,
        shape: buttonShape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        backgroundColor: AppColors.surface,
        minimumSize: const Size(64, 52),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        side: const BorderSide(color: AppColors.line),
        textStyle: text.labelLarge,
        shape: buttonShape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.ink,
        minimumSize: const Size(48, 48),
        textStyle: text.labelLarge,
        shape: buttonShape,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: AppColors.ink,
        minimumSize: const Size(48, 48),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: text.bodyLarge!.copyWith(color: AppColors.muted),
      floatingLabelStyle: text.bodyMedium!.copyWith(
        color: AppColors.ink,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: text.bodyLarge!.copyWith(color: AppColors.muted),
      prefixIconColor: AppColors.muted,
      suffixIconColor: AppColors.muted,
      border: inputBorder(AppColors.line),
      enabledBorder: inputBorder(AppColors.line),
      disabledBorder: inputBorder(AppColors.panel),
      focusedBorder: inputBorder(AppColors.ink, 2),
      errorBorder: inputBorder(AppColors.danger),
      focusedErrorBorder: inputBorder(AppColors.danger, 2),
      errorStyle: text.bodySmall!.copyWith(color: AppColors.danger),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 68,
      indicatorColor: AppColors.navyTint,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: selected(states) ? AppColors.ink : AppColors.muted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => text.labelSmall!.copyWith(
          color: selected(states) ? AppColors.ink : AppColors.muted,
          fontWeight: selected(states) ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: AppColors.line,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      titleTextStyle: text.titleLarge,
      contentTextStyle: text.bodyMedium!.copyWith(color: AppColors.muted),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      contentTextStyle: text.bodyMedium!.copyWith(color: Colors.white),
      actionTextColor: const Color(0xFFFFC08A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.ink,
    ),
    datePickerTheme: const DatePickerThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
    ),
    timePickerTheme: const TimePickerThemeData(
      backgroundColor: AppColors.surface,
    ),
  );
}

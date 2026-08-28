import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const background = Color(0xFF121416);
  static const surfaceLowest = Color(0xFF0C0E10);
  static const surfaceLow = Color(0xFF1A1C1E);
  static const surface = Color(0xFF1E2022);
  static const surfaceHigh = Color(0xFF282A2C);
  static const surfaceHighest = Color(0xFF333537);
  static const card = surface;
  static const primary = Color(0xFF95D784);
  static const primaryDark = Color(0xFF4E8B42);
  static const primarySoft = Color(0xFF213A26);
  static const secondary = Color(0xFFA1D494);
  static const text = Color(0xFFE2E2E5);
  static const muted = Color(0xFFC1C9BA);
  static const subtle = Color(0xFF8B9385);
  static const line = Color(0xFF2D3135);
  static const lineStrong = Color(0xFF41493D);
  static const warning = Color(0xFFF0B35E);
  static const danger = Color(0xFFFFB4AB);
  static const success = Color(0xFF95D784);
  static const info = Color(0xFF8AB4F8);
  static const offline = Color(0xFF94A3B8);
}

class AppSpacing {
  const AppSpacing._();

  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 40.0;

  static const screen = md;
  static const screenWide = xl;
  static const section = lg;
  static const card = md;
  static const inner = sm;
  static const tight = xs;
}

class AppRadii {
  const AppRadii._();

  static const xs = 6.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const card = lg;
  static const control = sm;
  static const pill = 999.0;
}

class AppTypography {
  const AppTypography._();

  static const fontFamily = 'Inter';
  static const monoFontFamily = 'JetBrains Mono';

  static const labelCaps = TextStyle(
    fontSize: 11,
    height: 1.35,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
    color: AppColors.subtle,
  );

  static const monoMetric = TextStyle(
    fontSize: 13,
    height: 1.25,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
    color: AppColors.text,
  );
}

ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.dark,
    primary: AppColors.primary,
    onPrimary: const Color(0xFF002200),
    secondary: AppColors.secondary,
    surface: AppColors.surface,
    error: AppColors.danger,
  );

  final base = ThemeData(
    colorScheme: colorScheme,
    brightness: Brightness.dark,
    useMaterial3: true,
    fontFamily: AppTypography.fontFamily,
  );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    canvasColor: AppColors.background,
    dividerColor: AppColors.line,
    textTheme: const TextTheme(
      displaySmall: TextStyle(
        fontSize: 32,
        height: 1.25,
        fontWeight: FontWeight.w700,
        color: AppColors.text,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        height: 1.3,
        fontWeight: FontWeight.w700,
        color: AppColors.text,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        height: 1.35,
        fontWeight: FontWeight.w700,
        color: AppColors.text,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        height: 1.35,
        fontWeight: FontWeight.w700,
        color: AppColors.text,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        height: 1.35,
        fontWeight: FontWeight.w700,
        color: AppColors.text,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: AppColors.text,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.45,
        fontWeight: FontWeight.w400,
        color: AppColors.muted,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        height: 1.35,
        fontWeight: FontWeight.w500,
        color: AppColors.subtle,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        height: 1.25,
        fontWeight: FontWeight.w700,
        color: AppColors.text,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        height: 1.25,
        fontWeight: FontWeight.w700,
        color: AppColors.text,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: const BorderSide(color: AppColors.line),
      ),
      margin: EdgeInsets.zero,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.text,
        fontSize: 20,
        height: 1.25,
        fontWeight: FontWeight.w700,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      backgroundColor: AppColors.surfaceLow,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.primarySoft,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.subtle,
          fontSize: 11,
          height: 1.2,
          fontWeight: FontWeight.w700,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.subtle,
          size: 22,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceLowest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: AppTypography.labelCaps,
      hintStyle: const TextStyle(color: AppColors.subtle),
      prefixIconColor: AppColors.subtle,
      suffixIconColor: AppColors.subtle,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.surfaceHighest,
        disabledForegroundColor: AppColors.subtle,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
        side: const BorderSide(color: AppColors.lineStrong),
        foregroundColor: AppColors.primary,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceHigh,
      selectedColor: AppColors.primarySoft,
      disabledColor: AppColors.surface,
      side: const BorderSide(color: AppColors.line),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      labelStyle: const TextStyle(
        color: AppColors.muted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      secondaryLabelStyle: const TextStyle(
        color: AppColors.primary,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surfaceHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: AppColors.surface,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surfaceHighest,
      contentTextStyle: const TextStyle(color: AppColors.text),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primaryDark,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadii.md)),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: AppColors.surfaceLowest,
        foregroundColor: AppColors.muted,
        selectedBackgroundColor: AppColors.primarySoft,
        selectedForegroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.line),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
      circularTrackColor: AppColors.surfaceHighest,
    ),
  );
}

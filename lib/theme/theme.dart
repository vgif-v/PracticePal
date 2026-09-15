import 'package:flutter/material.dart';

/// Kinetic Play design system — colors, typography, shapes, and elevation
/// tokens translated into a Flutter [ThemeData] setup.

// ---------------------------------------------------------------------------
// Colors
// ---------------------------------------------------------------------------
class KineticColors {
  KineticColors._();

  static const surface = Color(0xFFFBF8FF);
  static const surfaceDim = Color(0xFFD5D8F6);
  static const surfaceBright = Color(0xFFFBF8FF);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFF4F2FF);
  static const surfaceContainer = Color(0xFFECECFF);
  static const surfaceContainerHigh = Color(0xFFE5E6FF);
  static const surfaceContainerHighest = Color(0xFFDEE1FF);

  static const onSurface = Color(0xFF161A30);
  static const onSurfaceVariant = Color(0xFF5A403F);
  static const inverseSurface = Color(0xFF2B2F46);
  static const inverseOnSurface = Color(0xFFF0EFFF);

  static const outline = Color(0xFF8E706F);
  static const outlineVariant = Color(0xFFE2BEBC);

  static const surfaceTint = Color(0xFFB52330);
  static const primary = Color(0xFFB52330);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFFFF5A5F);
  static const onPrimaryContainer = Color(0xFF61000E);
  static const inversePrimary = Color(0xFFFFB3B0);

  static const secondary = Color(0xFF006B58);
  static const onSecondary = Color(0xFFFFFFFF);
  static const secondaryContainer = Color(0xFF47FDD6);
  static const onSecondaryContainer = Color(0xFF00725E);

  static const tertiary = Color(0xFF775A00);
  static const onTertiary = Color(0xFFFFFFFF);
  static const tertiaryContainer = Color(0xFFB98D00);
  static const onTertiaryContainer = Color(0xFF3A2A00);

  static const error = Color(0xFFBA1A1A);
  static const onError = Color(0xFFFFFFFF);
  static const errorContainer = Color(0xFFFFDAD6);
  static const onErrorContainer = Color(0xFF93000A);

  static const primaryFixed = Color(0xFFFFDAD8);
  static const primaryFixedDim = Color(0xFFFFB3B0);
  static const onPrimaryFixed = Color(0xFF410007);
  static const onPrimaryFixedVariant = Color(0xFF92001B);

  static const secondaryFixed = Color(0xFF47FDD6);
  static const secondaryFixedDim = Color(0xFF00E0BB);
  static const onSecondaryFixed = Color(0xFF002019);
  static const onSecondaryFixedVariant = Color(0xFF005142);

  static const tertiaryFixed = Color(0xFFFFDF99);
  static const tertiaryFixedDim = Color(0xFFF6BF22);
  static const onTertiaryFixed = Color(0xFF251A00);
  static const onTertiaryFixedVariant = Color(0xFF5A4300);

  static const background = Color(0xFFFBF8FF);
  static const onBackground = Color(0xFF161A30);
  static const surfaceVariant = Color(0xFFDEE1FF);

  // Brand accent hues called out in the style guide (not part of the
  // Material color role list above, but used across gamification UI).
  static const electricCoral = Color(0xFFFF5A5F);
  static const neonTeal = Color(0xFF08E2BD);
  static const sunnyGold = Color(0xFFFFC72C);
  static const accentLilac = Color(0xFF8B5CF6);
  static const warmCream = Color(0xFFFCFBF7);
  static const deepSlate = Color(0xFF1E2238);

  // Cool / dark tokens
  static const coolDark = Color(0xFF0F172A);
  static const coolSlate = Color(0xFF1E293B);
  static const coolBlue = Color(0xFF2563EB);
  static const coolBlueLight = Color(0xFF3B82F6);
  static const coolBorder = Color(0xFFCBD5E1);
  static const coolInputBg = Color(0xFFF8FAFC);
  static const coolMutedText = Color(0xFF64748B);
}

// ---------------------------------------------------------------------------
// Typography — Plus Jakarta Sans across the full scale
// ---------------------------------------------------------------------------
class KineticTypography {
  KineticTypography._();

  static const _fontFamily = 'Plus Jakarta Sans';

  static const displayHero = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 44,
    fontWeight: FontWeight.w800,
    height: 52 / 44,
    letterSpacing: -0.03 * 44,
  );

  static const headlineLg = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w800,
    height: 40 / 32,
    letterSpacing: -0.02 * 32,
  );

  static const headlineLgMobile = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 26,
    fontWeight: FontWeight.w800,
    height: 34 / 26,
    letterSpacing: -0.02 * 26,
  );

  static const headlineMd = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 28 / 22,
    letterSpacing: -0.01 * 22,
  );

  static const headlineSm = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 24 / 18,
  );

  static const titleMd = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 22 / 16,
  );

  static const bodyLg = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 24 / 16,
  );

  static const bodyMd = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 20 / 14,
  );

  static const bodySm = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 16 / 12,
  );

  static const labelLg = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 18 / 14,
    letterSpacing: 0.02 * 14,
  );

  static const labelMd = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    height: 16 / 12,
    letterSpacing: 0.04 * 12,
  );

  static const labelSm = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w800,
    height: 12 / 10,
    letterSpacing: 0.06 * 10,
  );

  static const metricCounter = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 48,
    fontWeight: FontWeight.w800,
    height: 52 / 48,
    letterSpacing: -0.04 * 48,
  );
}

// ---------------------------------------------------------------------------
// Shape & radius tokens
// ---------------------------------------------------------------------------
class KineticRadii {
  KineticRadii._();

  static const sm = 8.0; // 0.5rem
  static const dflt = 16.0; // 1rem
  static const md = 24.0; // 1.5rem
  static const lg = 32.0; // 2rem
  static const xl = 48.0; // 3rem
  static const full = 9999.0;
}

// ---------------------------------------------------------------------------
// Spacing tokens
// ---------------------------------------------------------------------------
class KineticSpacing {
  KineticSpacing._();

  static const gutter = 16.0; // 1rem
  static const margin = 20.0; // 1.25rem
  static const xs = 4.0; // 0.25rem
  static const sm = 8.0; // 0.5rem
  static const md = 16.0; // 1rem
  static const lg = 24.0; // 1.5rem
  static const xl = 32.0; // 2rem
}

// ---------------------------------------------------------------------------
// Elevation shadows (colored, per the "bouncy tactile" spec)
// ---------------------------------------------------------------------------
class KineticShadows {
  KineticShadows._();

  static List<BoxShadow> level1 = [
    BoxShadow(
      color: KineticColors.deepSlate.withValues(alpha: 0.06),
      offset: const Offset(0, 8),
      blurRadius: 24,
    ),
  ];

  static List<BoxShadow> level2 = [
    BoxShadow(
      color: KineticColors.deepSlate.withValues(alpha: 0.12),
      offset: const Offset(0, 12),
      blurRadius: 32,
    ),
  ];

  /// Coral "pop" shadow for primary action buttons.
  static List<BoxShadow> coralPop = [
    BoxShadow(
      color: KineticColors.electricCoral.withValues(alpha: 0.35),
      offset: const Offset(0, 8),
      blurRadius: 20,
    ),
  ];

  /// Cool dark pop shadow for primary action buttons.
  static List<BoxShadow> coolDarkPop = [
    BoxShadow(
      color: KineticColors.coolDark.withValues(alpha: 0.25),
      offset: const Offset(0, 8),
      blurRadius: 20,
    ),
  ];

  /// Collapsed press-state shadow (springy pad effect).
  static List<BoxShadow> pressed = [
    BoxShadow(
      color: KineticColors.deepSlate.withValues(alpha: 0.20),
      offset: const Offset(0, 2),
      blurRadius: 6,
    ),
  ];
}

// ---------------------------------------------------------------------------
// ThemeData
// ---------------------------------------------------------------------------
class KineticTheme {
  KineticTheme._();

  static ThemeData get light {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: KineticColors.primary,
      onPrimary: KineticColors.onPrimary,
      primaryContainer: KineticColors.primaryContainer,
      onPrimaryContainer: KineticColors.onPrimaryContainer,
      secondary: KineticColors.secondary,
      onSecondary: KineticColors.onSecondary,
      secondaryContainer: KineticColors.secondaryContainer,
      onSecondaryContainer: KineticColors.onSecondaryContainer,
      tertiary: KineticColors.tertiary,
      onTertiary: KineticColors.onTertiary,
      tertiaryContainer: KineticColors.tertiaryContainer,
      onTertiaryContainer: KineticColors.onTertiaryContainer,
      error: KineticColors.error,
      onError: KineticColors.onError,
      errorContainer: KineticColors.errorContainer,
      onErrorContainer: KineticColors.onErrorContainer,
      surface: KineticColors.surface,
      onSurface: KineticColors.onSurface,
      surfaceContainerLowest: KineticColors.surfaceContainerLowest,
      surfaceContainerLow: KineticColors.surfaceContainerLow,
      surfaceContainer: KineticColors.surfaceContainer,
      surfaceContainerHigh: KineticColors.surfaceContainerHigh,
      surfaceContainerHighest: KineticColors.surfaceContainerHighest,
      onSurfaceVariant: KineticColors.onSurfaceVariant,
      outline: KineticColors.outline,
      outlineVariant: KineticColors.outlineVariant,
      surfaceTint: KineticColors.surfaceTint,
      inverseSurface: KineticColors.inverseSurface,
      onInverseSurface: KineticColors.inverseOnSurface,
      inversePrimary: KineticColors.inversePrimary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: KineticColors.background,
      fontFamily: 'Plus Jakarta Sans',

      textTheme: const TextTheme(
        displayLarge: KineticTypography.displayHero,
        headlineLarge: KineticTypography.headlineLg,
        headlineMedium: KineticTypography.headlineMd,
        headlineSmall: KineticTypography.headlineSm,
        titleMedium: KineticTypography.titleMd,
        bodyLarge: KineticTypography.bodyLg,
        bodyMedium: KineticTypography.bodyMd,
        bodySmall: KineticTypography.bodySm,
        labelLarge: KineticTypography.labelLg,
        labelMedium: KineticTypography.labelMd,
        labelSmall: KineticTypography.labelSm,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: KineticColors.electricCoral,
          foregroundColor: Colors.white,
          textStyle: KineticTypography.labelLg,
          minimumSize: const Size(48, 48),
          shape: const StadiumBorder(),
          elevation: 0,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: KineticColors.neonTeal,
          foregroundColor: KineticColors.deepSlate,
          textStyle: KineticTypography.labelLg,
          minimumSize: const Size(48, 48),
          shape: const StadiumBorder(),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: KineticColors.deepSlate,
          side: BorderSide(
            color: KineticColors.deepSlate.withValues(alpha: 0.15),
            width: 2,
          ),
          textStyle: KineticTypography.labelLg,
          minimumSize: const Size(48, 48),
          shape: const StadiumBorder(),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF4F3ED),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: KineticSpacing.md,
          vertical: KineticSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KineticRadii.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KineticRadii.md),
          borderSide: const BorderSide(
            color: KineticColors.electricCoral,
            width: 2,
          ),
        ),
      ),

      cardTheme: CardThemeData(
        color: KineticColors.surfaceContainerLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KineticRadii.md),
        ),
        margin: EdgeInsets.zero,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        labelStyle: KineticTypography.labelMd,
        shape: const StadiumBorder(),
        side: BorderSide(color: KineticColors.outlineVariant),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return KineticColors.neonTeal;
          }
          return Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        shape: const CircleBorder(),
      ),
    );
  }
}

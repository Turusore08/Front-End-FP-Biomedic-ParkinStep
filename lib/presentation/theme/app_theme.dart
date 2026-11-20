import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Custom ThemeExtension carrying selective anti-slop elevation tokens.
@immutable
class ParkinThemeExt extends ThemeExtension<ParkinThemeExt> {
  const ParkinThemeExt({
    required this.azureCtaShadow,
    required this.subtleCardShadow,
    required this.diamondControlShadow,
    required this.rhythmAquaGlow,
  });

  final List<BoxShadow> azureCtaShadow;
  final List<BoxShadow> subtleCardShadow;
  final List<BoxShadow> diamondControlShadow;
  final List<BoxShadow> rhythmAquaGlow;

  static const ParkinThemeExt standard = ParkinThemeExt(
    azureCtaShadow: <BoxShadow>[
      BoxShadow(
        color: Color(0x470077B6),
        blurRadius: 24,
        offset: Offset(0, 10),
      ),
    ],
    subtleCardShadow: <BoxShadow>[
      BoxShadow(
        color: Color(0x0F0B1B2B),
        blurRadius: 14,
        offset: Offset(0, 4),
      ),
    ],
    diamondControlShadow: <BoxShadow>[
      BoxShadow(
        color: Color(0x570B1B2B),
        blurRadius: 18,
        offset: Offset(0, 8),
      ),
    ],
    rhythmAquaGlow: <BoxShadow>[
      BoxShadow(
        color: Color(0x3D1AEAD8),
        blurRadius: 24,
        spreadRadius: 2,
      ),
    ],
  );

  @override
  ParkinThemeExt copyWith({
    List<BoxShadow>? azureCtaShadow,
    List<BoxShadow>? subtleCardShadow,
    List<BoxShadow>? diamondControlShadow,
    List<BoxShadow>? rhythmAquaGlow,
  }) {
    return ParkinThemeExt(
      azureCtaShadow: azureCtaShadow ?? this.azureCtaShadow,
      subtleCardShadow: subtleCardShadow ?? this.subtleCardShadow,
      diamondControlShadow: diamondControlShadow ?? this.diamondControlShadow,
      rhythmAquaGlow: rhythmAquaGlow ?? this.rhythmAquaGlow,
    );
  }

  @override
  ParkinThemeExt lerp(ThemeExtension<ParkinThemeExt>? other, double t) {
    if (other is! ParkinThemeExt) return this;
    return t < 0.5 ? this : other;
  }
}

/// Unified ParkinStep v2 ThemeData compliant with WCAG 2.1 contrast and
/// Parkinson's motor accessibility guidelines.
abstract final class AppTheme {
  static ThemeData lightTheme() {
    const colorScheme = ColorScheme.light(
      primary: AppColors.clinicalAzure,
      onPrimary: AppColors.pureWhite,
      secondary: AppColors.royalNavy,
      onSecondary: AppColors.pureWhite,
      surface: AppColors.slateCanvas,
      onSurface: AppColors.royalNavy,
      error: AppColors.alertRed,
      onError: AppColors.pureWhite,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.slateCanvas,
      textTheme: AppTypography.buildTextTheme(),
      extensions: const <ThemeExtension<dynamic>>[
        ParkinThemeExt.standard,
      ],
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.pureWhite,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.subtleBorderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.subtleBorderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: AppColors.clinicalAzure,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.alertRed, width: 1.5),
        ),
      ),
    );
  }
}

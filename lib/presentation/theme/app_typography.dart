import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Geometric typography scale using Plus Jakarta Sans with tabular figures
/// and strict >= 14 sp minimum floor for Parkinson's patient readability.
abstract final class AppTypography {
  static TextTheme buildTextTheme() {
    final base = ThemeData(useMaterial3: true).textTheme;
    return GoogleFonts.plusJakartaSansTextTheme(base);
  }

  static TextStyle screenTitle({
    Color color = AppColors.royalNavy,
    double size = 26.0,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: FontWeight.w800,
      height: 1.20,
      letterSpacing: -0.5,
      color: color,
    );
  }

  static TextStyle heroMetric({
    Color color = AppColors.royalNavy,
    double size = 28.0,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: FontWeight.w800,
      height: 1.15,
      letterSpacing: -0.5,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  static TextStyle cardTitle({
    Color color = AppColors.royalNavy,
    double size = 18.0,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: FontWeight.w700,
      height: 1.25,
      letterSpacing: -0.2,
      color: color,
    );
  }

  static TextStyle buttonLabel({
    Color color = AppColors.pureWhite,
    double size = 17.0,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: FontWeight.w700,
      height: 1.20,
      color: color,
    );
  }

  static TextStyle bodyLarge({
    Color color = AppColors.mutedSlate,
    FontWeight weight = FontWeight.w400,
    double size = 15.5,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      height: 1.45,
      color: color,
    );
  }

  static TextStyle captionBadge({
    Color color = AppColors.mutedSlate,
    FontWeight weight = FontWeight.w600,
    bool tabular = false,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: 14.0,
      fontWeight: weight,
      height: 1.35,
      color: color,
      fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
    );
  }
}

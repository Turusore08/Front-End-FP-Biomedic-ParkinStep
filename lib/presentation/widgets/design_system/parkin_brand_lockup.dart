import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';

enum ParkinLockupVariant { light, dark }

/// ParkinStep Concept A (`P+S` Kinetic Stride) transparent lockup aligned
/// with Figma Brand/LockupLight & Brand/LockupDark without mismatched boxes.
class ParkinBrandLockup extends StatelessWidget {
  const ParkinBrandLockup({
    super.key,
    required this.variant,
    this.emblemSize = 28,
    this.fontSize = 19,
  });

  final ParkinLockupVariant variant;
  final double emblemSize;
  final double fontSize;

  static const String _emblemSvgDark =
      '<svg width="64" height="64" viewBox="0 0 1024 1024" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M 298 672 C 354 672, 392 634, 392 574 L 392 326 L 484 326 C 554 326, 602 368, 602 430 C 602 492, 554 534, 484 534 L 392 534" stroke="#00A9EC" stroke-width="88" stroke-linecap="round" stroke-linejoin="round"/>'
      '<path d="M 476 672 C 546 672, 574 618, 602 570 C 630 522, 662 492, 718 492" stroke="#1AEAD8" stroke-width="84" stroke-linecap="round"/>'
      '</svg>';

  static const String _emblemSvgLight =
      '<svg width="64" height="64" viewBox="0 0 1024 1024" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M 298 672 C 354 672, 392 634, 392 574 L 392 326 L 484 326 C 554 326, 602 368, 602 430 C 602 492, 554 534, 484 534 L 392 534" stroke="#0077B6" stroke-width="88" stroke-linecap="round" stroke-linejoin="round"/>'
      '<path d="M 476 672 C 546 672, 574 618, 602 570 C 630 522, 662 492, 718 492" stroke="#00A9EC" stroke-width="84" stroke-linecap="round"/>'
      '</svg>';

  @override
  Widget build(BuildContext context) {
    final isDark = variant == ParkinLockupVariant.dark;
    return Semantics(
      label: 'Logo ParkinStep',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.string(
            isDark ? _emblemSvgDark : _emblemSvgLight,
            width: emblemSize,
            height: emblemSize,
            excludeFromSemantics: true,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: RichText(
                textScaler: MediaQuery.textScalerOf(context),
                text: TextSpan(
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    height: 1.1,
                  ),
                  children: [
                    TextSpan(
                      text: 'Parkin',
                      style: TextStyle(
                        fontSize: fontSize,
                        color: isDark
                            ? AppColors.pureWhite
                            : AppColors.royalNavy,
                      ),
                    ),
                    TextSpan(
                      text: 'Step',
                      style: TextStyle(
                        fontSize: fontSize,
                        color: isDark
                            ? AppColors.vibrantAzure
                            : AppColors.clinicalAzure, // dark-bg-ok
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

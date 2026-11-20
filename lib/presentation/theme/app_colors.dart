import 'dart:ui';

/// WCAG 2.1 verified color palette mapped 1:1 from docs/DESIGN.md & Figma v2.
abstract final class AppColors {
  // Core Canvas & Navy Surfaces
  static const Color midnightNavy = Color(0xFF0B1B2B);
  static const Color darkElevated = Color(0xFF13263B);
  static const Color royalNavy = Color(0xFF234085);

  // Interactive Azure & Deliberate Accent
  static const Color clinicalAzure = Color(0xFF0077B6); // 4.87:1 w/ #FFFFFF
  static const Color vibrantAzure = Color(0xFF00A9EC); // Icons & dark-bg only
  static const Color onIceAzure = Color(0xFF006299); // 5.58:1 on #D8F1FC
  static const Color rhythmAqua = Color(0xFF1AEAD8); // Single rhythmic accent

  // Light Surfaces & Borders
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color slateCanvas = Color(0xFFF8FAFC);
  static const Color softIce = Color(0xFFD8F1FC);
  static const Color iceSurface = Color(0xFFE8F7FC);
  static const Color skyCard = Color(0xFFBAE6FD);
  static const Color subtleBorderLight = Color(0xFFE2E8F0);
  static const Color subtleBorderDark = Color(0xFF1F3852);

  // Accessible Text Neutrals
  static const Color mutedSlate = Color(0xFF475569); // 7.58:1 on white
  static const Color mutedNavSlate = Color(0xFF64748B); // 4.76:1 on white
  static const Color darkMuted = Color(0xFFCBD5E1); // 11.73:1 on midnight

  // Clinical Semantics (Always paired with icon + text)
  static const Color normalEmerald = Color(0xFF22D399);
  static const Color emeraldDarkText = Color(0xFF065F46);
  static const Color emeraldSoftBg = Color(0xFFD1FAE5);
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color warningAmberText = Color(0xFFB45309);
  static const Color amberSoftBg = Color(0xFFFFFBEB);
  static const Color amberSoftBorder = Color(0xFFFDE68A);
  static const Color amberDarkText = Color(0xFF92400E);
  static const Color alertRed = Color(0xFFDC2626); // 4.83:1 w/ #FFFFFF
  static const Color redSoftBg = Color(0xFFFEF2F2);
  static const Color redDarkText = Color(0xFF991B1B);
}

import 'package:material_ui/material_ui.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';

/// Elevated white guidance card highlighting the active movement cue with
/// high-contrast Royal Navy (`#234085`) text inside `#1AEAD8` (`6.44:1` AA+).
class ParkinHighlightPrompt extends StatelessWidget {
  const ParkinHighlightPrompt({
    super.key,
    required this.highlightWord,
    required this.instructionTail,
    this.highlightColor = AppColors.rhythmAqua,
  });

  final String highlightWord;
  final String instructionTail;
  final Color highlightColor;

  @override
  Widget build(BuildContext context) {
    final themeExt = Theme.of(context).extension<ParkinThemeExt>();
    final shadow =
        themeExt?.subtleCardShadow ?? ParkinThemeExt.standard.subtleCardShadow;

    return Semantics(
      liveRegion: true,
      label: '$highlightWord, $instructionTail',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.pureWhite,
          borderRadius: BorderRadius.circular(18),
          boxShadow: shadow,
        ),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: highlightColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                highlightWord,
                style: AppTypography.cardTitle(
                  color: AppColors.royalNavy,
                  size: 16.5,
                ),
              ),
            ),
            Text(
              instructionTail,
              textAlign: TextAlign.center,
              style: AppTypography.cardTitle(
                color: AppColors.royalNavy,
                size: 16.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

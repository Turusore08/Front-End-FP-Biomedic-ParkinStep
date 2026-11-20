import 'package:material_ui/material_ui.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import 'parkin_icons.dart';

/// Royal Navy (#234085) daily screening prompt card with dismiss ('Lewati')
/// and primary launch ('Mulai') buttons, both enforcing >= 56 dp hit height.
class ParkinDarkReminderCard extends StatelessWidget {
  const ParkinDarkReminderCard({
    super.key,
    required this.title,
    required this.body,
    required this.onDismiss,
    required this.onStart,
  });

  final String title;
  final String body;
  final VoidCallback onDismiss;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.royalNavy,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: AppTypography.cardTitle(
              color: AppColors.pureWhite,
              size: 17.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: AppTypography.bodyLarge(
              color: AppColors.darkMuted,
              size: 14.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Lewati pengingat hari ini',
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: Material(
                      color: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(
                          color: Color(0x99FFFFFF),
                          width: 1.5,
                        ),
                      ),
                      child: InkWell(
                        key: const Key('reminder_dismiss_button'),
                        onTap: onDismiss,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Lewati',
                                style: AppTypography.buttonLabel(
                                  color: AppColors.pureWhite,
                                  size: 15.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Mulai tes putar 360 derajat',
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.clinicalAzure,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          key: const Key('reminder_start_button'),
                          onTap: onStart,
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Mulai',
                                      style: AppTypography.buttonLabel(
                                        color: AppColors.pureWhite,
                                        size: 15.0,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 26,
                                      height: 26,
                                      decoration: const BoxDecoration(
                                        color: AppColors.pureWhite,
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: ParkinIcons.chevronRight(
                                        color: AppColors.clinicalAzure,
                                        size: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

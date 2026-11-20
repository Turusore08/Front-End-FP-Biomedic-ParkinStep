import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../di/dashboard_providers.dart';
import '../../../../domain/constants/clinical_copy.dart';
import '../../../../domain/enums/medication_state.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/design_system/parkin_empty_state_card.dart';
import '../../../widgets/design_system/parkin_icons.dart';
import '../../../widgets/design_system/parkin_secondary_ice_button.dart';
import '../../home/widgets/medication_log_sheet.dart';
import '../../home/widgets/upcoming_feature_sheet.dart';

/// Tab 1 (`/history`): Persisted Levodopa medication logs & screening session summaries.
class HistoryTabScreen extends ConsumerWidget {
  const HistoryTabScreen({super.key});

  static String _formatLocalTimestamp(DateTime utcTime) {
    final local = utcTime.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} · $hour:$minute';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(
      homeDashboardControllerProvider.select((s) => s.summary),
    );

    return Scaffold(
      backgroundColor: AppColors.slateCanvas,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Riwayat & Log Obat',
                style: AppTypography.screenTitle(size: 24),
              ),
              const SizedBox(height: 6),
              Text(
                'Pantau riwayat tes langkah 360° dan catatan konsumsi Levodopa ON/OFF Anda secara offline.',
                style: AppTypography.bodyLarge(size: 14.5),
              ),
              const SizedBox(height: 16),
              ParkinSecondaryIceButton(
                key: const Key('history_log_med_button'),
                title: 'Catat Obat Baru',
                subtitle: 'Tambah status ON, OFF, atau dosis harian',
                leadingIcon: ParkinIcons.capsule(color: AppColors.onIceAzure),
                onPressed: () => showMedicationLogSheet(context),
              ),
              const SizedBox(height: 22),
              Text(
                'Catatan Obat Terbaru',
                style: AppTypography.cardTitle(size: 18),
              ),
              const SizedBox(height: 10),
              if (summary.medicationLogs.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.pureWhite,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.subtleBorderLight),
                  ),
                  child: Text(
                    'Belum ada catatan konsumsi obat tersimpan. Ketuk Catat Obat Baru di atas untuk memulai.',
                    style: AppTypography.bodyLarge(size: 14.5),
                  ),
                )
              else
                Column(
                  children: [
                    for (final log in summary.medicationLogs) ...[
                      _MedicationLogTile(
                        drugName: log.drugName,
                        dosageMg: log.dosageMg,
                        medState: log.medState,
                        timestampLabel: _formatLocalTimestamp(log.takenAtUtc),
                        notes: log.notes,
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              const SizedBox(height: 18),
              Text(
                'Sesi Skrining 360°',
                style: AppTypography.cardTitle(size: 18),
              ),
              const SizedBox(height: 10),
              if (summary.recentSessions.isEmpty)
                ParkinEmptyStateCard(
                  title: ClinicalCopy.emptyHistoryTitle,
                  description: ClinicalCopy.emptyHistoryBody,
                  ctaLabel: ClinicalCopy.emptyHistoryCta,
                  onCtaPressed: () => showUpcomingFeatureSheet(
                    context,
                    flow: ParkinUpcomingFlow.tes360,
                  ),
                )
              else
                Column(
                  children: [
                    for (final session in summary.recentSessions) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.pureWhite,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.subtleBorderLight),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${session.fogPercentage.toStringAsFixed(1).replaceAll('.', ',')}% FoG',
                                    style: AppTypography.cardTitle(size: 18),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_formatLocalTimestamp(session.startedAtUtc)} · ${session.episodeCount} Episode',
                                    style: AppTypography.captionBadge(
                                      color: AppColors.mutedSlate,
                                      weight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.iceSurface,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: AppColors.skyCard),
                              ),
                              child: Text(
                                session.medState.labelId,
                                style: AppTypography.captionBadge(
                                  color: AppColors.onIceAzure,
                                  weight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MedicationLogTile extends StatelessWidget {
  const _MedicationLogTile({
    required this.drugName,
    required this.dosageMg,
    required this.medState,
    required this.timestampLabel,
    this.notes,
  });

  final String drugName;
  final double dosageMg;
  final MedicationState medState;
  final String timestampLabel;
  final String? notes;

  @override
  Widget build(BuildContext context) {
    final (badgeBg, badgeText) = switch (medState) {
      MedicationState.on => (AppColors.emeraldSoftBg, AppColors.emeraldDarkText),
      MedicationState.off => (AppColors.amberSoftBg, AppColors.amberDarkText),
      MedicationState.unknown => (AppColors.iceSurface, AppColors.onIceAzure),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.subtleBorderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$drugName (${dosageMg.round()} mg)',
                  style: AppTypography.cardTitle(size: 16.5),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  medState.labelId,
                  style: AppTypography.captionBadge(
                    color: badgeText,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            timestampLabel,
            style: AppTypography.captionBadge(
              color: AppColors.mutedSlate,
              weight: FontWeight.w500,
            ),
          ),
          if (notes != null && notes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              notes!,
              style: AppTypography.bodyLarge(size: 14.0),
            ),
          ],
        ],
      ),
    );
  }
}

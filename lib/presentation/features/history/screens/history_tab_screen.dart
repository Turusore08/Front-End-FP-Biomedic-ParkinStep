import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../di/dashboard_providers.dart';
import '../../../../domain/constants/clinical_copy.dart';
import '../../../../domain/entities/session_summary_item.dart';
import '../../../../domain/enums/medication_state.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/design_system/parkin_empty_state_card.dart';
import '../../../widgets/design_system/parkin_icons.dart';
import '../../../widgets/design_system/parkin_secondary_ice_button.dart';
import '../../analytics/widgets/medication_trend_chart.dart';
import '../../home/widgets/medication_log_sheet.dart';

enum HistoryRangeFilter {
  days7('7 Hari'),
  days30('30 Hari'),
  all('Semua');

  const HistoryRangeFilter(this.labelId);
  final String labelId;
}

/// S-10 (`Tab 1 /history`): Longitudinal ON vs OFF medication FoG trend chart,
/// range filters, session report drill-downs (S-09), medication log entries, and model metadata.
class HistoryTabScreen extends ConsumerStatefulWidget {
  const HistoryTabScreen({super.key});

  @override
  ConsumerState<HistoryTabScreen> createState() => _HistoryTabScreenState();
}

class _HistoryTabScreenState extends ConsumerState<HistoryTabScreen> {
  HistoryRangeFilter _rangeFilter = HistoryRangeFilter.all;

  static String _formatLocalTimestamp(DateTime utcTime) {
    final local = utcTime.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} · $hour:$minute';
  }

  List<SessionSummaryItem> _applyFilter(
    List<SessionSummaryItem> allSessions,
    DateTime nowLocal,
  ) {
    if (_rangeFilter == HistoryRangeFilter.all || allSessions.isEmpty) {
      return allSessions;
    }
    final cutoffDays = _rangeFilter == HistoryRangeFilter.days7 ? 7 : 30;
    final cutoff = nowLocal.subtract(Duration(days: cutoffDays));
    return allSessions
        .where((s) => !s.startedAtUtc.toLocal().isBefore(cutoff))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(
      homeDashboardControllerProvider.select((s) => s.summary),
    );
    final clock = ref.watch(homeDashboardClockProvider);
    final filteredSessions = _applyFilter(
      summary.recentSessions,
      clock().toLocal(),
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
                ClinicalCopy.historyScreenTitle,
                style: AppTypography.screenTitle(size: 24),
              ),
              const SizedBox(height: 6),
              Text(
                'Pantau tren FoG saat ON/OFF Levodopa, buka laporan grafik & PDF tiap sesi, dan catat obat harian secara offline.',
                style: AppTypography.bodyLarge(size: 14.5),
              ),
              const SizedBox(height: 14),

              // Filter Row (7 Hari | 30 Hari | Semua) with >= 56 dp hit height
              Row(
                children: [
                  _FilterButton(
                    key: const Key('history_filter_7d'),
                    label: HistoryRangeFilter.days7.labelId,
                    selected: _rangeFilter == HistoryRangeFilter.days7,
                    onPressed: () =>
                        setState(() => _rangeFilter = HistoryRangeFilter.days7),
                  ),
                  const SizedBox(width: 8),
                  _FilterButton(
                    key: const Key('history_filter_30d'),
                    label: HistoryRangeFilter.days30.labelId,
                    selected: _rangeFilter == HistoryRangeFilter.days30,
                    onPressed: () => setState(
                      () => _rangeFilter = HistoryRangeFilter.days30,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _FilterButton(
                    key: const Key('history_filter_all'),
                    label: HistoryRangeFilter.all.labelId,
                    selected: _rangeFilter == HistoryRangeFilter.all,
                    onPressed: () =>
                        setState(() => _rangeFilter = HistoryRangeFilter.all),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Longitudinal ON/OFF Chart (S-10)
              MedicationTrendChart(sessions: filteredSessions),
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
                'Riwayat Sesi Skrining',
                style: AppTypography.cardTitle(size: 18),
              ),
              const SizedBox(height: 10),
              if (filteredSessions.isEmpty)
                ParkinEmptyStateCard(
                  key: const Key('history_empty_state'),
                  title: ClinicalCopy.emptyHistoryTitle,
                  description: ClinicalCopy.emptyHistoryBody,
                  ctaLabel: ClinicalCopy.emptyHistoryCta,
                  onCtaPressed: () => context.push('/select-test'),
                )
              else
                Column(
                  children: [
                    for (final session in filteredSessions) ...[
                      Semantics(
                        button: true,
                        label:
                            'Buka laporan detail sesi ${session.fogPercentage.toStringAsFixed(1)} persen FoG',
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 64),
                          child: Material(
                            color: AppColors.pureWhite,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: const BorderSide(
                                color: AppColors.subtleBorderLight,
                              ),
                            ),
                            child: InkWell(
                              key: Key('history_session_${session.sessionId}'),
                              borderRadius: BorderRadius.circular(18),
                              onTap: () => context.push(
                                '/session-report/${session.sessionId}',
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${session.fogPercentage.toStringAsFixed(1).replaceAll('.', ',')}% FoG',
                                            style: AppTypography.cardTitle(
                                              size: 18,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${session.protocol.shortLabelId} · ${_formatLocalTimestamp(session.startedAtUtc)} · ${session.episodeCount} Episode',
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
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.iceSurface,
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(
                                          color: AppColors.skyCard,
                                        ),
                                      ),
                                      child: Text(
                                        session.medState.labelId,
                                        style: AppTypography.captionBadge(
                                          color: AppColors.onIceAzure,
                                          weight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ParkinIcons.chevronRight(
                                      color: AppColors.royalNavy,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),

              const SizedBox(height: 18),
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

              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.iceSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.skyCard),
                ),
                child: Text(
                  ClinicalCopy.historyModelMetadata,
                  style: AppTypography.captionBadge(
                    color: AppColors.onIceAzure,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: 'Filter riwayat $label',
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Material(
            color: selected ? AppColors.clinicalAzure : AppColors.pureWhite,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: selected
                    ? AppColors.clinicalAzure
                    : AppColors.subtleBorderLight,
                width: 1.5,
              ),
            ),
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      style: AppTypography.buttonLabel(
                        color: selected
                            ? AppColors.pureWhite
                            : AppColors.royalNavy,
                        size: 14.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
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

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../application/ports/report_export_port.dart';
import '../../../../application/use_cases/export_clinical_report.dart';
import '../../../../di/analytics_providers.dart';
import '../../../../di/clinical_session_providers.dart';
import '../../../../di/dashboard_providers.dart';
import '../../../../di/video_playback_providers.dart';
import '../../../../domain/constants/clinical_copy.dart';
import '../../../../domain/entities/session_clinical_report.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/design_system/parkin_icons.dart';
import '../../../widgets/design_system/parkin_primary_pill_button.dart';
import '../../../widgets/design_system/parkin_secondary_ice_button.dart';
import '../../../widgets/design_system/parkin_state_cards.dart';
import '../widgets/fog_timeline_chart.dart';
import '../widgets/spectral_freeze_index_chart.dart';
import '../widgets/video_skeleton_player_card.dart';

/// S-09: Post-Session Clinical Analytics Summary (`FogTimelineChart`,
/// `SpectralFreezeIndexChart`) & Offline Neurologist A4 PDF / CSV Export.
class SessionReportScreen extends ConsumerStatefulWidget {
  const SessionReportScreen({
    super.key,
    required this.sessionId,
  });

  final String sessionId;

  @override
  ConsumerState<SessionReportScreen> createState() =>
      _SessionReportScreenState();
}

class _SessionReportScreenState extends ConsumerState<SessionReportScreen> {
  bool _isExportingPdf = false;
  bool _isExportingCsv = false;
  ExportedReportFile? _lastExport;
  String? _exportError;

  Future<void> _exportPdf(SessionClinicalReport report) async {
    setState(() {
      _isExportingPdf = true;
      _exportError = null;
    });
    try {
      final useCase = ExportClinicalPdfUseCase(
        ref.read(reportExportPortProvider),
      );
      final saved = await useCase.execute(report);
      if (!mounted) return;
      setState(() {
        _isExportingPdf = false;
        _lastExport = saved;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isExportingPdf = false;
        _exportError = 'Gagal membuat laporan PDF A4. Silakan coba lagi.';
      });
    }
  }

  Future<void> _exportCsv(SessionClinicalReport report) async {
    setState(() {
      _isExportingCsv = true;
      _exportError = null;
    });
    try {
      final useCase = ExportClinicalCsvUseCase(
        ref.read(reportExportPortProvider),
      );
      final saved = await useCase.execute(report);
      if (!mounted) return;
      setState(() {
        _isExportingCsv = false;
        _lastExport = saved;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isExportingCsv = false;
        _exportError = 'Gagal mengekspor data CSV. Silakan coba lagi.';
      });
    }
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(sessionReportByIdProvider(widget.sessionId));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.slateCanvas,
        body: SafeArea(
          child: reportAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: ParkinLoadingDspCard(
                  title: 'Memuat Laporan Sesi...',
                  description: 'Menyiapkan grafik klinis dari memori lokal.',
                ),
              ),
            ),
            error: (_, _) => _MissingReportView(onBack: _goBack),
            data: (report) {
              if (report == null) {
                return _MissingReportView(onBack: _goBack);
              }
              return _buildReportBody(report);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildReportBody(SessionClinicalReport report) {
    final s = report.summary;
    final fogPctStr = s.fogPercentage.toStringAsFixed(1).replaceAll('.', ',');
    final medianStr = report.medianEpisodeDurationSec
        .toStringAsFixed(1)
        .replaceAll('.', ',');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Flexible(
                child: Semantics(
                  button: true,
                  label: 'Kembali ke halaman sebelumnya',
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        key: const Key('report_back_button'),
                        onTap: _goBack,
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ParkinIcons.arrowBack(
                                  color: AppColors.royalNavy,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Kembali',
                                  style: AppTypography.buttonLabel(
                                    color: AppColors.royalNavy,
                                    size: 16.0,
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
            ],
          ),
          const SizedBox(height: 8),
          Text(
            ClinicalCopy.reportScreenTitle,
            style: AppTypography.screenTitle(size: 24),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.iceSurface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.skyCard),
                ),
                child: Text(
                  s.protocol.titleId,
                  style: AppTypography.captionBadge(
                    color: AppColors.onIceAzure,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.iceSurface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.skyCard),
                ),
                child: Text(
                  report.isSimulatedPreview
                      ? 'Data Simulasi · ${s.medState.labelId}'
                      : 'Sesi Tersimpan · ${s.medState.labelId}',
                  style: AppTypography.captionBadge(
                    color: AppColors.onIceAzure,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3 KPI Summary Cards
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _KpiTile(
                  label: 'Waktu FoG',
                  value: '$fogPctStr%',
                  highlighted: s.episodeCount > 0,
                ),
                const SizedBox(width: 8),
                _KpiTile(
                  label: 'Episode',
                  value: '${s.episodeCount}',
                  highlighted: false,
                ),
                const SizedBox(width: 8),
                _KpiTile(
                  label: 'Median',
                  value: '${medianStr}s',
                  highlighted: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Putar Ulang Video & Skeleton 17-COCO
          VideoSkeletonPlayerCard(
            report: report,
            onDeleteVideo: () async {
              await ref.read(recordedMediaPortProvider).deleteSessionMedia(
                videoPath: report.recordedVideoPath,
                poseTrackPath: report.poseTrackPath,
              );
              final updated = report.copyWith(
                videoSecurelyDeleted: true,
                clearRecordedVideoPath: true,
                clearPoseTrackPath: true,
                clearPoseTrack: true,
              );
              await ref
                  .read(homeDashboardRepositoryProvider)
                  .saveSessionReport(updated);
              final currentCompletedId = ref
                  .read(clinicalSessionControllerProvider)
                  .completedRecord
                  ?.summary
                  .sessionId;
              if (currentCompletedId == widget.sessionId) {
                await ref
                    .read(clinicalSessionControllerProvider.notifier)
                    .deleteCompletedSessionVideo();
              }
              ref.invalidate(sessionReportByIdProvider(widget.sessionId));
            },
          ),
          const SizedBox(height: 16),

          // Grafik 1: 120s Timeline + Episode Annotations
          FogTimelineChart(report: report),
          const SizedBox(height: 16),

          // Grafik 2: Spectral Band Energy & Freeze Index
          SpectralFreezeIndexChart(report: report),
          const SizedBox(height: 18),

          if (_exportError != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.redSoftBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.alertRed),
              ),
              child: Text(
                _exportError!,
                style: AppTypography.captionBadge(
                  color: AppColors.redDarkText,
                  weight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          if (_lastExport != null) ...[
            Semantics(
              liveRegion: true,
              child: Container(
                key: const Key('export_status_banner'),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.emeraldSoftBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.normalEmerald),
                ),
                child: Row(
                  children: [
                    ParkinIcons.check(
                      color: AppColors.emeraldDarkText,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'File tersimpan offline: ${_lastExport!.fileName} '
                        '(${(_lastExport!.bytes.length / 1024).toStringAsFixed(1)} KB)',
                        style: AppTypography.captionBadge(
                          color: AppColors.emeraldDarkText,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          ParkinPrimaryPillButton(
            key: const Key('export_pdf_button'),
            label: 'Bagikan PDF ke Dokter',
            leadingIcon: ParkinIcons.offlineShield(
              color: AppColors.clinicalAzure,
            ),
            isLoading: _isExportingPdf,
            onPressed: _isExportingCsv ? null : () => _exportPdf(report),
          ),
          const SizedBox(height: 12),
          ParkinSecondaryIceButton(
            key: const Key('export_csv_button'),
            title: 'Ekspor CSV (${report.windows.length} Window)',
            subtitle: 'Simpan data kinematika 16 kolom untuk dokter/riset',
            leadingIcon: ParkinIcons.navHistory(color: AppColors.onIceAzure),
            isLoading: _isExportingCsv,
            onPressed: _isExportingPdf ? null : () => _exportCsv(report),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.amberSoftBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.amberSoftBorder),
            ),
            child: Text(
              ClinicalCopy.medicalDisclaimer,
              style: AppTypography.captionBadge(
                color: AppColors.amberDarkText,
                weight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.label,
    required this.value,
    required this.highlighted,
  });

  final String label;
  final String value;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: highlighted ? AppColors.redSoftBg : AppColors.pureWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: highlighted
                ? AppColors.alertRed
                : AppColors.subtleBorderLight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                style: AppTypography.captionBadge(
                  color: highlighted
                      ? AppColors.redDarkText
                      : AppColors.mutedSlate,
                  weight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: AppTypography.heroMetric(
                  color: highlighted
                      ? AppColors.redDarkText
                      : AppColors.royalNavy,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissingReportView extends StatelessWidget {
  const _MissingReportView({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Laporan Sesi Tidak Ditemukan',
            textAlign: TextAlign.center,
            style: AppTypography.screenTitle(size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            'Data sesi tidak tersedia pada memori perangkat.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyLarge(),
          ),
          const SizedBox(height: 20),
          ParkinPrimaryPillButton(
            label: 'Kembali',
            leadingIcon: ParkinIcons.arrowBack(color: AppColors.clinicalAzure),
            onPressed: onBack,
          ),
        ],
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../domain/constants/clinical_copy.dart';
import '../../../../domain/entities/fog_episode_item.dart';
import '../../../../domain/entities/session_clinical_report.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/design_system/parkin_icons.dart';

/// S-09 Chart 1 (`fl_chart`): 0..120s calibrated FoG probability curve with `50%`
/// (`thr_val`) threshold line, shaded episode blocks, and tremor-safe tap chips.
class FogTimelineChart extends StatefulWidget {
  const FogTimelineChart({
    super.key,
    required this.report,
  });

  final SessionClinicalReport report;

  @override
  State<FogTimelineChart> createState() => _FogTimelineChartState();
}

class _FogTimelineChartState extends State<FogTimelineChart> {
  int? _selectedEpisodeIdx;

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final spots = _buildSpots(report);
    final rawDur = report.summary.durationSec > 0
        ? report.summary.durationSec
        : 120.0;
    final maxWindowEnd = report.windows.isEmpty
        ? rawDur
        : report.windows.last.endSec;
    final maxX = math.max(rawDur, maxWindowEnd).clamp(10.0, 600.0);
    final xInterval = maxX <= 30.0 ? 10.0 : (maxX <= 60.0 ? 20.0 : 30.0);

    final selectedEp = _selectedEpisodeIdx != null &&
            _selectedEpisodeIdx! >= 0 &&
            _selectedEpisodeIdx! < report.episodes.length
        ? report.episodes[_selectedEpisodeIdx!]
        : null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.subtleBorderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ClinicalCopy.reportTimelineTitle,
            style: AppTypography.cardTitle(size: 17),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: AppColors.iceSurface,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Ambang Batas FoG: 50%',
                style: AppTypography.captionBadge(
                  color: AppColors.royalNavy,
                  weight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (report.episodes.isEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.emeraldSoftBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  ParkinIcons.check(
                    color: AppColors.emeraldDarkText,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ClinicalCopy.reportZeroEpisodeBadge,
                      style: AppTypography.captionBadge(
                        color: AppColors.emeraldDarkText,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: maxX,
                minY: 0,
                maxY: 100,
                clipData: const FlClipData.all(),
                lineTouchData: const LineTouchData(enabled: false),
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: 50,
                  verticalInterval: xInterval,
                  getDrawingHorizontalLine: (value) => const FlLine(
                    color: AppColors.subtleBorderLight,
                    strokeWidth: 1,
                  ),
                  getDrawingVerticalLine: (value) => const FlLine(
                    color: AppColors.subtleBorderLight,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: AppColors.subtleBorderLight),
                ),
                extraLinesData: ExtraLinesData(
                  horizontalLines: <HorizontalLine>[
                    HorizontalLine(
                      y: 50,
                      color: AppColors.royalNavy,
                      strokeWidth: 1.8,
                      dashArray: const <int>[6, 4],
                    ),
                  ],
                ),
                rangeAnnotations: RangeAnnotations(
                  verticalRangeAnnotations: report.episodes
                      .map(
                        (ep) => VerticalRangeAnnotation(
                          x1: ep.startSec.clamp(0.0, maxX),
                          x2: ep.endSec.clamp(0.0, maxX),
                          color: AppColors.alertRed.withValues(alpha: 0.18),
                        ),
                      )
                      .toList(),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 50,
                      reservedSize: 52,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            '${value.round()}%',
                            style: AppTypography.captionBadge(
                              color: AppColors.mutedNavSlate,
                              weight: FontWeight.w600,
                              tabular: true,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: xInterval,
                      reservedSize: 30,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        if (value > maxX + 0.1) return const SizedBox.shrink();
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            '${value.round()}s',
                            style: AppTypography.captionBadge(
                              color: AppColors.royalNavy,
                              weight: FontWeight.w600,
                              tabular: true,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: <LineChartBarData>[
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    preventCurveOverShooting: true,
                    color: AppColors.clinicalAzure,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          AppColors.clinicalAzure.withValues(alpha: 0.28),
                          AppColors.softIce.withValues(alpha: 0.05),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (report.episodes.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Ketuk Episode untuk Detail (Tanpa Hover):',
              style: AppTypography.captionBadge(
                color: AppColors.mutedSlate,
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < report.episodes.length; i++)
                  _EpisodeTapChip(
                    episode: report.episodes[i],
                    selected: _selectedEpisodeIdx == i,
                    onPressed: () {
                      setState(() {
                        _selectedEpisodeIdx =
                            _selectedEpisodeIdx == i ? null : i;
                      });
                    },
                  ),
              ],
            ),
            if (selectedEp != null) ...[
              const SizedBox(height: 10),
              Container(
                key: const Key('timeline_selected_episode_detail'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.redSoftBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.alertRed),
                ),
                child: Text(
                  'Episode ${selectedEp.episodeIndex}: '
                  'Mulai ${selectedEp.startSec.toStringAsFixed(1)} dtk - '
                  'Selesai ${selectedEp.endSec.toStringAsFixed(1)} dtk '
                  '(Durasi ${selectedEp.durationSec.toStringAsFixed(1)} dtk · '
                  'Puncak ${selectedEp.peakCalibratedScore.round()}%)',
                  style: AppTypography.captionBadge(
                    color: AppColors.redDarkText,
                    weight: FontWeight.w700,
                    tabular: true,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  List<FlSpot> _buildSpots(SessionClinicalReport report) {
    if (report.windows.isNotEmpty) {
      return report.windows
          .map(
            (w) => FlSpot(
              w.endSec,
              w.calibratedScore.isFinite
                  ? w.calibratedScore.clamp(0.0, 100.0)
                  : 0.0,
            ),
          )
          .toList();
    }

    final maxDur =
        report.summary.durationSec > 0 ? report.summary.durationSec : 120.0;
    final baselineY = report.summary.fogPercentage >= 50.0 ? 58.0 : 18.0;
    return <FlSpot>[
      FlSpot(0, baselineY * 0.7),
      FlSpot(maxDur * 0.5, baselineY),
      FlSpot(maxDur, baselineY * 0.8),
    ];
  }
}

class _EpisodeTapChip extends StatelessWidget {
  const _EpisodeTapChip({
    required this.episode,
    required this.selected,
    required this.onPressed,
  });

  final FogEpisodeItem episode;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppColors.alertRed : AppColors.redSoftBg;
    final fg = selected ? AppColors.pureWhite : AppColors.redDarkText;

    return Semantics(
      button: true,
      selected: selected,
      label:
          'Episode ${episode.episodeIndex}, durasi ${episode.durationSec.toStringAsFixed(1)} detik',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Material(
          color: bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.alertRed),
          ),
          child: InkWell(
            key: Key('episode_chip_${episode.episodeIndex}'),
            onTap: onPressed,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Text(
                'Ep ${episode.episodeIndex} (${episode.durationSec.toStringAsFixed(1)}s)',
                style: AppTypography.buttonLabel(color: fg, size: 14.0),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../domain/constants/clinical_copy.dart';
import '../../../../domain/entities/session_clinical_report.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';

/// S-09 Chart 2 (`fl_chart`): Locomotor normal (0.5-3.0 Hz) vs FoG tremor band
/// (3.0-7.35 Hz @ 15 Hz) spectral energy comparison + Moore's Freeze Index & Asymmetry.
class SpectralFreezeIndexChart extends StatelessWidget {
  const SpectralFreezeIndexChart({
    super.key,
    required this.report,
  });

  final SessionClinicalReport report;

  @override
  Widget build(BuildContext context) {
    final loco = report.locomotorBandEnergy.isFinite
        ? math.max(0.0, report.locomotorBandEnergy)
        : 0.0;
    final freeze = report.freezeBandEnergy.isFinite
        ? math.max(0.0, report.freezeBandEnergy)
        : 0.0;
    final maxY = math.max(5.0, math.max(loco, freeze) * 1.25);

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
            ClinicalCopy.reportSpectrumTitle,
            style: AppTypography.cardTitle(size: 17),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                minY: 0,
                maxY: maxY,
                alignment: BarChartAlignment.spaceAround,
                barTouchData: const BarTouchData(enabled: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxY / 2).clamp(1.0, 20.0),
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: AppColors.subtleBorderLight,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: AppColors.subtleBorderLight),
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
                      reservedSize: 44,
                      interval: (maxY / 2).clamp(1.0, 20.0),
                      getTitlesWidget: (double value, TitleMeta meta) {
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            value.toStringAsFixed(0),
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
                      reservedSize: 34,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        final label =
                            value.round() == 0 ? '0,5-3 Hz' : '3-7,35 Hz';
                        return SideTitleWidget(
                          meta: meta,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              label,
                              style: AppTypography.captionBadge(
                                color: AppColors.royalNavy,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: <BarChartGroupData>[
                  BarChartGroupData(
                    x: 0,
                    barRods: <BarChartRodData>[
                      BarChartRodData(
                        toY: loco,
                        width: 40,
                        color: AppColors.normalEmerald,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(10),
                        ),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 1,
                    barRods: <BarChartRodData>[
                      BarChartRodData(
                        toY: freeze,
                        width: 40,
                        color: AppColors.alertRed,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(10),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.slateCanvas,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.subtleBorderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Freeze Index',
                          style: AppTypography.captionBadge(
                            color: AppColors.mutedSlate,
                            weight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            report.meanFreezeIndex
                                .toStringAsFixed(2)
                                .replaceAll('.', ','),
                            style: AppTypography.heroMetric(size: 24),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.slateCanvas,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.subtleBorderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Asimetri Engkel',
                          style: AppTypography.captionBadge(
                            color: AppColors.mutedSlate,
                            weight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            report.asymmetryLevelId,
                            style: AppTypography.heroMetric(size: 22),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

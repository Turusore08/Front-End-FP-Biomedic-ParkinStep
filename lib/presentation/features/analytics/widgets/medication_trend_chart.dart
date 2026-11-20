import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../domain/entities/session_summary_item.dart';
import '../../../../domain/enums/medication_state.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';

/// S-10 Longitudinal Trend Chart (`fl_chart`): compares FoG% across recorded
/// sessions using distinct dot shapes + WCAG-safe colors for ON/OFF/UNKNOWN.
class MedicationTrendChart extends StatelessWidget {
  const MedicationTrendChart({
    super.key,
    required this.sessions,
  });

  final List<SessionSummaryItem> sessions;

  @override
  Widget build(BuildContext context) {
    final chronological = List<SessionSummaryItem>.of(sessions)
      ..sort((a, b) => a.startedAtUtc.compareTo(b.startedAtUtc));

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
            'Tren FoG Saat ON vs OFF Obat',
            style: AppTypography.cardTitle(size: 17.5),
          ),
          const SizedBox(height: 10),
          const Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _LegendDot(
                color: AppColors.clinicalAzure,
                shapeSymbol: '●',
                label: 'ON Obat',
              ),
              _LegendDot(
                color: AppColors.warningAmberText,
                shapeSymbol: '■',
                label: 'OFF Obat',
              ),
              _LegendDot(
                color: AppColors.mutedSlate,
                shapeSymbol: '×',
                label: 'Tidak Tahu',
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (chronological.isEmpty)
            Text(
              'Belum ada sesi skrining pada rentang waktu ini.',
              style: AppTypography.bodyLarge(size: 14.5),
            )
          else if (chronological.length == 1)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.iceSurface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Baru ada 1 sesi (${chronological.first.fogPercentage.toStringAsFixed(1).replaceAll('.', ',')}% FoG · ${chronological.first.medState.labelId}). Selesaikan minimal 2 sesi untuk membentuk garis tren.',
                style: AppTypography.bodyLarge(
                  color: AppColors.royalNavy,
                  size: 14.5,
                ),
              ),
            )
          else
            SizedBox(
              height: 190,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: (chronological.length - 1).toDouble(),
                  minY: 0,
                  maxY: 100,
                  lineTouchData: const LineTouchData(enabled: false),
                  gridData: FlGridData(
                    show: true,
                    horizontalInterval: 50,
                    verticalInterval: math.max(1.0, (chronological.length - 1) / 3),
                    getDrawingHorizontalLine: (_) => const FlLine(
                      color: AppColors.subtleBorderLight,
                      strokeWidth: 1,
                    ),
                    getDrawingVerticalLine: (_) => const FlLine(
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
                        reservedSize: 52,
                        interval: 50,
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
                        reservedSize: 30,
                        interval: 1,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          final idx = value.round();
                          if (idx < 0 || idx >= chronological.length) {
                            return const SizedBox.shrink();
                          }
                          // Show first, middle and last labels to avoid crowding on 360dp
                          final isEdgeOrMid = idx == 0 ||
                              idx == chronological.length - 1 ||
                              idx == chronological.length ~/ 2;
                          if (!isEdgeOrMid) return const SizedBox.shrink();
                          final local = chronological[idx].startedAtUtc.toLocal();
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              '${local.day}/${local.month}',
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
                      spots: <FlSpot>[
                        for (var i = 0; i < chronological.length; i++)
                          FlSpot(
                            i.toDouble(),
                            chronological[i].fogPercentage.clamp(0.0, 100.0),
                          ),
                      ],
                      isCurved: false,
                      color: AppColors.royalNavy,
                      barWidth: 2.5,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          final med = chronological[index].medState;
                          return switch (med) {
                            MedicationState.on => FlDotCirclePainter(
                                radius: 5.5,
                                color: AppColors.clinicalAzure,
                                strokeWidth: 2,
                                strokeColor: AppColors.pureWhite,
                              ),
                            MedicationState.off => FlDotSquarePainter(
                                size: 11,
                                color: AppColors.warningAmberText,
                                strokeWidth: 2,
                                strokeColor: AppColors.pureWhite,
                              ),
                            MedicationState.unknown => FlDotCrossPainter(
                                size: 11,
                                color: AppColors.mutedSlate,
                                width: 2.5,
                              ),
                          };
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.shapeSymbol,
    required this.label,
  });

  final Color color;
  final String shapeSymbol;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          shapeSymbol,
          style: AppTypography.captionBadge(
            color: color,
            weight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTypography.captionBadge(
            color: AppColors.royalNavy,
            weight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

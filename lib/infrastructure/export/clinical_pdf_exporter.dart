import 'dart:math' as math;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../application/ports/report_export_port.dart';
import '../../domain/constants/clinical_copy.dart';
import '../../domain/entities/session_clinical_report.dart';

/// Offline A4 PDF clinical report generator built with `package:pdf`, rendering
/// the monochrome Concept A P+S emblem, 4 summary KPIs, vector FoG timeline,
/// paginated episode table, and mandatory Indonesian Medical Disclaimer footer.
class ClinicalPdfExporter {
  const ClinicalPdfExporter();

  static const PdfColor _royalNavy = PdfColor.fromInt(0xFF234085);
  static const PdfColor _clinicalAzure = PdfColor.fromInt(0xFF0077B6);
  static const PdfColor _mutedSlate = PdfColor.fromInt(0xFF475569);
  static const PdfColor _borderLight = PdfColor.fromInt(0xFFE2E8F0);
  static const PdfColor _iceBg = PdfColor.fromInt(0xFFE8F7FC);
  static const PdfColor _alertRed = PdfColor.fromInt(0xFFDC2626);
  static const PdfColor _softRedBand = PdfColor.fromInt(0xFFFEE2E2);
  static const PdfColor _amberBg = PdfColor.fromInt(0xFFFFFBEB);
  static const PdfColor _amberBorder = PdfColor.fromInt(0xFFFDE68A);
  static const PdfColor _amberText = PdfColor.fromInt(0xFF92400E);

  static const String _emblemMonoSvg =
      '<svg viewBox="0 0 1024 1024" width="64" height="64" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M 298 672 C 354 672, 392 634, 392 574 L 392 326 L 484 326 C 554 326, 602 368, 602 430 C 602 492, 554 534, 484 534 L 392 534" fill="none" stroke="#234085" stroke-width="80" stroke-linecap="round" stroke-linejoin="round"/>'
      '<path d="M 476 672 C 546 672, 574 618, 602 570 C 630 522, 662 492, 718 492" fill="none" stroke="#234085" stroke-width="76" stroke-linecap="round"/>'
      '</svg>';

  Future<ExportedReportFile> generate(SessionClinicalReport report) async {
    final s = report.summary;
    final doc = pw.Document();

    final localTime = s.startedAtUtc.toLocal();
    final localStr =
        '${localTime.day.toString().padLeft(2, '0')}/${localTime.month.toString().padLeft(2, '0')}/${localTime.year} '
        '${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';

    final tableRows = report.episodes.isEmpty
        ? <List<String>>[
            <String>[ClinicalCopy.reportZeroEpisodeBadge, '-', '-', '-', '-'],
          ]
        : report.episodes
            .map(
              (ep) => <String>[
                'Episode ${ep.episodeIndex}',
                ep.startSec.toStringAsFixed(1),
                ep.endSec.toStringAsFixed(1),
                ep.durationSec.toStringAsFixed(1),
                '${ep.peakCalibratedScore.toStringAsFixed(1)}%',
              ],
            )
            .toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 28),
        footer: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: _amberBg,
                border: pw.Border.all(color: _amberBorder),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                ClinicalCopy.medicalDisclaimer,
                style: const pw.TextStyle(fontSize: 7.5, color: _amberText),
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'ParkinStep Mobile-FOG · Sesi ${s.sessionId}',
                  style: const pw.TextStyle(fontSize: 8, color: _mutedSlate),
                ),
                pw.Text(
                  'Halaman ${ctx.pageNumber} / ${ctx.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8, color: _mutedSlate),
                ),
              ],
            ),
          ],
        ),
        build: (pw.Context ctx) => <pw.Widget>[
          // Clinical Header with Monochrome SVG Brand Emblem
          pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: _borderLight, width: 1),
              ),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.SvgImage(svg: _emblemMonoSvg, width: 32, height: 32),
                pw.SizedBox(width: 8),
                pw.Text(
                  'ParkinStep',
                  style: const pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: _royalNavy,
                  ),
                ),
                pw.Spacer(),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Laporan Pemantauan Freezing of Gait',
                      style: const pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: _royalNavy,
                      ),
                    ),
                    pw.Text(
                      'Pasien: ${report.patientDisplayName} · Status Obat: ${s.medState.labelId}',
                      style: const pw.TextStyle(fontSize: 9, color: _mutedSlate),
                    ),
                    pw.Text(
                      'Waktu: $localStr (UTC: ${s.startedAtUtc.toUtc().toIso8601String()})',
                      style: const pw.TextStyle(fontSize: 8, color: _mutedSlate),
                    ),
                    pw.Text(
                      'Model: ${report.modelBundleVersion} · Ambang p=${report.thresholdUsed.toStringAsFixed(2)}',
                      style: const pw.TextStyle(fontSize: 8, color: _mutedSlate),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          // 4 KPI Summary Cards
          pw.Row(
            children: [
              _kpiBox('Durasi Sesi', '${s.durationSec.round()} detik'),
              pw.SizedBox(width: 8),
              _kpiBox(
                'Waktu FoG (%)',
                '${s.fogPercentage.toStringAsFixed(1)}%',
              ),
              pw.SizedBox(width: 8),
              _kpiBox('Jumlah Episode', '${s.episodeCount}'),
              pw.SizedBox(width: 8),
              _kpiBox(
                'Median Episode',
                '${report.medianEpisodeDurationSec.toStringAsFixed(1)} dtk',
              ),
            ],
          ),
          pw.SizedBox(height: 16),

          // Vector Timeline Graphic
          pw.Text(
            'Grafik Probabilitas Risiko FoG Terkalibrasi (0-100%, Ambang 50%)',
            style: const pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: _royalNavy,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _borderLight),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.CustomPaint(
              size: const PdfPoint(480, 105),
              painter: (PdfGraphics canvas, PdfPoint size) =>
                  _paintTimelineChart(canvas, size, report),
            ),
          ),
          pw.SizedBox(height: 12),

          // Spectral & Kinematic Summary Box
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: _iceBg,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  "Moore's Freeze Index: ${report.meanFreezeIndex.toStringAsFixed(2)}",
                  style: const pw.TextStyle(
                    fontSize: 9.5,
                    fontWeight: pw.FontWeight.bold,
                    color: _royalNavy,
                  ),
                ),
                pw.Text(
                  'Asimetri Engkel: ${report.asymmetryLevelId} (${report.meanBilateralAsymmetry.toStringAsFixed(2)})',
                  style: const pw.TextStyle(
                    fontSize: 9.5,
                    fontWeight: pw.FontWeight.bold,
                    color: _royalNavy,
                  ),
                ),
                pw.Text(
                  'Kualitas Sendi LB6: ${(report.validLb6Ratio * 100).round()}%',
                  style: const pw.TextStyle(
                    fontSize: 9.5,
                    fontWeight: pw.FontWeight.bold,
                    color: _royalNavy,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          pw.Text(
            'Daftar Episode FoG Terkonfirmasi (min_run >= 2 window)',
            style: const pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: _royalNavy,
            ),
          ),
          pw.SizedBox(height: 6),

          pw.TableHelper.fromTextArray(
            headers: const <String>[
              'Episode #',
              'Mulai (s)',
              'Selesai (s)',
              'Durasi (s)',
              'Skor Puncak (%)',
            ],
            data: tableRows,
            headerStyle: const pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(color: _royalNavy),
            cellStyle: const pw.TextStyle(fontSize: 8.5, color: _royalNavy),
            cellAlignment: pw.Alignment.centerLeft,
            border: pw.TableBorder.all(color: _borderLight, width: 0.5),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 5,
            ),
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    return ExportedReportFile(
      fileName: 'parkinstep_laporan_${s.sessionId}.pdf',
      mimeType: 'application/pdf',
      bytes: bytes,
    );
  }

  pw.Widget _kpiBox(String label, String value) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _borderLight),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 8, color: _mutedSlate),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              value,
              style: const pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: _royalNavy,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _paintTimelineChart(
    PdfGraphics canvas,
    PdfPoint size,
    SessionClinicalReport report,
  ) {
    final maxDur = math.max(
      report.summary.durationSec > 0 ? report.summary.durationSec : 120.0,
      report.windows.isEmpty ? 120.0 : report.windows.last.endSec,
    );

    // Draw episode bands in soft red
    canvas.setFillColor(_softRedBand);
    for (final ep in report.episodes) {
      final x1 = (ep.startSec / maxDur).clamp(0.0, 1.0) * size.x;
      final x2 = (ep.endSec / maxDur).clamp(0.0, 1.0) * size.x;
      if (x2 > x1) {
        canvas.drawRect(x1, 0, x2 - x1, size.y);
        canvas.fillPath();
      }
    }

    // Outer frame border
    canvas
      ..setStrokeColor(_borderLight)
      ..setLineWidth(0.8)
      ..drawRect(0, 0, size.x, size.y)
      ..strokePath();

    // 50% threshold dashed line (midpoint Y)
    canvas
      ..setStrokeColor(_alertRed)
      ..setLineWidth(0.8)
      ..setLineDashPattern(<int>[4, 3])
      ..moveTo(0, size.y * 0.5)
      ..lineTo(size.x, size.y * 0.5)
      ..strokePath()
      ..setLineDashPattern(<int>[]);

    if (report.windows.isEmpty) {
      final y = (report.summary.fogPercentage >= 50 ? 60.0 : 18.0) / 100.0;
      canvas
        ..setStrokeColor(_clinicalAzure)
        ..setLineWidth(1.5)
        ..moveTo(0, y * size.y)
        ..lineTo(size.x, y * size.y)
        ..strokePath();
      return;
    }

    canvas
      ..setStrokeColor(_clinicalAzure)
      ..setLineWidth(1.6);
    for (var i = 0; i < report.windows.length; i++) {
      final w = report.windows[i];
      final x = (w.endSec / maxDur).clamp(0.0, 1.0) * size.x;
      final y = (w.calibratedScore.clamp(0.0, 100.0) / 100.0) * size.y;
      if (i == 0) {
        canvas.moveTo(x, y);
      } else {
        canvas.lineTo(x, y);
      }
    }
    canvas.strokePath();
  }
}

import 'dart:io';

import '../../application/ports/report_export_port.dart';
import '../../domain/entities/session_clinical_report.dart';
import 'clinical_csv_exporter.dart';
import 'clinical_pdf_exporter.dart';

/// Offline file export adapter combining A4 PDF & CSV exporters and saving
/// reports cleanly to local application storage without network dependencies.
class LocalReportExportAdapter implements ReportExportPort {
  LocalReportExportAdapter({
    this.pdfExporter = const ClinicalPdfExporter(),
    this.csvExporter = const ClinicalCsvExporter(),
    Directory Function()? targetDirectoryProvider,
  }) : _targetDirectoryProvider = targetDirectoryProvider ?? _defaultExportDir;

  final ClinicalPdfExporter pdfExporter;
  final ClinicalCsvExporter csvExporter;
  final Directory Function() _targetDirectoryProvider;

  static Directory _defaultExportDir() =>
      Directory('${Directory.systemTemp.path}/parkinstep_exports');

  @override
  Future<ExportedReportFile> generatePdfReport(SessionClinicalReport report) {
    return pdfExporter.generate(report);
  }

  @override
  Future<ExportedReportFile> generateCsvReport(SessionClinicalReport report) async {
    return csvExporter.generate(report);
  }

  @override
  Future<ExportedReportFile> saveReportFile(ExportedReportFile file) async {
    final dir = _targetDirectoryProvider();
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    final sanitizedName = file.fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final target = File('${dir.path}/$sanitizedName');
    await target.writeAsBytes(file.bytes, flush: true);
    return file.copyWith(savedPath: target.path);
  }
}

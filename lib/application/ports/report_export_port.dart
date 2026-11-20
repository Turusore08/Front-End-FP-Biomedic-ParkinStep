import '../../domain/entities/session_clinical_report.dart';

/// Generated offline PDF or CSV artifact ready for local save or share sheet.
class ExportedReportFile {
  const ExportedReportFile({
    required this.fileName,
    required this.mimeType,
    required this.bytes,
    this.savedPath,
  });

  final String fileName;
  final String mimeType;
  final List<int> bytes;
  final String? savedPath;

  ExportedReportFile copyWith({String? savedPath}) {
    return ExportedReportFile(
      fileName: fileName,
      mimeType: mimeType,
      bytes: bytes,
      savedPath: savedPath ?? this.savedPath,
    );
  }
}

/// Port for offline A4 PDF & CSV clinical report generation and persistence.
abstract interface class ReportExportPort {
  Future<ExportedReportFile> generatePdfReport(SessionClinicalReport report);

  Future<ExportedReportFile> generateCsvReport(SessionClinicalReport report);

  Future<ExportedReportFile> saveReportFile(ExportedReportFile file);
}

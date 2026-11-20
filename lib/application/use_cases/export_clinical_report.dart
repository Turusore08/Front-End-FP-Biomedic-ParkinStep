import '../../domain/entities/session_clinical_report.dart';
import '../ports/report_export_port.dart';

/// Generates & persists an A4 offline clinical PDF report for neurologist review.
class ExportClinicalPdfUseCase {
  const ExportClinicalPdfUseCase(this._port);

  final ReportExportPort _port;

  Future<ExportedReportFile> execute(SessionClinicalReport report) async {
    final generated = await _port.generatePdfReport(report);
    return _port.saveReportFile(generated);
  }
}

/// Generates & persists a 16-column research-parity CSV export of session windows.
class ExportClinicalCsvUseCase {
  const ExportClinicalCsvUseCase(this._port);

  final ReportExportPort _port;

  Future<ExportedReportFile> execute(SessionClinicalReport report) async {
    final generated = await _port.generateCsvReport(report);
    return _port.saveReportFile(generated);
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/report_model.dart';

/// In-memory report state for the current app session.
/// Reports are not persisted to Supabase yet; this provider starts empty.
class ReportsNotifier extends Notifier<List<ReportModel>> {
  @override
  List<ReportModel> build() => [];

  void addReport(ReportModel newReport) {
    state = [newReport, ...state];
  }

  void updateReportStatus(String id, ReportStatus newStatus, {String? resolutionNote}) {
    state = state.map((r) {
      if (r.id == id) {
        return r.copyWith(status: newStatus, resolutionNote: resolutionNote);
      }
      return r;
    }).toList();
  }
}

final reportsProvider = NotifierProvider<ReportsNotifier, List<ReportModel>>(ReportsNotifier.new);

final nearbyReportsProvider = Provider<List<ReportModel>>((ref) {
  final all = ref.watch(reportsProvider);
  return all.where((r) => r.status != ReportStatus.resolved).take(4).toList();
});

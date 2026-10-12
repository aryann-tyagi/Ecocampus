import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/report_model.dart';

class UserPointsNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void addPoints(int points) {
    state = state + points;
  }
}

final userPointsProvider = NotifierProvider<UserPointsNotifier, int>(UserPointsNotifier.new);

final userLevelProvider = Provider<Map<String, dynamic>>((ref) {
  final points = ref.watch(userPointsProvider);
  return {
    'level': null,
    'title': 'Not configured',
    'points': points,
    'nextRank': null,
    'totalLevels': null,
  };
});

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

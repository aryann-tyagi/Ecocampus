import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/report_model.dart';

class UserPointsNotifier extends Notifier<int> {
  @override
  int build() => 420;

  void addPoints(int points) {
    state = state + points;
  }
}

final userPointsProvider = NotifierProvider<UserPointsNotifier, int>(UserPointsNotifier.new);

final userLevelProvider = Provider<Map<String, dynamic>>((ref) {
  final points = ref.watch(userPointsProvider);
  return {
    'level': 5,
    'title': 'Sprout',
    'points': points,
    'nextRank': 'Guardian · Level 10',
    'totalLevels': 20,
  };
});

class ReportsNotifier extends Notifier<List<ReportModel>> {
  @override
  List<ReportModel> build() => [
        ReportModel(
          id: 'REP-2026-001',
          title: 'Overflowing waste bin',
          category: IssueCategory.waste,
          severity: IssueSeverity.high,
          location: const CampusLocation(
            building: 'Block B',
            floor: 'Ground Floor',
            area: 'Cafeteria Entrance',
          ),
          status: ReportStatus.reported,
          createdAt: DateTime.now().subtract(const Duration(minutes: 42)),
          description: 'Recycling bin overflowing near east patio with food containers spilled.',
          department: 'Sanitation & Grounds',
          distanceMeters: 120,
          aiConfidence: 0.96,
        ),
        ReportModel(
          id: 'REP-2026-002',
          title: 'Broken light',
          category: IssueCategory.electricity,
          severity: IssueSeverity.medium,
          location: const CampusLocation(
            building: 'Block A',
            floor: '2nd Floor',
            area: 'Room 204',
          ),
          status: ReportStatus.inProgress,
          createdAt: DateTime.now().subtract(const Duration(hours: 3)),
          description: 'Overhead LED fixture flickering continuously causing distraction.',
          department: 'Electrical Maintenance',
          distanceMeters: 240,
          aiConfidence: 0.92,
        ),
        ReportModel(
          id: 'REP-2026-003',
          title: 'Leaking faucet in restroom',
          category: IssueCategory.water,
          severity: IssueSeverity.medium,
          location: const CampusLocation(
            building: 'Library',
            floor: '1st Floor',
            area: 'Washroom 102',
          ),
          status: ReportStatus.assigned,
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          description: 'Continuous dripping from the cold water tap, wasting ~10L/day.',
          department: 'Plumbing & Facilities',
          distanceMeters: 310,
          aiConfidence: 0.94,
        ),
        ReportModel(
          id: 'REP-2026-004',
          title: 'Air conditioning left running in empty hall',
          category: IssueCategory.electricity,
          severity: IssueSeverity.low,
          location: const CampusLocation(
            building: 'Canteen',
            floor: 'Ground Floor',
            area: 'Conference Hall B',
          ),
          status: ReportStatus.resolved,
          createdAt: DateTime.now().subtract(const Duration(days: 3)),
          description: 'AC was running at 18°C overnight with no occupants present.',
          department: 'Energy Conservation',
          distanceMeters: 180,
          aiConfidence: 0.88,
          resolutionNote: 'Thermostat turned off and scheduled smart sensor timer installed.',
        ),
      ];

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

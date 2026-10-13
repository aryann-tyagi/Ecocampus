import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../report/data/reports_provider.dart';
import '../../report/domain/report_model.dart';
import '../../rewards/data/eco_points_provider.dart';
import '../../rewards/domain/eco_points_model.dart';

/// Returns a time-of-day greeting based on the current hour.
String _greetingForHour(int hour) {
  if (hour < 5) return 'Good night';
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  if (hour < 21) return 'Good evening';
  return 'Good night';
}

/// Provides the time-of-day greeting. Auto-disposed so it refreshes each build.
final greetingProvider = Provider.autoDispose<String>((ref) {
  return _greetingForHour(DateTime.now().hour);
});

/// Summary statistics derived from the reports state and live get_my_eco_stats RPC.
class HomeDashboardStats {
  final int totalReports;
  final int activeReports;
  final int resolvedReports;
  final int pendingReports;

  /// EcoScore from live get_my_eco_stats (total points capped at 100; 0 for new account).
  final int ecoScore;

  /// User level derived dynamically from live get_my_eco_stats RPC.
  final int level;
  final String levelTitle;

  const HomeDashboardStats({
    required this.totalReports,
    required this.activeReports,
    required this.resolvedReports,
    required this.pendingReports,
    required this.ecoScore,
    required this.level,
    required this.levelTitle,
  });
}

/// Computes home dashboard statistics from current reports and dynamic live EcoScore state.
final homeDashboardProvider = Provider<HomeDashboardStats>((ref) {
  final reports = ref.watch(reportsProvider);
  final ecoSummary = ref.watch(ecoPointsProvider).value ?? EcoPointsSummary.zero();

  final total = reports.length;
  int resolved = 0;
  int active = 0;
  int pending = 0;

  for (final r in reports) {
    if (r.status == ReportStatus.resolved) {
      resolved++;
    } else if (r.status != ReportStatus.rejected &&
        r.status != ReportStatus.duplicate) {
      active++;
    }
    if (r.status == ReportStatus.reported) {
      pending++;
    }
  }

  return HomeDashboardStats(
    totalReports: total,
    activeReports: active,
    resolvedReports: resolved,
    pendingReports: pending,
    ecoScore: ecoSummary.ecoScore,
    level: ecoSummary.level,
    levelTitle: ecoSummary.levelTitle,
  );
});

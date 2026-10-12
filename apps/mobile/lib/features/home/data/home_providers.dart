import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../report/data/reports_provider.dart';
import '../../report/domain/report_model.dart';

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

/// Summary statistics derived from the reports state.
class HomeDashboardStats {
  final int totalReports;
  final int activeReports;
  final int resolvedReports;
  final int pendingReports;

  /// Campus Eco Score — currently a demo estimate derived from resolved ratio.
  /// Labeled as estimate; not a verified environmental metric.
  final int? ecoScore;

  /// User level derived from points. Demo formula until backend defines it.
  final int? level;
  final String? levelTitle;

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

/// Computes home dashboard statistics from current reports and points state.
///
/// Eco Score is a demo estimate: base 60 + up to 40 based on resolved ratio.
/// Level is derived from points with a simple tier formula.
/// Both are explicitly labeled as demo/estimate values in the UI.
final homeDashboardProvider = Provider<HomeDashboardStats>((ref) {
  final reports = ref.watch(reportsProvider);

  final total = reports.length;
  final resolved =
      reports.where((r) => r.status == ReportStatus.resolved).length;
  final active = reports
      .where((r) =>
          r.status != ReportStatus.resolved &&
          r.status != ReportStatus.rejected)
      .length;
  final pending =
      reports.where((r) => r.status == ReportStatus.reported).length;

  // No score or level is displayed until an approved calculation and trusted
  // points ledger are connected to the backend.
  return HomeDashboardStats(
    totalReports: total,
    activeReports: active,
    resolvedReports: resolved,
    pendingReports: pending,
    ecoScore: null,
    level: null,
    levelTitle: null,
  );
});

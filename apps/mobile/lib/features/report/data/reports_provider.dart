import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_providers.dart';
import '../domain/report_model.dart';
import 'reports_repository.dart';

import '../../rewards/data/achievements_provider.dart';
import '../../rewards/data/challenges_provider.dart';
import '../../map/data/campus_map_provider.dart';

// Old UserPointsNotifier / userPointsProvider / userLevelProvider removed.
// EcoPoints are now managed by rewards/data/eco_points_provider.dart
// which reads from the server-side eco_point_events ledger.

class ReportsNotifier extends Notifier<List<ReportModel>> {
  @override
  List<ReportModel> build() {
    // Watch current user: when auth state changes or user signs out,
    // automatically reset in-memory report state to empty.
    ref.watch(currentUserProvider);
    return const [];
  }

  void setReports(List<ReportModel> reports) {
    state = reports;
  }

  void addReport(ReportModel newReport) {
    state = [newReport, ...state.where((r) => r.id != newReport.id)];
    ref.invalidate(achievementsProvider);
    ref.invalidate(dailyChallengesProvider);
    ref.invalidate(buildingSummariesProvider);
  }

  void updateReportStatus(String id, ReportStatus newStatus, {String? resolutionNote}) {
    state = state.map((r) {
      if (r.id == id) {
        return r.copyWith(status: newStatus, resolutionNote: resolutionNote);
      }
      return r;
    }).toList();
    ref.invalidate(achievementsProvider);
    ref.invalidate(dailyChallengesProvider);
    ref.invalidate(buildingSummariesProvider);
  }

  void softDeleteReport(String id, {String? reason}) {
    final now = DateTime.now();
    state = state.map((r) {
      if (r.id == id) {
        return r.copyWith(deletedAt: now, deletionReason: reason);
      }
      return r;
    }).toList();
    ref.invalidate(buildingSummariesProvider);
  }
}

final reportsProvider = NotifierProvider<ReportsNotifier, List<ReportModel>>(ReportsNotifier.new);

/// Async notifier for loading and refreshing student reports directly from Supabase.
class MyReportsNotifier extends AsyncNotifier<List<ReportModel>> {
  @override
  FutureOr<List<ReportModel>> build() {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      ref.read(reportsProvider.notifier).setReports([]);
      return const [];
    }

    return _fetchReports(user.id);
  }

  Future<List<ReportModel>> _fetchReports(String userId) async {
    final repo = ref.watch(reportsRepositoryProvider);
    final reports = await repo.getMyReports(userId);

    // Race condition check: Ensure the authenticated user has not changed while fetching
    final current = ref.read(currentUserProvider);
    if (current?.id != userId) {
      return const [];
    }

    // Sync to synchronous reportsProvider so home screen and widgets stay in sync
    ref.read(reportsProvider.notifier).setReports(reports);
    return reports;
  }

  bool _isRefreshing = false;

  /// Refreshes the reports list from Supabase.
  Future<void> refresh() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) {
        state = const AsyncValue.data([]);
        ref.read(reportsProvider.notifier).setReports([]);
        return;
      }
      final repo = ref.read(reportsRepositoryProvider);
      final reports = await repo.getMyReports(user.id);

      // Race condition check: discard stale response from previous user
      final current = ref.read(currentUserProvider);
      if (current?.id != user.id) return;

      ref.read(reportsProvider.notifier).setReports(reports);
      state = AsyncValue.data(reports);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    } finally {
      _isRefreshing = false;
    }
  }

  /// Optimistically prepends a newly created report.
  void addReport(ReportModel report) {
    final List<ReportModel> current = state.value ?? ref.read(reportsProvider);
    final updated = [report, ...current.where((r) => r.id != report.id)];
    state = AsyncValue.data(updated);
    ref.read(reportsProvider.notifier).setReports(updated);
    // Also notify campusReportsProvider so nearby feed updates immediately
    ref.read(campusReportsProvider.notifier).addReport(report);
    ref.invalidate(achievementsProvider);
    ref.invalidate(dailyChallengesProvider);
    ref.invalidate(buildingSummariesProvider);
  }

  /// Updates report status and invalidates rewards state
  void updateReportStatus(String id, ReportStatus newStatus, {String? resolutionNote}) {
    final List<ReportModel> current = state.value ?? ref.read(reportsProvider);
    final updated = current.map((r) {
      if (r.id == id) {
        return r.copyWith(status: newStatus, resolutionNote: resolutionNote);
      }
      return r;
    }).toList();
    state = AsyncValue.data(updated);
    ref.read(reportsProvider.notifier).setReports(updated);
    // Immediately synchronize campusReportsProvider so Home feed updates
    ref.read(campusReportsProvider.notifier).updateReportStatus(id, newStatus, resolutionNote: resolutionNote);
    ref.invalidate(achievementsProvider);
    ref.invalidate(dailyChallengesProvider);
    ref.invalidate(buildingSummariesProvider);
  }

  /// Soft deletes a report and immediately purges it from the campus feed
  void softDeleteReport(String id, {String? reason}) {
    final List<ReportModel> current = state.value ?? ref.read(reportsProvider);
    final now = DateTime.now();
    final updated = current.map((r) {
      if (r.id == id) {
        return r.copyWith(deletedAt: now, deletionReason: reason);
      }
      return r;
    }).toList();
    state = AsyncValue.data(updated);
    ref.read(reportsProvider.notifier).setReports(updated);
    // Immediately remove from campus reports feed
    ref.read(campusReportsProvider.notifier).removeReport(id);
    ref.invalidate(buildingSummariesProvider);
  }
}

final myReportsProvider =
    AsyncNotifierProvider<MyReportsNotifier, List<ReportModel>>(
  MyReportsNotifier.new,
);

/// Async notifier for loading and refreshing active campus reports for the shared nearby feed.
class CampusReportsNotifier extends AsyncNotifier<List<ReportModel>> {
  @override
  FutureOr<List<ReportModel>> build() {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return const [];
    }
    return _fetchCampusReports(user.id);
  }

  Future<List<ReportModel>> _fetchCampusReports(String expectedUserId) async {
    final repo = ref.watch(reportsRepositoryProvider);
    final reports = await repo.getNearbyReports(limit: 10);
    if (ref.read(currentUserProvider)?.id != expectedUserId) {
      return const [];
    }
    // Filter out resolved and soft-deleted reports at client level as defense-in-depth
    return reports
        .where((r) =>
            r.status != ReportStatus.resolved &&
            r.status != ReportStatus.rejected &&
            r.status != ReportStatus.duplicate &&
            !r.isDeleted)
        .toList();
  }

  bool _isRefreshing = false;

  /// Refreshes the campus reports feed from Supabase.
  Future<void> refresh() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      state = const AsyncValue.data([]);
      return;
    }
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      final repo = ref.read(reportsRepositoryProvider);
      final reports = await repo.getNearbyReports(limit: 10);
      if (ref.read(currentUserProvider)?.id == user.id) {
        state = AsyncValue.data(reports
            .where((r) =>
                r.status != ReportStatus.resolved &&
                r.status != ReportStatus.rejected &&
                r.status != ReportStatus.duplicate &&
                !r.isDeleted)
            .toList());
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    } finally {
      _isRefreshing = false;
    }
  }

  /// Adds a newly created report to the campus reports feed if active and not deleted.
  void addReport(ReportModel report) {
    final current = state.value ?? const [];
    if (report.status != ReportStatus.resolved &&
        report.status != ReportStatus.rejected &&
        report.status != ReportStatus.duplicate &&
        !report.isDeleted) {
      state = AsyncValue.data([report, ...current.where((r) => r.id != report.id)]);
    }
  }

  /// Immediately removes a report from the active campus feed.
  void removeReport(String reportId) {
    final current = state.value ?? const [];
    state = AsyncValue.data(current.where((r) => r.id != reportId).toList());
  }

  /// Updates report status and automatically purges it from feed if resolved or deleted.
  void updateReportStatus(
    String id,
    ReportStatus newStatus, {
    String? resolutionNote,
    DateTime? deletedAt,
    String? deletionReason,
  }) {
    final current = state.value ?? const [];
    if (newStatus == ReportStatus.resolved ||
        newStatus == ReportStatus.rejected ||
        newStatus == ReportStatus.duplicate ||
        deletedAt != null) {
      state = AsyncValue.data(current.where((r) => r.id != id).toList());
    } else {
      state = AsyncValue.data(current.map((r) {
        if (r.id == id) {
          return r.copyWith(
            status: newStatus,
            resolutionNote: resolutionNote,
            deletedAt: deletedAt,
            deletionReason: deletionReason,
          );
        }
        return r;
      }).toList());
    }
  }
}

final campusReportsProvider =
    AsyncNotifierProvider<CampusReportsNotifier, List<ReportModel>>(
  CampusReportsNotifier.new,
);

final nearbyReportsProvider = Provider<List<ReportModel>>((ref) {
  final campusAsync = ref.watch(campusReportsProvider);
  final campusList = campusAsync.value ?? const [];
  final userReports = ref.watch(reportsProvider);

  final combined = <ReportModel>[...campusList];
  for (final r in userReports) {
    final existingIdx = combined.indexWhere((c) => c.id == r.id);
    if (existingIdx >= 0) {
      if (combined[existingIdx].imageUrl == null && r.imageUrl != null) {
        combined[existingIdx] = combined[existingIdx].copyWith(imageUrl: r.imageUrl);
      }
    } else if (r.status != ReportStatus.resolved &&
        r.status != ReportStatus.rejected &&
        r.status != ReportStatus.duplicate &&
        !r.isDeleted) {
      combined.add(r);
    }
  }

  return combined
      .where((r) =>
          r.status != ReportStatus.resolved &&
          r.status != ReportStatus.rejected &&
          r.status != ReportStatus.duplicate &&
          !r.isDeleted)
      .take(10)
      .toList();
});

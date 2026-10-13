import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_providers.dart';
import '../domain/eco_points_model.dart';
import 'eco_points_repository.dart';
import 'achievements_provider.dart';
import 'challenges_provider.dart';

/// Async notifier that loads the authenticated user's EcoPoints summary from get_my_eco_stats.
///
/// Single source of truth for total points, EcoScore (capped at 100), level, and progress.
class EcoPointsNotifier extends AsyncNotifier<EcoPointsSummary> {
  @override
  FutureOr<EcoPointsSummary> build() {
    final user = ref.watch(currentUserProvider);
    if (user == null) return EcoPointsSummary.zero();
    return _fetch(user.id);
  }

  Future<EcoPointsSummary> _fetch(String expectedUserId) async {
    final repo = ref.read(ecoPointsRepositoryProvider);
    final summary = await repo.getUserSummary(userId: expectedUserId);
    // Prevent stale in-flight responses from overwriting a newly switched account
    if (ref.read(currentUserProvider)?.id != expectedUserId) {
      return EcoPointsSummary.zero();
    }
    return summary;
  }

  bool _isRefreshing = false;

  /// Refreshes the summary from Supabase and updates state immediately.
  Future<void> refresh() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      state = AsyncValue.data(EcoPointsSummary.zero());
      return;
    }
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      final summary = await _fetch(user.id);
      state = AsyncValue.data(summary);
    } catch (e, st) {
      debugPrint('EcoPointsNotifier.refresh failed: $e');
      state = AsyncValue.error(e, st);
    } finally {
      _isRefreshing = false;
    }
  }

  /// Triggers refresh after report submission.
  /// Points (+5) are automatically awarded server-side by the database trigger.
  Future<int> awardReportSubmitted({
    required String userId,
    required String reportId,
    bool isCritical = false,
  }) async {
    // Database trigger handles the award; client refreshes state
    await refresh();
    ref.invalidate(leaderboardProvider);
    ref.invalidate(ecoPointEventsProvider);
    ref.invalidate(achievementsProvider);
    ref.invalidate(dailyChallengesProvider);
    return EcoScoringRules.reportSubmitted;
  }

  /// Triggers refresh after a report reaches RESOLVED.
  /// Points (+15) are automatically awarded server-side by the database trigger.
  Future<int> awardReportResolved({
    required String userId,
    required String reportId,
  }) async {
    await refresh();
    ref.invalidate(leaderboardProvider);
    ref.invalidate(ecoPointEventsProvider);
    ref.invalidate(achievementsProvider);
    ref.invalidate(dailyChallengesProvider);
    return EcoScoringRules.reportResolved;
  }
}

final ecoPointsProvider =
    AsyncNotifierProvider<EcoPointsNotifier, EcoPointsSummary>(
  EcoPointsNotifier.new,
);

/// Convenience provider that exposes total points for quick numeric access.
final ecoTotalPointsProvider = Provider<int>((ref) {
  final summary = ref.watch(ecoPointsProvider);
  return summary.value?.totalPoints ?? 0;
});

/// Async notifier for the campus leaderboard from get_campus_leaderboard.
class LeaderboardNotifier extends AsyncNotifier<List<LeaderboardEntry>> {
  @override
  FutureOr<List<LeaderboardEntry>> build() {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const [];
    return _fetch(user.id);
  }

  Future<List<LeaderboardEntry>> _fetch(String expectedUserId) async {
    final repo = ref.read(ecoPointsRepositoryProvider);
    final list = await repo.getLeaderboard(limit: 50, currentUserId: expectedUserId);
    if (ref.read(currentUserProvider)?.id != expectedUserId) {
      return const [];
    }
    return list;
  }

  Future<void> refresh() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      state = const AsyncValue.data([]);
      return;
    }
    state = await AsyncValue.guard(() => _fetch(user.id));
  }
}

final leaderboardProvider =
    AsyncNotifierProvider<LeaderboardNotifier, List<LeaderboardEntry>>(
  LeaderboardNotifier.new,
);

/// Async provider for the user's recent point events history.
final ecoPointEventsProvider = FutureProvider.autoDispose<List<EcoPointEvent>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  final repo = ref.read(ecoPointsRepositoryProvider);
  return repo.getUserEvents(userId: user.id, limit: 50);
});

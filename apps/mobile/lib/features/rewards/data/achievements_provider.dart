import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_providers.dart';
import '../domain/achievement_model.dart';
import 'achievements_repository.dart';

/// State notifier managing user achievements, loading states, and refreshes.
class AchievementsNotifier extends AsyncNotifier<List<Achievement>> {
  @override
  FutureOr<List<Achievement>> build() {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return Achievement.buildCatalog(
        validReportCount: 0,
        resolvedReportCount: 0,
      );
    }
    return _fetch(user.id);
  }

  Future<List<Achievement>> _fetch(String expectedUserId) async {
    final repo = ref.read(achievementsRepositoryProvider);
    final list = await repo.getAchievements(userId: expectedUserId);

    // Prevent race conditions when user switches account in-flight
    if (ref.read(currentUserProvider)?.id != expectedUserId) {
      return Achievement.buildCatalog(
        validReportCount: 0,
        resolvedReportCount: 0,
      );
    }
    return list;
  }

  bool _isRefreshing = false;

  /// Refreshes achievements from the server and updates state immediately.
  Future<void> refresh() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      state = AsyncValue.data(Achievement.buildCatalog(
        validReportCount: 0,
        resolvedReportCount: 0,
      ));
      return;
    }

    if (_isRefreshing) return;
    _isRefreshing = true;

    try {
      final list = await _fetch(user.id);
      state = AsyncValue.data(list);
    } catch (e, st) {
      debugPrint('AchievementsNotifier.refresh failed: $e');
      state = AsyncValue.error(e, st);
    } finally {
      _isRefreshing = false;
    }
  }
}

/// Provider exposing the list of achievements for the authenticated student.
final achievementsProvider =
    AsyncNotifierProvider<AchievementsNotifier, List<Achievement>>(
  AchievementsNotifier.new,
);

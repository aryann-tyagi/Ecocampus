import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_providers.dart';
import '../domain/daily_challenge_model.dart';
import 'challenges_repository.dart';

/// State notifier managing daily challenges, progress updates, and account isolation.
class DailyChallengesNotifier extends AsyncNotifier<List<DailyChallenge>> {
  @override
  FutureOr<List<DailyChallenge>> build() {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return const [];
    }
    return _fetch(user.id);
  }

  Future<List<DailyChallenge>> _fetch(String expectedUserId) async {
    final repo = ref.read(challengesRepositoryProvider);
    final list = await repo.getDailyChallenges(userId: expectedUserId);

    // Prevent race conditions when user switches account in-flight
    if (ref.read(currentUserProvider)?.id != expectedUserId) {
      return const [];
    }
    return list;
  }

  bool _isRefreshing = false;

  /// Refreshes daily challenges from Supabase and updates state immediately.
  Future<void> refresh() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      state = const AsyncValue.data([]);
      return;
    }

    if (_isRefreshing) return;
    _isRefreshing = true;

    try {
      final list = await _fetch(user.id);
      state = AsyncValue.data(list);
    } catch (e, st) {
      debugPrint('DailyChallengesNotifier.refresh failed: $e');
      state = AsyncValue.error(e, st);
    } finally {
      _isRefreshing = false;
    }
  }
}

/// Provider exposing student daily challenges.
final dailyChallengesProvider =
    AsyncNotifierProvider<DailyChallengesNotifier, List<DailyChallenge>>(
  DailyChallengesNotifier.new,
);

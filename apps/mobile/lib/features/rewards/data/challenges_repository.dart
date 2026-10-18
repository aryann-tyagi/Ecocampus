import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/supabase_client_provider.dart';
import '../domain/daily_challenge_model.dart';

/// Contract for fetching student challenges.
abstract class ChallengesRepository {
  /// Fetches customizable and daily challenges for [userId] (or the current authenticated user).
  Future<List<DailyChallenge>> getDailyChallenges({String? userId});

  /// Flushes in-memory caches upon account switch or sign out.
  void clearCache();
}

/// Supabase implementation of [ChallengesRepository].
class SupabaseChallengesRepository implements ChallengesRepository {
  final SupabaseClient? _client;
  final Map<String, List<DailyChallenge>> _cachedByUser = {};

  SupabaseChallengesRepository([this._client]);

  @override
  void clearCache() {
    _cachedByUser.clear();
  }

  @override
  Future<List<DailyChallenge>> getDailyChallenges({String? userId}) async {
    final client = _client;
    final targetId = userId ?? client?.auth.currentUser?.id;

    if (targetId == null || client == null) {
      return DailyChallenge.buildCatalog();
    }

    try {
      // Primary: Call get_student_challenges to retrieve all active customizable challenges
      final response = await client.rpc('get_student_challenges');
      if (response is List && response.isNotEmpty) {
        final list = response
            .map((item) => DailyChallenge.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
        _cachedByUser[targetId] = list;
        return list;
      }

      // Fallback: Call get_my_daily_challenges if no custom challenges exist yet
      final fallbackResponse = await client.rpc('get_my_daily_challenges');
      if (fallbackResponse is List) {
        final list = fallbackResponse
            .map((item) => DailyChallenge.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
        list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        _cachedByUser[targetId] = list;
        return list;
      }
      return const [];
    } catch (e) {
      debugPrint('get_student_challenges error, attempting fallback: $e');
      try {
        final fallbackResponse = await client.rpc('get_my_daily_challenges');
        if (fallbackResponse is List) {
          final list = fallbackResponse
              .map((item) => DailyChallenge.fromJson(Map<String, dynamic>.from(item as Map)))
              .toList();
          list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
          _cachedByUser[targetId] = list;
          return list;
        }
      } catch (fallbackError) {
        debugPrint('Fallback get_my_daily_challenges also failed: $fallbackError');
      }
      rethrow;
    }
  }
}

/// Provider exposing the [ChallengesRepository].
final challengesRepositoryProvider = Provider<ChallengesRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseChallengesRepository(client);
});

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/supabase_client_provider.dart';
import '../domain/eco_points_model.dart';

/// Repository for EcoPoints operations against live Supabase RPCs.
///
/// Features:
/// 1. get_my_eco_stats(): Fetches authenticated user's points, EcoScore, level, and progress.
/// 2. get_campus_leaderboard(p_limit): Fetches campus leaderboard without exposing private emails or IDs.
/// 3. Server-side database triggers award points automatically on report insertion (+5)
///    and resolution (+15); client does not tamper or insert duplicate ledger events.
class EcoPointsRepository {
  final SupabaseClient? _client;

  EcoPointsRepository(this._client);

  /// Fetches the authenticated user's EcoPoints summary directly from live RPC.
  Future<EcoPointsSummary> getUserSummary({String? userId}) async {
    final client = _client;
    if (client == null) return EcoPointsSummary.zero();

    final targetUserId = userId ?? client.auth.currentUser?.id;
    if (targetUserId == null) return EcoPointsSummary.zero();

    try {
      final result = await client.rpc('get_my_eco_stats');
      if (result is List && result.isNotEmpty) {
        final row = (result.first as Map).cast<String, dynamic>();
        return EcoPointsSummary.fromJson(row);
      } else if (result is Map) {
        return EcoPointsSummary.fromJson(result.cast<String, dynamic>());
      }
    } catch (e) {
      debugPrint('get_my_eco_stats RPC error: $e');
    }

    // Default zero-activity summary for new users or when offline
    return EcoPointsSummary.zero();
  }

  /// Fetches the authenticated user's recent point events from eco_point_events table.
  Future<List<EcoPointEvent>> getUserEvents({String? userId, int limit = 50}) async {
    final client = _client;
    if (client == null) return const [];

    final targetUserId = userId ?? client.auth.currentUser?.id;
    if (targetUserId == null) return const [];

    try {
      final data = await client
          .from('eco_point_events')
          .select()
          .eq('user_id', targetUserId)
          .order('created_at', ascending: false)
          .limit(limit);

      if (data.isNotEmpty) {
        return (data as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(EcoPointEvent.fromJson)
            .toList();
      }
    } catch (e) {
      debugPrint('eco_point_events query error: $e');
    }

    return const [];
  }

  /// Fetches campus leaderboard from live RPC get_campus_leaderboard.
  Future<List<LeaderboardEntry>> getLeaderboard({
    int limit = 50,
    String? currentUserId,
  }) async {
    final client = _client;
    if (client == null) return const [];

    try {
      final result = await client.rpc('get_campus_leaderboard', params: {
        'p_limit': limit,
      });

      if (result is List) {
        return result
            .whereType<Map>()
            .map((m) => LeaderboardEntry.fromJson(m.cast<String, dynamic>()))
            .toList();
      }
    } catch (e) {
      debugPrint('get_campus_leaderboard RPC error: $e');
    }

    return const [];
  }

  /// Refresh helper after report submission or status update.
  /// Points are awarded by server-side database trigger.
  Future<int> awardPoints({
    required String userId,
    required String actionType,
    required int points,
    required String idempotencyKey,
    String? referenceId,
    String? description,
  }) async {
    return points;
  }
}

final ecoPointsRepositoryProvider = Provider<EcoPointsRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return EcoPointsRepository(client);
});

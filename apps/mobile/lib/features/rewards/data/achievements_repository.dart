import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/supabase_client_provider.dart';
import '../domain/achievement_model.dart';

/// Contract for fetching and persisting user achievements.
abstract class AchievementsRepository {
  /// Fetches achievement list for [userId] (or the current authenticated user).
  Future<List<Achievement>> getAchievements({String? userId});

  /// Flushes in-memory caches upon account switch or sign out.
  void clearCache();
}

/// Supabase implementation of [AchievementsRepository].
class SupabaseAchievementsRepository implements AchievementsRepository {
  final SupabaseClient? _client;
  final Map<String, List<Achievement>> _cachedByUser = {};

  SupabaseAchievementsRepository([this._client]);

  @override
  void clearCache() {
    _cachedByUser.clear();
  }

  @override
  Future<List<Achievement>> getAchievements({String? userId}) async {
    final client = _client;
    final targetId = userId ?? client?.auth.currentUser?.id;

    if (targetId == null || client == null) {
      return Achievement.buildCatalog(
        validReportCount: 0,
        resolvedReportCount: 0,
      );
    }

    // 1. Primary path: Call the secure server-side RPC get_my_achievements
    try {
      final response = await client.rpc('get_my_achievements');
      if (response is List) {
        final list = response
            .map((item) => Achievement.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
        list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        if (list.isNotEmpty) {
          _cachedByUser[targetId] = list;
          return list;
        }
      }
    } catch (e) {
      debugPrint('get_my_achievements RPC call notice: $e');
      // Graceful fallback to querying actual database tables directly
    }

    // 2. Direct table fallback: query actual user_achievements & genuine reports
    try {
      // Fetch persisted unlock records
      final unlockRows = await client
          .from('user_achievements')
          .select('achievement_id, unlocked_at')
          .eq('user_id', targetId);

      final unlockMap = <String, DateTime>{};
      for (final row in (unlockRows as List)) {
        final achId = row['achievement_id'] as String?;
        final unlockedAtStr = row['unlocked_at'] as String?;
        if (achId != null && unlockedAtStr != null) {
          final dt = DateTime.tryParse(unlockedAtStr);
          if (dt != null) unlockMap[achId] = dt;
        }
      }

      // Fetch authentic persisted reports for this user
      final reportRows = await client
          .from('reports')
          .select('id, status')
          .eq('reporter_id', targetId);

      int validCount = 0;
      int resolvedCount = 0;

      for (final r in (reportRows as List)) {
        final status = (r['status'] as String? ?? '').toUpperCase();
        if (status == 'REJECTED' || status == 'DUPLICATE') continue;
        validCount++;
        if (status == 'RESOLVED') {
          resolvedCount++;
        }
      }

      final catalog = Achievement.buildCatalog(
        validReportCount: validCount,
        resolvedReportCount: resolvedCount,
        unlocks: unlockMap,
      );

      _cachedByUser[targetId] = catalog;
      return catalog;
    } catch (e) {
      debugPrint('Supabase direct query fallback notice: $e');
    }

    // Return cached if present, otherwise clean zero catalog
    return _cachedByUser[targetId] ??
        Achievement.buildCatalog(
          validReportCount: 0,
          resolvedReportCount: 0,
        );
  }
}

/// Provider exposing the [AchievementsRepository].
final achievementsRepositoryProvider = Provider<AchievementsRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseAchievementsRepository(client);
});

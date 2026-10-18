import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/supabase_client_provider.dart';
import '../domain/campus_building_summary_model.dart';

/// Contract for fetching live campus building report summaries.
abstract class CampusMapRepository {
  /// Calls the server-side RPC `get_campus_building_summary` to get genuine building report metrics.
  Future<List<CampusBuildingSummary>> getCampusBuildingSummaries();
}

/// Supabase implementation calling the server-side RPC `get_campus_building_summary`.
class SupabaseCampusMapRepository implements CampusMapRepository {
  final SupabaseClient? _client;

  SupabaseCampusMapRepository([this._client]);

  @override
  Future<List<CampusBuildingSummary>> getCampusBuildingSummaries() async {
    final client = _client;
    if (client == null) {
      return const [];
    }

    try {
      final response = await client.rpc('get_campus_building_summary');
      if (response is List) {
        final list = response
            .map((item) => CampusBuildingSummary.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ))
            .toList();
        list.sort((a, b) => a.buildingName.compareTo(b.buildingName));
        return list;
      }
      return const [];
    } catch (e) {
      debugPrint('get_campus_building_summary RPC call failed: $e');
      rethrow;
    }
  }
}

/// Provider exposing the [CampusMapRepository].
final campusMapRepositoryProvider = Provider<CampusMapRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseCampusMapRepository(client);
});

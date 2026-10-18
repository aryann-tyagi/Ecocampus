import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/supabase_client_provider.dart';
import '../domain/notice_model.dart';

abstract class NoticesRepository {
  Future<List<CampusNoticeModel>> getActiveNotices({String? buildingId});
}

class SupabaseNoticesRepository implements NoticesRepository {
  final SupabaseClient? _client;

  SupabaseNoticesRepository([this._client]);

  @override
  Future<List<CampusNoticeModel>> getActiveNotices({String? buildingId}) async {
    final client = _client;
    if (client == null) return const [];

    try {
      final response = await client.rpc(
        'get_active_campus_notices',
        params: {
          if (buildingId != null) 'p_building_id': buildingId,
        },
      );

      if (response is List) {
        return response
            .map((item) => CampusNoticeModel.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      }
      return const [];
    } catch (e) {
      debugPrint('Error fetching active campus notices: $e');
      rethrow;
    }
  }
}

final noticesRepositoryProvider = Provider<NoticesRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseNoticesRepository(client);
});

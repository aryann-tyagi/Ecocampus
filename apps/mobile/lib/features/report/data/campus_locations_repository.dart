import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/supabase_client_provider.dart';
import '../domain/campus_location_models.dart';

/// Repository for retrieving campus location hierarchy from Supabase.
class CampusLocationsRepository {
  final SupabaseClient? _client;

  CampusLocationsRepository(this._client);

  /// Fetches all active buildings ordered by name.
  Future<List<CampusBuilding>> getActiveBuildings() async {
    final client = _client;
    if (client == null) return const [];
    try {
      final data = await client
          .from('buildings')
          .select()
          .eq('active', true)
          .order('name');

      return (data as List<dynamic>)
          .map((b) => CampusBuilding.fromJson(b as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Re-throw so caller/provider can report or retry
      rethrow;
    }
  }

  /// Fetches active floors for the given [buildingId] ordered by sort_order.
  Future<List<CampusFloor>> getFloorsForBuilding(String buildingId) async {
    final client = _client;
    if (client == null || buildingId.isEmpty) return const [];
    try {
      final data = await client
          .from('floors')
          .select()
          .eq('building_id', buildingId)
          .eq('active', true)
          .order('sort_order');

      return (data as List<dynamic>)
          .map((f) => CampusFloor.fromJson(f as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Fetches active areas for the given [floorId] ordered by name.
  Future<List<CampusArea>> getAreasForFloor(String floorId) async {
    final client = _client;
    if (client == null || floorId.isEmpty) return const [];
    try {
      final data = await client
          .from('areas')
          .select()
          .eq('floor_id', floorId)
          .eq('active', true)
          .order('name');

      return (data as List<dynamic>)
          .map((a) => CampusArea.fromJson(a as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }
}

final campusLocationsRepositoryProvider = Provider<CampusLocationsRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return CampusLocationsRepository(client);
});

/// FutureProvider providing active buildings.
final campusBuildingsProvider = FutureProvider<List<CampusBuilding>>((ref) async {
  final repo = ref.watch(campusLocationsRepositoryProvider);
  return repo.getActiveBuildings();
});

/// FutureProvider family providing floors for a selected building.
final buildingFloorsProvider =
    FutureProvider.family<List<CampusFloor>, String>((ref, buildingId) async {
  if (buildingId.isEmpty) return const [];
  final repo = ref.watch(campusLocationsRepositoryProvider);
  return repo.getFloorsForBuilding(buildingId);
});

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/campus_building_summary_model.dart';
import 'campus_map_repository.dart';

/// Meaningful filters for building selection based on genuine data.
enum CampusMapFilter {
  all('All'),
  hasActive('With Issues'),
  noIssues('No Issues');

  final String label;
  const CampusMapFilter(this.label);
}

/// Async notifier managing live building summaries from Supabase.
class BuildingSummariesNotifier
    extends AsyncNotifier<List<CampusBuildingSummary>> {
  @override
  FutureOr<List<CampusBuildingSummary>> build() {
    return _fetch();
  }

  Future<List<CampusBuildingSummary>> _fetch() async {
    final repo = ref.read(campusMapRepositoryProvider);
    return repo.getCampusBuildingSummaries();
  }

  bool _isRefreshing = false;

  /// Refreshes the building summaries from the live Supabase database.
  Future<void> refresh() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      final repo = ref.read(campusMapRepositoryProvider);
      final list = await repo.getCampusBuildingSummaries();
      state = AsyncValue.data(list);
    } catch (e, st) {
      debugPrint('BuildingSummariesNotifier.refresh failed: $e');
      state = AsyncValue.error(e, st);
    } finally {
      _isRefreshing = false;
    }
  }
}

/// Provider exposing the list of building summaries across campus.
final buildingSummariesProvider = AsyncNotifierProvider<
    BuildingSummariesNotifier, List<CampusBuildingSummary>>(
  BuildingSummariesNotifier.new,
);

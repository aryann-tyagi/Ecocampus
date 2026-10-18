import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/notice_model.dart';
import 'notices_repository.dart';

class ActiveNoticesNotifier extends AsyncNotifier<List<CampusNoticeModel>> {
  @override
  FutureOr<List<CampusNoticeModel>> build() {
    return _fetch();
  }

  Future<List<CampusNoticeModel>> _fetch() async {
    final repo = ref.read(noticesRepositoryProvider);
    return repo.getActiveNotices();
  }

  Future<void> refresh() async {
    try {
      final list = await _fetch();
      state = AsyncValue.data(list);
    } catch (e, st) {
      debugPrint('Failed to refresh campus notices: $e');
      state = AsyncValue.error(e, st);
    }
  }
}

final activeNoticesProvider =
    AsyncNotifierProvider<ActiveNoticesNotifier, List<CampusNoticeModel>>(
  ActiveNoticesNotifier.new,
);

/// Derives the single most urgent or pinned notice to highlight on the home screen
final latestHomeNoticeProvider = Provider<CampusNoticeModel?>((ref) {
  final noticesAsync = ref.watch(activeNoticesProvider);
  return noticesAsync.maybeWhen(
    data: (notices) {
      if (notices.isEmpty) return null;
      // 1. First priority: Pinned urgent notices
      final pinnedUrgent = notices.where((n) => n.isPinned && n.isUrgent);
      if (pinnedUrgent.isNotEmpty) return pinnedUrgent.first;

      // 2. Second: Any urgent notice
      final anyUrgent = notices.where((n) => n.isUrgent);
      if (anyUrgent.isNotEmpty) return anyUrgent.first;

      // 3. Third: Any pinned notice
      final anyPinned = notices.where((n) => n.isPinned);
      if (anyPinned.isNotEmpty) return anyPinned.first;

      // 4. Fallback: Most recent notice
      return notices.first;
    },
    orElse: () => null,
  );
});

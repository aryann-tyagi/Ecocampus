import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ecocampus_mobile/core/network/supabase_client_provider.dart';
import 'package:ecocampus_mobile/features/auth/data/auth_providers.dart';
import 'package:ecocampus_mobile/features/notifications/domain/notification_model.dart';
import 'package:ecocampus_mobile/features/notifications/data/notifications_repository.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return NotificationsRepository(client);
});

/// Async notifier for unread notification count badge.
class UnreadNotificationCountNotifier extends AsyncNotifier<int> {
  @override
  FutureOr<int> build() {
    final user = ref.watch(currentUserProvider);
    if (user == null) return 0;
    return _fetch();
  }

  Future<int> _fetch() async {
    final repo = ref.read(notificationsRepositoryProvider);
    try {
      return await repo.getUnreadCount();
    } catch (e) {
      debugPrint('UnreadNotificationCountNotifier._fetch error: $e');
      return 0;
    }
  }

  Future<void> refresh() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      state = const AsyncValue.data(0);
      return;
    }
    try {
      final count = await _fetch();
      state = AsyncValue.data(count);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void decrement() {
    final current = state.value ?? 0;
    if (current > 0) {
      state = AsyncValue.data(current - 1);
    }
  }

  void reset() {
    state = const AsyncValue.data(0);
  }

  void setCount(int count) {
    state = AsyncValue.data(count < 0 ? 0 : count);
  }
}

final unreadNotificationCountProvider =
    AsyncNotifierProvider<UnreadNotificationCountNotifier, int>(() {
  return UnreadNotificationCountNotifier();
});

/// Async notifier managing the list of in-app notifications.
class NotificationsListNotifier extends AsyncNotifier<List<NotificationModel>> {
  @override
  FutureOr<List<NotificationModel>> build() {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const [];
    return _fetch();
  }

  Future<List<NotificationModel>> _fetch() async {
    final repo = ref.read(notificationsRepositoryProvider);
    final list = await repo.getNotifications();
    // Update unread count provider to match
    final unreadCount = list.where((n) => !n.isRead).length;
    ref.read(unreadNotificationCountProvider.notifier).setCount(unreadCount);
    return list;
  }

  Future<void> refresh() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      state = const AsyncValue.data([]);
      return;
    }

    try {
      final list = await _fetch();
      state = AsyncValue.data(list);
    } catch (e, st) {
      debugPrint('NotificationsListNotifier.refresh failed: $e');
      state = AsyncValue.error(e, st);
    }
  }

  /// Optimistically marks a single notification as read and persists in Supabase.
  Future<void> markAsRead(String notificationId) async {
    final currentList = state.value;
    if (currentList == null) return;

    final targetIndex = currentList.indexWhere((n) => n.id == notificationId);
    if (targetIndex == -1) return;

    final target = currentList[targetIndex];
    if (target.isRead) return; // Already read

    // Optimistic update
    final updatedList = List<NotificationModel>.from(currentList);
    updatedList[targetIndex] = target.copyWith(
      isRead: true,
      readAt: DateTime.now(),
    );
    state = AsyncValue.data(updatedList);
    ref.read(unreadNotificationCountProvider.notifier).decrement();

    // Persist
    final repo = ref.read(notificationsRepositoryProvider);
    final success = await repo.markAsRead(notificationId);
    if (!success) {
      // Revert if failed
      state = AsyncValue.data(currentList);
      ref.read(unreadNotificationCountProvider.notifier).refresh();
    }
  }

  /// Optimistically marks all notifications as read and persists in Supabase.
  Future<void> markAllAsRead() async {
    final currentList = state.value;
    if (currentList == null || currentList.isEmpty) return;

    final hasUnread = currentList.any((n) => !n.isRead);
    if (!hasUnread) return;

    // Optimistic update
    final now = DateTime.now();
    final updatedList = currentList.map((n) {
      if (n.isRead) return n;
      return n.copyWith(isRead: true, readAt: now);
    }).toList();

    state = AsyncValue.data(updatedList);
    ref.read(unreadNotificationCountProvider.notifier).reset();

    // Persist
    final repo = ref.read(notificationsRepositoryProvider);
    try {
      await repo.markAllAsRead();
    } catch (e) {
      debugPrint('markAllAsRead failed on server: $e');
      state = AsyncValue.data(currentList);
      ref.read(unreadNotificationCountProvider.notifier).refresh();
    }
  }
}

final notificationsListProvider =
    AsyncNotifierProvider<NotificationsListNotifier, List<NotificationModel>>(() {
  return NotificationsListNotifier();
});

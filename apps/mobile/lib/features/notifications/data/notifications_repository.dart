import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/notification_model.dart';

class NotificationsRepository {
  final SupabaseClient? _client;

  NotificationsRepository(this._client);

  /// Fetches in-app notifications for the authenticated user, newest first.
  Future<List<NotificationModel>> getNotifications({int limit = 50}) async {
    final client = _client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) return const [];

    try {
      final List<dynamic> data = await client
          .from('notifications')
          .select('*')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(limit);

      return data
          .whereType<Map>()
          .map((item) => NotificationModel.fromJson(item.cast<String, dynamic>()))
          .toList();
    } catch (e) {
      debugPrint('Failed to fetch notifications: $e');
      rethrow;
    }
  }

  /// Retrieves the unread notification count from the server.
  Future<int> getUnreadCount() async {
    final client = _client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) return 0;

    try {
      final result = await client.rpc('get_unread_notification_count');
      if (result is num) {
        return result.toInt();
      }
      return 0;
    } catch (e) {
      debugPrint('Failed to get unread notification count via RPC: $e');
      // Fallback: direct table count query protected by RLS
      try {
        final count = await client
            .from('notifications')
            .select('id')
            .eq('user_id', user.id)
            .eq('is_read', false)
            .count(CountOption.exact);
        return count.count;
      } catch (inner) {
        debugPrint('Fallback notification count failed: $inner');
        return 0;
      }
    }
  }

  /// Marks a single notification as read.
  Future<bool> markAsRead(String notificationId) async {
    final client = _client;
    final user = client?.auth.currentUser;
    if (client == null || user == null || notificationId.isEmpty) return false;

    try {
      final res = await client.rpc('mark_notification_as_read', params: {
        'p_notification_id': notificationId,
      });
      return res == true;
    } catch (e) {
      debugPrint('mark_notification_as_read RPC failed, falling back to update: $e');
      try {
        await client
            .from('notifications')
            .update({
              'is_read': true,
              'read_at': DateTime.now().toIso8601String(),
            })
            .eq('id', notificationId)
            .eq('user_id', user.id);
        return true;
      } catch (inner) {
        debugPrint('Direct notification update failed: $inner');
        return false;
      }
    }
  }

  /// Marks all unread notifications as read for the authenticated user.
  Future<int> markAllAsRead() async {
    final client = _client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) return 0;

    try {
      final res = await client.rpc('mark_all_notifications_as_read');
      if (res is num) {
        return res.toInt();
      }
      return 0;
    } catch (e) {
      debugPrint('mark_all_notifications_as_read RPC failed, falling back to update: $e');
      try {
        final List<dynamic> res = await client
            .from('notifications')
            .update({
              'is_read': true,
              'read_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', user.id)
            .eq('is_read', false)
            .select('id');
        return res.length;
      } catch (inner) {
        debugPrint('Direct mark all update failed: $inner');
        return 0;
      }
    }
  }
}

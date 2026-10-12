import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/supabase_client_provider.dart';
import '../domain/user_profile.dart';

/// Repository for reading and updating student profile records in `public.profiles`.
class ProfileRepository {
  final SupabaseClient? _client;

  ProfileRepository(this._client);

  /// Fetches the profile for the given [userId].
  /// Returns `null` if no profile exists or if the client is uninitialized.
  Future<UserProfile?> getProfile(String userId) async {
    final client = _client;
    if (client == null) return null;
    try {
      final data = await client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (data == null) return null;
      return UserProfile.fromJson(data);
    } catch (e) {
      rethrow;
    }
  }

  /// Updates profile fields (`display_name`, `companion_name`, `avatar_url`) for [userId].
  Future<void> updateProfile({
    required String userId,
    String? displayName,
    String? companionName,
    String? avatarUrl,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase client is not initialized.');
    }

    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (displayName != null) {
      updates['display_name'] = displayName.trim();
    }
    if (companionName != null) {
      updates['companion_name'] = companionName.trim();
    }
    if (avatarUrl != null) {
      updates['avatar_url'] = avatarUrl;
    }

    if (updates.length == 1) {
      // Only updated_at provided, nothing to update
      return;
    }

    await client
        .from('profiles')
        .update(updates)
        .eq('id', userId);
  }
}

/// Riverpod provider for [ProfileRepository].
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ProfileRepository(client);
});

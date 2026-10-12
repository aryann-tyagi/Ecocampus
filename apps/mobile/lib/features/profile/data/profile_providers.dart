import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_providers.dart';
import '../../home/data/companion_provider.dart';
import '../domain/user_profile.dart';
import 'profile_repository.dart';

/// Notifier that manages loading and updating the current user's [UserProfile].
class UserProfileNotifier extends AsyncNotifier<UserProfile?> {
  @override
  FutureOr<UserProfile?> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return null;
    }

    final repo = ref.watch(profileRepositoryProvider);
    final profile = await repo.getProfile(user.id);

    // If a companion name exists in Supabase, sync it to companionNameProvider and local disk
    if (profile?.companionName != null && profile!.companionName!.isNotEmpty) {
      ref.read(companionNameProvider.notifier).syncFromRemote(profile.companionName!);
    }

    return profile;
  }

  /// Updates the user's display name in Supabase profiles.
  Future<void> updateDisplayName(String displayName) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      throw StateError('Cannot update profile: user is not signed in.');
    }

    final repo = ref.read(profileRepositoryProvider);
    await repo.updateProfile(
      userId: user.id,
      displayName: displayName,
    );
    ref.invalidateSelf();
  }

  /// Updates the companion name in Supabase profiles.
  Future<void> updateCompanionName(String companionName) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      throw StateError('Cannot update companion: user is not signed in.');
    }

    final repo = ref.read(profileRepositoryProvider);
    await repo.updateProfile(
      userId: user.id,
      companionName: companionName,
    );
    ref.invalidateSelf();
  }
}

/// Provider exposing the current student's [UserProfile].
final userProfileProvider =
    AsyncNotifierProvider.autoDispose<UserProfileNotifier, UserProfile?>(
  UserProfileNotifier.new,
);

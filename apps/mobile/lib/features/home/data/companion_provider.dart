import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/data/auth_providers.dart';
import '../../profile/data/profile_repository.dart';

/// Key used for persisting the companion name in SharedPreferences.
const _kCompanionNameKey = 'eco_companion_name';

/// Default companion name used when no persisted value exists.
const kDefaultCompanionName = 'Sprig';

/// Maximum character length for the companion name.
const kCompanionNameMaxLength = 20;

/// Provides the SharedPreferences instance.
/// Defaults to null if not overridden, preventing UnimplementedError crashes.
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null);

/// Manages the companion name with local persistence via SharedPreferences
/// and remote synchronization to Supabase `public.profiles`.
class CompanionNameNotifier extends Notifier<String> {
  String? _lastError;

  /// Returns the error message from the most recent failed [setName] attempt, if any.
  String? get lastError => _lastError;

  @override
  String build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs?.getString(_kCompanionNameKey) ?? kDefaultCompanionName;
  }

  /// Synchronizes companion name from remote Supabase profile.
  void syncFromRemote(String remoteName) {
    final trimmed = remoteName.trim();
    if (trimmed.isNotEmpty && trimmed.length <= kCompanionNameMaxLength) {
      final prefs = ref.read(sharedPreferencesProvider);
      if (prefs != null) {
        prefs.setString(_kCompanionNameKey, trimmed);
      }
      state = trimmed;
    }
  }

  /// Validates and persists a new companion name.
  ///
  /// Updates local storage immediately. If the student is authenticated with Supabase,
  /// saves the updated name to their remote profile row.
  /// Returns `true` if saved successfully, `false` on validation or remote persistence failure.
  Future<bool> setName(String rawName) async {
    _lastError = null;
    final trimmed = rawName.trim();
    if (trimmed.isEmpty || trimmed.length > kCompanionNameMaxLength) {
      _lastError = 'Name must be between 1 and $kCompanionNameMaxLength characters.';
      return false;
    }

    // If signed into Supabase, persist to remote profile first
    final user = ref.read(currentUserProvider);
    if (user != null) {
      try {
        final profileRepo = ref.read(profileRepositoryProvider);
        await profileRepo.updateProfile(
          userId: user.id,
          companionName: trimmed,
        );
      } catch (e) {
        debugPrint('CompanionNameNotifier.setName remote update failed: $e');
        if (e is PostgrestException) {
          if (e.code == '42501' || e.message.toLowerCase().contains('permission denied')) {
            _lastError =
                'Permission denied in database. Please run the Supabase migration to grant UPDATE on public.profiles.';
          } else {
            _lastError = e.message;
          }
        } else {
          _lastError = e.toString();
        }
        return false;
      }
    }

    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs != null) {
      await prefs.setString(_kCompanionNameKey, trimmed);
    }
    state = trimmed;
    return true;
  }
}

final companionNameProvider =
    NotifierProvider<CompanionNameNotifier, String>(CompanionNameNotifier.new);

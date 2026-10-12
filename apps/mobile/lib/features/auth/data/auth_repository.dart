import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/supabase_client_provider.dart';

/// Repository managing Supabase Authentication interactions.
class AuthRepository {
  final SupabaseClient? _client;

  AuthRepository(this._client);

  /// Returns the currently signed-in user, or `null`.
  User? get currentUser => _client?.auth.currentUser;

  /// Returns the current active session, or `null`.
  Session? get currentSession => _client?.auth.currentSession;

  /// Stream of Supabase authentication state changes.
  Stream<AuthState> get authStateChanges {
    final client = _client;
    if (client == null) {
      return Stream.value(const AuthState(AuthChangeEvent.signedOut, null));
    }
    return client.auth.onAuthStateChange;
  }

  /// Signs in a student with email and password.
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase client is not initialized.');
    }
    return await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Registers a student with email, password, and display name.
  /// Passes `display_name` in metadata so the database trigger populates `public.profiles`.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase client is not initialized.');
    }
    final trimmedName = displayName.trim();
    return await client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'display_name': trimmedName,
        'full_name': trimmedName,
        'name': trimmedName,
      },
    );
  }

  /// Terminates the current session and signs the user out.
  Future<void> signOut() async {
    final client = _client;
    if (client == null) return;
    await client.auth.signOut();
  }

  /// Sends a password recovery email.
  Future<void> resetPasswordForEmail(String email) async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase client is not initialized.');
    }
    await client.auth.resetPasswordForEmail(email.trim());
  }
}

/// Riverpod provider for [AuthRepository].
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AuthRepository(client);
});

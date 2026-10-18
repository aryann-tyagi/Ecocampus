import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_repository.dart';
import '../../home/data/companion_provider.dart';
import '../../profile/data/profile_providers.dart';
import '../../report/data/reports_provider.dart';
import '../../report/data/reports_repository.dart';
import '../../rewards/data/eco_points_provider.dart';
import '../../rewards/data/achievements_repository.dart';
import '../../rewards/data/achievements_provider.dart';
import '../../rewards/data/challenges_repository.dart';
import '../../rewards/data/challenges_provider.dart';
import '../../../core/notifications/push_notification_service.dart';

/// Stream of auth changes emitted by Supabase.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges;
});

/// Provides the currently authenticated [User], or `null` if signed out.
/// Can be overridden in tests via `currentUserProvider.overrideWithValue(...)`.
final currentUserProvider = Provider<User?>((ref) {
  final authAsync = ref.watch(authStateChangesProvider);
  final repo = ref.watch(authRepositoryProvider);
  return authAsync.when(
    data: (state) => state.session?.user ?? repo.currentUser,
    loading: () => repo.currentUser,
    error: (_, __) => null,
  );
});

/// Represents the high-level outcome of an authentication request.
class AuthResult {
  final bool isSuccess;
  final bool requiresEmailConfirmation;
  final String? errorMessage;

  const AuthResult.success({this.requiresEmailConfirmation = false})
      : isSuccess = true,
        errorMessage = null;

  const AuthResult.failure(this.errorMessage)
      : isSuccess = false,
        requiresEmailConfirmation = false;
}

/// Controller managing auth operations (login, registration, reset, logout).
/// Non-autoDispose Notifier to prevent lifecycle disposal during async network requests.
class AuthController extends Notifier<void> {
  @override
  void build() {}

  /// Attempts to sign in with email and password.
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final repo = ref.read(authRepositoryProvider);
      final res = await repo
          .signInWithPassword(
            email: email,
            password: password,
          )
          .timeout(const Duration(seconds: 15));

      if (res.user != null) {
        ref.read(reportsRepositoryProvider).clearCache();
        ref.read(achievementsRepositoryProvider).clearCache();
        ref.read(challengesRepositoryProvider).clearCache();
        ref.read(companionNameProvider.notifier).resetToDefault();
        ref.invalidate(reportsProvider);
        ref.invalidate(myReportsProvider);
        ref.invalidate(campusReportsProvider);
        ref.invalidate(ecoPointsProvider);
        ref.invalidate(leaderboardProvider);
        ref.invalidate(ecoPointEventsProvider);
        ref.invalidate(userProfileProvider);
        ref.invalidate(achievementsProvider);
        ref.invalidate(dailyChallengesProvider);
        return const AuthResult.success();
      } else {
        return const AuthResult.failure('Authentication failed. Please try again.');
      }
    } on TimeoutException {
      return const AuthResult.failure(
        'Connection timed out. Please check your internet and try again.',
      );
    } on AuthException catch (e) {
      return AuthResult.failure(_mapAuthException(e));
    } catch (e) {
      return AuthResult.failure(
        'Unable to connect. Please check your network and try again.',
      );
    }
  }

  /// Attempts to register a new student account.
  Future<AuthResult> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final repo = ref.read(authRepositoryProvider);
      final res = await repo
          .signUp(
            email: email,
            password: password,
            displayName: displayName,
          )
          .timeout(const Duration(seconds: 15));

      // If email confirmation is required, session will be null while user is created.
      final needsConfirmation = res.session == null && res.user != null;
      return AuthResult.success(
        requiresEmailConfirmation: needsConfirmation,
      );
    } on TimeoutException {
      return const AuthResult.failure(
        'Registration timed out. Please check your internet connection.',
      );
    } on AuthException catch (e) {
      return AuthResult.failure(_mapAuthException(e));
    } catch (e) {
      return AuthResult.failure(
        'Unable to connect. Please check your network and try again.',
      );
    }
  }

  /// Sends a password reset recovery link.
  Future<AuthResult> resetPassword(String email) async {
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo
          .resetPasswordForEmail(email)
          .timeout(const Duration(seconds: 15));
      return const AuthResult.success();
    } on TimeoutException {
      return const AuthResult.failure('Request timed out. Please check your connection.');
    } on AuthException catch (e) {
      return AuthResult.failure(_mapAuthException(e));
    } catch (_) {
      return const AuthResult.failure(
        'Unable to send reset instructions. Please check your network.',
      );
    }
  }

  /// Signs the user out of their session and clears all user-scoped state.
  Future<void> signOut() async {
    try {
      // Disassociate FCM device token from this user before clearing session
      try {
        await PushNotificationService.instance.unregisterCurrentDeviceToken();
      } catch (_) {}

      final repo = ref.read(authRepositoryProvider);
      await repo.signOut().timeout(const Duration(seconds: 10));
    } catch (_) {
      // Ignore signOut network errors to always allow offline logout
    } finally {
      // Clear in-memory caches and invalidate user-scoped providers
      ref.read(reportsRepositoryProvider).clearCache();
      ref.read(achievementsRepositoryProvider).clearCache();
      ref.read(challengesRepositoryProvider).clearCache();
      ref.read(companionNameProvider.notifier).resetToDefault();
      ref.invalidate(reportsProvider);
      ref.invalidate(myReportsProvider);
      ref.invalidate(campusReportsProvider);
      ref.invalidate(ecoPointsProvider);
      ref.invalidate(leaderboardProvider);
      ref.invalidate(ecoPointEventsProvider);
      ref.invalidate(userProfileProvider);
      ref.invalidate(achievementsProvider);
      ref.invalidate(dailyChallengesProvider);
    }
  }

  String _mapAuthException(AuthException e) {
    final msg = e.message.toLowerCase();
    final statusCode = e.statusCode;

    if (msg.contains('rate limit') || statusCode == '429' || msg.contains('over_email_send_rate_limit')) {
      return 'Email rate limit exceeded by server. Please wait a few minutes before trying again.';
    }
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid_credentials')) {
      return 'Invalid email or password. Please try again.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Please verify your email address before signing in. Check your inbox for the verification link.';
    }
    if (msg.contains('user already registered') ||
        msg.contains('already in use') ||
        msg.contains('already exists')) {
      return 'An account with this email already exists. Please sign in instead.';
    }
    if (msg.contains('password should be at least')) {
      return 'Password must be at least 6 characters.';
    }
    if (msg.contains('email_address_invalid') ||
        (msg.contains('invalid') && msg.contains('email'))) {
      return 'Please enter a valid, active email address.';
    }
    if (msg.contains('empty response with status code 400')) {
      return 'Registration request was rejected. Please check your email format and password.';
    }
    return e.message;
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, void>(AuthController.new);

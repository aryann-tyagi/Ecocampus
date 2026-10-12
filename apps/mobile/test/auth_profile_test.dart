import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ecocampus_mobile/core/theme/app_theme.dart';
import 'package:ecocampus_mobile/features/auth/data/auth_providers.dart';
import 'package:ecocampus_mobile/features/auth/presentation/auth_gate.dart';
import 'package:ecocampus_mobile/features/auth/presentation/login_screen.dart';
import 'package:ecocampus_mobile/features/auth/presentation/register_screen.dart';
import 'package:ecocampus_mobile/features/profile/data/profile_repository.dart';
import 'package:ecocampus_mobile/features/profile/domain/user_profile.dart';
import 'package:ecocampus_mobile/features/home/data/companion_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Fake in-memory ProfileRepository for unit tests
class FakeProfileRepository extends ProfileRepository {
  UserProfile? storedProfile;
  bool shouldThrow = false;

  FakeProfileRepository([this.storedProfile]) : super(null);

  @override
  Future<UserProfile?> getProfile(String userId) async {
    if (shouldThrow) throw Exception('Network timeout');
    return storedProfile;
  }

  @override
  Future<void> updateProfile({
    required String userId,
    String? displayName,
    String? companionName,
    String? avatarUrl,
  }) async {
    if (shouldThrow) throw Exception('Failed to update remote profile');
    storedProfile = UserProfile(
      id: userId,
      displayName: displayName ?? storedProfile?.displayName,
      companionName: companionName ?? storedProfile?.companionName,
      avatarUrl: avatarUrl ?? storedProfile?.avatarUrl,
      updatedAt: DateTime.now(),
    );
  }
}

void main() {
  group('UserProfile Model Tests', () {
    test('Serializes and deserializes from JSON correctly', () {
      final json = {
        'id': 'user-123',
        'display_name': 'Taylor Swift',
        'companion_name': 'Fern',
        'avatar_url': 'https://example.com/avatar.png',
        'created_at': '2026-03-01T12:00:00.000Z',
        'updated_at': '2026-03-02T15:30:00.000Z',
      };

      final profile = UserProfile.fromJson(json);
      expect(profile.id, 'user-123');
      expect(profile.displayName, 'Taylor Swift');
      expect(profile.companionName, 'Fern');
      expect(profile.avatarUrl, 'https://example.com/avatar.png');
      expect(profile.createdAt, isNotNull);
      expect(profile.updatedAt, isNotNull);

      final backToJson = profile.toJson();
      expect(backToJson['id'], 'user-123');
      expect(backToJson['display_name'], 'Taylor Swift');
      expect(backToJson['companion_name'], 'Fern');
    });

    test('copyWith updates fields immutably', () {
      final profile = const UserProfile(
        id: 'u1',
        displayName: 'Original Name',
        companionName: 'Sprig',
      );

      final updated = profile.copyWith(
        displayName: 'Updated Name',
        companionName: 'Leafy',
      );

      expect(updated.id, 'u1');
      expect(updated.displayName, 'Updated Name');
      expect(updated.companionName, 'Leafy');
      expect(profile.displayName, 'Original Name');
    });
  });

  group('Profile & Companion Synchronization Tests', () {
    test('Syncs companion name from remote Supabase profile', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(companionNameProvider), kDefaultCompanionName);

      container.read(companionNameProvider.notifier).syncFromRemote('Bramble');
      expect(container.read(companionNameProvider), 'Bramble');
    });

    test('setName handles remote failure gracefully and returns false without claiming success', () async {
      final fakeRepo = FakeProfileRepository();
      fakeRepo.shouldThrow = true; // Simulates network or RLS permission error

      final mockUser = const User(
        id: 'user-xyz',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-01-01',
      );

      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWithValue(mockUser),
          profileRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(companionNameProvider.notifier)
          .setName('FailingName');

      // Must be false because remote persistence failed
      expect(result, isFalse);
      expect(container.read(companionNameProvider.notifier).lastError, isNotNull);
    });

    test('setName persists to fake profile repository when user is authenticated', () async {
      final fakeRepo = FakeProfileRepository(
        const UserProfile(id: 'user-xyz', companionName: 'Sprig'),
      );

      final mockUser = const User(
        id: 'user-xyz',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-01-01',
      );

      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWithValue(mockUser),
          profileRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(companionNameProvider.notifier)
          .setName('Mossy');

      expect(result, isTrue);
      expect(container.read(companionNameProvider), 'Mossy');
      expect(fakeRepo.storedProfile?.companionName, 'Mossy');
    });
  });

  group('LoginScreen Widget Tests', () {
    testWidgets('Validates email format and required password', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ProviderScope(child: LoginScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Attempt submit without filling fields
      await tester.tap(find.text('Sign In'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);

      // Enter invalid email format
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Student Email'),
        'notanemail',
      );
      await tester.tap(find.text('Sign In'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Enter a valid email address'), findsOneWidget);
    });

    testWidgets('Opens forgot password modal and displays reset action', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ProviderScope(child: LoginScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('Forgot Password?'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Reset Password'), findsOneWidget);
      expect(find.text('Send Reset Link'), findsOneWidget);
    });

    testWidgets('Tapping Register navigates to RegisterScreen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ProviderScope(child: LoginScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('Register'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Join EcoCampus'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
    });
  });

  group('RegisterScreen Widget Tests', () {
    testWidgets('Validates matching passwords and minimum password length', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ProviderScope(child: RegisterScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Fill valid name and email
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Full Name / Display Name'),
        'Jordan Smith',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Student Email'),
        'jordan@university.edu',
      );

      // Enter short password
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        '123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm Password'),
        '123456',
      );

      await tester.tap(find.text('Create Account'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Password must be at least 6 characters'), findsOneWidget);
      expect(find.text('Passwords do not match'), findsOneWidget);
    });
  });

  group('AuthGate Routing Tests', () {
    testWidgets('Renders LoginScreen when unauthenticated', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ProviderScope(
            overrides: [
              currentUserProvider.overrideWithValue(null),
            ],
            child: const AuthGate(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Sign in to your campus account'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
    });

    testWidgets('Renders MainNavigationShell when user is authenticated', (tester) async {
      const mockUser = User(
        id: 'test-student-id',
        appMetadata: {},
        userMetadata: {'display_name': 'Test Student'},
        aud: 'authenticated',
        createdAt: '2026-01-01',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ProviderScope(
            overrides: [
              currentUserProvider.overrideWithValue(mockUser),
            ],
            child: const AuthGate(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Should show student home screen elements
      expect(find.text('Report an issue'), findsOneWidget);
      expect(find.text('Nearby issues'), findsOneWidget);
    });
  });
}

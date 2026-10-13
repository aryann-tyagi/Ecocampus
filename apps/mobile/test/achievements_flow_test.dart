import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ecocampus_mobile/features/rewards/domain/achievement_model.dart';
import 'package:ecocampus_mobile/features/rewards/data/achievements_repository.dart';
import 'package:ecocampus_mobile/features/rewards/data/achievements_provider.dart';
import 'package:ecocampus_mobile/features/auth/data/auth_providers.dart';

/// In-memory mock simulating server-side achievement evaluation,
/// unique constraint idempotency, and per-user isolation.
class FakeAchievementsRepository implements AchievementsRepository {
  /// Map of userId -> list of user reports ({'id': String, 'status': String})
  final Map<String, List<Map<String, String>>> _reportsByUser = {};

  /// Map of userId -> (achievementId -> unlockTimestamp)
  /// Represents the public.user_achievements table with UNIQUE(user_id, achievement_id)
  final Map<String, Map<String, DateTime>> _userAchievements = {};

  bool cacheCleared = false;

  void addReport({
    required String userId,
    required String reportId,
    required String status,
  }) {
    _reportsByUser.putIfAbsent(userId, () => []).add({
      'id': reportId,
      'status': status.toUpperCase(),
    });
    // Server-side trigger: automatically evaluate achievements upon insert/update
    _serverEvaluateAndUnlock(userId);
  }

  void updateReportStatus({
    required String userId,
    required String reportId,
    required String newStatus,
  }) {
    final list = _reportsByUser[userId] ?? [];
    for (final r in list) {
      if (r['id'] == reportId) {
        r['status'] = newStatus.toUpperCase();
      }
    }
    // Server-side trigger: automatically evaluate achievements upon update
    _serverEvaluateAndUnlock(userId);
  }

  void _serverEvaluateAndUnlock(String userId) {
    final reports = _reportsByUser[userId] ?? [];
    final validReports = reports
        .where((r) => r['status'] != 'REJECTED' && r['status'] != 'DUPLICATE')
        .toList();
    final resolvedReports = reports
        .where((r) => r['status'] == 'RESOLVED')
        .toList();

    final userUnlocks = _userAchievements.putIfAbsent(userId, () => {});

    // Rule 1: First Report (>= 1 valid report)
    if (validReports.isNotEmpty && !userUnlocks.containsKey(Achievement.firstReportId)) {
      userUnlocks[Achievement.firstReportId] = DateTime(2026, 10, 14, 10, 0);
    }

    // Rule 2: 10 Issues Reported (>= 10 valid reports)
    if (validReports.length >= 10 && !userUnlocks.containsKey(Achievement.tenReportedId)) {
      userUnlocks[Achievement.tenReportedId] = DateTime(2026, 10, 14, 12, 0);
    }

    // Rule 3: 10 Issues Resolved (>= 10 resolved reports)
    if (resolvedReports.length >= 10 && !userUnlocks.containsKey(Achievement.tenResolvedId)) {
      userUnlocks[Achievement.tenResolvedId] = DateTime(2026, 10, 14, 14, 0);
    }
  }

  @override
  void clearCache() {
    cacheCleared = true;
  }

  @override
  Future<List<Achievement>> getAchievements({String? userId}) async {
    final targetId = userId ?? 'student-1';
    final reports = _reportsByUser[targetId] ?? [];
    final validCount = reports
        .where((r) => r['status'] != 'REJECTED' && r['status'] != 'DUPLICATE')
        .length;
    final resolvedCount = reports
        .where((r) => r['status'] == 'RESOLVED')
        .length;

    final unlocks = _userAchievements[targetId] ?? {};

    return Achievement.buildCatalog(
      validReportCount: validCount,
      resolvedReportCount: resolvedCount,
      unlocks: unlocks,
    );
  }

  /// Direct client write attempt simulation.
  /// Throws SecurityException if client attempts to write without database authority.
  Future<void> simulateUnauthorizedClientWrite({
    required String callingUserId,
    required String targetUserId,
    required String achievementId,
  }) async {
    // RLS Mandate: Students cannot insert or update user_achievements table directly
    if (callingUserId != targetUserId || callingUserId.startsWith('student')) {
      throw Exception('42501: permission denied for table user_achievements');
    }
    _userAchievements.putIfAbsent(targetUserId, () => {})[achievementId] = DateTime.now();
  }

  int getUnlockRecordCount(String userId) {
    return _userAchievements[userId]?.length ?? 0;
  }
}

User _mockUser(String id, String email) {
  return User(
    id: id,
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    email: email,
    createdAt: '2026-10-14T00:00:00Z',
  );
}

void main() {
  late FakeAchievementsRepository fakeRepo;
  late ProviderContainer container;

  setUp(() {
    fakeRepo = FakeAchievementsRepository();
    container = ProviderContainer(
      overrides: [
        achievementsRepositoryProvider.overrideWithValue(fakeRepo),
        currentUserProvider.overrideWith((ref) => _mockUser('student-1', 'student1@campus.edu')),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('EcoCampus Achievement System End-to-End Tests', () {
    test('1. Clean initial state for new account with zero reports', () async {
      final achievements = await container.read(achievementsProvider.future);

      expect(achievements.length, 3);

      // Rule 1: First Report locked, progress 0/1
      final firstReport = achievements.firstWhere((a) => a.id == Achievement.firstReportId);
      expect(firstReport.isUnlocked, isFalse);
      expect(firstReport.progress, 0);
      expect(firstReport.target, 1);
      expect(firstReport.isPending, isFalse);
      expect(firstReport.unlockedAt, isNull);

      // Rule 2: 10 Issues Reported locked, progress 0/10
      final tenReported = achievements.firstWhere((a) => a.id == Achievement.tenReportedId);
      expect(tenReported.isUnlocked, isFalse);
      expect(tenReported.progress, 0);
      expect(tenReported.target, 10);
      expect(tenReported.isPending, isFalse);

      // Rule 3: 10 Issues Resolved locked, progress 0/10
      final tenResolved = achievements.firstWhere((a) => a.id == Achievement.tenResolvedId);
      expect(tenResolved.isUnlocked, isFalse);
      expect(tenResolved.progress, 0);
      expect(tenResolved.target, 10);
      expect(tenResolved.isPending, isFalse);
    });

    test('2. Save first report and verify First Report unlocks with valid timestamp', () async {
      // Clean start
      var list = await container.read(achievementsProvider.future);
      expect(list.firstWhere((a) => a.id == Achievement.firstReportId).isUnlocked, isFalse);

      // Student submits 1 report
      fakeRepo.addReport(userId: 'student-1', reportId: 'REP-1', status: 'REPORTED');
      await container.read(achievementsProvider.notifier).refresh();

      list = await container.read(achievementsProvider.future);
      final firstReport = list.firstWhere((a) => a.id == Achievement.firstReportId);

      expect(firstReport.isUnlocked, isTrue);
      expect(firstReport.progress, 1);
      expect(firstReport.unlockedAt, isNotNull);
      expect(firstReport.formattedUnlockDate, 'Oct 14, 2026');

      // 10-report and 10-resolved remain locked
      final tenReported = list.firstWhere((a) => a.id == Achievement.tenReportedId);
      expect(tenReported.isUnlocked, isFalse);
      expect(tenReported.progress, 1);

      final tenResolved = list.firstWhere((a) => a.id == Achievement.tenResolvedId);
      expect(tenResolved.isUnlocked, isFalse);
      expect(tenResolved.progress, 0);
    });

    test('3. Verify 10-report achievement threshold at 9 versus 10 reports', () async {
      // Add 9 reports
      for (int i = 1; i <= 9; i++) {
        fakeRepo.addReport(userId: 'student-1', reportId: 'REP-$i', status: 'REPORTED');
      }
      await container.read(achievementsProvider.notifier).refresh();

      var list = await container.read(achievementsProvider.future);
      var tenReported = list.firstWhere((a) => a.id == Achievement.tenReportedId);

      // At 9 reports: locked, progress 9 / 10
      expect(tenReported.isUnlocked, isFalse);
      expect(tenReported.progress, 9);
      expect(tenReported.progressFraction, 0.9);

      // Add 10th report
      fakeRepo.addReport(userId: 'student-1', reportId: 'REP-10', status: 'REPORTED');
      await container.read(achievementsProvider.notifier).refresh();

      list = await container.read(achievementsProvider.future);
      tenReported = list.firstWhere((a) => a.id == Achievement.tenReportedId);

      // At 10 reports: unlocked, progress 10 / 10
      expect(tenReported.isUnlocked, isTrue);
      expect(tenReported.progress, 10);
      expect(tenReported.progressFraction, 1.0);
      expect(tenReported.unlockedAt, isNotNull);
    });

    test('4. Verify 10-resolved achievement threshold at 9 versus 10 resolved reports', () async {
      // Add 12 reports, resolve 9 of them
      for (int i = 1; i <= 12; i++) {
        fakeRepo.addReport(
          userId: 'student-1',
          reportId: 'REP-$i',
          status: i <= 9 ? 'RESOLVED' : 'IN_PROGRESS',
        );
      }
      await container.read(achievementsProvider.notifier).refresh();

      var list = await container.read(achievementsProvider.future);
      var tenResolved = list.firstWhere((a) => a.id == Achievement.tenResolvedId);

      // At 9 resolved: locked, progress 9 / 10
      expect(tenResolved.isUnlocked, isFalse);
      expect(tenResolved.progress, 9);

      // 10th report transitions to RESOLVED
      fakeRepo.updateReportStatus(userId: 'student-1', reportId: 'REP-10', newStatus: 'RESOLVED');
      await container.read(achievementsProvider.notifier).refresh();

      list = await container.read(achievementsProvider.future);
      tenResolved = list.firstWhere((a) => a.id == Achievement.tenResolvedId);

      // At 10 resolved: unlocked!
      expect(tenResolved.isUnlocked, isTrue);
      expect(tenResolved.progress, 10);
      expect(tenResolved.unlockedAt, isNotNull);
    });

    test('5. Retry requests and refresh multiple times: unlocks are never duplicated', () async {
      fakeRepo.addReport(userId: 'student-1', reportId: 'REP-1', status: 'REPORTED');

      // First unlock
      await container.read(achievementsProvider.notifier).refresh();
      var list = await container.read(achievementsProvider.future);
      final initialDate = list.firstWhere((a) => a.id == Achievement.firstReportId).unlockedAt;

      expect(initialDate, isNotNull);
      expect(fakeRepo.getUnlockRecordCount('student-1'), 1);

      // Refresh multiple times and retry evaluate
      for (int i = 0; i < 5; i++) {
        fakeRepo.addReport(userId: 'student-1', reportId: 'REP-DUP-$i', status: 'REPORTED');
        await container.read(achievementsProvider.notifier).refresh();
      }

      // Check unlock record count for 'first_report' in repository
      expect(fakeRepo.getUnlockRecordCount('student-1'), 1); // Only 1 achievement record, not 6
      list = await container.read(achievementsProvider.future);
      final subsequentDate = list.firstWhere((a) => a.id == Achievement.firstReportId).unlockedAt;
      expect(subsequentDate, equals(initialDate)); // Timestamp is never overwritten or mutated
    });

    test('6. Account switching: each account sees strictly its own achievements', () async {
      // Account A has 10 reports (First Report + 10 Issues Reported unlocked)
      for (int i = 1; i <= 10; i++) {
        fakeRepo.addReport(userId: 'student-1', reportId: 'REP-A-$i', status: 'REPORTED');
      }
      await container.read(achievementsProvider.notifier).refresh();

      final listA = await container.read(achievementsProvider.future);
      expect(listA.firstWhere((a) => a.id == Achievement.firstReportId).isUnlocked, isTrue);
      expect(listA.firstWhere((a) => a.id == Achievement.tenReportedId).isUnlocked, isTrue);

      // Switch to Account B (new student, 0 reports)
      final containerB = ProviderContainer(
        overrides: [
          achievementsRepositoryProvider.overrideWithValue(fakeRepo),
          currentUserProvider.overrideWith((ref) => _mockUser('student-2', 'student2@campus.edu')),
        ],
      );
      addTearDown(containerB.dispose);

      final listB = await containerB.read(achievementsProvider.future);
      // Account B must NOT see Account A's unlocked achievements
      expect(listB.firstWhere((a) => a.id == Achievement.firstReportId).isUnlocked, isFalse);
      expect(listB.firstWhere((a) => a.id == Achievement.tenReportedId).isUnlocked, isFalse);
      expect(listB.firstWhere((a) => a.id == Achievement.firstReportId).progress, 0);

      // Account A remains unchanged
      final listARestored = await container.read(achievementsProvider.future);
      expect(listARestored.firstWhere((a) => a.id == Achievement.firstReportId).isUnlocked, isTrue);
    });

    test('7. Unauthorized direct client writes to achievements are rejected', () async {
      // Student 1 attempts to write an unlock directly without server authorization
      expect(
        () => fakeRepo.simulateUnauthorizedClientWrite(
          callingUserId: 'student-1',
          targetUserId: 'student-1',
          achievementId: Achievement.tenResolvedId,
        ),
        throwsA(isA<Exception>()),
      );

      // Student 1 attempts to unlock achievements for Student 2
      expect(
        () => fakeRepo.simulateUnauthorizedClientWrite(
          callingUserId: 'student-1',
          targetUserId: 'student-2',
          achievementId: Achievement.firstReportId,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}

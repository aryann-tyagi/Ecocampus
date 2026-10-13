import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ecocampus_mobile/features/rewards/domain/daily_challenge_model.dart';
import 'package:ecocampus_mobile/features/rewards/data/challenges_repository.dart';
import 'package:ecocampus_mobile/features/rewards/data/challenges_provider.dart';
import 'package:ecocampus_mobile/features/auth/data/auth_providers.dart';

/// In-memory mock simulating server-side daily challenges evaluation,
/// category-specific rules, and account isolation.
class FakeChallengesRepository implements ChallengesRepository {
  /// Map of userId -> list of reports submitted today ({'id': String, 'category': String})
  final Map<String, List<Map<String, String>>> _todayReportsByUser = {};

  bool cacheCleared = false;
  bool shouldThrow = false;

  void addReport({
    required String userId,
    required String reportId,
    required String category,
  }) {
    _todayReportsByUser.putIfAbsent(userId, () => []).add({
      'id': reportId,
      'category': category.toLowerCase(),
    });
  }

  @override
  void clearCache() {
    cacheCleared = true;
  }

  @override
  Future<List<DailyChallenge>> getDailyChallenges({String? userId}) async {
    if (shouldThrow) {
      throw Exception('Network error: failed to fetch daily challenges');
    }

    final targetId = userId ?? 'student-1';
    final reports = _todayReportsByUser[targetId] ?? [];

    // Category filtering per PRD & instructions:
    // 1. daily_reporter: any report
    // 2. water_watch: water report
    // 3. energy_check: electricity report
    final anyCount = reports.length;
    final waterCount = reports.where((r) => r['category'] == 'water').length;
    final energyCount = reports.where((r) => r['category'] == 'electricity').length;

    return [
      DailyChallenge(
        challengeKey: DailyChallenge.dailyReporterKey,
        title: 'Daily Reporter',
        description: 'Submit at least 1 verified campus issue report today.',
        targetCount: 1,
        progressCount: anyCount.clamp(0, 1),
        isCompleted: anyCount >= 1,
        challengeDate: '2026-10-14',
        sortOrder: 1,
      ),
      DailyChallenge(
        challengeKey: DailyChallenge.waterWatchKey,
        title: 'Water Watch',
        description: 'Report any active water leak or plumbing issue today.',
        targetCount: 1,
        progressCount: waterCount.clamp(0, 1),
        isCompleted: waterCount >= 1,
        challengeDate: '2026-10-14',
        sortOrder: 2,
      ),
      DailyChallenge(
        challengeKey: DailyChallenge.energyCheckKey,
        title: 'Energy Check',
        description: 'Spot and report any lighting or electrical energy waste today.',
        targetCount: 1,
        progressCount: energyCount.clamp(0, 1),
        isCompleted: energyCount >= 1,
        challengeDate: '2026-10-14',
        sortOrder: 3,
      ),
    ];
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
  late FakeChallengesRepository fakeRepo;
  late ProviderContainer container;

  setUp(() {
    fakeRepo = FakeChallengesRepository();
    container = ProviderContainer(
      overrides: [
        challengesRepositoryProvider.overrideWithValue(fakeRepo),
        currentUserProvider.overrideWith((ref) => _mockUser('student-1', 'student1@campus.edu')),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('EcoCampus Daily Challenge Progress Tests', () {
    test('1. Initial clean state: 0 progress and not completed', () async {
      final challenges = await container.read(dailyChallengesProvider.future);

      expect(challenges.length, 3);

      final reporter = challenges.firstWhere((c) => c.challengeKey == DailyChallenge.dailyReporterKey);
      expect(reporter.progressCount, 0);
      expect(reporter.targetCount, 1);
      expect(reporter.isCompleted, isFalse);
      expect(reporter.challengeDate, '2026-10-14');

      final water = challenges.firstWhere((c) => c.challengeKey == DailyChallenge.waterWatchKey);
      expect(water.progressCount, 0);
      expect(water.isCompleted, isFalse);

      final energy = challenges.firstWhere((c) => c.challengeKey == DailyChallenge.energyCheckKey);
      expect(energy.progressCount, 0);
      expect(energy.isCompleted, isFalse);
    });

    test('2. Waste report completes Daily Reporter only', () async {
      fakeRepo.addReport(userId: 'student-1', reportId: 'REP-1', category: 'waste');
      await container.read(dailyChallengesProvider.notifier).refresh();

      final challenges = await container.read(dailyChallengesProvider.future);

      final reporter = challenges.firstWhere((c) => c.challengeKey == DailyChallenge.dailyReporterKey);
      expect(reporter.progressCount, 1);
      expect(reporter.isCompleted, isTrue);

      final water = challenges.firstWhere((c) => c.challengeKey == DailyChallenge.waterWatchKey);
      expect(water.progressCount, 0);
      expect(water.isCompleted, isFalse);

      final energy = challenges.firstWhere((c) => c.challengeKey == DailyChallenge.energyCheckKey);
      expect(energy.progressCount, 0);
      expect(energy.isCompleted, isFalse);
    });

    test('3. Water report completes Daily Reporter and Water Watch, but NOT Energy Check', () async {
      fakeRepo.addReport(userId: 'student-1', reportId: 'REP-W1', category: 'water');
      await container.read(dailyChallengesProvider.notifier).refresh();

      final challenges = await container.read(dailyChallengesProvider.future);

      final reporter = challenges.firstWhere((c) => c.challengeKey == DailyChallenge.dailyReporterKey);
      expect(reporter.isCompleted, isTrue);

      final water = challenges.firstWhere((c) => c.challengeKey == DailyChallenge.waterWatchKey);
      expect(water.progressCount, 1);
      expect(water.isCompleted, isTrue);

      final energy = challenges.firstWhere((c) => c.challengeKey == DailyChallenge.energyCheckKey);
      expect(energy.progressCount, 0);
      expect(energy.isCompleted, isFalse);
    });

    test('4. Electricity report completes Daily Reporter and Energy Check, but NOT Water Watch', () async {
      fakeRepo.addReport(userId: 'student-1', reportId: 'REP-E1', category: 'electricity');
      await container.read(dailyChallengesProvider.notifier).refresh();

      final challenges = await container.read(dailyChallengesProvider.future);

      final reporter = challenges.firstWhere((c) => c.challengeKey == DailyChallenge.dailyReporterKey);
      expect(reporter.isCompleted, isTrue);

      final water = challenges.firstWhere((c) => c.challengeKey == DailyChallenge.waterWatchKey);
      expect(water.progressCount, 0);
      expect(water.isCompleted, isFalse);

      final energy = challenges.firstWhere((c) => c.challengeKey == DailyChallenge.energyCheckKey);
      expect(energy.progressCount, 1);
      expect(energy.isCompleted, isTrue);
    });

    test('5. Challenges do not complete simply by reading or checking them', () async {
      // Multiple reads without submitting reports
      await container.read(dailyChallengesProvider.notifier).refresh();
      await container.read(dailyChallengesProvider.notifier).refresh();

      final challenges = await container.read(dailyChallengesProvider.future);
      for (final c in challenges) {
        expect(c.isCompleted, isFalse);
        expect(c.progressCount, 0);
      }
    });

    test('6. Network failure surfaces error instead of false progress', () async {
      fakeRepo.shouldThrow = true;

      // Expect refresh to result in error state
      await container.read(dailyChallengesProvider.notifier).refresh();
      final state = container.read(dailyChallengesProvider);
      expect(state.hasError, isTrue);
    });

    test('7. Account switching isolates daily challenges state', () async {
      fakeRepo.addReport(userId: 'student-1', reportId: 'REP-1', category: 'water');
      await container.read(dailyChallengesProvider.notifier).refresh();

      var listA = await container.read(dailyChallengesProvider.future);
      expect(listA.firstWhere((c) => c.challengeKey == DailyChallenge.waterWatchKey).isCompleted, isTrue);

      // Switch to Student B with no reports
      final containerB = ProviderContainer(
        overrides: [
          challengesRepositoryProvider.overrideWithValue(fakeRepo),
          currentUserProvider.overrideWith((ref) => _mockUser('student-2', 'student2@campus.edu')),
        ],
      );
      addTearDown(containerB.dispose);

      final listB = await containerB.read(dailyChallengesProvider.future);

      for (final c in listB) {
        expect(c.isCompleted, isFalse);
        expect(c.progressCount, 0);
      }
    });
  });
}

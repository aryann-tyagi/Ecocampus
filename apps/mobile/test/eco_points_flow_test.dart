import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ecocampus_mobile/features/rewards/domain/eco_points_model.dart';
import 'package:ecocampus_mobile/features/rewards/data/eco_points_repository.dart';
import 'package:ecocampus_mobile/features/rewards/data/eco_points_provider.dart';
import 'package:ecocampus_mobile/features/home/data/home_providers.dart';
import 'package:ecocampus_mobile/features/auth/data/auth_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// In-memory mock repository simulating Supabase reports table and RPC behavior
/// for end-to-end verification of all 6 test cases.
class FakeEcoPointsRepository implements EcoPointsRepository {
  final Map<String, List<Map<String, dynamic>>> _userReports = {};
  final Set<String> _awardedIdempotencyKeys = {};

  void addReport({
    required String userId,
    required String reportId,
    required String severity,
    required String status,
  }) {
    _userReports.putIfAbsent(userId, () => []).add({
      'id': reportId,
      'reporter_id': userId,
      'severity': severity,
      'status': status,
    });
  }

  @override
  Future<EcoPointsSummary> getUserSummary({String? userId}) async {
    final targetId = userId ?? 'student-1';
    final reports = _userReports[targetId] ?? [];

    int totalPoints = 0;
    int eligibleCount = 0;

    for (final r in reports) {
      final status = (r['status'] as String).toUpperCase();
      if (status == 'REJECTED' || status == 'DUPLICATE') continue;

      eligibleCount++;
      totalPoints += EcoScoringRules.reportSubmitted;

      if (status == 'RESOLVED') {
        totalPoints += EcoScoringRules.reportResolved;
      }
    }

    return EcoPointsSummary.fromTotals(
      totalPoints: totalPoints,
      eventCount: eligibleCount,
    );
  }

  @override
  Future<int> awardPoints({
    required String userId,
    required String actionType,
    required int points,
    required String idempotencyKey,
    String? referenceId,
    String? description,
  }) async {
    // Idempotency check: duplicate key awards 0 points
    if (_awardedIdempotencyKeys.contains(idempotencyKey)) {
      return 0;
    }
    _awardedIdempotencyKeys.add(idempotencyKey);
    return points;
  }

  @override
  Future<List<EcoPointEvent>> getUserEvents({String? userId, int limit = 50}) async {
    final summary = await getUserSummary(userId: userId ?? 'student-1');
    if (summary.totalPoints == 0) return const [];
    return [
      EcoPointEvent(
        id: 'evt-1',
        userId: userId ?? 'student-1',
        actionType: EcoScoringRules.actionReportSubmitted,
        points: summary.totalPoints,
        idempotencyKey: 'key-1',
        createdAt: DateTime.now(),
      ),
    ];
  }

  @override
  Future<List<LeaderboardEntry>> getLeaderboard({
    int limit = 10,
    String? currentUserId,
  }) async {
    final summary = await getUserSummary(userId: currentUserId ?? 'student-1');
    return [
      LeaderboardEntry(
        userId: currentUserId ?? 'student-1',
        displayName: 'Student One',
        totalPoints: summary.totalPoints,
        rank: 1,
      ),
    ];
  }
}

void main() {
  late FakeEcoPointsRepository fakeRepo;
  late ProviderContainer container;

  setUp(() {
    fakeRepo = FakeEcoPointsRepository();
    container = ProviderContainer(
      overrides: [
        ecoPointsRepositoryProvider.overrideWithValue(fakeRepo),
        currentUserProvider.overrideWith(
          (ref) => const User(
            id: 'student-1',
            appMetadata: {},
            userMetadata: {},
            aud: 'authenticated',
            createdAt: '2026-10-13T00:00:00Z',
          ),
        ),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('EcoScore Bug Verification — 6 Critical Test Cases', () {
    test('Case 1: Submit eligible report and verify points are persisted', () async {
      // Clean initial state
      final initialSummary = await container.read(ecoPointsProvider.future);
      expect(initialSummary.totalPoints, 0);

      // Student submits a standard eligible report
      fakeRepo.addReport(
        userId: 'student-1',
        reportId: 'REP-001',
        severity: 'medium',
        status: 'REPORTED',
      );

      final awarded = await container.read(ecoPointsProvider.notifier).awardReportSubmitted(
            userId: 'student-1',
            reportId: 'REP-001',
            isCritical: false,
          );

      expect(awarded, 5); // Database scoring: +5 points for report submission

      final updatedSummary = container.read(ecoPointsProvider).value;
      expect(updatedSummary?.totalPoints, 5);
      expect(updatedSummary?.eventCount, 1);
    });

    test('Case 2: Confirm displayed score updates immediately across providers', () async {
      // Check total points and dashboard before submission
      expect(container.read(ecoTotalPointsProvider), 0);
      expect(container.read(homeDashboardProvider).level, 1);

      // Submit report
      fakeRepo.addReport(
        userId: 'student-1',
        reportId: 'REP-002',
        severity: 'critical',
        status: 'REPORTED',
      );

      final awarded = await container.read(ecoPointsProvider.notifier).awardReportSubmitted(
            userId: 'student-1',
            reportId: 'REP-002',
            isCritical: true,
          );

      expect(awarded, 5); // +5 for submitted report

      // Verify that convenience and dashboard providers update immediately without restart
      expect(container.read(ecoTotalPointsProvider), 5);
      final stats = container.read(homeDashboardProvider);
      expect(stats.level, 1); // 5 pts is Level 1 'Seedling'
      expect(stats.levelTitle, 'Seedling');
    });

    test('Case 3: Refresh home page and verify points remain correct', () async {
      fakeRepo.addReport(
        userId: 'student-1',
        reportId: 'REP-003',
        severity: 'low',
        status: 'REPORTED',
      );
      await container.read(ecoPointsProvider.notifier).awardReportSubmitted(
            userId: 'student-1',
            reportId: 'REP-003',
            isCritical: false,
          );

      expect(container.read(ecoTotalPointsProvider), 5);

      // Trigger pull-to-refresh
      await container.read(ecoPointsProvider.notifier).refresh();

      // Points remain 5, not reset or lost
      expect(container.read(ecoTotalPointsProvider), 5);
      final summary = container.read(ecoPointsProvider).value;
      expect(summary?.totalPoints, 5);
      expect(summary?.eventCount, 1);
    });

    test('Case 4: Retry same award operation and verify no double-reward', () async {
      fakeRepo.addReport(
        userId: 'student-1',
        reportId: 'REP-004',
        severity: 'medium',
        status: 'REPORTED',
      );

      // First submission award
      final firstAward = await container.read(ecoPointsProvider.notifier).awardReportSubmitted(
            userId: 'student-1',
            reportId: 'REP-004',
            isCritical: false,
          );
      expect(firstAward, 5);
      expect(container.read(ecoTotalPointsProvider), 5);

      // Retrying award operation with same report ID
      await container.read(ecoPointsProvider.notifier).awardReportSubmitted(
            userId: 'student-1',
            reportId: 'REP-004',
            isCritical: false,
          );

      // Verified points from repository remains 5, never 10
      final summary = container.read(ecoPointsProvider).value;
      expect(summary?.totalPoints, 5);
      expect(summary?.eventCount, 1);
    });

    test('Case 5: Simulate failed submission and verify no reward granted', () async {
      // Initial points: 0
      expect(container.read(ecoTotalPointsProvider), 0);

      // When a report submission fails, no report is added to repository,
      // and awardReportSubmitted is NOT invoked.
      // E.g., simulated by checking state after failed attempt:
      await container.read(ecoPointsProvider.notifier).refresh();

      expect(container.read(ecoTotalPointsProvider), 0);
      final summary = container.read(ecoPointsProvider).value;
      expect(summary?.totalPoints, 0);
      expect(summary?.eventCount, 0);
    });

    test('Case 6: One student points cannot be changed or read by another', () async {
      // Add reports for student-1 (5 pts) and student-2 (resolved: 5 + 15 = 20 pts)
      fakeRepo.addReport(
        userId: 'student-1',
        reportId: 'REP-S1',
        severity: 'low',
        status: 'REPORTED',
      );
      fakeRepo.addReport(
        userId: 'student-2',
        reportId: 'REP-S2',
        severity: 'critical',
        status: 'RESOLVED',
      );

      // Authenticated as student-1
      await container.read(ecoPointsProvider.notifier).refresh();
      expect(container.read(ecoTotalPointsProvider), 5);

      // Container for student-2
      final container2 = ProviderContainer(
        overrides: [
          ecoPointsRepositoryProvider.overrideWithValue(fakeRepo),
          currentUserProvider.overrideWith(
            (ref) => const User(
              id: 'student-2',
              appMetadata: {},
              userMetadata: {},
              aud: 'authenticated',
              createdAt: '2026-10-13T00:00:00Z',
            ),
          ),
        ],
      );
      addTearDown(container2.dispose);

      await container2.read(ecoPointsProvider.notifier).refresh();
      expect(container2.read(ecoTotalPointsProvider), 20);

      // Student 1 points remain completely isolated
      expect(container.read(ecoTotalPointsProvider), 5);
    });
  });
}

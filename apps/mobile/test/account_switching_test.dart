import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ecocampus_mobile/features/auth/data/auth_providers.dart';
import 'package:ecocampus_mobile/features/home/data/home_providers.dart';
import 'package:ecocampus_mobile/features/report/data/reports_provider.dart';
import 'package:ecocampus_mobile/features/report/data/reports_repository.dart';
import 'package:ecocampus_mobile/features/report/domain/ai_analysis_models.dart';
import 'package:ecocampus_mobile/features/report/domain/duplicate_detection_models.dart';
import 'package:ecocampus_mobile/features/report/domain/report_model.dart';
import 'package:ecocampus_mobile/features/rewards/data/eco_points_provider.dart';
import 'package:ecocampus_mobile/features/rewards/data/eco_points_repository.dart';
import 'package:ecocampus_mobile/features/rewards/domain/eco_points_model.dart';
import 'package:ecocampus_mobile/features/profile/data/profile_repository.dart';
import 'package:ecocampus_mobile/features/profile/domain/user_profile.dart';

/// Test in-memory repository implementing dual accounts, reports isolation,
/// campus feed discovery, and genuine scoring.
class FakeMultiAccountRepository implements ReportsRepository, EcoPointsRepository, ProfileRepository {
  final Map<String, List<ReportModel>> _reportsByUser = {
    'user-a': [],
    'user-b': [],
  };

  final Map<String, UserProfile> _profilesByUser = {
    'user-a': const UserProfile(id: 'user-a', displayName: 'Alice Student', companionName: 'Flora'),
    'user-b': const UserProfile(id: 'user-b', displayName: 'Bob Student', companionName: 'Sprout'),
  };

  final Set<String> _awardedKeys = {};
  bool cacheCleared = false;

  // ─── ReportsRepository implementation ─────────────────────────────────

  @override
  void clearCache() {
    cacheCleared = true;
  }

  @override
  Future<String?> getSignedPhotoUrl(String storagePath, {int expiresIn = 3600}) async {
    return 'https://storage.supabase.co/$storagePath?signed=true';
  }

  @override
  Future<ReportModel> submitReport({
    required ReportSubmissionDraft draft,
    required String userId,
  }) async {
    final report = ReportModel(
      id: draft.draftId,
      title: draft.title,
      description: draft.description,
      category: draft.category,
      severity: draft.severity,
      status: ReportStatus.reported,
      location: CampusLocation(
        building: 'Building A',
        floor: draft.floorText ?? '',
        area: draft.locationDetails,
      ),
      createdAt: DateTime.now(),
    );
    _reportsByUser.putIfAbsent(userId, () => []).insert(0, report);
    return report;
  }

  @override
  Future<List<ReportModel>> getMyReports(String userId) async {
    return List.unmodifiable(_reportsByUser[userId] ?? const []);
  }

  @override
  Future<List<ReportModel>> getNearbyReports({
    int limit = 10,
    double? userLat,
    double? userLng,
  }) async {
    final all = <ReportModel>[];
    for (final list in _reportsByUser.values) {
      all.addAll(list);
    }
    return all
        .where((r) =>
            r.status != ReportStatus.resolved &&
            r.status != ReportStatus.rejected &&
            r.status != ReportStatus.duplicate)
        .take(limit)
        .toList();
  }

  @override
  Future<ReportModel?> getReportDetail(String reportId, String userId) async {
    final userReports = _reportsByUser[userId] ?? const [];
    try {
      return userReports.firstWhere((r) => r.id == reportId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<AiIssueAnalysis> analyzeReport({
    required Uint8List photoBytes,
    required String photoMimeType,
    String? userDescription,
  }) async {
    return const AiIssueAnalysis(
      issueTitle: 'Test Campus Issue',
      issueDescription: 'Observable test issue.',
      category: IssueCategory.waste,
      severity: IssueSeverity.medium,
      department: 'Sanitation & Grounds',
      confidence: 'high',
      needsReview: false,
      reasoningSummary: 'Test photo evidence analysis.',
    );
  }

  @override
  Future<DuplicateCheckResult> checkDuplicates({
    required String buildingId,
    required IssueCategory category,
    required String title,
    required String description,
    String? floorId,
    String? floorText,
    String? locationDetails,
  }) async {
    return DuplicateCheckResult.noMatch();
  }

  // ─── EcoPointsRepository implementation ───────────────────────────────

  @override
  Future<EcoPointsSummary> getUserSummary({String? userId}) async {
    final targetId = userId ?? 'user-a';
    final userReports = _reportsByUser[targetId] ?? const [];

    int points = 0;
    int count = 0;
    for (final r in userReports) {
      if (r.status == ReportStatus.rejected || r.status == ReportStatus.duplicate) continue;
      count++;
      final isCritical = r.severity == IssueSeverity.critical;
      points += isCritical ? EcoScoringRules.reportCritical : EcoScoringRules.reportSubmitted;
      if (r.status == ReportStatus.resolved) {
        points += EcoScoringRules.reportResolved;
      }
    }

    if (points == 0 && count == 0) {
      return EcoPointsSummary.zero();
    }
    return EcoPointsSummary.fromTotals(totalPoints: points, eventCount: count);
  }

  @override
  Future<List<EcoPointEvent>> getUserEvents({String? userId, int limit = 50}) async {
    final targetId = userId ?? 'user-a';
    final userReports = _reportsByUser[targetId] ?? const [];
    final events = <EcoPointEvent>[];

    for (final r in userReports) {
      if (r.status == ReportStatus.rejected || r.status == ReportStatus.duplicate) continue;
      final isCritical = r.severity == IssueSeverity.critical;
      final pts = isCritical ? EcoScoringRules.reportCritical : EcoScoringRules.reportSubmitted;
      events.add(EcoPointEvent(
        id: 'evt-${r.id}',
        userId: targetId,
        actionType: isCritical ? EcoScoringRules.actionReportCritical : EcoScoringRules.actionReportSubmitted,
        points: pts,
        idempotencyKey: EcoScoringRules.reportSubmittedKey(r.id),
        referenceId: r.id,
        createdAt: r.createdAt,
      ));
    }
    return events;
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
    if (_awardedKeys.contains(idempotencyKey)) return 0;
    _awardedKeys.add(idempotencyKey);
    return points;
  }

  @override
  Future<List<LeaderboardEntry>> getLeaderboard({
    int limit = 10,
    String? currentUserId,
  }) async {
    final userScores = <String, int>{};
    for (final entry in _reportsByUser.entries) {
      int pts = 0;
      for (final r in entry.value) {
        if (r.status == ReportStatus.rejected || r.status == ReportStatus.duplicate) continue;
        pts += r.severity == IssueSeverity.critical
            ? EcoScoringRules.reportCritical
            : EcoScoringRules.reportSubmitted;
        if (r.status == ReportStatus.resolved) pts += EcoScoringRules.reportResolved;
      }
      if (pts > 0) {
        userScores[entry.key] = pts;
      }
    }

    final sorted = userScores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final entries = <LeaderboardEntry>[];
    for (int i = 0; i < sorted.take(limit).length; i++) {
      final u = sorted[i];
      final profile = _profilesByUser[u.key];
      entries.add(LeaderboardEntry(
        userId: u.key,
        displayName: profile?.displayName ?? 'Student',
        totalPoints: u.value,
        rank: i + 1,
      ));
    }
    return entries;
  }

  // ─── ProfileRepository implementation ─────────────────────────────────

  @override
  Future<UserProfile?> getProfile(String userId) async {
    return _profilesByUser[userId];
  }

  @override
  Future<void> updateProfile({
    required String userId,
    String? displayName,
    String? companionName,
    String? avatarUrl,
  }) async {
    final existing = _profilesByUser[userId];
    _profilesByUser[userId] = UserProfile(
      id: userId,
      displayName: displayName ?? existing?.displayName,
      companionName: companionName ?? existing?.companionName,
      avatarUrl: avatarUrl ?? existing?.avatarUrl,
      updatedAt: DateTime.now(),
    );
  }
}

User _createTestUser(String id, String email) {
  return User(
    id: id,
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: DateTime.now().toIso8601String(),
    email: email,
  );
}

class TestUserNotifier extends Notifier<User?> {
  @override
  User? build() => null;
  void setUser(User? user) => state = user;
}

final testUserProvider = NotifierProvider<TestUserNotifier, User?>(TestUserNotifier.new);

void main() {
  group('EcoCampus Account Switching & User Data Isolation Tests', () {
    late FakeMultiAccountRepository repo;

    setUp(() {
      repo = FakeMultiAccountRepository();
    });

    ProviderContainer createContainer() {
      return ProviderContainer(
        overrides: [
          currentUserProvider.overrideWith((ref) => ref.watch(testUserProvider)),
          reportsRepositoryProvider.overrideWithValue(repo),
          ecoPointsRepositoryProvider.overrideWithValue(repo),
          profileRepositoryProvider.overrideWithValue(repo),
        ],
      );
    }

    test('Verification 1 & 2: Account A submits report, earns points, then signs out cleanly', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      final userA = _createTestUser('user-a', 'alice@campus.edu');
      container.read(testUserProvider.notifier).setUser(userA);

      // Account A loads initial empty state
      final initialReports = await container.read(myReportsProvider.future);
      expect(initialReports, isEmpty);
      expect(container.read(homeDashboardProvider).ecoScore, 0); // No preset 60!
      expect(container.read(ecoTotalPointsProvider), 0);

      // Account A submits a report
      final draftA = ReportSubmissionDraft(
        draftId: 'rep-a-1',
        title: 'Broken solar panel',
        category: IssueCategory.electricity,
        severity: IssueSeverity.critical,
        buildingId: 'b-1',
        locationDetails: 'Rooftop',
        description: 'Glass cracked',
        photoBytes: Uint8List(0),
        photoMimeType: 'image/jpeg',
        photoFileName: 'photo.jpg',
      );
      final submitted = await repo.submitReport(draft: draftA, userId: userA.id);
      container.read(myReportsProvider.notifier).addReport(submitted);

      // Award points for Account A (+50 for critical report per PRD §12.1)
      await container.read(ecoPointsProvider.notifier).awardReportSubmitted(
            userId: userA.id,
            reportId: submitted.id,
            isCritical: true,
          );

      // Verify Account A points and report state
      final userAReports = await container.read(myReportsProvider.future);
      expect(userAReports.length, 1);
      expect(userAReports.first.id, 'rep-a-1');
      expect(container.read(ecoTotalPointsProvider), 50);
      expect(container.read(homeDashboardProvider).level, 2); // 50 pts = Level 2 'Bud'

      // Sign out Account A
      await container.read(authControllerProvider.notifier).signOut();
      container.read(testUserProvider.notifier).setUser(null);

      // Verify state was cleared on sign-out
      expect(repo.cacheCleared, true);
      expect(container.read(reportsProvider), isEmpty);
      expect(container.read(ecoTotalPointsProvider), 0);
      expect(container.read(homeDashboardProvider).ecoScore, 0);
    });

    test('Verification 3, 4 & 5: Account B signs in without seeing Account A reports and shows genuine 0 score', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      // Setup Account A data in repo
      final userA = _createTestUser('user-a', 'alice@campus.edu');
      final draftA = ReportSubmissionDraft(
        draftId: 'rep-a-1',
        title: 'Broken solar panel',
        category: IssueCategory.electricity,
        severity: IssueSeverity.critical,
        buildingId: 'b-1',
        locationDetails: 'Rooftop',
        description: 'Glass cracked',
        photoBytes: Uint8List(0),
        photoMimeType: 'image/jpeg',
        photoFileName: 'photo.jpg',
      );
      await repo.submitReport(draft: draftA, userId: userA.id);

      // Sign in as Account B (brand new student, 0 reports)
      final userB = _createTestUser('user-b', 'bob@campus.edu');
      container.read(testUserProvider.notifier).setUser(userB);

      // Verification 3: My Reports must show ONLY Account B reports (empty)
      final userBReports = await container.read(myReportsProvider.future);
      expect(userBReports, isEmpty, reason: "Account B must NOT see Account A's private My Reports data");
      expect(container.read(reportsProvider), isEmpty);

      // Verification 5: Account B shows genuine 0 score (NOT preset 60/100)
      final statsB = container.read(homeDashboardProvider);
      expect(statsB.ecoScore, 0, reason: "Account B must show genuine 0 EcoScore, never preset 60/100");
      expect(statsB.totalReports, 0);
      expect(statsB.resolvedReports, 0);
      expect(statsB.level, 1);
      expect(statsB.levelTitle, 'Seedling');
      expect(container.read(ecoTotalPointsProvider), 0);

      // Verification 4: Nearby Issues loads campus reports (includes Account A's report)
      await container.read(campusReportsProvider.future);
      final nearby = container.read(nearbyReportsProvider);
      expect(nearby.length, 1, reason: "Campus nearby issues must display genuine community reports");
      expect(nearby.first.id, 'rep-a-1');
      expect(nearby.first.title, 'Broken solar panel');

      // Leaderboard reflects campus standings: Account A is #1 with 50 pts
      final leaderboard = await container.read(leaderboardProvider.future);
      expect(leaderboard.length, 1);
      expect(leaderboard.first.userId, 'user-a');
      expect(leaderboard.first.totalPoints, 50);
      expect(leaderboard.first.rank, 1);
    });

    test('Verification 6: Switch back to Account A and confirm genuine reports and points remain intact', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      // 1. Account A signs in and submits
      final userA = _createTestUser('user-a', 'alice@campus.edu');
      container.read(testUserProvider.notifier).setUser(userA);
      final draftA = ReportSubmissionDraft(
        draftId: 'rep-a-1',
        title: 'Water tap leaking',
        category: IssueCategory.water,
        severity: IssueSeverity.low,
        buildingId: 'b-1',
        locationDetails: 'Floor 1',
        description: 'Drips constantly',
        photoBytes: Uint8List(0),
        photoMimeType: 'image/jpeg',
        photoFileName: 'photo.jpg',
      );
      final repA = await repo.submitReport(draft: draftA, userId: userA.id);
      container.read(myReportsProvider.notifier).addReport(repA);
      await container.read(ecoPointsProvider.notifier).awardReportSubmitted(
            userId: userA.id,
            reportId: repA.id,
            isCritical: false,
          );

      expect(container.read(ecoTotalPointsProvider), 5);
      expect((await container.read(myReportsProvider.future)).length, 1);

      // 2. Switch to Account B
      final userB = _createTestUser('user-b', 'bob@campus.edu');
      container.read(testUserProvider.notifier).setUser(userB);
      await container.read(myReportsProvider.notifier).refresh();
      await container.read(ecoPointsProvider.notifier).refresh();

      expect(container.read(ecoTotalPointsProvider), 0);
      expect(container.read(homeDashboardProvider).ecoScore, 0);
      expect((await container.read(myReportsProvider.future)), isEmpty);

      // 3. Switch back to Account A
      container.read(testUserProvider.notifier).setUser(userA);
      await container.read(myReportsProvider.notifier).refresh();
      await container.read(ecoPointsProvider.notifier).refresh();

      // Confirm Account A's state is completely intact
      final restoredReports = await container.read(myReportsProvider.future);
      expect(restoredReports.length, 1);
      expect(restoredReports.first.id, 'rep-a-1');
      expect(container.read(ecoTotalPointsProvider), 5);
      expect(container.read(homeDashboardProvider).totalReports, 1);
    });

    test('Verification 7: Stale async fetch from Account A does not leak into Account B', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      final userA = _createTestUser('user-a', 'alice@campus.edu');
      final userB = _createTestUser('user-b', 'bob@campus.edu');

      // Populate Account A report in repo
      await repo.submitReport(
        draft: ReportSubmissionDraft(
          draftId: 'rep-a-delayed',
          title: 'Delayed issue',
          category: IssueCategory.waste,
          severity: IssueSeverity.medium,
          buildingId: 'b-2',
          locationDetails: 'Yard',
          description: 'Trash can overflow',
          photoBytes: Uint8List(0),
          photoMimeType: 'image/jpeg',
          photoFileName: 'photo.jpg',
        ),
        userId: userA.id,
      );

      // Active user is Account A
      container.read(testUserProvider.notifier).setUser(userA);

      // Immediately switch to Account B while Account A might have in-flight responses
      container.read(testUserProvider.notifier).setUser(userB);

      // Refresh My Reports as Account B
      await container.read(myReportsProvider.notifier).refresh();

      // Confirm Account B's state has 0 reports and reportsProvider did not get polluted
      expect(container.read(reportsProvider), isEmpty);
      expect((await container.read(myReportsProvider.future)), isEmpty);
      expect(container.read(homeDashboardProvider).ecoScore, 0);
    });
  });
}

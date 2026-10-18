import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ecocampus_mobile/features/notices/domain/notice_model.dart';
import 'package:ecocampus_mobile/features/notices/data/notices_repository.dart';
import 'package:ecocampus_mobile/features/notices/data/notices_provider.dart';
import 'package:ecocampus_mobile/features/notices/presentation/notice_banner_card.dart';
import 'package:ecocampus_mobile/features/rewards/domain/daily_challenge_model.dart';

class FakeNoticesRepository implements NoticesRepository {
  final List<CampusNoticeModel> notices;

  FakeNoticesRepository(this.notices);

  @override
  Future<List<CampusNoticeModel>> getActiveNotices({String? buildingId}) async {
    if (buildingId != null) {
      return notices.where((n) => n.targetBuildingId == null || n.targetBuildingId == buildingId).toList();
    }
    return notices;
  }
}

void main() {
  group('Campus Notice Domain & Presentation Tests', () {
    test('1. CampusNoticeModel parses JSON correctly with priority and building', () {
      final json = {
        'id': 'notice-123',
        'title': 'Water Maintenance in Hostel Block A',
        'message': 'Routine pipe maintenance will occur between 2 PM and 5 PM.',
        'summary': 'Water outage scheduled for Hostel Block A.',
        'notice_type': 'utility_notice',
        'priority': 'urgent',
        'is_pinned': true,
        'target_building_id': 'bldg-1',
        'target_building_name': 'Boys Hostel Block A',
        'starts_at': DateTime.now().toIso8601String(),
        'published_at': DateTime.now().toIso8601String(),
      };

      final notice = CampusNoticeModel.fromJson(json);

      expect(notice.id, 'notice-123');
      expect(notice.title, 'Water Maintenance in Hostel Block A');
      expect(notice.isUrgent, isTrue);
      expect(notice.isImportant, isFalse);
      expect(notice.isPinned, isTrue);
      expect(notice.typeLabel, 'Utility');
      expect(notice.targetBuildingName, 'Boys Hostel Block A');
      expect(notice.formattedDate, isNotEmpty);
    });

    test('2. Notice prioritization selects pinned urgent notice as top home notice', () async {
      final now = DateTime.now();
      final normalNotice = CampusNoticeModel(
        id: 'n-normal',
        title: 'General Campus Notice',
        message: 'Welcome to campus',
        noticeType: 'general_notice',
        priority: 'normal',
        isPinned: false,
        startsAt: now,
      );

      final urgentPinnedNotice = CampusNoticeModel(
        id: 'n-urgent-pinned',
        title: 'Emergency Power Shutdown',
        message: 'Power shutdown in 10 minutes',
        noticeType: 'safety_notice',
        priority: 'urgent',
        isPinned: true,
        startsAt: now,
      );

      final container = ProviderContainer(
        overrides: [
          noticesRepositoryProvider.overrideWithValue(
            FakeNoticesRepository([normalNotice, urgentPinnedNotice]),
          ),
        ],
      );

      // Await async notifier to load data
      await container.read(activeNoticesProvider.future);

      // The latestHomeNoticeProvider must choose the urgent pinned notice
      final homeNotice = container.read(latestHomeNoticeProvider);
      expect(homeNotice?.id, 'n-urgent-pinned');
      expect(homeNotice?.title, 'Emergency Power Shutdown');
    });

    testWidgets('3. NoticeBannerCard renders notice title, priority badge, and location', (tester) async {
      final notice = CampusNoticeModel(
        id: 'n-1',
        title: 'Solar Panels Inspection',
        message: 'Engineers are inspecting solar panel arrays on the terrace.',
        summary: 'Solar arrays inspection in Academic Block 1.',
        noticeType: 'maintenance_update',
        priority: 'important',
        isPinned: true,
        targetBuildingName: 'Academic Block 1',
        startsAt: DateTime.now(),
      );

      final container = ProviderContainer(
        overrides: [
          latestHomeNoticeProvider.overrideWithValue(notice),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: NoticeBannerCard(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Solar Panels Inspection'), findsOneWidget);
      expect(find.text('Solar arrays inspection in Academic Block 1.'), findsOneWidget);
      expect(find.text('Academic Block 1'), findsOneWidget);
      expect(find.text('PINNED'), findsOneWidget);
      expect(find.text('Tap to read →'), findsOneWidget);
    });
  });

  group('Custom Challenge Domain & Points Customization Tests', () {
    test('1. DailyChallenge parses custom reward points and criteria from get_student_challenges', () {
      final json = {
        'id': 'ch-uuid-1',
        'challenge_key': 'water_hero_block_b',
        'title': 'Block B Water Guardian',
        'description': 'Report any water leak in Boys Hostel Block B.',
        'instructions': 'Spot a leaking tap in washrooms and submit a Water report.',
        'challenge_type': 'building_reporting',
        'category': 'water',
        'building_id': 'bldg-2',
        'building_name': 'Hostel Block B',
        'target_count': 1,
        'reward_points': 65, // Admin custom configured points!
        'recurrence_type': 'daily',
        'is_pinned': true,
        'progress_count': 0,
        'is_completed': false,
        'period_key': '2026-10-17',
      };

      final challenge = DailyChallenge.fromJson(json);

      expect(challenge.id, 'ch-uuid-1');
      expect(challenge.title, 'Block B Water Guardian');
      expect(challenge.rewardPoints, 65); // Authoritative reward points
      expect(challenge.category, 'water');
      expect(challenge.buildingName, 'Hostel Block B');
      expect(challenge.recurrenceLabel, 'DAILY');
      expect(challenge.progressFraction, 0.0);
      expect(challenge.progressLabel, '0 / 1');
      expect(challenge.isCompleted, isFalse);
    });

    test('2. Multi-report weekly challenge calculates progress fraction accurately', () {
      final challenge = DailyChallenge(
        challengeKey: 'weekly_recycler',
        title: 'Weekly Recycling Leader',
        description: 'Submit 3 reports in the waste category this week.',
        targetCount: 3,
        progressCount: 2,
        rewardPoints: 100, // Custom 100 points
        recurrenceType: 'weekly',
        isCompleted: false,
        challengeDate: '2026-W42',
      );

      expect(challenge.targetCount, 3);
      expect(challenge.progressCount, 2);
      expect(challenge.progressFraction, closeTo(2 / 3, 0.01));
      expect(challenge.progressLabel, '2 / 3');
      expect(challenge.rewardPoints, 100);
      expect(challenge.recurrenceLabel, 'WEEKLY');
    });

    test('3. Completed challenge returns 1.0 progressFraction and Completed label', () {
      final challenge = DailyChallenge(
        challengeKey: 'campus_clean_champ',
        title: 'Campus Cleanliness Sentinel',
        description: 'Submit 1 cleanliness report.',
        targetCount: 1,
        progressCount: 1,
        rewardPoints: 50,
        isCompleted: true,
        challengeDate: '2026-10-17',
      );

      expect(challenge.progressFraction, 1.0);
      expect(challenge.progressLabel, 'Completed');
      expect(challenge.rewardPoints, 50);
    });
  });
}

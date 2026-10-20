import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ecocampus_mobile/core/theme/app_theme.dart';
import 'package:ecocampus_mobile/features/home/data/home_providers.dart';
import 'package:ecocampus_mobile/features/home/presentation/student_home_screen.dart';
import 'package:ecocampus_mobile/features/report/data/reports_provider.dart';
import 'package:ecocampus_mobile/features/report/domain/report_model.dart';
import 'package:ecocampus_mobile/features/reports_tracking/presentation/report_detail_screen.dart';
import 'package:ecocampus_mobile/features/rewards/data/eco_points_provider.dart';
import 'package:ecocampus_mobile/features/rewards/domain/eco_points_model.dart';

class _FakeCampusReportsNotifier extends CampusReportsNotifier {
  final List<ReportModel> _feed;
  _FakeCampusReportsNotifier(this._feed);

  @override
  FutureOr<List<ReportModel>> build() => _feed;

  @override
  Future<void> refresh() async {
    state = AsyncData(_feed);
  }
}

class _FakeMyReportsNotifier extends MyReportsNotifier {
  final List<ReportModel> _reports;
  _FakeMyReportsNotifier(this._reports);

  @override
  FutureOr<List<ReportModel>> build() {
    ref.read(reportsProvider.notifier).setReports(_reports);
    return _reports;
  }

  @override
  Future<void> refresh() async {
    ref.read(reportsProvider.notifier).setReports(_reports);
    state = AsyncData(_reports);
  }
}

class _FakeEcoPointsNotifier extends EcoPointsNotifier {
  @override
  FutureOr<EcoPointsSummary> build() => EcoPointsSummary.zero();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Home Page Image Loading Pipeline Tests', () {
    test('ReportModel.fromCampusIssueFeedJson correctly maps storage_path and signedUrl', () {
      final json = {
        'id': 'd87c45aa-11a0-4901-8aef-3034104f5859',
        'category': 'waste',
        'severity': 'medium',
        'issue_label': 'Overflowing Campus Trash Bin',
        'description': 'A dark slatted outdoor trash receptacle is overflowing.',
        'status': 'REPORTED',
        'created_at': '2026-10-20T12:20:31.064804+00:00',
        'building_name': 'Engineering Block',
        'floor_label': 'Fourth Floor',
        'location_details': 'Floor 4 walkway',
        'latitude': 28.9997,
        'longitude': 77.0034,
        'storage_path': 'user-123/draft-456/photo.jpg',
      };

      const signedUrl = 'https://example.supabase.co/storage/v1/object/sign/report-photos/user-123/draft-456/photo.jpg?token=abc';

      final model = ReportModel.fromCampusIssueFeedJson(
        json,
        signedUrl: signedUrl,
      );

      expect(model.id, 'd87c45aa-11a0-4901-8aef-3034104f5859');
      expect(model.title, 'Overflowing Campus Trash Bin');
      expect(model.imageUrl, signedUrl);
      expect(model.media.length, 1);
      expect(model.media.first.storagePath, 'user-123/draft-456/photo.jpg');
      expect(model.media.first.signedUrl, signedUrl);
    });

    test('ReportModel.fromCampusIssueFeedJson handles null storage_path gracefully', () {
      final json = {
        'id': 'cd3e4f66-eefa-41dd-aacf-c13d428590e6',
        'category': 'water',
        'severity': 'low',
        'issue_label': 'Leaking pipe',
        'description': 'Slow drip near fountain.',
        'status': 'REPORTED',
        'created_at': '2026-10-20T12:00:00.000000+00:00',
        'building_name': 'Library',
        'floor_label': 'Ground Floor',
        'location_details': 'East entrance',
        'storage_path': null,
      };

      final model = ReportModel.fromCampusIssueFeedJson(json);

      expect(model.id, 'cd3e4f66-eefa-41dd-aacf-c13d428590e6');
      expect(model.imageUrl, isNull);
      expect(model.media, isEmpty);
    });

    testWidgets('Home page displays Image.network with BoxFit.cover and fixed bounds for report with photo', (tester) async {
      final reportWithPhoto = ReportModel(
        id: 'rep-photo-001',
        title: 'Overflowing Bin',
        category: IssueCategory.waste,
        severity: IssueSeverity.high,
        location: const CampusLocation(building: 'Block B', floor: '1st Floor', area: 'Corridor'),
        status: ReportStatus.reported,
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        description: 'Trash spilling onto walkway',
        imageUrl: 'https://example.com/photos/trash.jpg',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            greetingProvider.overrideWithValue('Good afternoon'),
            campusReportsProvider.overrideWith(() => _FakeCampusReportsNotifier([reportWithPhoto])),
            myReportsProvider.overrideWith(() => _FakeMyReportsNotifier([])),
            ecoPointsProvider.overrideWith(_FakeEcoPointsNotifier.new),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: StudentHomeScreen(onNavigateToReports: () {}),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Overflowing Bin'), findsOneWidget);

      // Verify Image.network widget is rendered
      final imageFinder = find.byType(Image);
      expect(imageFinder, findsWidgets);

      final networkImageFinder = find.byWidgetPredicate(
        (w) {
          if (w is! Image) return false;
          final img = w.image;
          if (img is ResizeImage && img.imageProvider is NetworkImage) {
            return (img.imageProvider as NetworkImage).url == 'https://example.com/photos/trash.jpg';
          }
          if (img is NetworkImage) {
            return img.url == 'https://example.com/photos/trash.jpg';
          }
          return false;
        },
      );
      expect(networkImageFinder, findsOneWidget);

      final imageWidget = tester.widget<Image>(networkImageFinder);
      expect(imageWidget.fit, BoxFit.cover);
      expect(imageWidget.image, isA<ResizeImage>());
      final resizeImage = imageWidget.image as ResizeImage;
      expect(resizeImage.width, 168);
      expect(resizeImage.height, 168);

      // Verify the parent container bounds: width 56, height 56, radius 14
      final sizedBoxFinder = find.ancestor(
        of: networkImageFinder,
        matching: find.byWidgetPredicate(
          (w) => w is SizedBox && w.width == 56 && w.height == 56,
        ),
      );
      expect(sizedBoxFinder, findsOneWidget);

      final clipRRectFinder = find.ancestor(
        of: networkImageFinder,
        matching: find.byType(ClipRRect),
      );
      expect(clipRRectFinder, findsWidgets);
      final clipRRect = tester.widget<ClipRRect>(clipRRectFinder.first);
      expect(clipRRect.borderRadius, BorderRadius.circular(14));
    });

    testWidgets('Home page displays neutral camera placeholder when report has no imageUrl', (tester) async {
      final reportNoPhoto = ReportModel(
        id: 'rep-no-photo-002',
        title: 'Broken Bench',
        category: IssueCategory.infrastructure,
        severity: IssueSeverity.low,
        location: const CampusLocation(building: 'Library', floor: 'Ground Floor', area: 'Garden'),
        status: ReportStatus.reported,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        description: 'Wooden slat damaged',
        imageUrl: null,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            greetingProvider.overrideWithValue('Good afternoon'),
            campusReportsProvider.overrideWith(() => _FakeCampusReportsNotifier([reportNoPhoto])),
            myReportsProvider.overrideWith(() => _FakeMyReportsNotifier([])),
            ecoPointsProvider.overrideWith(_FakeEcoPointsNotifier.new),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: StudentHomeScreen(onNavigateToReports: () {}),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Broken Bench'), findsOneWidget);

      // Should display Icons.photo_camera_outlined fallback
      expect(find.byIcon(Icons.photo_camera_outlined), findsOneWidget);

      // Verify no NetworkImage was instantiated for this report
      final networkImageFinder = find.byWidgetPredicate(
        (w) => w is Image && w.image is NetworkImage,
      );
      expect(networkImageFinder, findsNothing);
    });

    testWidgets('Tapping report card with photo navigates to ReportDetailScreen with initialReport preserved', (tester) async {
      final reportWithPhoto = ReportModel(
        id: 'rep-detail-003',
        title: 'Leaking Pipe in Washroom',
        category: IssueCategory.water,
        severity: IssueSeverity.critical,
        location: const CampusLocation(building: 'Block C', floor: '2nd Floor', area: 'Washroom 204'),
        status: ReportStatus.reported,
        createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
        description: 'Water spraying from valve',
        imageUrl: 'https://example.com/photos/water_leak.jpg',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            greetingProvider.overrideWithValue('Good morning'),
            campusReportsProvider.overrideWith(() => _FakeCampusReportsNotifier([reportWithPhoto])),
            myReportsProvider.overrideWith(() => _FakeMyReportsNotifier([])),
            ecoPointsProvider.overrideWith(_FakeEcoPointsNotifier.new),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: StudentHomeScreen(onNavigateToReports: () {}),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Scroll card into view and tap (avoid pumpAndSettle due to continuous ambient mascot animation)
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Leaking Pipe in Washroom'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // ReportDetailScreen is shown
      expect(find.byType(ReportDetailScreen), findsOneWidget);
      expect(find.text('rep-detail-003'), findsOneWidget);
      expect(find.text('Water spraying from valve'), findsOneWidget);

      // Detail screen has NetworkImage for the report photo
      final detailImageFinder = find.byWidgetPredicate(
        (w) {
          if (w is! Image) return false;
          final img = w.image;
          if (img is ResizeImage && img.imageProvider is NetworkImage) {
            return (img.imageProvider as NetworkImage).url == 'https://example.com/photos/water_leak.jpg';
          }
          if (img is NetworkImage) {
            return img.url == 'https://example.com/photos/water_leak.jpg';
          }
          return false;
        },
      );
      expect(detailImageFinder, findsOneWidget);
    });

    testWidgets('nearbyReportsProvider merges and preserves imageUrl from user reports if campus feed has none', (tester) async {
      final campusVersion = ReportModel(
        id: 'rep-sync-004',
        title: 'Litter in Quad',
        category: IssueCategory.waste,
        severity: IssueSeverity.medium,
        location: const CampusLocation(building: 'Quad', floor: 'Ground', area: 'Lawn'),
        status: ReportStatus.reported,
        createdAt: DateTime.now(),
        description: 'Plastic bottles',
        imageUrl: null, // Feed temporarily had no URL
      );

      final userVersion = ReportModel(
        id: 'rep-sync-004',
        title: 'Litter in Quad',
        category: IssueCategory.waste,
        severity: IssueSeverity.medium,
        location: const CampusLocation(building: 'Quad', floor: 'Ground', area: 'Lawn'),
        status: ReportStatus.reported,
        createdAt: DateTime.now(),
        description: 'Plastic bottles',
        imageUrl: 'https://example.com/photos/litter.jpg', // User submitted with URL
      );

      final container = ProviderContainer(
        overrides: [
          campusReportsProvider.overrideWith(() => _FakeCampusReportsNotifier([campusVersion])),
          myReportsProvider.overrideWith(() => _FakeMyReportsNotifier([userVersion])),
        ],
      );
      addTearDown(container.dispose);

      // Build MyReportsNotifier so reportsProvider has the user's report
      container.read(myReportsProvider);
      final nearby = container.read(nearbyReportsProvider);

      expect(nearby.length, 1);
      expect(nearby.first.id, 'rep-sync-004');
      // Must preserve the imageUrl from user version
      expect(nearby.first.imageUrl, 'https://example.com/photos/litter.jpg');
    });

    testWidgets('errorBuilder renders clean fallback when network image fails to load without distorting layout', (tester) async {
      final reportWithErrorPhoto = ReportModel(
        id: 'rep-err-005',
        title: 'Broken Glass',
        category: IssueCategory.infrastructure,
        severity: IssueSeverity.high,
        location: const CampusLocation(building: 'Science Block', floor: '1st Floor', area: 'Lab 3'),
        status: ReportStatus.reported,
        createdAt: DateTime.now(),
        description: 'Glass shards on floor',
        imageUrl: 'https://invalid-nonexistent-domain.test/broken.jpg',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            greetingProvider.overrideWithValue('Good evening'),
            campusReportsProvider.overrideWith(() => _FakeCampusReportsNotifier([reportWithErrorPhoto])),
            myReportsProvider.overrideWith(() => _FakeMyReportsNotifier([])),
            ecoPointsProvider.overrideWith(_FakeEcoPointsNotifier.new),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: StudentHomeScreen(onNavigateToReports: () {}),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Network image is in tree with errorBuilder attached
      final networkImageFinder = find.byWidgetPredicate(
        (w) {
          if (w is! Image) return false;
          final img = w.image;
          if (img is ResizeImage && img.imageProvider is NetworkImage) {
            return (img.imageProvider as NetworkImage).url == 'https://invalid-nonexistent-domain.test/broken.jpg';
          }
          if (img is NetworkImage) {
            return img.url == 'https://invalid-nonexistent-domain.test/broken.jpg';
          }
          return false;
        },
      );
      expect(networkImageFinder, findsOneWidget);

      final imageWidget = tester.widget<Image>(networkImageFinder);
      expect(imageWidget.errorBuilder, isNotNull);

      // Invoke errorBuilder directly to verify clean placeholder
      final errorWidget = imageWidget.errorBuilder!(tester.element(networkImageFinder), Exception('HTTP 404'), null);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SizedBox(width: 56, height: 56, child: errorWidget)),
        ),
      );

      expect(find.byIcon(Icons.photo_camera_outlined), findsOneWidget);
    });

    test('Report with multiple images parses all media records correctly', () {
      final json = {
        'id': 'rep-multi-006',
        'title': 'Tree Branch Fallen',
        'category': 'greenery',
        'severity': 'medium',
        'location_details': 'Path near hostel',
        'created_at': '2026-10-21T00:00:00Z',
        'buildings': {'id': 'b-hostel', 'name': 'Hostel'},
        'floors': null,
        'report_media': [
          {
            'id': 'm-1',
            'report_id': 'rep-multi-006',
            'storage_path': 'user-1/rep-multi-006/photo1.jpg',
            'mime_type': 'image/jpeg',
            'position': 0,
          },
          {
            'id': 'm-2',
            'report_id': 'rep-multi-006',
            'storage_path': 'user-1/rep-multi-006/photo2.jpg',
            'mime_type': 'image/jpeg',
            'position': 1,
          },
        ],
      };

      final report = ReportModel.fromSupabaseJson(
        json,
        primarySignedUrl: 'https://example.com/photo1.jpg?token=abc',
      );

      expect(report.id, 'rep-multi-006');
      expect(report.imageUrl, 'https://example.com/photo1.jpg?token=abc');
      expect(report.media.length, 2);
      expect(report.media[0].storagePath, 'user-1/rep-multi-006/photo1.jpg');
      expect(report.media[1].storagePath, 'user-1/rep-multi-006/photo2.jpg');
    });
  });
}

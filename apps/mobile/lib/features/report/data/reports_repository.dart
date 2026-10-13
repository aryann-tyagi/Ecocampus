import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/supabase_client_provider.dart';
import '../domain/report_model.dart';

/// Draft payload containing all validated fields to submit a new issue report.
class ReportSubmissionDraft {
  final String draftId;
  final String title;
  final IssueCategory category;
  final IssueSeverity severity;
  final String buildingId;
  final String? floorId;
  final String? floorText;
  final String? areaId;
  final String locationDetails;
  final String description;
  final String? suggestedDepartmentLabel;
  final double? latitude;
  final double? longitude;
  final Uint8List photoBytes;
  final String photoMimeType;
  final String photoFileName;

  const ReportSubmissionDraft({
    required this.draftId,
    required this.title,
    required this.category,
    required this.severity,
    required this.buildingId,
    this.floorId,
    this.floorText,
    this.areaId,
    required this.locationDetails,
    required this.description,
    this.suggestedDepartmentLabel,
    this.latitude,
    this.longitude,
    required this.photoBytes,
    required this.photoMimeType,
    required this.photoFileName,
  });
}

class _CachedUrl {
  final String url;
  final DateTime expiresAt;
  _CachedUrl(this.url, this.expiresAt);
  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Repository managing report creation, photo upload, and student report queries.
class ReportsRepository {
  final SupabaseClient? _client;
  final Map<String, _CachedUrl> _signedUrlCache = {};

  ReportsRepository(this._client);

  /// Clears in-memory signed URL cache on sign-out and account switch.
  void clearCache() {
    _signedUrlCache.clear();
  }

  /// Helper to get a short-lived signed URL for a private storage path.
  Future<String?> getSignedPhotoUrl(String storagePath, {int expiresIn = 3600}) async {
    final client = _client;
    if (client == null || storagePath.isEmpty) return null;

    final cached = _signedUrlCache[storagePath];
    if (cached != null && !cached.isExpired) {
      return cached.url;
    }

    try {
      final signedUrl = await client.storage
          .from('report-photos')
          .createSignedUrl(storagePath, expiresIn);

      _signedUrlCache[storagePath] = _CachedUrl(
        signedUrl,
        DateTime.now().add(Duration(seconds: expiresIn - 60)),
      );
      return signedUrl;
    } catch (e) {
      debugPrint('Failed to generate signed URL for $storagePath: $e');
      return null;
    }
  }

  /// Submits an issue report and links its uploaded photograph.
  ///
  /// Safe workflow sequence:
  /// 1. Upload photo to private `report-photos` bucket under `{userId}/{draftId}/`.
  /// 2. Insert report row in `public.reports` with default status (`REPORTED`).
  /// 3. Insert media row in `public.report_media`.
  /// 4. Cleans up orphan storage file if initial report insert fails.
  Future<ReportModel> submitReport({
    required ReportSubmissionDraft draft,
    required String userId,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase client is not initialized.');
    }

    final ext = _getExtensionFromMime(draft.photoMimeType);
    final storagePath = '$userId/${draft.draftId}/photo.$ext';

    // Step 1: Upload photo to private storage
    try {
      await client.storage.from('report-photos').uploadBinary(
            storagePath,
            draft.photoBytes,
            fileOptions: FileOptions(
              contentType: draft.photoMimeType,
              upsert: true,
            ),
          );
    } catch (e) {
      debugPrint('Photo upload failed: $e');
      rethrow;
    }

    String? createdReportId;
    try {
      // Step 2: Insert report record
      final payload = <String, dynamic>{
        'reporter_id': userId,
        'building_id': draft.buildingId,
        'location_details': draft.locationDetails.trim(),
        'category': draft.category.toDbValue(),
        'severity': draft.severity.toDbValue(),
        'issue_label': draft.title.trim(),
        'description': draft.description.trim(),
      };

      if (draft.floorId != null && draft.floorId!.isNotEmpty) {
        payload['floor_id'] = draft.floorId;
      } else if (draft.floorText != null && draft.floorText!.trim().isNotEmpty) {
        payload['floor_text'] = draft.floorText!.trim();
      }

      if (draft.areaId != null && draft.areaId!.isNotEmpty) {
        payload['area_id'] = draft.areaId;
      }

      if (draft.suggestedDepartmentLabel != null &&
          draft.suggestedDepartmentLabel!.isNotEmpty) {
        payload['suggested_department_label'] = draft.suggestedDepartmentLabel;
      }

      if (draft.latitude != null && draft.longitude != null) {
        payload['latitude'] = draft.latitude;
        payload['longitude'] = draft.longitude;
      }

      final reportRow = await client.from('reports').insert(payload).select('''
        *,
        buildings(id, name, slug),
        floors(id, label, sort_order)
      ''').single();

      createdReportId = (reportRow['id'] as String?) ?? '';

      // Step 3: Insert report media record
      await client.from('report_media').insert({
        'report_id': createdReportId,
        'uploader_id': userId,
        'storage_path': storagePath,
        'mime_type': draft.photoMimeType,
        'position': 0,
      });

      // Step 4: Resolve signed URL for immediate preview
      final signedUrl = await getSignedPhotoUrl(storagePath);

      return ReportModel.fromSupabaseJson(
        reportRow,
        primarySignedUrl: signedUrl,
      );
    } catch (e) {
      debugPrint('Report database creation error: $e');
      // If report was not created, clean up orphan image from storage
      if (createdReportId == null) {
        try {
          await client.storage.from('report-photos').remove([storagePath]);
        } catch (_) {}
      }
      rethrow;
    }
  }

  /// Fetches reports submitted by [userId], ordered newest first.
  Future<List<ReportModel>> getMyReports(String userId) async {
    final client = _client;
    if (client == null) return const [];

    try {
      final data = await client
          .from('reports')
          .select('''
            *,
            buildings(id, name, slug),
            floors(id, label, sort_order),
            areas(id, name),
            report_media(id, report_id, storage_path, mime_type, position, created_at),
            report_status_events(id, report_id, from_status, to_status, actor_id, note, occurred_at)
          ''')
          .eq('reporter_id', userId)
          .order('created_at', ascending: false);

      final rawList =
          (data as List<dynamic>).whereType<Map<dynamic, dynamic>>().toList();

      final reports = await Future.wait(rawList.map((item) async {
        final json = item.cast<String, dynamic>();
        final rawMedia = json['report_media'] as List<dynamic>? ?? [];
        String? primarySignedUrl;

        if (rawMedia.isNotEmpty) {
          final firstItem = rawMedia.first;
          if (firstItem is Map) {
            final firstPath = firstItem['storage_path'] as String?;
            if (firstPath != null && firstPath.isNotEmpty) {
              primarySignedUrl = await getSignedPhotoUrl(firstPath);
            }
          }
        }

        return ReportModel.fromSupabaseJson(
          json,
          primarySignedUrl: primarySignedUrl,
        );
      }));

      return reports;
    } catch (e) {
      debugPrint('getMyReports failed: $e');
      rethrow;
    }
  }

  /// Fetches campus-wide issue cards from get_campus_issue_feed RPC.
  /// Protects reporter privacy and includes nullable coordinates and floor labels safely.
  Future<List<ReportModel>> getNearbyReports({
    int limit = 10,
    double? userLat,
    double? userLng,
  }) async {
    final client = _client;
    if (client == null) return const [];

    try {
      final result = await client.rpc('get_campus_issue_feed', params: {
        'p_limit': limit,
      });

      if (result is List) {
        return result.whereType<Map>().map((row) {
          final json = row.cast<String, dynamic>();
          return ReportModel.fromCampusIssueFeedJson(
            json,
            userLat: userLat,
            userLng: userLng,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('get_campus_issue_feed RPC failed: $e');
    }

    return const [];
  }

  /// Fetches a single report by [reportId] belonging to [userId].
  Future<ReportModel?> getReportDetail(String reportId, String userId) async {
    final client = _client;
    if (client == null) return null;

    try {
      final data = await client
          .from('reports')
          .select('''
            *,
            buildings(id, name, slug),
            floors(id, label, sort_order),
            areas(id, name),
            report_media(id, report_id, storage_path, mime_type, position, created_at),
            report_status_events(id, report_id, from_status, to_status, actor_id, note, occurred_at)
          ''')
          .eq('id', reportId)
          .eq('reporter_id', userId)
          .maybeSingle();

      if (data == null) return null;

      final json = data;
      final rawMedia = json['report_media'] as List<dynamic>? ?? [];
      String? primarySignedUrl;
      if (rawMedia.isNotEmpty) {
        final firstItem = rawMedia.first;
        if (firstItem is Map) {
          final firstPath = firstItem['storage_path'] as String?;
          if (firstPath != null && firstPath.isNotEmpty) {
            primarySignedUrl = await getSignedPhotoUrl(firstPath);
          }
        }
      }

      return ReportModel.fromSupabaseJson(
        json,
        primarySignedUrl: primarySignedUrl,
      );
    } catch (e) {
      debugPrint('getReportDetail failed: $e');
      rethrow;
    }
  }

  String _getExtensionFromMime(String mimeType) {
    switch (mimeType.toLowerCase()) {
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      case 'image/jpeg':
      case 'image/jpg':
      default:
        return 'jpg';
    }
  }
}

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ReportsRepository(client);
});

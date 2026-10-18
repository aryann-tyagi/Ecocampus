import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/supabase_client_provider.dart';
import '../domain/ai_analysis_models.dart';
import '../domain/duplicate_detection_models.dart';
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

    // Client-side pre-validation to avoid unnecessary photo upload and check constraint violations
    final locationValidation = LocationDetailsValidator.validate(draft.locationDetails, isRequired: true);
    if (locationValidation != null) {
      throw ReportSubmissionException(
        locationValidation,
        code: '23514',
        field: 'location_details',
      );
    }

    if (draft.title.trim().isEmpty || draft.title.trim().length > 160) {
      throw const ReportSubmissionException(
        'Issue title must be between 1 and 160 characters.',
        code: '23514',
        field: 'title',
      );
    }

    if (draft.description.trim().isEmpty) {
      throw const ReportSubmissionException(
        'Issue description cannot be empty.',
        code: '23514',
        field: 'description',
      );
    }

    if (draft.floorText != null &&
        (draft.floorText!.trim().isEmpty || draft.floorText!.trim().length > 80)) {
      throw const ReportSubmissionException(
        'Floor text must be between 1 and 80 characters.',
        code: '23514',
        field: 'floor_text',
      );
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
      final resolvedIssueLabel = draft.title.trim().isNotEmpty && draft.title.trim().toLowerCase() != 'unnamed'
          ? draft.title.trim()
          : (draft.description.trim().isNotEmpty
              ? (draft.description.trim().length > 60
                  ? '${draft.description.trim().substring(0, 57)}...'
                  : draft.description.trim())
              : '${draft.category.displayName} Issue');

      final payload = <String, dynamic>{
        'reporter_id': userId,
        'building_id': draft.buildingId,
        'location_details': draft.locationDetails.trim(),
        'category': draft.category.toDbValue(),
        'severity': draft.severity.toDbValue(),
        'issue_label': resolvedIssueLabel,
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

      // Step 5: Asynchronously trigger FCM push to student device (non-blocking)
      try {
        unawaited(client.functions.invoke('send-fcm-notification', body: {
          'userId': userId,
          'title': 'Report Submitted',
          'body': 'Your report for "$resolvedIssueLabel" has been received and logged for review.',
          'data': {'report_id': createdReportId, 'event_type': 'report_submitted'},
        }).catchError((err, st) {
          debugPrint('FCM push dispatch notice: $err');
          return FunctionResponse(status: 500);
        }));
      } catch (_) {}

      return ReportModel.fromSupabaseJson(
        reportRow,
        primarySignedUrl: signedUrl,
      );
    } on PostgrestException catch (e) {
      debugPrint('PostgrestException during report creation: ${e.message} (code: ${e.code})');
      if (createdReportId == null) {
        try {
          await client.storage.from('report-photos').remove([storagePath]);
        } catch (_) {}
      }

      final errorMsg = e.message.toLowerCase();
      final errorDetails = (e.details?.toString() ?? '').toLowerCase();

      if (e.code == '23514' || errorMsg.contains('check constraint')) {
        if (errorMsg.contains('location_details') ||
            errorMsg.contains('location_detials') ||
            errorDetails.contains('location_details') ||
            errorDetails.contains('location_detials')) {
          throw const ReportSubmissionException(
            'Location details must be between 2 and 255 characters.',
            code: '23514',
            field: 'location_details',
          );
        }
        if (errorMsg.contains('floor_text') || errorDetails.contains('floor_text')) {
          throw const ReportSubmissionException(
            'Floor text must be between 1 and 80 characters.',
            code: '23514',
            field: 'floor_text',
          );
        }
        if (errorMsg.contains('issue_label') || errorDetails.contains('issue_label')) {
          throw const ReportSubmissionException(
            'Issue title must be between 1 and 160 characters.',
            code: '23514',
            field: 'issue_label',
          );
        }
        if (errorMsg.contains('description') || errorDetails.contains('description')) {
          throw const ReportSubmissionException(
            'Issue description cannot be empty.',
            code: '23514',
            field: 'description',
          );
        }
        throw ReportSubmissionException(
          'Database validation failed: Please ensure all report fields satisfy constraints.',
          code: e.code,
        );
      } else if (e.code == '42501' || errorMsg.contains('permission denied')) {
        throw const ReportSubmissionException(
          'Database permission error: Unable to submit report. Please check authentication.',
          code: '42501',
        );
      }
      throw ReportSubmissionException(
        'Failed to submit report due to database error (${e.code ?? 'unknown'}).',
        code: e.code,
      );
    } catch (e) {
      debugPrint('Report database creation error: $e');
      // If report was not created, clean up orphan image from storage
      if (createdReportId == null) {
        try {
          await client.storage.from('report-photos').remove([storagePath]);
        } catch (_) {}
      }
      if (e is ReportSubmissionException) rethrow;
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
            assigned_department:departments!reports_assigned_department_id_fkey(id, name, slug),
            suggested_department:departments!reports_suggested_department_id_fkey(id, name, slug),
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
            assigned_department:departments!reports_assigned_department_id_fkey(id, name, slug),
            suggested_department:departments!reports_suggested_department_id_fkey(id, name, slug),
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

  /// Analyzes a photo using the Supabase Edge Function `analyze-report`.
  /// Calls the Gemini multimodal intelligence endpoint. If the service is
  /// unavailable, unconfigured, or times out, this method throws [AiAnalysisException]
  /// to ensure the student is accurately informed rather than presenting synthetic
  /// or misleading hardcoded classifications.
  Future<AiIssueAnalysis> analyzeReport({
    required Uint8List photoBytes,
    required String photoMimeType,
    String? userDescription,
  }) async {
    final client = _client;

    if (client == null) {
      throw const AiAnalysisException(
        code: 'CLIENT_NOT_INITIALIZED',
        message: 'Supabase client is not initialized. Please enter details manually.',
      );
    }

    try {
      final base64Image = base64Encode(photoBytes);
      final response = await client.functions.invoke(
        'analyze-report',
        body: {
          'imageBase64': base64Image,
          'mimeType': photoMimeType,
          'userDescription': userDescription ?? '',
        },
      );

      if (response.status == 200 && response.data != null) {
        final data = response.data;
        if (data is Map && data['ok'] == true && data['data'] is Map) {
          return AiIssueAnalysis.fromJson(
            (data['data'] as Map).cast<String, dynamic>(),
          );
        } else if (data is Map && data['issue_title'] != null) {
          return AiIssueAnalysis.fromJson(data.cast<String, dynamic>());
        } else if (data is Map && data['ok'] == false && data['error'] is Map) {
          final errMap = (data['error'] as Map).cast<String, dynamic>();
          throw AiAnalysisException(
            code: errMap['code']?.toString() ?? 'AI_ERROR',
            message: errMap['message']?.toString() ?? 'AI analysis service reported an error.',
          );
        }
      }

      // Handle non-200 responses
      if (response.status == 404) {
        throw const AiAnalysisException(
          code: 'FUNCTION_NOT_FOUND',
          message: 'AI analysis service is not deployed on this server (404 Not Found). Please report manually.',
        );
      } else if (response.status == 503) {
        throw const AiAnalysisException(
          code: 'AI_SERVICE_UNAVAILABLE',
          message: 'AI service is temporarily experiencing high demand. Please try again or continue with manual entry.',
        );
      } else if (response.status == 429) {
        throw const AiAnalysisException(
          code: 'RATE_LIMITED',
          message: 'AI service rate limit reached. Please proceed with manual entry.',
        );
      } else if (response.status == 504) {
        throw const AiAnalysisException(
          code: 'AI_TIMEOUT',
          message: 'AI analysis request timed out. You can enter details manually.',
        );
      } else {
        throw AiAnalysisException(
          code: 'SERVER_ERROR_${response.status}',
          message: 'AI service returned status ${response.status}. Please enter details manually.',
        );
      }
    } on FunctionException catch (e) {
      debugPrint('analyze-report Edge Function error status ${e.status}: ${e.details}');
      if (e.status == 404) {
        throw const AiAnalysisException(
          code: 'FUNCTION_NOT_FOUND',
          message: 'AI analysis function was not found on the server (404 Not Found). Please enter details manually.',
        );
      }
      final detailsMap = e.details is Map ? e.details as Map : null;
      final errorMap = detailsMap?['error'] is Map ? detailsMap!['error'] as Map : null;
      final serverCode = errorMap?['code']?.toString() ?? detailsMap?['code']?.toString();
      final serverMessage = errorMap?['message']?.toString() ?? detailsMap?['message']?.toString();

      if (e.status == 503 || serverCode == 'AI_SERVICE_UNAVAILABLE') {
        throw AiAnalysisException(
          code: 'AI_SERVICE_UNAVAILABLE',
          message: serverMessage ?? 'AI service is temporarily experiencing high demand. Please try again or continue with manual entry.',
        );
      } else if (e.status == 429 || serverCode == 'RATE_LIMITED') {
        throw AiAnalysisException(
          code: 'RATE_LIMITED',
          message: serverMessage ?? 'AI service rate limit reached. Please proceed with manual entry.',
        );
      }

      throw AiAnalysisException(
        code: serverCode ?? 'FUNCTION_ERROR_${e.status}',
        message: serverMessage ?? 'AI analysis is temporarily unavailable (${e.status}).',
      );
    } on AiAnalysisException {
      rethrow;
    } catch (e) {
      debugPrint('analyzeReport unexpected error: $e');
      throw AiAnalysisException(
        code: 'CONNECTION_ERROR',
        message: 'Could not connect to AI service ($e). You can continue with manual entry.',
      );
    }
  }

  /// Checks for active duplicate reports matching the proposed issue.
  /// First queries the Edge Function / Supabase RPC, then evaluates multi-signal similarity.
  Future<DuplicateCheckResult> checkDuplicates({
    required String buildingId,
    required IssueCategory category,
    required String title,
    required String description,
    String? floorId,
    String? floorText,
    String? locationDetails,
  }) async {
    final client = _client;

    if (client != null) {
      // 1. Attempt calling Edge Function
      try {
        final response = await client.functions.invoke(
          'find-duplicates',
          body: {
            'buildingId': buildingId,
            'category': category.toDbValue(),
            'title': title,
            'description': description,
            'floorId': floorId,
            'floorText': floorText ?? '',
            'locationDetails': locationDetails ?? '',
          },
        );

        if (response.status == 200 && response.data != null) {
          final data = response.data;
          if (data is Map && data['ok'] == true && data['data'] is Map) {
            return DuplicateCheckResult.fromJson(
              (data['data'] as Map).cast<String, dynamic>(),
            );
          } else if (data is Map && data['outcome'] != null) {
            return DuplicateCheckResult.fromJson(data.cast<String, dynamic>());
          }
        }
      } catch (e) {
        debugPrint('find-duplicates Edge Function call failed: $e');
      }

      // 2. Fallback to Supabase Database RPC
      try {
        final rpcResult = await client.rpc(
          'find_duplicate_candidates',
          params: {
            'p_building_id': buildingId,
            'p_category': category.toDbValue(),
            'p_floor_id': floorId,
            'p_limit': 10,
          },
        );

        if (rpcResult is List) {
          final rawRows = rpcResult
              .whereType<Map>()
              .map((r) => r.cast<String, dynamic>())
              .toList();

          return evaluateDuplicateCandidates(
            candidates: rawRows,
            proposedTitle: title,
            proposedDescription: description,
            proposedCategory: category,
            proposedFloorId: floorId,
            proposedFloorText: floorText,
            proposedLocationDetails: locationDetails,
          );
        }
      } catch (e) {
        debugPrint('find_duplicate_candidates RPC failed: $e');
      }
    }

    // When service is uninitialized or both service queries fail, return check_unavailable
    return DuplicateCheckResult.unavailable('Duplicate checking service is temporarily unavailable.');
  }

  /// Multi-signal similarity evaluator comparing proposed issue against shortlisted active candidates.
  static DuplicateCheckResult evaluateDuplicateCandidates({
    required List<Map<String, dynamic>> candidates,
    required String proposedTitle,
    required String proposedDescription,
    required IssueCategory proposedCategory,
    String? proposedFloorId,
    String? proposedFloorText,
    String? proposedLocationDetails,
  }) {
    if (candidates.isEmpty) {
      return DuplicateCheckResult.noMatch();
    }

    final proposedTokens = _tokenize('$proposedTitle $proposedDescription');
    final proposedLocTokens = _tokenize('${proposedFloorText ?? ""} ${proposedLocationDetails ?? ""}');

    final List<MapEntry<DuplicateCandidate, double>> scored = [];

    for (final c in candidates) {
      // Must be an active unresolved issue
      final status = ReportStatus.fromDbValue(c['status'] as String?);
      if (status == ReportStatus.resolved ||
          status == ReportStatus.rejected ||
          status == ReportStatus.duplicate) {
        continue;
      }

      double score = 0.0;

      // 1. Same building (guaranteed by query): +0.20
      score += 0.20;

      // 2. Floor comparison
      final candFloorId = c['floor_id'] as String?;
      final candFloorLabel = (c['floor_label'] as String?)?.toLowerCase().trim() ?? '';
      final candLocDetails = (c['location_details'] as String?)?.toLowerCase().trim() ?? '';

      bool floorMismatch = false;
      if (proposedFloorId != null && candFloorId != null) {
        if (proposedFloorId == candFloorId) {
          score += 0.15; // Same floor ID match
        } else {
          // Different floors in the same building indicate different physical incidents
          score -= 0.35;
          floorMismatch = true;
        }
      } else if (proposedFloorText != null &&
          proposedFloorText.trim().isNotEmpty &&
          candFloorLabel.isNotEmpty) {
        final floorSim = _tokenSimilarity(
          _tokenize(proposedFloorText),
          _tokenize(candFloorLabel),
        );
        if (floorSim > 0.5) {
          score += 0.12;
        } else if (floorSim == 0) {
          score -= 0.25;
          floorMismatch = true;
        }
      } else {
        score += 0.05;
      }

      // Exact location details similarity (room / corridor)
      if (proposedLocationDetails != null &&
          proposedLocationDetails.trim().isNotEmpty &&
          candLocDetails.isNotEmpty) {
        final locSim = _tokenSimilarity(
          proposedLocTokens,
          _tokenize(candLocDetails),
        );
        score += 0.10 * locSim;
      }

      // 3. Category compatibility (+0.15)
      final candCategory = IssueCategory.fromDbValue(c['category'] as String?);
      if (candCategory == proposedCategory) {
        score += 0.15;
      } else if (candCategory == IssueCategory.other ||
          proposedCategory == IssueCategory.other) {
        score += 0.05;
      }

      // 4. Description and title text similarity (+0.35)
      final candText = '${c['issue_label'] ?? ""} ${c['description'] ?? ""}';
      final textSim = _tokenSimilarity(proposedTokens, _tokenize(candText));
      score += 0.35 * textSim;

      // 5. Time proximity (+0.10 for active incidents within last 48h)
      DateTime? createdAt;
      if (c['created_at'] != null) {
        createdAt = DateTime.tryParse(c['created_at'].toString());
      }
      if (createdAt != null) {
        final diffHours = DateTime.now().difference(createdAt).inHours.abs();
        if (diffHours <= 24) {
          score += 0.10;
        } else if (diffHours <= 72) {
          score += 0.05;
        } else {
          score += 0.02;
        }
      }

      // Floor mismatch strictly caps maximum score to prevent false duplicate flagging
      final normalizedScore = floorMismatch
          ? score.clamp(0.0, 0.30)
          : score.clamp(0.0, 1.0);

      final candidateModel = DuplicateCandidate(
        reportId: (c['id'] ?? c['report_id'] ?? '') as String,
        title: (c['issue_label'] ?? c['title'] ?? 'Campus Issue') as String,
        category: candCategory,
        severity: IssueSeverity.fromDbValue(c['severity'] as String?),
        buildingName: (c['building_name'] ?? 'Campus Building') as String,
        floorName: c['floor_label'] as String?,
        areaName: c['location_details'] as String?,
        status: status,
        reportedAt: createdAt ?? DateTime.now(),
        similarityScore: double.parse(normalizedScore.toStringAsFixed(2)),
      );

      scored.add(MapEntry(candidateModel, normalizedScore));
    }

    if (scored.isEmpty) {
      return DuplicateCheckResult.noMatch();
    }

    scored.sort((a, b) => b.value.compareTo(a.value));

    final topMatch = scored.first;
    final topScore = topMatch.value;

    final topCand = topMatch.key;
    final topCandRow = candidates.firstWhere(
      (c) => (c['id'] ?? c['report_id']) == topCand.reportId,
      orElse: () => <String, dynamic>{},
    );
    final topCandText = '${topCandRow['issue_label'] ?? topCand.title} ${topCandRow['description'] ?? ""}';
    final topTextSim = _tokenSimilarity(proposedTokens, _tokenize(topCandText));

    DuplicateOutcome outcome = DuplicateOutcome.noMatch;
    String explanation = 'No similar active report was found.';

    // PRD & Workflow rule: Matching category and building alone are NEVER sufficient
    // without incident/textual evidence that they refer to the same occurrence.
    if (topTextSim >= 0.15) {
      if (topScore >= 0.65 && topTextSim >= 0.25) {
        outcome = DuplicateOutcome.likelyDuplicate;
        final bName = topCand.buildingName;
        final fName = topCand.floorName != null ? ' (${topCand.floorName})' : '';
        explanation = 'High similarity to an active report in $bName$fName. Both reports appear to describe the same incident.';
      } else if (topScore >= 0.45) {
        outcome = DuplicateOutcome.possibleMatch;
        final bName = topCand.buildingName;
        final fName = topCand.floorName != null ? ' (${topCand.floorName})' : '';
        explanation = 'Potential match found in $bName$fName. Review before submitting a new report.';
      }
    }

    final topCandidates = scored
        .where((s) => s.value >= 0.35)
        .take(3)
        .map((s) => s.key)
        .toList();

    return DuplicateCheckResult(
      outcome: outcome,
      explanation: explanation,
      candidates: outcome == DuplicateOutcome.noMatch ? [] : topCandidates,
    );
  }

  static Set<String> _tokenize(String text) {
    const stopwords = {
      'a', 'an', 'the', 'in', 'on', 'at', 'by', 'for', 'with', 'about',
      'against', 'between', 'into', 'through', 'during', 'before', 'after',
      'above', 'below', 'to', 'from', 'up', 'down', 'is', 'are', 'was', 'were',
      'and', 'or', 'not', 'this', 'that', 'these', 'those', 'near',
      'of', 'it', 'its', 'there', 'has', 'have', 'had', 'be', 'been',
    };

    final words = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2 && !stopwords.contains(w));

    return words.toSet();
  }

  static double _tokenSimilarity(Set<String> setA, Set<String> setB) {
    if (setA.isEmpty || setB.isEmpty) return 0.0;
    int intersection = 0;
    for (final token in setA) {
      if (setB.contains(token)) intersection++;
    }
    final union = setA.length + setB.length - intersection;
    return union > 0 ? intersection / union : 0.0;
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

import 'report_model.dart';

/// Outcomes for pre-submission intelligent duplicate detection.
enum DuplicateOutcome {
  likelyDuplicate,
  possibleMatch,
  noMatch,
  checkUnavailable;

  String get displayName {
    switch (this) {
      case DuplicateOutcome.likelyDuplicate:
        return 'Likely Duplicate';
      case DuplicateOutcome.possibleMatch:
        return 'Possible Match';
      case DuplicateOutcome.noMatch:
        return 'No Match';
      case DuplicateOutcome.checkUnavailable:
        return 'Check Unavailable';
    }
  }

  static DuplicateOutcome fromString(String? value) {
    if (value == null) return DuplicateOutcome.checkUnavailable;
    final normalized = value.trim().toLowerCase().replaceAll('-', '_');
    switch (normalized) {
      case 'likely_duplicate':
        return DuplicateOutcome.likelyDuplicate;
      case 'possible_match':
        return DuplicateOutcome.possibleMatch;
      case 'no_match':
        return DuplicateOutcome.noMatch;
      case 'check_unavailable':
      default:
        return DuplicateOutcome.checkUnavailable;
    }
  }
}

/// Redacted candidate issue model returned during duplicate checking.
/// Excludes private user IDs, reporter identities, and internal administrative notes.
class DuplicateCandidate {
  final String reportId;
  final String title;
  final IssueCategory category;
  final IssueSeverity severity;
  final String buildingName;
  final String? floorName;
  final String? areaName;
  final ReportStatus status;
  final DateTime reportedAt;
  final double? similarityScore;

  const DuplicateCandidate({
    required this.reportId,
    required this.title,
    required this.category,
    required this.severity,
    required this.buildingName,
    this.floorName,
    this.areaName,
    required this.status,
    required this.reportedAt,
    this.similarityScore,
  });

  factory DuplicateCandidate.fromJson(Map<String, dynamic> json) {
    return DuplicateCandidate(
      reportId: (json['report_id'] ?? json['id'] ?? '') as String,
      title: (json['title'] ?? json['issue_label'] ?? 'Campus Issue') as String,
      category: IssueCategory.fromDbValue(json['category'] as String?),
      severity: IssueSeverity.fromDbValue(json['severity'] as String?),
      buildingName: (json['building_name'] ?? 'Campus Building') as String,
      floorName: (json['floor_name'] ?? json['floor_label']) as String?,
      areaName: (json['area_name'] ?? json['location_details']) as String?,
      status: ReportStatus.fromDbValue(json['status'] as String?),
      reportedAt: json['reported_at'] != null
          ? (DateTime.tryParse(json['reported_at'].toString()) ?? DateTime.now())
          : (json['created_at'] != null
              ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
              : DateTime.now()),
      similarityScore: (json['similarity_score'] as num?)?.toDouble(),
    );
  }

  ReportModel toReportModel() {
    return ReportModel(
      id: reportId,
      title: title,
      category: category,
      severity: severity,
      location: CampusLocation(
        building: buildingName,
        floor: floorName ?? '',
        area: areaName ?? '',
      ),
      status: status,
      createdAt: reportedAt,
      description: 'Existing campus report.',
      media: const [],
      statusEvents: const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'report_id': reportId,
        'title': title,
        'category': category.toDbValue(),
        'severity': severity.toDbValue(),
        'building_name': buildingName,
        'floor_name': floorName,
        'area_name': areaName,
        'status': status.toDbValue(),
        'reported_at': reportedAt.toIso8601String(),
        'similarity_score': similarityScore,
      };
}

/// Composite result of pre-submission duplicate detection.
class DuplicateCheckResult {
  final DuplicateOutcome outcome;
  final String explanation;
  final List<DuplicateCandidate> candidates;

  const DuplicateCheckResult({
    required this.outcome,
    required this.explanation,
    this.candidates = const [],
  });

  bool get hasMatch =>
      outcome == DuplicateOutcome.likelyDuplicate ||
      outcome == DuplicateOutcome.possibleMatch;

  factory DuplicateCheckResult.noMatch() => const DuplicateCheckResult(
        outcome: DuplicateOutcome.noMatch,
        explanation: 'No similar active report was found.',
        candidates: [],
      );

  factory DuplicateCheckResult.unavailable([String? reason]) => DuplicateCheckResult(
        outcome: DuplicateOutcome.checkUnavailable,
        explanation: reason ?? 'Duplicate checking is temporarily unavailable.',
        candidates: const [],
      );

  factory DuplicateCheckResult.fromJson(Map<String, dynamic> json) {
    final rawOutcome = json['outcome'] as String?;
    final outcome = DuplicateOutcome.fromString(rawOutcome);
    final explanation = (json['explanation'] as String?) ?? '';

    final rawCandidates = json['candidates'] as List<dynamic>? ?? [];
    final candidates = rawCandidates
        .whereType<Map>()
        .map((c) => DuplicateCandidate.fromJson(c.cast<String, dynamic>()))
        .toList();

    return DuplicateCheckResult(
      outcome: outcome,
      explanation: explanation,
      candidates: candidates,
    );
  }
}

import 'report_model.dart';

/// Structured AI Issue Understanding result returned by the `analyze-report` Edge Function.
class AiIssueAnalysis {
  final String issueTitle;
  final String issueDescription;
  final IssueCategory category;
  final IssueSeverity severity;
  final String? department;
  final String confidence; // 'high' | 'medium' | 'low'
  final bool needsReview;
  final String reasoningSummary;

  const AiIssueAnalysis({
    required this.issueTitle,
    required this.issueDescription,
    required this.category,
    required this.severity,
    this.department,
    required this.confidence,
    required this.needsReview,
    required this.reasoningSummary,
  });

  factory AiIssueAnalysis.fromJson(Map<String, dynamic> json) {
    // Robust category mapping
    final rawCat = json['category'] as String?;
    final category = IssueCategory.fromDbValue(rawCat);

    // Robust severity mapping
    final rawSev = json['severity'] as String?;
    final severity = IssueSeverity.fromDbValue(rawSev);

    // Normalize confidence
    final rawConf = (json['confidence'] as String?)?.toLowerCase().trim() ?? 'medium';
    final confidence = (rawConf == 'high' || rawConf == 'low') ? rawConf : 'medium';

    return AiIssueAnalysis(
      issueTitle: (json['issue_title'] as String?)?.trim() ?? 'Campus Issue',
      issueDescription: (json['issue_description'] as String?)?.trim() ?? '',
      category: category,
      severity: severity,
      department: json['department'] as String?,
      confidence: confidence,
      needsReview: json['needs_review'] == true,
      reasoningSummary: (json['reasoning_summary'] as String?)?.trim() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'issue_title': issueTitle,
        'issue_description': issueDescription,
        'category': category.toDbValue(),
        'severity': severity.toDbValue(),
        'department': department,
        'confidence': confidence,
        'needs_review': needsReview,
        'reasoning_summary': reasoningSummary,
      };

  AiIssueAnalysis copyWith({
    String? issueTitle,
    String? issueDescription,
    IssueCategory? category,
    IssueSeverity? severity,
    String? department,
    String? confidence,
    bool? needsReview,
    String? reasoningSummary,
  }) {
    return AiIssueAnalysis(
      issueTitle: issueTitle ?? this.issueTitle,
      issueDescription: issueDescription ?? this.issueDescription,
      category: category ?? this.category,
      severity: severity ?? this.severity,
      department: department ?? this.department,
      confidence: confidence ?? this.confidence,
      needsReview: needsReview ?? this.needsReview,
      reasoningSummary: reasoningSummary ?? this.reasoningSummary,
    );
  }
}

/// Exception thrown when real AI Issue Understanding fails or is unavailable.
/// Used to prevent misleading deterministic fallbacks from being shown as AI results.
class AiAnalysisException implements Exception {
  final String code;
  final String message;

  const AiAnalysisException({
    required this.code,
    required this.message,
  });

  @override
  String toString() => message;
}

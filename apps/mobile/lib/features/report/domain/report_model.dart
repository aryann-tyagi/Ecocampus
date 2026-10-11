enum IssueCategory {
  waste,
  water,
  electricity,
  infrastructure,
  greenery,
  cleanliness,
  other;

  String get displayName {
    switch (this) {
      case IssueCategory.waste:
        return 'Waste';
      case IssueCategory.water:
        return 'Water';
      case IssueCategory.electricity:
        return 'Energy';
      case IssueCategory.infrastructure:
        return 'Infrastructure';
      case IssueCategory.greenery:
        return 'Greenery';
      case IssueCategory.cleanliness:
        return 'Cleanliness';
      case IssueCategory.other:
        return 'Other';
    }
  }
}

enum IssueSeverity {
  low,
  medium,
  high,
  critical;

  String get displayName {
    switch (this) {
      case IssueSeverity.low:
        return 'Low';
      case IssueSeverity.medium:
        return 'Medium';
      case IssueSeverity.high:
        return 'High';
      case IssueSeverity.critical:
        return 'Critical';
    }
  }
}

enum ReportStatus {
  reported,
  assigned,
  inProgress,
  resolved,
  rejected,
  duplicate;

  String get displayName {
    switch (this) {
      case ReportStatus.reported:
        return 'Reported';
      case ReportStatus.assigned:
        return 'Assigned';
      case ReportStatus.inProgress:
        return 'In Progress';
      case ReportStatus.resolved:
        return 'Resolved';
      case ReportStatus.rejected:
        return 'Rejected';
      case ReportStatus.duplicate:
        return 'Duplicate';
    }
  }
}

class CampusLocation {
  final String building;
  final String floor;
  final String area;

  const CampusLocation({
    required this.building,
    required this.floor,
    required this.area,
  });

  String get formatted => '$building · $floor ($area)';
}

class ReportModel {
  final String id;
  final String title;
  final IssueCategory category;
  final IssueSeverity severity;
  final CampusLocation location;
  final ReportStatus status;
  final DateTime createdAt;
  final String description;
  final String? department;
  final String? imageUrl;
  final int distanceMeters;
  final double? aiConfidence;
  final String? resolutionNote;

  const ReportModel({
    required this.id,
    required this.title,
    required this.category,
    required this.severity,
    required this.location,
    required this.status,
    required this.createdAt,
    required this.description,
    this.department,
    this.imageUrl,
    this.distanceMeters = 0,
    this.aiConfidence,
    this.resolutionNote,
  });

  ReportModel copyWith({
    String? id,
    String? title,
    IssueCategory? category,
    IssueSeverity? severity,
    CampusLocation? location,
    ReportStatus? status,
    DateTime? createdAt,
    String? description,
    String? department,
    String? imageUrl,
    int? distanceMeters,
    double? aiConfidence,
    String? resolutionNote,
  }) {
    return ReportModel(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      severity: severity ?? this.severity,
      location: location ?? this.location,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      description: description ?? this.description,
      department: department ?? this.department,
      imageUrl: imageUrl ?? this.imageUrl,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      aiConfidence: aiConfidence ?? this.aiConfidence,
      resolutionNote: resolutionNote ?? this.resolutionNote,
    );
  }
}

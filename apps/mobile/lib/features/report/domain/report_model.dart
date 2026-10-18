import 'dart:math' as math;

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

  String toDbValue() => name;

  static IssueCategory fromDbValue(String? value) {
    if (value == null) return IssueCategory.other;
    return IssueCategory.values.firstWhere(
      (c) => c.name.toLowerCase() == value.toLowerCase(),
      orElse: () => IssueCategory.other,
    );
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

  String toDbValue() => name;

  static IssueSeverity fromDbValue(String? value) {
    if (value == null) return IssueSeverity.medium;
    return IssueSeverity.values.firstWhere(
      (s) => s.name.toLowerCase() == value.toLowerCase(),
      orElse: () => IssueSeverity.medium,
    );
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

  String toDbValue() {
    switch (this) {
      case ReportStatus.reported:
        return 'REPORTED';
      case ReportStatus.assigned:
        return 'ASSIGNED';
      case ReportStatus.inProgress:
        return 'IN_PROGRESS';
      case ReportStatus.resolved:
        return 'RESOLVED';
      case ReportStatus.rejected:
        return 'REJECTED';
      case ReportStatus.duplicate:
        return 'DUPLICATE';
    }
  }

  static ReportStatus fromDbValue(String? value) {
    if (value == null) return ReportStatus.reported;
    final normalized = value.trim().toUpperCase().replaceAll(' ', '_');
    switch (normalized) {
      case 'REPORTED':
        return ReportStatus.reported;
      case 'ASSIGNED':
        return ReportStatus.assigned;
      case 'IN_PROGRESS':
        return ReportStatus.inProgress;
      case 'RESOLVED':
        return ReportStatus.resolved;
      case 'REJECTED':
        return ReportStatus.rejected;
      case 'DUPLICATE':
        return ReportStatus.duplicate;
      default:
        return ReportStatus.reported;
    }
  }
}

class CampusLocation {
  final String building;
  final String floor;
  final String area;
  final String? buildingId;
  final String? floorId;
  final String? floorText;
  final String? areaId;
  final String? locationDetails;

  const CampusLocation({
    required this.building,
    required this.floor,
    required this.area,
    this.buildingId,
    this.floorId,
    this.floorText,
    this.areaId,
    this.locationDetails,
  });

  String get formatted {
    final floorPart = floor.isNotEmpty ? floor : (floorText ?? '');
    final areaPart = area.isNotEmpty ? area : (locationDetails ?? '');
    if (areaPart.isNotEmpty && floorPart.isNotEmpty) {
      return '$building · $floorPart ($areaPart)';
    } else if (areaPart.isNotEmpty) {
      return '$building · $areaPart';
    } else if (floorPart.isNotEmpty) {
      return '$building · $floorPart';
    }
    return building;
  }
}

/// Client-side validator for report location details adhering to database check constraint
/// `reports_location_details_length_check` (or `report_location_detials_length_check`):
/// CHECK (char_length(btrim(location_details)) BETWEEN 2 AND 255).
class LocationDetailsValidator {
  static const int minLength = 2;
  static const int maxLength = 255;

  /// Validates [value] against the database constraint.
  ///
  /// If [isRequired] is true (default in the reports schema), [value] must not be null,
  /// empty, or whitespace-only, and its trimmed length must be between 2 and 255 characters.
  /// If [isRequired] is false and [value] is null/empty/whitespace-only, returns null.
  static String? validate(String? value, {bool isRequired = true}) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      if (isRequired) {
        return 'Please enter specific location details (at least $minLength characters, e.g. Room 204).';
      }
      return null;
    }
    if (trimmed.length < minLength) {
      return 'Location details must be at least $minLength characters.';
    }
    if (trimmed.length > maxLength) {
      return 'Location details cannot exceed $maxLength characters (currently ${trimmed.length} characters).';
    }
    return null;
  }
}

/// Exception thrown when submitting an issue report fails.
class ReportSubmissionException implements Exception {
  final String message;
  final String? code;
  final String? field;

  const ReportSubmissionException(this.message, {this.code, this.field});

  @override
  String toString() => message;
}

class ReportMediaModel {
  final String id;
  final String reportId;
  final String? uploaderId;
  final String storagePath;
  final String mimeType;
  final int position;
  final String? signedUrl;
  final DateTime? createdAt;

  const ReportMediaModel({
    required this.id,
    required this.reportId,
    this.uploaderId,
    required this.storagePath,
    required this.mimeType,
    this.position = 0,
    this.signedUrl,
    this.createdAt,
  });

  factory ReportMediaModel.fromJson(
    Map<String, dynamic> json, {
    String? fallbackReportId,
    String? signedUrl,
  }) {
    return ReportMediaModel(
      id: (json['id'] as String?) ?? '',
      reportId: (json['report_id'] as String?) ?? fallbackReportId ?? '',
      uploaderId: json['uploader_id'] as String?,
      storagePath: (json['storage_path'] as String?) ?? '',
      mimeType: (json['mime_type'] as String?) ?? 'image/jpeg',
      position: (json['position'] as num?)?.toInt() ?? 0,
      signedUrl: signedUrl ?? (json['signed_url'] as String?),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  ReportMediaModel copyWith({String? signedUrl}) {
    return ReportMediaModel(
      id: id,
      reportId: reportId,
      uploaderId: uploaderId,
      storagePath: storagePath,
      mimeType: mimeType,
      position: position,
      signedUrl: signedUrl ?? this.signedUrl,
      createdAt: createdAt,
    );
  }
}

class ReportStatusEventModel {
  final String id;
  final String reportId;
  final String? fromStatus;
  final String toStatus;
  final String? actorId;
  final String? note;
  final DateTime occurredAt;

  const ReportStatusEventModel({
    required this.id,
    required this.reportId,
    this.fromStatus,
    required this.toStatus,
    this.actorId,
    this.note,
    required this.occurredAt,
  });

  bool get isInitialCreation => fromStatus == null;

  String get displayTitle {
    if (isInitialCreation) {
      return 'Report Created';
    }
    final toDisplay = ReportStatus.fromDbValue(toStatus).displayName;
    return 'Status updated to $toDisplay';
  }

  factory ReportStatusEventModel.fromJson(
    Map<String, dynamic> json, {
    String? fallbackReportId,
  }) {
    return ReportStatusEventModel(
      id: (json['id'] as String?) ?? '',
      reportId: (json['report_id'] as String?) ?? fallbackReportId ?? '',
      fromStatus: json['from_status'] as String?,
      toStatus: (json['to_status'] as String?) ?? 'REPORTED',
      actorId: json['actor_id'] as String?,
      note: json['note'] as String?,
      occurredAt: json['occurred_at'] != null
          ? (DateTime.tryParse(json['occurred_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }
}

class ReportModel {
  final String id;
  final String? reporterId;
  final String title;
  final IssueCategory category;
  final IssueSeverity severity;
  final CampusLocation location;
  final ReportStatus status;
  final DateTime createdAt;
  final String description;
  final String? department;
  final String? departmentId;
  final String? assignedDepartment;
  final String? assignedDepartmentId;
  final String? imageUrl;
  final List<ReportMediaModel> media;
  final List<ReportStatusEventModel> statusEvents;
  final int distanceMeters;
  final bool hasCalculatedDistance;
  final double? aiConfidence;
  final String? resolutionNote;
  final double? latitude;
  final double? longitude;

  const ReportModel({
    required this.id,
    this.reporterId,
    required this.title,
    required this.category,
    required this.severity,
    required this.location,
    required this.status,
    required this.createdAt,
    required this.description,
    this.department,
    this.departmentId,
    this.assignedDepartment,
    this.assignedDepartmentId,
    this.imageUrl,
    this.media = const [],
    this.statusEvents = const [],
    this.distanceMeters = 0,
    this.hasCalculatedDistance = false,
    this.aiConfidence,
    this.resolutionNote,
    this.latitude,
    this.longitude,
  });

  /// Factory constructor to parse from Supabase `reports` join query
  factory ReportModel.fromSupabaseJson(
    Map<String, dynamic> json, {
    String? primarySignedUrl,
  }) {
    final reportId = (json['id'] as String?) ?? '';

    // 1. Building details
    final dynamic rawBuilding = json['buildings'];
    final Map<String, dynamic>? buildingMap = rawBuilding is Map
        ? rawBuilding.cast<String, dynamic>()
        : (rawBuilding is List && rawBuilding.isNotEmpty && rawBuilding.first is Map
            ? (rawBuilding.first as Map).cast<String, dynamic>()
            : null);
    final buildingName = (buildingMap?['name'] as String?)?.trim();
    final buildingDisplay = (buildingName != null && buildingName.isNotEmpty)
        ? buildingName
        : 'Campus Building';
    final buildingId = (json['building_id'] as String?) ??
        (buildingMap?['id'] as String?) ??
        '';

    // 2. Floor details (fallback to floor_text if floor relation / label is absent)
    final dynamic rawFloor = json['floors'];
    final Map<String, dynamic>? floorMap = rawFloor is Map
        ? rawFloor.cast<String, dynamic>()
        : (rawFloor is List && rawFloor.isNotEmpty && rawFloor.first is Map
            ? (rawFloor.first as Map).cast<String, dynamic>()
            : null);
    final floorLabel = (floorMap?['label'] as String?)?.trim();
    final floorText = (json['floor_text'] as String?)?.trim();
    final floorDisplay = (floorLabel != null && floorLabel.isNotEmpty)
        ? floorLabel
        : ((floorText != null && floorText.isNotEmpty) ? floorText : 'General Area');

    // 3. Area details (fallback to location_details if area relation / name is absent)
    final dynamic rawArea = json['areas'];
    final Map<String, dynamic>? areaMap = rawArea is Map
        ? rawArea.cast<String, dynamic>()
        : (rawArea is List && rawArea.isNotEmpty && rawArea.first is Map
            ? (rawArea.first as Map).cast<String, dynamic>()
            : null);
    final areaName = (areaMap?['name'] as String?)?.trim();
    final locationDetails = (json['location_details'] as String?)?.trim() ?? '';
    final areaDisplay = (areaName != null && areaName.isNotEmpty)
        ? (locationDetails.isNotEmpty ? '$areaName · $locationDetails' : areaName)
        : locationDetails;

    // 4. Media
    final rawMediaList = json['report_media'] as List<dynamic>? ?? [];
    final mediaList = rawMediaList
        .whereType<Map>()
        .map((m) => ReportMediaModel.fromJson(
              m.cast<String, dynamic>(),
              fallbackReportId: reportId,
              signedUrl: primarySignedUrl,
            ))
        .toList();

    // 5. Status events
    final rawEventsList = json['report_status_events'] as List<dynamic>? ?? [];
    final statusEvents = rawEventsList
        .whereType<Map>()
        .map((e) => ReportStatusEventModel.fromJson(
              e.cast<String, dynamic>(),
              fallbackReportId: reportId,
            ))
        .toList();

    // Check resolution note from latest event if any
    String? resNote;
    if (statusEvents.isNotEmpty) {
      for (final ev in statusEvents.reversed) {
        if (ev.note != null && ev.note!.trim().isNotEmpty) {
          resNote = ev.note!.trim();
          break;
        }
      }
    }

    // 6. Department details (prioritize assigned department if set, then suggested department / label)
    final dynamic rawAssignedDept = json['assigned_department'];
    final Map<String, dynamic>? assignedDeptMap = rawAssignedDept is Map
        ? rawAssignedDept.cast<String, dynamic>()
        : (rawAssignedDept is List && rawAssignedDept.isNotEmpty && rawAssignedDept.first is Map
            ? (rawAssignedDept.first as Map).cast<String, dynamic>()
            : null);
    final assignedDeptName = (assignedDeptMap?['name'] as String?)?.trim();
    final assignedDeptId = (json['assigned_department_id'] as String?) ??
        (assignedDeptMap?['id'] as String?);

    final dynamic rawSuggestedDept = json['suggested_department'] ?? json['departments'];
    final Map<String, dynamic>? suggestedDeptMap = rawSuggestedDept is Map
        ? rawSuggestedDept.cast<String, dynamic>()
        : (rawSuggestedDept is List && rawSuggestedDept.isNotEmpty && rawSuggestedDept.first is Map
            ? (rawSuggestedDept.first as Map).cast<String, dynamic>()
            : null);
    final suggestedDeptName = (suggestedDeptMap?['name'] as String?)?.trim();
    final suggestedDeptLabel = (json['suggested_department_label'] as String?)?.trim();

    final departmentDisplay = (assignedDeptName != null && assignedDeptName.isNotEmpty)
        ? assignedDeptName
        : ((suggestedDeptLabel != null && suggestedDeptLabel.isNotEmpty)
            ? suggestedDeptLabel
            : suggestedDeptName);

    final resolvedDeptId = assignedDeptId ??
        (json['suggested_department_id'] as String?) ??
        (suggestedDeptMap?['id'] as String?);

    double? parseDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    final rawTitle = ((json['issue_label'] ?? json['title']) as String?)?.trim();
    final rawDesc = (json['description'] as String?)?.trim() ?? '';
    final resolvedTitle = (rawTitle != null && rawTitle.isNotEmpty && rawTitle.toLowerCase() != 'unnamed')
        ? rawTitle
        : (rawDesc.isNotEmpty
            ? (rawDesc.length > 50 ? '${rawDesc.substring(0, 47)}...' : rawDesc)
            : 'Campus Issue');

    return ReportModel(
      id: reportId,
      reporterId: json['reporter_id'] as String?,
      title: resolvedTitle,
      category: IssueCategory.fromDbValue(json['category'] as String?),
      severity: IssueSeverity.fromDbValue(json['severity'] as String?),
      location: CampusLocation(
        building: buildingDisplay,
        floor: floorDisplay,
        area: areaDisplay,
        buildingId: buildingId.isNotEmpty ? buildingId : null,
        floorId: json['floor_id'] as String?,
        floorText: floorText,
        areaId: json['area_id'] as String?,
        locationDetails: locationDetails.isNotEmpty ? locationDetails : null,
      ),
      status: ReportStatus.fromDbValue(json['status'] as String?),
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      description: (json['description'] as String?)?.trim() ?? '',
      department: departmentDisplay,
      departmentId: resolvedDeptId,
      assignedDepartment: assignedDeptName,
      assignedDepartmentId: assignedDeptId,
      imageUrl: primarySignedUrl ?? (mediaList.isNotEmpty ? mediaList.first.signedUrl : null),
      media: mediaList,
      statusEvents: statusEvents,
      resolutionNote: resNote,
      latitude: parseDouble(json['latitude']),
      longitude: parseDouble(json['longitude']),
      distanceMeters: (json['distance_meters'] as num?)?.toInt() ?? 0,
      hasCalculatedDistance: json['distance_meters'] != null,
      aiConfidence: parseDouble(json['ai_confidence']),
    );
  }

  /// Factory constructor to parse campus issue cards from get_campus_issue_feed RPC.
  /// Protects reporter privacy and calculates distance only if real coordinates exist.
  factory ReportModel.fromCampusIssueFeedJson(
    Map<String, dynamic> json, {
    double? userLat,
    double? userLng,
  }) {
    final reportId = (json['id'] as String?) ?? '';
    final buildingName = (json['building_name'] as String?)?.trim();
    final buildingDisplay = (buildingName != null && buildingName.isNotEmpty)
        ? buildingName
        : 'Campus Building';

    final floorLabel = (json['floor_label'] as String?)?.trim();
    final floorDisplay = (floorLabel != null && floorLabel.isNotEmpty)
        ? floorLabel
        : 'General Area';

    final locationDetails = (json['location_details'] as String?)?.trim() ?? '';

    double? parseDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    final lat = parseDouble(json['latitude']);
    final lng = parseDouble(json['longitude']);

    int? distance;
    if (userLat != null && userLng != null && lat != null && lng != null) {
      distance = calculateDistanceMeters(userLat, userLng, lat, lng);
    }

    return ReportModel(
      id: reportId,
      reporterId: null, // Private: reporter identity protected across campus
      title: (json['issue_label'] as String?)?.trim().isNotEmpty == true
          ? (json['issue_label'] as String).trim()
          : 'Campus Issue',
      category: IssueCategory.fromDbValue(json['category'] as String?),
      severity: IssueSeverity.fromDbValue(json['severity'] as String?),
      location: CampusLocation(
        building: buildingDisplay,
        floor: floorDisplay,
        area: locationDetails,
        floorText: floorLabel,
        locationDetails: locationDetails.isNotEmpty ? locationDetails : null,
      ),
      status: ReportStatus.fromDbValue(json['status'] as String?),
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      description: (json['description'] as String?)?.trim() ?? '',
      latitude: lat,
      longitude: lng,
      distanceMeters: distance ?? 0,
      hasCalculatedDistance: distance != null,
    );
  }

  ReportModel copyWith({
    String? id,
    String? reporterId,
    String? title,
    IssueCategory? category,
    IssueSeverity? severity,
    CampusLocation? location,
    ReportStatus? status,
    DateTime? createdAt,
    String? description,
    String? department,
    String? departmentId,
    String? assignedDepartment,
    String? assignedDepartmentId,
    String? imageUrl,
    List<ReportMediaModel>? media,
    List<ReportStatusEventModel>? statusEvents,
    int? distanceMeters,
    bool? hasCalculatedDistance,
    double? aiConfidence,
    String? resolutionNote,
    double? latitude,
    double? longitude,
  }) {
    return ReportModel(
      id: id ?? this.id,
      reporterId: reporterId ?? this.reporterId,
      title: title ?? this.title,
      category: category ?? this.category,
      severity: severity ?? this.severity,
      location: location ?? this.location,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      description: description ?? this.description,
      department: department ?? this.department,
      departmentId: departmentId ?? this.departmentId,
      assignedDepartment: assignedDepartment ?? this.assignedDepartment,
      assignedDepartmentId: assignedDepartmentId ?? this.assignedDepartmentId,
      imageUrl: imageUrl ?? this.imageUrl,
      media: media ?? this.media,
      statusEvents: statusEvents ?? this.statusEvents,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      hasCalculatedDistance: hasCalculatedDistance ?? this.hasCalculatedDistance,
      aiConfidence: aiConfidence ?? this.aiConfidence,
      resolutionNote: resolutionNote ?? this.resolutionNote,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}

/// Computes great-circle distance between two GPS coordinates in meters.
int calculateDistanceMeters(double lat1, double lon1, double lat2, double lon2) {
  const earthRadius = 6371000.0;
  final dLat = (lat2 - lat1) * (math.pi / 180.0);
  final dLon = (lon2 - lon1) * (math.pi / 180.0);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * (math.pi / 180.0)) *
          math.cos(lat2 * (math.pi / 180.0)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return (earthRadius * c).round();
}

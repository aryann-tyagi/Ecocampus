/// Represents an authentic campus building summary returned by
/// the server-side RPC `get_campus_building_summary()`.
class CampusBuildingSummary {
  final String buildingId;
  final String buildingName;
  final int totalReports;
  final int activeReports;
  final int resolvedReports;
  final int wasteReports;
  final int waterReports;
  final int electricityReports;
  final int infrastructureReports;
  final int greeneryReports;
  final int cleanlinessReports;
  final int otherReports;
  final int reportsWithCoordinates;
  final DateTime? lastReportAt;

  const CampusBuildingSummary({
    required this.buildingId,
    required this.buildingName,
    required this.totalReports,
    required this.activeReports,
    required this.resolvedReports,
    required this.wasteReports,
    required this.waterReports,
    required this.electricityReports,
    required this.infrastructureReports,
    required this.greeneryReports,
    required this.cleanlinessReports,
    required this.otherReports,
    required this.reportsWithCoordinates,
    this.lastReportAt,
  });

  /// Safely parses PostgreSQL response rows, accounting for bigint and nullable values.
  factory CampusBuildingSummary.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic val) {
      if (val == null) return 0;
      if (val is int) return val;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 0;
      return 0;
    }

    DateTime? parseDateTime(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return CampusBuildingSummary(
      buildingId: (json['building_id'] as String?) ?? '',
      buildingName: (json['building_name'] as String?) ?? 'Campus Building',
      totalReports: parseInt(json['total_reports']),
      activeReports: parseInt(json['active_reports']),
      resolvedReports: parseInt(json['resolved_reports']),
      wasteReports: parseInt(json['waste_reports']),
      waterReports: parseInt(json['water_reports']),
      electricityReports: parseInt(json['electricity_reports']),
      infrastructureReports: parseInt(json['infrastructure_reports']),
      greeneryReports: parseInt(json['greenery_reports']),
      cleanlinessReports: parseInt(json['cleanliness_reports']),
      otherReports: parseInt(json['other_reports']),
      reportsWithCoordinates: parseInt(json['reports_with_coordinates']),
      lastReportAt: parseDateTime(json['last_report_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'building_id': buildingId,
        'building_name': buildingName,
        'total_reports': totalReports,
        'active_reports': activeReports,
        'resolved_reports': resolvedReports,
        'waste_reports': wasteReports,
        'water_reports': waterReports,
        'electricity_reports': electricityReports,
        'infrastructure_reports': infrastructureReports,
        'greenery_reports': greeneryReports,
        'cleanliness_reports': cleanlinessReports,
        'other_reports': otherReports,
        'reports_with_coordinates': reportsWithCoordinates,
        'last_report_at': lastReportAt?.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CampusBuildingSummary &&
          runtimeType == other.runtimeType &&
          buildingId == other.buildingId &&
          totalReports == other.totalReports &&
          activeReports == other.activeReports &&
          resolvedReports == other.resolvedReports;

  @override
  int get hashCode => Object.hash(
        buildingId,
        totalReports,
        activeReports,
        resolvedReports,
      );
}

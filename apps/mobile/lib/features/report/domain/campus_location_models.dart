/// Represents a campus building stored in Supabase `public.buildings`.
class CampusBuilding {
  final String id;
  final String name;
  final String slug;
  final bool active;

  const CampusBuilding({
    required this.id,
    required this.name,
    required this.slug,
    this.active = true,
  });

  factory CampusBuilding.fromJson(Map<String, dynamic> json) {
    return CampusBuilding(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      slug: (json['slug'] as String?) ?? '',
      active: json['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'active': active,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CampusBuilding &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Represents a floor record stored in Supabase `public.floors`.
class CampusFloor {
  final String id;
  final String buildingId;
  final String label;
  final int sortOrder;
  final bool active;

  const CampusFloor({
    required this.id,
    required this.buildingId,
    required this.label,
    required this.sortOrder,
    this.active = true,
  });

  factory CampusFloor.fromJson(Map<String, dynamic> json) {
    return CampusFloor(
      id: (json['id'] as String?) ?? '',
      buildingId: (json['building_id'] as String?) ?? '',
      label: (json['label'] as String?) ?? '',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      active: json['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'building_id': buildingId,
        'label': label,
        'sort_order': sortOrder,
        'active': active,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CampusFloor &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Represents an area record stored in Supabase `public.areas`.
class CampusArea {
  final String id;
  final String floorId;
  final String name;
  final bool active;

  const CampusArea({
    required this.id,
    required this.floorId,
    required this.name,
    this.active = true,
  });

  factory CampusArea.fromJson(Map<String, dynamic> json) {
    return CampusArea(
      id: (json['id'] as String?) ?? '',
      floorId: (json['floor_id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      active: json['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'floor_id': floorId,
        'name': name,
        'active': active,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CampusArea &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

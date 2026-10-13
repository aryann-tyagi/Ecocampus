/// Represents a student profile record in `public.profiles`.
class UserProfile {
  final String id;
  final String? displayName;
  final String? companionName;
  final String? avatarUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserProfile({
    required this.id,
    this.displayName,
    this.companionName,
    this.avatarUrl,
    this.createdAt,
    this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: (json['id'] as String?) ?? '',
      displayName: json['display_name'] as String?,
      companionName: json['companion_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'display_name': displayName,
      'companion_name': companionName,
      'avatar_url': avatarUrl,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? displayName,
    String? companionName,
    String? avatarUrl,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id,
      displayName: displayName ?? this.displayName,
      companionName: companionName ?? this.companionName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          displayName == other.displayName &&
          companionName == other.companionName &&
          avatarUrl == other.avatarUrl;

  @override
  int get hashCode =>
      id.hashCode ^
      displayName.hashCode ^
      companionName.hashCode ^
      avatarUrl.hashCode;
}

enum UserRole {
  trainee,
  instructor,
  admin;

  String get label {
    switch (this) {
      case UserRole.trainee:
        return 'ОБУЧАЕМЫЙ';
      case UserRole.instructor:
        return 'ИНСТРУКТОР';
      case UserRole.admin:
        return 'АДМИНИСТРАТОР';
    }
  }

  static UserRole fromString(
    String? value,
  ) {
    switch (value) {
      case 'instructor':
        return UserRole.instructor;
      case 'admin':
        return UserRole.admin;
      case 'trainee':
      default:
        return UserRole.trainee;
    }
  }
}

class AppUser {
  final String id;
  final String callsign;
  final String fullName;
  final UserRole role;
  final String unitName;
  final bool isActive;
  final DateTime createdAt;

  const AppUser({
    required this.id,
    required this.callsign,
    required this.fullName,
    required this.role,
    this.unitName = '',
    this.isActive = true,
    required this.createdAt,
  });

  AppUser copyWith({
    String? id,
    String? callsign,
    String? fullName,
    UserRole? role,
    String? unitName,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      callsign: callsign ?? this.callsign,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      unitName: unitName ?? this.unitName,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'callsign': callsign,
      'fullName': fullName,
      'role': role.name,
      'unitName': unitName,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AppUser.fromJson(
    Map<String, dynamic> json,
  ) {
    return AppUser(
      id: json['id']?.toString() ?? '',
      callsign:
          json['callsign']?.toString() ?? '',
      fullName:
          json['fullName']?.toString() ?? '',
      role: UserRole.fromString(
        json['role']?.toString(),
      ),
      unitName:
          json['unitName']?.toString() ?? '',
      isActive: json['isActive'] is bool
          ? json['isActive'] as bool
          : true,
      createdAt: DateTime.tryParse(
            json['createdAt']?.toString() ?? '',
          ) ??
          DateTime.now(),
    );
  }
}


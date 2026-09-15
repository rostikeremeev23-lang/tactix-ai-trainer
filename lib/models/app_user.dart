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

  static UserRole fromString(String? value) {
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
  final String? serverId;
  final String? email;
  final UserRole? serverRole;
  final String unitName;
  final bool isActive;
  final DateTime createdAt;

  const AppUser({
    required this.id,
    required this.callsign,
    required this.fullName,
    required this.role,
    this.serverId,
    this.email,
    this.serverRole,
    this.unitName = '',
    this.isActive = true,
    required this.createdAt,
  });

  AppUser copyWith({
    String? id,
    String? callsign,
    String? fullName,
    UserRole? role,
    String? serverId,
    String? email,
    UserRole? serverRole,
    String? unitName,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      callsign: callsign ?? this.callsign,
      fullName: fullName ?? this.fullName,
      role: this.serverRole ?? serverRole ?? role ?? this.role,
      serverId: serverId ?? this.serverId,
      email: email ?? this.email,
      serverRole: serverRole ?? this.serverRole,
      unitName: unitName ?? this.unitName,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory AppUser.fromServer(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final roleValue = json['role']?.toString();
    if (id.isEmpty ||
        !const {'trainee', 'instructor', 'admin'}.contains(roleValue)) {
      throw const FormatException('Invalid server identity');
    }
    final role = UserRole.fromString(roleValue);
    final name = json['first_name']?.toString() ?? '';
    return AppUser(
      id: id,
      serverId: id,
      email: json['email']?.toString(),
      callsign: json['callsign']?.toString() ?? '',
      fullName: name,
      role: role,
      serverRole: role,
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'callsign': callsign,
      'fullName': fullName,
      'role': (serverRole ?? role).name,
      if (serverId != null) 'serverId': serverId,
      if (email != null) 'email': email,
      if (serverRole != null) 'serverRole': serverRole!.name,
      'unitName': unitName,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id']?.toString() ?? '',
      callsign: json['callsign']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      role: UserRole.fromString(
        json['serverRole']?.toString() ?? json['role']?.toString(),
      ),
      serverId: json['serverId']?.toString(),
      email: json['email']?.toString(),
      serverRole: json['serverRole'] == null
          ? null
          : UserRole.fromString(json['serverRole']?.toString()),
      unitName: json['unitName']?.toString() ?? '',
      isActive: json['isActive'] is bool ? json['isActive'] as bool : true,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

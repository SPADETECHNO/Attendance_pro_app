// lib/models/user_model.dart
import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String id;
  final String userId;
  final String name;
  final String email;
  final String? phone;
  final String role;
  final String? instituteId;
  final String? departmentId;
  final String accountStatus;
  final bool tempPasswordUsed;
  final DateTime createdAt;
  final DateTime updatedAt;

  // ⭐ Join fields for display
  final String? departmentName;
  final String? academicYearId;

  const UserModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    this.phone,
    required this.role,
    this.instituteId,
    this.departmentId,
    required this.accountStatus,
    required this.tempPasswordUsed,
    required this.createdAt,
    required this.updatedAt,
    this.departmentName,
    this.academicYearId,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      role: json['role'] as String,
      instituteId: json['institute_id'] as String?,
      departmentId: json['department_id'] as String?,
      accountStatus: json['account_status'] as String? ?? 'inactive',
      tempPasswordUsed: json['temp_password_used'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      departmentName: json['department_name'] as String?, // ⭐ Added
      academicYearId: json['academic_year_id'] as String?, // ⭐ Added
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'institute_id': instituteId,
      'department_id': departmentId,
      'account_status': accountStatus,
      'temp_password_used': tempPasswordUsed,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? email,
    String? phone,
    String? role,
    String? instituteId,
    String? departmentId,
    String? accountStatus,
    bool? tempPasswordUsed,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? departmentName, // ⭐ Added
    String? academicYearId, // ⭐ Added
  }) {
    return UserModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      instituteId: instituteId ?? this.instituteId,
      departmentId: departmentId ?? this.departmentId,
      accountStatus: accountStatus ?? this.accountStatus,
      tempPasswordUsed: tempPasswordUsed ?? this.tempPasswordUsed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      departmentName: departmentName ?? this.departmentName, // ⭐ Added
      academicYearId: academicYearId ?? this.academicYearId, // ⭐ Added
    );
  }

  // Convenience getters
  bool get isActive => accountStatus == 'active';
  bool get isSuperAdmin => role == 'super_admin';
  bool get isInstituteAdmin => role == 'institute_admin';
  bool get isAdmin => role == 'admin';
  bool get isUser => role == 'user';
  bool get needsPasswordChange => tempPasswordUsed;
  
  String get displayName => name;
  String get initials {
    final words = name.split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase(); // ⭐ Fixed: was missing [0]
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String get roleDisplayName {
    switch (role) {
      case 'super_admin':
        return 'Super Admin';
      case 'institute_admin':
        return 'Institute Admin';
      case 'admin':
        return 'Admin';
      case 'user':
        return 'User';
      default:
        return role;
    }
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        name,
        email,
        phone,
        role,
        instituteId,
        departmentId,
        accountStatus,
        tempPasswordUsed,
        createdAt,
        updatedAt,
        departmentName, // ⭐ Added
        academicYearId, // ⭐ Added
      ];

  @override
  String toString() {
    return 'UserModel('
        'id: $id, '
        'userId: $userId, '
        'name: $name, '
        'email: $email, '
        'role: $role, '
        'accountStatus: $accountStatus, '
        'departmentName: $departmentName' // ⭐ Added
        ')';
  }
}

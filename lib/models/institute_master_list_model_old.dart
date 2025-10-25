import 'package:equatable/equatable.dart';

class InstituteMasterListModel extends Equatable {
  final String id;
  final String userId;
  final String name;
  final String email;
  final String? phone;
  final String role; // Always 'user' but kept for consistency
  final String instituteId;
  final String? departmentId;
  final String? academicYearId;
  final String accountStatus;
  final bool tempPasswordUsed;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  
  // Join fields for display
  final String? departmentName;
  final String? academicYearLabel;

  const InstituteMasterListModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    this.phone,
    required this.role,
    required this.instituteId,
    this.departmentId,
    this.academicYearId,
    required this.accountStatus,
    required this.tempPasswordUsed,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.departmentName,
    this.academicYearLabel,
  });

  factory InstituteMasterListModel.fromJson(Map<String, dynamic> json) {
    return InstituteMasterListModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      role: json['role'] as String? ?? 'user', // Always 'user'
      instituteId: json['institute_id'] as String,
      departmentId: json['department_id'] as String?,
      academicYearId: json['academic_year_id'] as String?,
      accountStatus: json['account_status'] as String? ?? 'active',
      tempPasswordUsed: json['temp_password_used'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      createdBy: json['created_by'] as String?,
      // Join fields
      departmentName: json['department_name'] as String?,
      academicYearLabel: json['academic_year_label'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'email': email,
      'phone': phone,
      'role': 'user', // Always 'user'
      'institute_id': instituteId,
      'department_id': departmentId,
      'academic_year_id': academicYearId,
      'account_status': accountStatus,
      'temp_password_used': tempPasswordUsed,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'created_by': createdBy,
    };
  }

  // Convenience getters
  bool get isActive => accountStatus == 'active';
  bool get needsPasswordChange => tempPasswordUsed;
  String get displayName => name;
  String get displayRole => 'User'; // Always 'User'
  String get displayDepartment => departmentName ?? 'Not Assigned';
  String get displayAcademicYear => academicYearLabel ?? 'Not Assigned';
  
  String get initials {
    final words = name.split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  List<Object?> get props => [
    id, userId, name, email, phone, role, instituteId, departmentId, 
    academicYearId, accountStatus, tempPasswordUsed, createdAt, updatedAt, 
    createdBy, departmentName, academicYearLabel,
  ];
}

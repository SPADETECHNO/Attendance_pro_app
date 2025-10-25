import 'package:equatable/equatable.dart';

class SessionModel extends Equatable {
  final String id;
  final String name;
  final String? description;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final DateTime sessionDate;
  final String academicYearId;
  final String departmentId;
  final String createdBy;
  final bool gpsValidationEnabled;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SessionModel({
    required this.id,
    required this.name,
    this.description,
    required this.startDateTime,
    required this.endDateTime,
    required this.sessionDate,
    required this.academicYearId,
    required this.departmentId,
    required this.createdBy,
    required this.gpsValidationEnabled,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      startDateTime: DateTime.parse(json['start_datetime'] as String),
      endDateTime: DateTime.parse(json['end_datetime'] as String),
      sessionDate: DateTime.parse(json['session_date'] as String),
      academicYearId: json['academic_year_id'] as String,
      departmentId: json['department_id'] as String,
      createdBy: json['created_by'] as String,
      gpsValidationEnabled: json['gps_validation_enabled'] as bool? ?? true,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'start_datetime': startDateTime.toIso8601String(),
      'end_datetime': endDateTime.toIso8601String(),
      'session_date': sessionDate.toIso8601String(),
      'academic_year_id': academicYearId,
      'department_id': departmentId,
      'created_by': createdBy,
      'gps_validation_enabled': gpsValidationEnabled,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  SessionModel copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? startDateTime,
    DateTime? endDateTime,
    DateTime? sessionDate,
    String? academicYearId,
    String? departmentId,
    String? createdBy,
    bool? gpsValidationEnabled,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SessionModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      startDateTime: startDateTime ?? this.startDateTime,
      endDateTime: endDateTime ?? this.endDateTime,
      sessionDate: sessionDate ?? this.sessionDate,
      academicYearId: academicYearId ?? this.academicYearId,
      departmentId: departmentId ?? this.departmentId,
      createdBy: createdBy ?? this.createdBy,
      gpsValidationEnabled: gpsValidationEnabled ?? this.gpsValidationEnabled,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Convenience getters
  Duration get duration => endDateTime.difference(startDateTime);
  
  bool get isLive {
    final now = DateTime.now();
    return now.isAfter(startDateTime) && now.isBefore(endDateTime) && isActive;
  }

  bool get isUpcoming {
    return DateTime.now().isBefore(startDateTime) && isActive;
  }

  bool get hasEnded {
    return DateTime.now().isAfter(endDateTime);
  }

  String get status {
    if (!isActive) return 'Inactive';
    if (isLive) return 'Live';
    if (isUpcoming) return 'Upcoming';
    return 'Ended';
  }

  String get durationString {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  String get timeRemaining {
    if (hasEnded) return 'Ended';
    
    final now = DateTime.now();
    final target = isLive ? endDateTime : startDateTime;
    final difference = target.difference(now);
    
    if (difference.isNegative) return 'Ended';
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ${difference.inHours % 24}h remaining';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ${difference.inMinutes % 60}m remaining';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m remaining';
    } else {
      return 'Starting soon';
    }
  }

  // bool get canMarkAttendance => isLive && isActive;
  bool get canMarkAttendance {
    final now = DateTime.now();
    return now.isAfter(startDateTime) && now.isBefore(endDateTime);
  }


  @override
  List<Object?> get props => [
        id,
        name,
        description,
        startDateTime,
        endDateTime,
        sessionDate,
        academicYearId,
        departmentId,
        createdBy,
        gpsValidationEnabled,
        isActive,
        createdAt,
        updatedAt,
      ];

  @override
  String toString() {
    return 'SessionModel('
        'id: $id, '
        'name: $name, '
        'startDateTime: $startDateTime, '
        'endDateTime: $endDateTime, '
        'status: $status'
        ')';
  }
}

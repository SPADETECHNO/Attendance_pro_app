import 'package:equatable/equatable.dart';

class AttendanceModel extends Equatable {
  final String id;
  final String sessionId;
  final String userId;
  final String markedBy;
  final bool markedByUser;
  final bool markedByAdmin;
  final String status;
  final double? gpsLatitude;
  final double? gpsLongitude;
  final int? distanceFromInstitute;
  final DateTime markedAt;

  const AttendanceModel({
    required this.id,
    required this.sessionId,
    required this.userId,
    required this.markedBy,
    required this.markedByUser,
    required this.markedByAdmin,
    required this.status,
    this.gpsLatitude,
    this.gpsLongitude,
    this.distanceFromInstitute,
    required this.markedAt,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      userId: json['user_id'] as String,
      markedBy: json['marked_by'] as String,
      markedByUser: json['marked_by_user'] as bool? ?? false,
      markedByAdmin: json['marked_by_admin'] as bool? ?? false,
      status: json['status'] as String,
      gpsLatitude: json['gps_latitude'] != null 
          ? (json['gps_latitude'] as num).toDouble() 
          : null,
      gpsLongitude: json['gps_longitude'] != null 
          ? (json['gps_longitude'] as num).toDouble() 
          : null,
      distanceFromInstitute: json['distance_from_institute'] as int?,
      markedAt: DateTime.parse(json['marked_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_id': sessionId,
      'user_id': userId,
      'marked_by': markedBy,
      'marked_by_user': markedByUser,
      'marked_by_admin': markedByAdmin,
      'status': status,
      'gps_latitude': gpsLatitude,
      'gps_longitude': gpsLongitude,
      'distance_from_institute': distanceFromInstitute,
      'marked_at': markedAt.toIso8601String(),
    };
  }

  AttendanceModel copyWith({
    String? id,
    String? sessionId,
    String? userId,
    String? markedBy,
    bool? markedByUser,
    bool? markedByAdmin,
    String? status,
    double? gpsLatitude,
    double? gpsLongitude,
    int? distanceFromInstitute,
    DateTime? markedAt,
  }) {
    return AttendanceModel(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      userId: userId ?? this.userId,
      markedBy: markedBy ?? this.markedBy,
      markedByUser: markedByUser ?? this.markedByUser,
      markedByAdmin: markedByAdmin ?? this.markedByAdmin,
      status: status ?? this.status,
      gpsLatitude: gpsLatitude ?? this.gpsLatitude,
      gpsLongitude: gpsLongitude ?? this.gpsLongitude,
      distanceFromInstitute: distanceFromInstitute ?? this.distanceFromInstitute,
      markedAt: markedAt ?? this.markedAt,
    );
  }

  // Convenience getters
  bool get isPresent => status == 'present';
  bool get isAbsent => status == 'absent';
  bool get hasGpsData => gpsLatitude != null && gpsLongitude != null;
  bool get isSelfMarked => markedByUser;
  bool get isAdminMarked => markedByAdmin;

  String get coordinates {
    if (hasGpsData) {
      return '${gpsLatitude!.toStringAsFixed(6)}, ${gpsLongitude!.toStringAsFixed(6)}';
    }
    return 'Not recorded';
  }

  String get distanceText {
    if (distanceFromInstitute == null) return 'Unknown';
    
    if (distanceFromInstitute! >= 1000) {
      return '${(distanceFromInstitute! / 1000).toStringAsFixed(1)} km';
    } else {
      return '${distanceFromInstitute}m';
    }
  }

  String get markedByText {
    if (markedByUser && markedByAdmin) {
      return 'User & Admin'; // This shouldn't happen normally
    } else if (markedByUser) {
      return 'Self-marked';
    } else if (markedByAdmin) {
      return 'Admin-marked';
    } else {
      return 'System';
    }
  }

  String get statusText {
    return status == 'present' ? 'Present' : 'Absent';
  }

  @override
  List<Object?> get props => [
        id,
        sessionId,
        userId,
        markedBy,
        markedByUser,
        markedByAdmin,
        status,
        gpsLatitude,
        gpsLongitude,
        distanceFromInstitute,
        markedAt,
      ];

  @override
  String toString() {
    return 'AttendanceModel('
        'id: $id, '
        'sessionId: $sessionId, '
        'userId: $userId, '
        'status: $status, '
        'markedAt: $markedAt'
        ')';
  }
}

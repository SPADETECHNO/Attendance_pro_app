import 'package:equatable/equatable.dart';

class AcademicYearModel extends Equatable {
  final String id;
  final String yearLabel;
  final int startYear;
  final int endYear;
  final DateTime startDate;
  final DateTime endDate;
  final bool isCurrent;
  final String instituteId;
  final DateTime createdAt;

  const AcademicYearModel({
    required this.id,
    required this.yearLabel,
    required this.startYear,
    required this.endYear,
    required this.startDate,
    required this.endDate,
    required this.isCurrent,
    required this.instituteId,
    required this.createdAt,
  });

  factory AcademicYearModel.fromJson(Map<String, dynamic> json) {
    return AcademicYearModel(
      id: json['id'] as String,
      yearLabel: json['year_label'] as String,
      startYear: (json['start_year'] as num).toInt(),
      endYear: (json['end_year'] as num).toInt(),
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      isCurrent: json['is_current'] as bool? ?? false,
      instituteId: json['institute_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'year_label': yearLabel,
      'start_year': startYear,
      'end_year': endYear,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'is_current': isCurrent,
      'institute_id': instituteId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  AcademicYearModel copyWith({
    String? id,
    String? yearLabel,
    int? startYear,
    int? endYear,
    DateTime? startDate,
    DateTime? endDate,
    bool? isCurrent,
    String? instituteId,
    DateTime? createdAt,
  }) {
    return AcademicYearModel(
      id: id ?? this.id,
      yearLabel: yearLabel ?? this.yearLabel,
      startYear: startYear ?? this.startYear,
      endYear: endYear ?? this.endYear,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isCurrent: isCurrent ?? this.isCurrent,
      instituteId: instituteId ?? this.instituteId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Convenience getters
  Duration get duration => endDate.difference(startDate);
  
  bool get isActive {
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate);
  }

  bool get hasStarted => DateTime.now().isAfter(startDate);
  bool get hasEnded => DateTime.now().isAfter(endDate);
  bool get isUpcoming => DateTime.now().isBefore(startDate);

  String get status {
    if (isActive) return 'Active';
    if (isUpcoming) return 'Upcoming';
    if (hasEnded) return 'Ended';
    return 'Unknown';
  }

  String get yearRange => '$startYear-$endYear';

  String get displayLabel {
    if (yearLabel.isNotEmpty) {
      return yearLabel;
    }
    return yearRange;
  }

  int get durationInDays => duration.inDays;
  
  double get progressPercentage {
    if (!hasStarted) return 0.0;
    if (hasEnded) return 100.0;
    
    final totalDuration = endDate.difference(startDate);
    final elapsed = DateTime.now().difference(startDate);
    
    return (elapsed.inMilliseconds / totalDuration.inMilliseconds) * 100;
  }

  String get timeRemaining {
    if (hasEnded) return 'Ended';
    if (isUpcoming) {
      final diff = startDate.difference(DateTime.now());
      if (diff.inDays > 0) {
        return '${diff.inDays} days to start';
      } else {
        return 'Starting soon';
      }
    }
    
    final diff = endDate.difference(DateTime.now());
    if (diff.inDays > 30) {
      return '${(diff.inDays / 30).floor()} months remaining';
    } else if (diff.inDays > 0) {
      return '${diff.inDays} days remaining';
    } else {
      return 'Ending soon';
    }
  }

  @override
  List<Object?> get props => [
        id,
        yearLabel,
        startYear,
        endYear,
        startDate,
        endDate,
        isCurrent,
        instituteId,
        createdAt,
      ];

  @override
  String toString() {
    return 'AcademicYearModel('
        'id: $id, '
        'yearLabel: $yearLabel, '
        'yearRange: $yearRange, '
        'isCurrent: $isCurrent, '
        'status: $status'
        ')';
  }
}

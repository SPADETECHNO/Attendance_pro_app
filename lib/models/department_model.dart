import 'package:equatable/equatable.dart';

class DepartmentModel extends Equatable {
  final String id;
  final String name;
  final String? description;
  final String instituteId;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DepartmentModel({
    required this.id,
    required this.name,
    this.description,
    required this.instituteId,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DepartmentModel.fromJson(Map<String, dynamic> json) {
    return DepartmentModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      instituteId: json['institute_id'] as String,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'institute_id': instituteId,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  DepartmentModel copyWith({
    String? id,
    String? name,
    String? description,
    String? instituteId,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DepartmentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      instituteId: instituteId ?? this.instituteId,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Convenience getters
  String get displayDescription => description ?? 'No description provided';
  bool get hasDescription => description != null && description!.isNotEmpty;

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        instituteId,
        createdBy,
        createdAt,
        updatedAt,
      ];

  @override
  String toString() {
    return 'DepartmentModel('
        'id: $id, '
        'name: $name, '
        'instituteId: $instituteId'
        ')';
  }
}

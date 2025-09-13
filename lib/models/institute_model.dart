class InstituteModel {
  final String id;
  final String name;
  final String? address;
  final String? phone;
  final double? gpsLatitude;
  final double? gpsLongitude;
  final int allowedRadius;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const InstituteModel({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    this.gpsLatitude,
    this.gpsLongitude,
    required this.allowedRadius,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  // Computed properties
  bool get hasGpsCoordinates => gpsLatitude != null && gpsLongitude != null;

  String get coordinates => hasGpsCoordinates 
      ? '${gpsLatitude!.toStringAsFixed(6)}, ${gpsLongitude!.toStringAsFixed(6)}' 
      : 'Not set';

  String get displayAddress => address?.isNotEmpty == true ? address! : 'No address provided';
  String get displayPhone => phone?.isNotEmpty == true ? phone! : 'No phone provided';

  double get radiusInKilometers => allowedRadius / 1000.0;

  String get radiusDisplayText => allowedRadius >= 1000
      ? '${radiusInKilometers.toStringAsFixed(1)} km'
      : '${allowedRadius}m';

  factory InstituteModel.fromJson(Map<String, dynamic> json) {
    // Util functions to safely parse types
    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    int parseInt(dynamic value, {int defaultValue = 100}) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? defaultValue;
      return defaultValue;
    }

    String parseString(dynamic value, {String defaultValue = ''}) {
      if (value == null) return defaultValue;
      return value.toString();
    }

    DateTime parseDateTime(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    return InstituteModel(
      id: parseString(json['id']),
      name: parseString(json['name']),
      address: json['address']?.toString(),
      phone: json['phone']?.toString(),
      gpsLatitude: parseDouble(json['gps_latitude']),
      gpsLongitude: parseDouble(json['gps_longitude']),
      allowedRadius: parseInt(json['allowed_radius'], defaultValue: 100),
      createdBy: json['created_by']?.toString(),
      createdAt: parseDateTime(json['created_at']),
      updatedAt: parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'phone': phone,
      'gps_latitude': gpsLatitude,
      'gps_longitude': gpsLongitude,
      'allowed_radius': allowedRadius,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  InstituteModel copyWith({
    String? id,
    String? name,
    String? address,
    String? phone,
    double? gpsLatitude,
    double? gpsLongitude,
    int? allowedRadius,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InstituteModel(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      gpsLatitude: gpsLatitude ?? this.gpsLatitude,
      gpsLongitude: gpsLongitude ?? this.gpsLongitude,
      allowedRadius: allowedRadius ?? this.allowedRadius,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'InstituteModel(id: $id, name: $name, hasGPS: $hasGpsCoordinates, radius: $radiusDisplayText)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InstituteModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

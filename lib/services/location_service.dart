import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:attendance_pro_app/constants/app_constants.dart';
import 'package:attendance_pro_app/utils/helpers.dart';

class LocationService {
  /// Check if location services are enabled on device
  static Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Check current location permission status
  static Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  /// Request location permission from user
  static Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }

  /// ✅ Added: Get current location (alias for getCurrentPosition)
  static Future<LocationResult> getCurrentLocation({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration? timeLimit,
  }) async {
    try {
      // Check if location service is enabled
      if (!await isLocationServiceEnabled()) {
        return LocationResult(
          hasLocation: false,
          error: 'Location services are disabled',
          errorCode: AppConstants.locationServiceDisabled,
        );
      }

      // Check permission
      LocationPermission permission = await checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await requestPermission();
        if (permission == LocationPermission.denied) {
          return LocationResult(
            hasLocation: false,
            error: 'Location permission denied',
            errorCode: AppConstants.locationPermissionDenied,
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationResult(
          hasLocation: false,
          error: 'Location permission permanently denied. Please enable in settings.',
          errorCode: AppConstants.locationPermissionDenied,
        );
      }

      // Get position with timeout
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: accuracy,
        timeLimit: timeLimit ?? const Duration(seconds: 30),
      );

      return LocationResult(
        hasLocation: true,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
      );
    } catch (e) {
      AppHelpers.debugError('Get current location error: $e');
      
      String errorMessage;
      String errorCode;
      
      if (e is LocationServiceDisabledException) {
        errorMessage = 'Location services are disabled';
        errorCode = AppConstants.locationServiceDisabled;
      } else if (e is PermissionDeniedException) {
        errorMessage = 'Location permission denied';
        errorCode = AppConstants.locationPermissionDenied;
      } else {
        errorMessage = 'Failed to get location: ${e.toString()}';
        errorCode = AppConstants.networkConnectionFailed;
      }

      return LocationResult(
        hasLocation: false,
        error: errorMessage,
        errorCode: errorCode,
      );
    }
  }

  /// Get current position with error handling
  static Future<Position?> getCurrentPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration? timeLimit,
  }) async {
    try {
      // Check if location service is enabled
      if (!await isLocationServiceEnabled()) {
        throw LocationServiceDisabledException();
      }

      // Check permission
      LocationPermission permission = await checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await requestPermission();
        if (permission == LocationPermission.denied) {
          throw LocationPermissionDeniedException('Location permission denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw LocationPermissionDeniedException('Location permission permanently denied');
      }

      // Get position with timeout
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: accuracy,
        timeLimit: timeLimit ?? const Duration(seconds: 30),
      );

      return position;
    } catch (e) {
      AppHelpers.debugError('Get current position error: $e');
      return null;
    }
  }

  /// Get last known position
  static Future<Position?> getLastKnownPosition() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (e) {
      AppHelpers.debugError('Get last known position error: $e');
      return null;
    }
  }

  /// Calculate distance between two coordinates in meters
  static double calculateDistance({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  /// Calculate bearing between two coordinates
  static double calculateBearing({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    return Geolocator.bearingBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  /// Check if user is within allowed radius of institute
  static bool isWithinAllowedRadius({
    required double userLatitude,
    required double userLongitude,
    required double instituteLatitude,
    required double instituteLongitude,
    required double allowedRadiusMeters,
  }) {
    final distance = calculateDistance(
      startLatitude: userLatitude,
      startLongitude: userLongitude,
      endLatitude: instituteLatitude,
      endLongitude: instituteLongitude,
    );

    return distance <= allowedRadiusMeters;
  }

  /// Get location stream for continuous tracking
  static Stream<Position> getPositionStream({
    LocationSettings? locationSettings,
  }) {
    final settings = locationSettings ??
        const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // meters
        );

    return Geolocator.getPositionStream(locationSettings: settings);
  }

  /// Validate location for attendance marking
  static Future<LocationValidationResult> validateLocationForAttendance({
    required double instituteLatitude,
    required double instituteLongitude,
    required double allowedRadiusMeters,
  }) async {
    try {
      final position = await getCurrentPosition();
      if (position == null) {
        return LocationValidationResult(
          isValid: false,
          error: 'Unable to get current location',
          errorCode: AppConstants.locationServiceDisabled,
        );
      }

      // Check accuracy
      if (position.accuracy > 50) { // 50 meters accuracy threshold
        return LocationValidationResult(
          isValid: false,
          error: 'Location accuracy too low (${position.accuracy.toStringAsFixed(1)}m)',
          errorCode: AppConstants.locationAccuracyLow,
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
        );
      }

      // Calculate distance from institute
      final distance = calculateDistance(
        startLatitude: position.latitude,
        startLongitude: position.longitude,
        endLatitude: instituteLatitude,
        endLongitude: instituteLongitude,
      );

      // Check if within allowed radius
      final isWithinRadius = distance <= allowedRadiusMeters;

      return LocationValidationResult(
        isValid: isWithinRadius,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        distanceFromInstitute: distance.round(),
        error: isWithinRadius ? null : 'Outside allowed area (${distance.toStringAsFixed(0)}m away)',
        errorCode: isWithinRadius ? null : AppConstants.locationOutOfRange,
      );
    } catch (e) {
      AppHelpers.debugError('Location validation error: $e');
      
      String errorCode;
      String errorMessage;
      
      if (e is LocationServiceDisabledException) {
        errorCode = AppConstants.locationServiceDisabled;
        errorMessage = 'Location services are disabled';
      } else if (e is LocationPermissionDeniedException) {
        errorCode = AppConstants.locationPermissionDenied;
        errorMessage = 'Location permission denied';
      } else {
        errorCode = AppConstants.networkConnectionFailed;
        errorMessage = 'Location error: ${e.toString()}';
      }

      return LocationValidationResult(
        isValid: false,
        error: errorMessage,
        errorCode: errorCode,
      );
    }
  }

  /// Open app settings for location permissions
  static Future<void> openLocationSettings() async {
    try {
      await Geolocator.openLocationSettings();
    } catch (e) {
      AppHelpers.debugError('Open location settings error: $e');
      // Fallback to general app settings
      await openAppSettings();
    }
  }

  /// Open app settings
  static Future<void> openAppSettings() async {
    try {
      await Geolocator.openAppSettings();
    } catch (e) {
      AppHelpers.debugError('Open app settings error: $e');
    }
  }

  /// Format coordinates for display
  static String formatCoordinates(double latitude, double longitude) {
    return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  }

  /// Format distance for display
  static String formatDistance(double distanceInMeters) {
    if (distanceInMeters >= 1000) {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)} km';
    } else {
      return '${distanceInMeters.toStringAsFixed(0)} m';
    }
  }
}

/// ✅ New: Simple result class for getCurrentLocation
class LocationResult {
  final bool hasLocation;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final String? error;
  final String? errorCode;

  LocationResult({
    required this.hasLocation,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.error,
    this.errorCode,
  });

  @override
  String toString() {
    if (hasLocation) {
      return 'LocationResult(lat: $latitude, lng: $longitude, accuracy: ${accuracy?.toStringAsFixed(1)}m)';
    } else {
      return 'LocationResult(error: $error)';
    }
  }
}

/// Result class for location validation
class LocationValidationResult {
  final bool isValid;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final int? distanceFromInstitute;
  final String? error;
  final String? errorCode;

  LocationValidationResult({
    required this.isValid,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.distanceFromInstitute,
    this.error,
    this.errorCode,
  });

  Map<String, dynamic> toJson() {
    return {
      'is_valid': isValid,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'distance_from_institute': distanceFromInstitute,
      'error': error,
      'error_code': errorCode,
    };
  }

  @override
  String toString() {
    return 'LocationValidationResult(isValid: $isValid, error: $error, distance: $distanceFromInstitute)';
  }
}

/// Custom exceptions for location errors
class LocationPermissionDeniedException implements Exception {
  final String message;
  LocationPermissionDeniedException(this.message);

  @override
  String toString() => 'LocationPermissionDeniedException: $message';
}

class LocationServiceDisabledException implements Exception {
  @override
  String toString() => 'LocationServiceDisabledException: Location services are disabled';
}

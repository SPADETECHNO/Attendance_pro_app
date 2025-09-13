import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attendance_pro_app/services/auth_service.dart';
import 'package:attendance_pro_app/services/database_service.dart';
import 'package:attendance_pro_app/services/location_service.dart';
import 'package:attendance_pro_app/widgets/loading_widget.dart';
import 'package:attendance_pro_app/widgets/custom_button.dart';
import 'package:attendance_pro_app/utils/constants.dart';
import 'package:attendance_pro_app/utils/helpers.dart';
import 'package:attendance_pro_app/models/user_model.dart';
import 'package:attendance_pro_app/models/session_model.dart';
import 'package:attendance_pro_app/models/attendance_model.dart';
import 'package:attendance_pro_app/constants/app_constants.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';

class SessionDetailScreen extends StatefulWidget {
  final SessionModel session;

  const SessionDetailScreen({
    super.key,
    required this.session,
  });

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  UserModel? _currentUser;
  AttendanceModel? _attendanceRecord;
  bool _isLoading = true;
  bool _isMarkingAttendance = false;

  @override
  void initState() {
    super.initState();
    _loadSessionData();
  }

  Future<void> _loadSessionData() async {
    try {
      final authService = context.read<AuthService>();
      final databaseService = context.read<DatabaseService>();

      // Get current user
      final user = await authService.getCurrentUserProfile();
      if (user == null) return;

      // Check if user has already marked attendance for this session
      final attendanceRecords = await databaseService.getAttendanceRecords(widget.session.id);
      final userAttendance = attendanceRecords.firstWhere(
        (record) => record.userId == user.id,
        orElse: () => throw StateError('Not found'),
      );

      setState(() {
        _currentUser = user;
        _attendanceRecord = userAttendance;
        _isLoading = false;
      });
    } catch (e) {
      // User hasn't marked attendance yet
      setState(() async {
        _currentUser = await context.read<AuthService>().getCurrentUserProfile();
        _attendanceRecord = null;
        _isLoading = false;
      });
    }
  }

  /// Validates user location against real institute GPS coordinates from database
  Future<LocationValidationResult> _validateLocationForSession() async {
    try {
      final databaseService = context.read<DatabaseService>();

      // 1. Fetch session details including departmentId
      final session = await databaseService.getSessionById(widget.session.id);
      if (session == null) {
        return LocationValidationResult(
          isValid: false,
          error: 'Session not found',
          errorCode: 'SESSION_NOT_FOUND',
        );
      }

      // 2. Fetch department details to get instituteId
      final department = await databaseService.getDepartmentById(session.departmentId);
      if (department == null) {
        return LocationValidationResult(
          isValid: false,
          error: 'Department not found',
          errorCode: 'DEPARTMENT_NOT_FOUND',
        );
      }

      // 3. Fetch institute details to get GPS coordinates and allowed radius
      final institute = await databaseService.getInstituteById(department.instituteId);
      if (institute == null) {
        return LocationValidationResult(
          isValid: false,
          error: 'Institute not found',
          errorCode: 'INSTITUTE_NOT_FOUND',
        );
      }

      // 4. Check if institute has GPS coordinates set
      if (!institute.hasGpsCoordinates) {
        return LocationValidationResult(
          isValid: false,
          error: 'Institute GPS coordinates not configured',
          errorCode: 'GPS_NOT_CONFIGURED',
        );
      }

      // 5. Validate current device location against institute GPS coordinates
      final validationResult = await LocationService.validateLocationForAttendance(
        instituteLatitude: institute.gpsLatitude!,
        instituteLongitude: institute.gpsLongitude!,
        allowedRadiusMeters: institute.allowedRadius.toDouble(),
      );

      return validationResult;
    } catch (e) {
      AppHelpers.debugError('GPS validation error: $e');
      return LocationValidationResult(
        isValid: false,
        error: 'Failed to validate location: ${e.toString()}',
        errorCode: 'VALIDATION_ERROR',
      );
    }
  }

  /// Show dialog to help user enable location services
  void _showLocationSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.location_off,
              color: AppColors.warning,
              size: AppSizes.iconMd,
            ),
            const SizedBox(width: AppSizes.sm),
            const Text('Location Required'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This app needs location access to verify you are at the correct location for attendance marking.',
            ),
            const SizedBox(height: AppSizes.md),
            Container(
              padding: const EdgeInsets.all(AppSizes.sm),
              decoration: BoxDecoration(
                color: AppColors.info.withAlpha((0.1 * 255).toInt()),
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info,
                        color: AppColors.info,
                        size: AppSizes.iconSm,
                      ),
                      const SizedBox(width: AppSizes.sm),
                      const Text(
                        'Steps to enable location:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.xs),
                  const Text(
                    '1. Tap "Open Settings" below\n'
                    '2. Enable location services\n'
                    '3. Grant permission to this app\n'
                    '4. Return and try again',
                    style: TextStyle(fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await LocationService.openLocationSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _markAttendance() async {
    if (_currentUser == null || !widget.session.canMarkAttendance) return;

    setState(() => _isMarkingAttendance = true);

    try {
      final databaseService = context.read<DatabaseService>();
      LocationValidationResult? locationResult;

      // ✅ REAL GPS VALIDATION - Fetch actual institute coordinates
      if (widget.session.gpsValidationEnabled) {
        locationResult = await _validateLocationForSession();

        if (!locationResult.isValid) {
          setState(() => _isMarkingAttendance = false);
          
          // Show appropriate error message based on error code
          String errorMessage = locationResult.error ?? 'Location validation failed';
          
          switch (locationResult.errorCode) {
            case 'SESSION_NOT_FOUND':
              errorMessage = 'Session not found. Please refresh and try again.';
              break;
            case 'DEPARTMENT_NOT_FOUND':
              errorMessage = 'Department information not found.';
              break;
            case 'INSTITUTE_NOT_FOUND':
              errorMessage = 'Institute information not found.';
              break;
            case 'GPS_NOT_CONFIGURED':
              errorMessage = 'Institute GPS location not configured. Contact admin.';
              break;
            case AppConstants.locationServiceDisabled:
              errorMessage = 'Please enable location services to mark attendance.';
              break;
            case AppConstants.locationPermissionDenied:
              errorMessage = 'Location permission required to mark attendance.';
              break;
            case AppConstants.locationAccuracyLow:
              errorMessage = 'GPS accuracy too low. Please move to an open area.';
              break;
            case AppConstants.locationOutOfRange:
              errorMessage = 'You are outside the allowed attendance area.';
              break;
            default:
              // Use the original error message
              break;
          }
          
          AppHelpers.showErrorToast(errorMessage);
          
          // Offer option to open location settings if needed
          if (locationResult.errorCode == AppConstants.locationServiceDisabled ||
              locationResult.errorCode == AppConstants.locationPermissionDenied) {
            _showLocationSettingsDialog();
          }
          
          return;
        }
      }

      // Mark attendance as present
      await databaseService.markAttendance(
        sessionId: widget.session.id,
        userId: _currentUser!.id,
        markedBy: _currentUser!.id,
        status: 'present',
        markedByUser: true,
        gpsLatitude: locationResult?.latitude,
        gpsLongitude: locationResult?.longitude,
        distanceFromInstitute: locationResult?.distanceFromInstitute,
      );

      AppHelpers.showSuccessToast('Attendance marked successfully!');
      
      // Show location info if available
      if (locationResult != null && locationResult.distanceFromInstitute != null) {
        AppHelpers.showInfoToast(
          'Distance from institute: ${LocationService.formatDistance(locationResult.distanceFromInstitute!.toDouble())}'
        );
      }
      
      // Reload session data to get the attendance record
      await _loadSessionData();
    } catch (e) {
      AppHelpers.debugError('Mark attendance error: $e');
      AppHelpers.showErrorToast('Failed to mark attendance: ${e.toString()}');
    } finally {
      setState(() => _isMarkingAttendance = false);
    }
  }

  void _showQrCode() {
    if (_currentUser == null) return;

    final qrData = {
      'user_id': _currentUser!.id,
      'session_id': widget.session.id,
      'timestamp': DateTime.now().toIso8601String(),
      'version': 1,
    };

    showDialog(
      context: context,
      builder: (context) => QrCodeDialog(
        qrData: jsonEncode(qrData),
        session: widget.session,
        user: _currentUser!,
      ),
    );
  }

  Color _getSessionStatusColor() {
    return AppHelpers.getSessionStatusColor(
      widget.session.startDateTime,
      widget.session.endDateTime,
    );
  }

  IconData _getSessionStatusIcon() {
    return AppHelpers.getSessionStatusIcon(
      widget.session.startDateTime,
      widget.session.endDateTime,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(
        body: LoadingWidget(message: 'Loading session details...'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.session.name),
        backgroundColor: _getSessionStatusColor(),
        foregroundColor: Colors.white,
        actions: [
          if (widget.session.canMarkAttendance && _attendanceRecord == null)
            IconButton(
              onPressed: _showQrCode,
              icon: const Icon(Icons.qr_code),
              tooltip: 'Show QR Code',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Session Status Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSizes.lg),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _getSessionStatusColor(),
                    _getSessionStatusColor().withAlpha((0.8 * 255).toInt()),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppSizes.radiusLg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSizes.sm),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha((0.2 * 255).toInt()),
                          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                        ),
                        child: Icon(
                          _getSessionStatusIcon(),
                          color: Colors.white,
                          size: AppSizes.iconMd,
                        ),
                      ),
                      const SizedBox(width: AppSizes.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.session.name,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              widget.session.status,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white.withAlpha((0.9 * 255).toInt()),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (widget.session.description?.isNotEmpty == true) ...[
                    const SizedBox(height: AppSizes.md),
                    Text(
                      widget.session.description!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withAlpha((0.8 * 255).toInt()),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: AppSizes.xl),

            // Session Details
            Text(
              'Session Details',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSizes.md),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.md),
                child: Column(
                  children: [
                    _buildDetailRow(
                      'Start Time',
                      AppHelpers.formatDateTime(widget.session.startDateTime),
                      Icons.access_time,
                    ),
                    _buildDetailRow(
                      'End Time',
                      AppHelpers.formatDateTime(widget.session.endDateTime),
                      Icons.access_time_filled,
                    ),
                    _buildDetailRow(
                      'Duration',
                      widget.session.durationString,
                      Icons.schedule,
                    ),
                    if (widget.session.isLive)
                      _buildDetailRow(
                        'Time Remaining',
                        widget.session.timeRemaining,
                        Icons.timer,
                        valueColor: AppColors.live,
                      ),
                    _buildDetailRow(
                      'GPS Validation',
                      widget.session.gpsValidationEnabled ? 'Enabled' : 'Disabled',
                      Icons.location_on,
                      valueColor: widget.session.gpsValidationEnabled 
                          ? AppColors.success 
                          : AppColors.gray500,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSizes.xl),

            // Attendance Status
            Text(
              'My Attendance',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSizes.md),

            if (_attendanceRecord != null)
              _buildAttendanceCard(theme)
            else if (widget.session.canMarkAttendance)
              _buildMarkAttendanceCard(theme)
            else
              _buildNotAvailableCard(theme),

            const SizedBox(height: AppSizes.xl),

            // Instructions
            if (widget.session.canMarkAttendance && _attendanceRecord == null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSizes.md),
                decoration: BoxDecoration(
                  color: AppColors.info.withAlpha((0.1 * 255).toInt()),
                  borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                  border: Border.all(
                    color: AppColors.info.withAlpha((0.3 * 255).toInt()),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info,
                          color: AppColors.info,
                          size: AppSizes.iconSm,
                        ),
                        const SizedBox(width: AppSizes.sm),
                        Text(
                          'How to Mark Attendance',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.info,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.sm),
                    const Text(
                      '1. Tap "Mark Attendance" button below\n'
                      '2. Allow location access if prompted\n'
                      '3. Ensure you\'re within the allowed location\n'
                      '4. Your attendance will be recorded automatically\n\n'
                      'Alternative: Show your QR code to admin for scanning',
                      style: TextStyle(height: 1.5),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.md),
      child: Row(
        children: [
          Icon(
            icon,
            size: AppSizes.iconSm,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.gray600,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.gray800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard(ThemeData theme) {
    final record = _attendanceRecord!;
    final isPresent = record.isPresent;

    return Card(
      color: isPresent 
          ? AppColors.success.withAlpha((0.05 * 255).toInt())
          : AppColors.error.withAlpha((0.05 * 255).toInt()),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSizes.sm),
                  decoration: BoxDecoration(
                    color: isPresent 
                        ? AppColors.success.withAlpha((0.1 * 255).toInt())
                        : AppColors.error.withAlpha((0.1 * 255).toInt()),
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                  child: Icon(
                    isPresent ? Icons.check_circle : Icons.cancel,
                    color: isPresent ? AppColors.success : AppColors.error,
                    size: AppSizes.iconLg,
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Attendance Recorded',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Status: ${record.statusText}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isPresent ? AppColors.success : AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.sm,
                    vertical: AppSizes.xs,
                  ),
                  decoration: BoxDecoration(
                    color: isPresent ? AppColors.success : AppColors.error,
                    borderRadius: BorderRadius.circular(AppSizes.radiusRound),
                  ),
                  child: Text(
                    record.statusText.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSizes.sm),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withAlpha((0.5 * 255).toInt()),
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: AppSizes.iconXs,
                        color: theme.colorScheme.onSurface.withAlpha((0.6 * 255).toInt()),
                      ),
                      const SizedBox(width: AppSizes.xs),
                      Text(
                        'Marked at: ${AppHelpers.formatDateTime(record.markedAt)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  if (record.hasGpsData) ...[
                    const SizedBox(height: AppSizes.xs),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: AppSizes.iconXs,
                          color: theme.colorScheme.onSurface.withAlpha((0.6 * 255).toInt()),
                        ),
                        const SizedBox(width: AppSizes.xs),
                        Text(
                          'Location: ${record.coordinates}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                  if (record.distanceFromInstitute != null) ...[
                    const SizedBox(height: AppSizes.xs),
                    Row(
                      children: [
                        Icon(
                          Icons.radar,
                          size: AppSizes.iconXs,
                          color: theme.colorScheme.onSurface.withAlpha((0.6 * 255).toInt()),
                        ),
                        const SizedBox(width: AppSizes.xs),
                        Text(
                          'Distance: ${record.distanceText}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSizes.xs),
                  Row(
                    children: [
                      Icon(
                        Icons.person,
                        size: AppSizes.iconXs,
                        color: theme.colorScheme.onSurface.withAlpha((0.6 * 255).toInt()),
                      ),
                      const SizedBox(width: AppSizes.xs),
                      Text(
                        'Method: ${record.markedByText}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarkAttendanceCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSizes.sm),
                  decoration: BoxDecoration(
                    color: AppColors.success.withAlpha((0.1 * 255).toInt()),
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                  child: const Icon(
                    Icons.touch_app,
                    color: AppColors.success,
                    size: AppSizes.iconLg,
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ready to Mark Attendance',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Session is live and accepting attendance',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.lg),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'Show QR Code',
                    onPressed: _showQrCode,
                    icon: Icons.qr_code,
                    isOutlined: true,
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: CustomButton(
                    text: 'Mark Attendance',
                    onPressed: _isMarkingAttendance ? null : _markAttendance,
                    isLoading: _isMarkingAttendance,
                    icon: Icons.check_circle,
                    backgroundColor: AppColors.success,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotAvailableCard(ThemeData theme) {
    String reason;
    IconData icon;
    Color color;

    if (widget.session.hasEnded) {
      reason = 'Session has ended';
      icon = Icons.event_busy;
      color = AppColors.gray500;
    } else if (widget.session.isUpcoming) {
      reason = 'Session hasn\'t started yet';
      icon = Icons.schedule;
      color = AppColors.info;
    } else {
      reason = 'Session is not active';
      icon = Icons.pause_circle;
      color = AppColors.warning;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSizes.sm),
              decoration: BoxDecoration(
                color: color.withAlpha((0.1 * 255).toInt()),
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              child: Icon(
                icon,
                color: color,
                size: AppSizes.iconLg,
              ),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Attendance Not Available',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    reason,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// QR Code Dialog
class QrCodeDialog extends StatelessWidget {
  final String qrData;
  final SessionModel session;
  final UserModel user;

  const QrCodeDialog({
    super.key,
    required this.qrData,
    required this.session,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSizes.xs),
                  decoration: BoxDecoration(
                    color: AppColors.user.withAlpha((0.1 * 255).toInt()),
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                  ),
                  child: const Icon(
                    Icons.qr_code,
                    color: AppColors.user,
                    size: AppSizes.iconSm,
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: Text(
                    'My QR Code',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),

            const SizedBox(height: AppSizes.lg),

            // QR Code
            Container(
              padding: const EdgeInsets.all(AppSizes.md),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                border: Border.all(color: AppColors.gray300),
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 200.0,
                backgroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: AppSizes.lg),

            // User Info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSizes.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withAlpha((0.5 * 255).toInt()),
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'ID: ${user.userId}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSizes.sm),
                  Text(
                    'Session: ${session.name}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSizes.lg),

            // Instructions
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSizes.sm),
              decoration: BoxDecoration(
                color: AppColors.info.withAlpha((0.1 * 255).toInt()),
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info,
                    color: AppColors.info,
                    size: AppSizes.iconSm,
                  ),
                  const SizedBox(width: AppSizes.sm),
                  Expanded(
                    child: Text(
                      'Show this QR code to your admin for attendance scanning',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.info,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSizes.lg),

            // Close Button
            SizedBox(
              width: double.infinity,
              child: CustomButton(
                text: 'Close',
                onPressed: () => Navigator.pop(context),
                isOutlined: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

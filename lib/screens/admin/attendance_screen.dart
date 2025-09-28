import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:attendance_pro_app/services/auth_service.dart';
import 'package:attendance_pro_app/services/database_service.dart';
import 'package:attendance_pro_app/services/location_service.dart';
import 'package:attendance_pro_app/widgets/loading_widget.dart';
import 'package:attendance_pro_app/widgets/custom_button.dart';
import 'package:attendance_pro_app/utils/constants.dart';
import 'package:attendance_pro_app/utils/helpers.dart';
import 'package:attendance_pro_app/models/session_model.dart';
import 'package:attendance_pro_app/models/user_model.dart';
import 'dart:convert';

class AttendanceScreen extends StatefulWidget {
  final SessionModel? session;

  const AttendanceScreen({
    super.key,
    this.session,
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  UserModel? _currentUser;
  SessionModel? _selectedSession;
  List<SessionModel> _availableSessions = [];
  List<Map<String, dynamic>> _attendanceRecords = [];
  
  bool _isLoading = true;
  bool _isScanning = false;
  bool _isScannerActive = false;
  MobileScannerController? _scannerController;

  @override
  void initState() {
    super.initState();
    _selectedSession = widget.session;
    _loadData();
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final authService = context.read<AuthService>();
      final databaseService = context.read<DatabaseService>();

      // Get current user
      final user = await authService.getCurrentUserProfile();
      if (user == null) return;

      // Get available sessions for this department
      final sessions = await databaseService.getSessions(
        departmentId: user.departmentId,
      );

      // Filter to only active/live sessions if no specific session provided
      final activeSessions = widget.session == null
          ? sessions.where((s) => s.canMarkAttendance).toList()
          : sessions;

      setState(() {
        _currentUser = user;
        _availableSessions = activeSessions;
        if (_selectedSession == null && activeSessions.isNotEmpty) {
          _selectedSession = activeSessions.first;
        }
        _isLoading = false;
      });

      if (_selectedSession != null) {
        await _loadAttendanceRecords();
      }
    } catch (e) {
      AppHelpers.debugError('Load attendance data error: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAttendanceRecords() async {
    if (_selectedSession == null) return;

    try {
      final databaseService = context.read<DatabaseService>();
      final records = await databaseService.getSessionAttendance(_selectedSession!.id);
      
      setState(() {
        _attendanceRecords = records;
      });
    } catch (e) {
      AppHelpers.debugError('Load attendance records error: $e');
    }
  }

  void _startScanning() {
    if (_selectedSession == null) {
      AppHelpers.showWarningToast('Please select a session first');
      return;
    }

    if (!_selectedSession!.canMarkAttendance) {
      AppHelpers.showWarningToast('This session is not active for attendance');
      return;
    }

    setState(() {
      _isScannerActive = true;
      _scannerController = MobileScannerController();
    });
  }

  void _stopScanning() {
    setState(() {
      _isScannerActive = false;
    });
    _scannerController?.dispose();
    _scannerController = null;
  }
  
  Future<void> _onQRScanned(BarcodeCapture capture) async {
    if (_isScanning || _selectedSession == null) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final code = barcodes.first.rawValue;
    if (code == null) return;

    setState(() => _isScanning = true);

    try {
      String? userId;
      String? sessionId;

      final decoded = jsonDecode(code);
      if (decoded is Map) {
        userId = decoded['user_id']?.toString();
        sessionId = decoded['session_id']?.toString();
      } else if (decoded is String || decoded is int) {
        // fallback: QR only has user_id
        userId = decoded.toString();
        sessionId = _selectedSession!.id;
      }

      if (userId == null || sessionId != _selectedSession!.id) {
        AppHelpers.showErrorToast('Invalid QR code');
        return;
      }

      await _markAttendance(userId, 'present', isScanned: true);

    } catch (e) {
      AppHelpers.debugError('QR scan error: $e');
      AppHelpers.showErrorToast('Failed to process QR code');
    } finally {
      setState(() => _isScanning = false);
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  // Future<void> _onQRScanned(BarcodeCapture capture) async {
  //   if (_isScanning || _selectedSession == null) return;

  //   final barcodes = capture.barcodes;
  //   if (barcodes.isEmpty) return;

  //   final code = barcodes.first.rawValue;
  //   if (code == null) return;

  //   setState(() => _isScanning = true);

  //   try {
  //     // Parse QR code data
  //     final qrData = jsonDecode(code);
  //     final userId = qrData['user_id'] as String?;
  //     final sessionId = qrData['session_id'] as String?;

  //     if (userId == null || sessionId != _selectedSession!.id) {
  //       AppHelpers.showErrorToast('Invalid QR code');
  //       return;
  //     }

  //     await _markAttendance(userId, 'present', isScanned: true);

  //   } catch (e) {
  //     AppHelpers.debugError('QR scan error: $e');
  //     AppHelpers.showErrorToast('Failed to process QR code');
  //   } finally {
  //     setState(() => _isScanning = false);
      
  //     // Brief pause before allowing next scan
  //     await Future.delayed(const Duration(seconds: 2));
  //   }
  // }

  Future<void> _markAttendance(
    String userId,
    String status, {
    bool isScanned = false,
  }) async {
    if (_selectedSession == null || _currentUser == null) return;

    try {
      final databaseService = context.read<DatabaseService>();
      
      // Get location if GPS validation is enabled
      LocationValidationResult? locationResult;
      if (_selectedSession!.gpsValidationEnabled) {
        // For admin marking, we might skip GPS validation or use institute coordinates
        // This depends on your business logic
      }

      await databaseService.markAttendance(
        sessionId: _selectedSession!.id,
        userId: userId,
        markedBy: _currentUser!.id,
        status: status,
        markedByAdmin: true,
        gpsLatitude: locationResult?.latitude,
        gpsLongitude: locationResult?.longitude,
        distanceFromInstitute: locationResult?.distanceFromInstitute,
      );

      AppHelpers.showSuccessToast(
        isScanned 
            ? 'Attendance marked via QR scan'
            : 'Attendance marked manually'
      );

      // Reload attendance records
      await _loadAttendanceRecords();

    } catch (e) {
      AppHelpers.debugError('Mark attendance error: $e');
      AppHelpers.showErrorToast('Failed to mark attendance');
    }
  }

  void _showManualAttendanceDialog() {
    if (_selectedSession == null) return;

    showDialog(
      context: context,
      builder: (context) => ManualAttendanceDialog(
        session: _selectedSession!,
        onAttendanceMarked: (userId, status) {
          _markAttendance(userId, status);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(
        body: LoadingWidget(message: 'Loading attendance data...'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mark Attendance'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        actions: [
          if (_selectedSession != null)
            IconButton(
              onPressed: _showManualAttendanceDialog,
              icon: const Icon(Icons.edit),
              tooltip: 'Manual Attendance',
            ),
        ],
      ),
      body: Column(
        children: [
          // Session Selection
          if (_availableSessions.length > 1)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSizes.md),
              color: theme.colorScheme.surfaceVariant,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Session',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSizes.sm),
                  DropdownButtonFormField<SessionModel>(
                    value: _selectedSession,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: AppSizes.md,
                        vertical: AppSizes.sm,
                      ),
                    ),
                    items: _availableSessions.map((session) {
                      return DropdownMenuItem(
                        value: session,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              session.name,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${AppHelpers.formatDateTime(session.startDateTime)} • ${session.status}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (session) {
                      setState(() {
                        _selectedSession = session;
                      });
                      if (session != null) {
                        _loadAttendanceRecords();
                      }
                    },
                  ),
                ],
              ),
            ),

          // Scanner or Content
          Expanded(
            child: _selectedSession == null
                ? const EmptyStateWidget(
                    icon: Icons.event_busy,
                    title: 'No Active Sessions',
                    subtitle: 'There are no sessions available for attendance marking',
                  )
                : _isScannerActive
                    ? _buildScannerView(theme)
                    : _buildAttendanceView(theme),
          ),
        ],
      ),
      floatingActionButton: _selectedSession?.canMarkAttendance == true
          ? FloatingActionButton.extended(
              onPressed: _isScannerActive ? _stopScanning : _startScanning,
              icon: Icon(_isScannerActive ? Icons.stop : Icons.qr_code_scanner),
              label: Text(_isScannerActive ? 'Stop Scanner' : 'Scan QR'),
              backgroundColor: _isScannerActive 
                  ? AppColors.error 
                  : theme.colorScheme.primary,
            )
          : null,
    );
  }

  Widget _buildScannerView(ThemeData theme) {
    return Column(
      children: [
        // Scanner Instructions
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSizes.md),
          color: AppColors.info.withOpacity(0.1),
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
                  'Point the camera at a student\'s QR code to mark attendance',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.info,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Scanner View
        Expanded(
          child: Stack(
            children: [
              MobileScanner(
                controller: _scannerController,
                onDetect: _onQRScanned,
              ),
              
              // Scanning Overlay
              if (_isScanning)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: const Center(
                    child: LoadingWidget(
                      message: 'Processing QR code...',
                      color: Colors.white,
                    ),
                  ),
                ),

              // Scanning Frame
              Center(
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Controls
        Container(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: 'Manual Entry',
                  onPressed: _showManualAttendanceDialog,
                  isOutlined: true,
                  icon: Icons.edit,
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: CustomButton(
                  text: 'Stop Scanner',
                  onPressed: _stopScanning,
                  backgroundColor: AppColors.error,
                  icon: Icons.stop,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceView(ThemeData theme) {
    return Column(
      children: [
        // Session Info
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSizes.md),
          color: theme.colorScheme.surfaceVariant,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedSession!.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.sm,
                      vertical: AppSizes.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppHelpers.getSessionStatusColor(
                        _selectedSession!.startDateTime,
                        _selectedSession!.endDateTime,
                      ).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppSizes.radiusRound),
                    ),
                    child: Text(
                      _selectedSession!.status,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppHelpers.getSessionStatusColor(
                          _selectedSession!.startDateTime,
                          _selectedSession!.endDateTime,
                        ),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.sm),
              Text(
                '${AppHelpers.formatDateTime(_selectedSession!.startDateTime)} - ${AppHelpers.formatTime(_selectedSession!.endDateTime)}',
                style: theme.textTheme.bodyMedium,
              ),
              if (_selectedSession!.description?.isNotEmpty == true) ...[
                const SizedBox(height: AppSizes.xs),
                Text(
                  _selectedSession!.description!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Attendance Records
        Expanded(
          child: _attendanceRecords.isEmpty
              ? EmptyStateWidget(
                  icon: Icons.people_outline,
                  title: 'No Attendance Records',
                  subtitle: 'Start scanning QR codes or manually mark attendance',
                  buttonText: 'Start Scanner',
                  onButtonPressed: _selectedSession!.canMarkAttendance 
                      ? _startScanning 
                      : null,
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSizes.md),
                  itemCount: _attendanceRecords.length,
                  itemBuilder: (context, index) {
                    final record = _attendanceRecords[index];
                    return _buildAttendanceRecord(record, theme);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAttendanceRecord(Map<String, dynamic> record, ThemeData theme) {
    final userProfile = record['profiles'];
    final status = record['status'] as String;
    final markedAt = DateTime.parse(record['marked_at']);
    final markedByUser = record['marked_by_user'] as bool? ?? false;
    final markedByAdmin = record['marked_by_admin'] as bool? ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppHelpers.getAttendanceStatusColor(status).withOpacity(0.1),
          child: Icon(
            AppHelpers.getAttendanceStatusIcon(status),
            color: AppHelpers.getAttendanceStatusColor(status),
          ),
        ),
        title: Text(
          userProfile?['name'] ?? 'Unknown User',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              userProfile?['user_id'] ?? '',
              style: theme.textTheme.bodySmall,
            ),
            Text(
              'Marked at ${AppHelpers.formatTime(markedAt)}',
              style: theme.textTheme.bodySmall,
            ),
            if (markedByUser)
              Text(
                'Self-marked',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.info,
                ),
              )
            else if (markedByAdmin)
              Text(
                'Admin marked',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.warning,
                ),
              ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.sm,
            vertical: AppSizes.xs,
          ),
          decoration: BoxDecoration(
            color: AppHelpers.getAttendanceStatusColor(status).withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          ),
          child: Text(
            status.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppHelpers.getAttendanceStatusColor(status),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

// Manual Attendance Dialog
class ManualAttendanceDialog extends StatefulWidget {
  final SessionModel session;
  final Function(String userId, String status) onAttendanceMarked;

  const ManualAttendanceDialog({
    super.key,
    required this.session,
    required this.onAttendanceMarked,
  });

  @override
  State<ManualAttendanceDialog> createState() => _ManualAttendanceDialogState();
}

class _ManualAttendanceDialogState extends State<ManualAttendanceDialog> {
  final _userIdController = TextEditingController();
  String _selectedStatus = 'present';

  @override
  void dispose() {
    _userIdController.dispose();
    super.dispose();
  }

  void _markAttendance() {
    final userId = _userIdController.text.trim();
    if (userId.isEmpty) {
      AppHelpers.showWarningToast('Please enter a User ID');
      return;
    }

    widget.onAttendanceMarked(userId, _selectedStatus);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Manual Attendance'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _userIdController,
            decoration: const InputDecoration(
              labelText: 'User ID',
              hintText: 'Enter student ID',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: AppSizes.md),
          DropdownButtonFormField<String>(
            value: _selectedStatus,
            decoration: const InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'present', child: Text('Present')),
              DropdownMenuItem(value: 'absent', child: Text('Absent')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedStatus = value);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _markAttendance,
          child: const Text('Mark Attendance'),
        ),
      ],
    );
  }
}

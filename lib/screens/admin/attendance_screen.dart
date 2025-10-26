// lib/screens/admin/attendance_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:attendance_pro_app/services/auth_service.dart';
import 'package:attendance_pro_app/services/database_service.dart';
import 'package:attendance_pro_app/services/location_service.dart';
import 'package:attendance_pro_app/widgets/loading_widget.dart';
import 'package:attendance_pro_app/widgets/custom_text_field.dart';
import 'package:attendance_pro_app/screens/admin/edit_session_screen.dart';
import 'package:attendance_pro_app/utils/constants.dart';
import 'package:attendance_pro_app/utils/helpers.dart';
import 'package:attendance_pro_app/models/session_model.dart';
import 'package:attendance_pro_app/models/user_model.dart';
import 'package:attendance_pro_app/constants/app_constants.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import 'dart:io';

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
  List<Map<String, dynamic>> _filteredRecords = [];
  bool _isLoading = true;
  bool _isScanning = false;
  bool _isScannerActive = false;
  bool _isDownloading = false;
  MobileScannerController? _scannerController;
  final _searchController = TextEditingController();
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _selectedSession = widget.session;
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final authService = context.read<AuthService>();
      final databaseService = context.read<DatabaseService>();
      final user = await authService.getCurrentUserProfile();
      
      if (user == null) return;

      final sessions = await databaseService.getSessions(
        departmentId: user.departmentId,
      );

      setState(() {
        _currentUser = user;
        _availableSessions = sessions;
        
        if (widget.session != null) {
          _selectedSession = sessions.firstWhere(
            (s) => s.id == widget.session!.id,
            orElse: () => widget.session!,
          );
        } else {
          final activeSessions = sessions.where((s) => s.canMarkAttendance).toList();
          if (activeSessions.isNotEmpty) {
            _selectedSession = activeSessions.first;
          } else if (sessions.isNotEmpty) {
            _selectedSession = sessions.first;
          }
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
      final records = await databaseService.getSessionAttendanceSimplified(
        _selectedSession!.id,
      );

      setState(() {
        _attendanceRecords = records.map((record) {
          final masterListData = record['institute_master_list'];
          return {
            'attendance_id': record['id'],
            'master_list_id': record['master_list_id'],
            'user_id': masterListData['user_id'],
            'user_detail': masterListData,
            'status': record['status'],
            'marked_at': record['marked_at'],
            'scan_count': record['scan_count'] ?? 0,
            'added_during_session': record['added_during_session'] ?? false,
          };
        }).toList();
      });
      
      _applyFilters();
    } catch (e) {
      AppHelpers.debugError('Load attendance records error: $e');
    }
  }

  void _applyFilters() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredRecords = _attendanceRecords.where((record) {
        final user = record['user_detail'];
        final matchesSearch = query.isEmpty ||
            user['name'].toString().toLowerCase().contains(query) ||
            user['user_id'].toString().toLowerCase().contains(query) ||
            user['email'].toString().toLowerCase().contains(query);
        
        final matchesStatus = _statusFilter == 'all' || record['status'] == _statusFilter;
        
        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  int _getStatusCount(String status) {
    if (status == 'all') return _attendanceRecords.length;
    return _attendanceRecords.where((r) => r['status'] == status).length;
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
      _scannerController?.dispose();
      _scannerController = null;
    });
  }

  Future<void> _onQRScanned(BarcodeCapture capture) async {
    if (_isScanning || _selectedSession == null) return;
    
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    
    final code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    setState(() => _isScanning = true);
    
    try {
      String userId;
      try {
        final qrData = jsonDecode(code);
        userId = qrData['user_id'].toString();
      } catch (jsonError) {
        userId = code.trim();
      }

      if (userId.isEmpty) {
        AppHelpers.showErrorToast('Invalid QR code');
        setState(() => _isScanning = false);
        return;
      }

      final existingRecord = _attendanceRecords.firstWhere(
        (r) => r['user_id'].toString() == userId,
        orElse: () => {},
      );

      if (existingRecord.isEmpty) {
        _stopScanning();
        _showAddUserDialog(userId);
      } else {
        await _markAttendance(
          existingRecord['master_list_id'],
          'present',
          isScanned: true,
        );
      }
    } catch (e) {
      AppHelpers.debugError('QR scan error: $e');
      AppHelpers.showErrorToast('Failed to process QR code');
    } finally {
      setState(() => _isScanning = false);
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  void _showAddUserDialog(String scannedUserId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSizes.xs),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              child: Icon(
                Icons.person_add_outlined,
                color: AppColors.warning,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            Text(
              'User Not in Session',
              style: TextStyle(
                color: AppColors.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSizes.sm),
              decoration: BoxDecoration(
                color: AppColors.gray100,
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              child: Text(
                'User ID: $scannedUserId',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.gray700,
                ),
              ),
            ),
            const SizedBox(height: AppSizes.md),
            Text(
              'This user is not enrolled in the current session. Would you like to add them and mark as present?',
              style: TextStyle(
                color: AppColors.gray700,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startScanning();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.gray600,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.lg,
                vertical: AppSizes.sm,
              ),
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _addUserAndMarkAttendance(scannedUserId, 'present');
              _startScanning();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gray700,
              foregroundColor: Colors.white,
              elevation: 2,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.lg,
                vertical: AppSizes.sm,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
            ),
            child: const Text('Add & Mark Present'),
          ),
        ],
      ),
    );
  }

  Future<void> _addUserAndMarkAttendance(String userIdFromInput, String status) async {
    if (_selectedSession == null || _currentUser == null) return;
    
    try {
      final databaseService = context.read<DatabaseService>();
      final user = await databaseService.searchMasterListByUserId(
        instituteId: _currentUser!.instituteId!,
        userId: userIdFromInput,
      );

      if (user == null) {
        AppHelpers.showErrorToast('User ID "$userIdFromInput" not found in master list');
        return;
      }

      final masterListId = user['id'];
      double? latitude;
      double? longitude;
      
      try {
        final locationResult = await LocationService.getCurrentLocation();
        if (locationResult.hasLocation) {
          latitude = locationResult.latitude;
          longitude = locationResult.longitude;
        }
      } catch (e) {
        AppHelpers.debugError('Location error: $e');
      }

      await databaseService.markAttendanceSimplified(
        sessionId: _selectedSession!.id,
        masterListId: masterListId,
        markedBy: _currentUser!.id,
        status: status,
        gpsLatitude: latitude,
        gpsLongitude: longitude,
        distanceFromInstitute: null,
      );

      AppHelpers.showSuccessToast('User added and marked $status!');
      await _loadAttendanceRecords();
    } catch (e) {
      AppHelpers.debugError('Add user error: $e');
      AppHelpers.showErrorToast('Failed to add user: ${e.toString()}');
    }
  }

  Future<void> _markAttendance(String masterListId, String status, {bool isScanned = false}) async {
    if (_selectedSession == null || _currentUser == null) return;

    if (!_selectedSession!.canMarkAttendance) {
      AppHelpers.showWarningToast('Cannot mark attendance - session has ended');
      return;
    }

    try {
      final databaseService = context.read<DatabaseService>();
      double? latitude;
      double? longitude;
      
      try {
        final locationResult = await LocationService.getCurrentLocation();
        if (locationResult.hasLocation) {
          latitude = locationResult.latitude;
          longitude = locationResult.longitude;
        }
      } catch (locationError) {
        AppHelpers.debugError('Location error: $locationError');
      }

      final result = await databaseService.markAttendanceSimplified(
        sessionId: _selectedSession!.id,
        masterListId: masterListId,
        markedBy: _currentUser!.id,
        status: status,
        gpsLatitude: latitude,
        gpsLongitude: longitude,
        distanceFromInstitute: null,
      );

      if (result['duplicate'] == true) {
        final previousStatus = result['previous_status'] as String;
        if (previousStatus == status) {
          AppHelpers.showWarningToast(
            'Already marked as $status (Scan #${result['scan_count']})',
          );
          await _loadAttendanceRecords();
          return;
        }

        final shouldUpdate = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            'Change Status?',
            style: TextStyle(
              color: AppColors.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'User already marked as "$previousStatus".\n'
            'This is scan/entry #${result['scan_count']}.\n\n'
            'Change status from "$previousStatus" to "$status"?',
            style: TextStyle(
              color: AppColors.gray700,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.gray600,
              ),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gray700,
                foregroundColor: Colors.white,
                elevation: 2,
              ),
              child: const Text('Change Status'),
            ),
          ],
        ),
      );

      if (shouldUpdate != true) return;

      await databaseService.markAttendanceSimplified(
        sessionId: _selectedSession!.id,
        masterListId: masterListId,
        markedBy: _currentUser!.id,
        status: status,
        gpsLatitude: latitude,
        gpsLongitude: longitude,
        distanceFromInstitute: null,
      );
      }

      AppHelpers.showSuccessToast(
        isScanned ? 'Attendance marked via QR ✓' : 'Attendance marked manually ✓',
      );
      await _loadAttendanceRecords();
    } catch (e) {
      AppHelpers.debugError('Mark attendance error: $e');
      AppHelpers.showErrorToast('Failed to mark attendance');
    }
  }

  void _showManualAttendanceDialog() {
    if (_selectedSession == null) return;
    
    final userIdController = TextEditingController();
    String selectedStatus = 'present';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSizes.xs),
                decoration: BoxDecoration(
                  color: AppColors.gray700.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
                child: Icon(
                  Icons.edit_note_rounded,
                  color: AppColors.gray700,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              Text(
                'Manual Attendance Entry',
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                label: 'User ID',
                controller: userIdController,
                hint: 'e.g., 202411073',
                prefixIcon: Icons.badge_outlined,
              ),
              const SizedBox(height: AppSizes.lg),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.gray300),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                child: DropdownButtonFormField<String>(
                  value: selectedStatus,
                  decoration: InputDecoration(
                    labelText: 'Status',
                    labelStyle: TextStyle(color: AppColors.gray600),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(AppSizes.md),
                    prefixIcon: Icon(
                      Icons.check_circle_outline,
                      color: AppColors.gray600,
                    ),
                  ),
                  dropdownColor: AppColors.surface,
                  items: [
                    DropdownMenuItem(
                      value: 'present',
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: AppColors.success, size: 18),
                          const SizedBox(width: AppSizes.sm),
                          const Text('Present'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'absent',
                      child: Row(
                        children: [
                          Icon(Icons.cancel, color: AppColors.error, size: 18),
                          const SizedBox(width: AppSizes.sm),
                          const Text('Absent'),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      selectedStatus = value!;
                    });
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.gray600,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.lg,
                  vertical: AppSizes.sm,
                ),
              ),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final userId = userIdController.text.trim();
                if (userId.isEmpty) {
                  AppHelpers.showErrorToast('Please enter user ID');
                  return;
                }

                Navigator.pop(context);
                
                final existingRecord = _attendanceRecords.firstWhere(
                  (r) => r['user_id'] == userId,
                  orElse: () => {},
                );

                if (existingRecord.isEmpty) {
                  await _addUserAndMarkAttendance(userId, selectedStatus);
                } else {
                  await _markAttendance(
                    existingRecord['master_list_id'],
                    selectedStatus,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gray700,
                foregroundColor: Colors.white,
                elevation: 2,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.lg,
                  vertical: AppSizes.sm,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
              ),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadReport() async {
    if (_selectedSession == null) return;
    
    setState(() => _isDownloading = true);
    
    try {
      final databaseService = context.read<DatabaseService>();
      final detailedRecords = await databaseService.client
          .from(AppConstants.sessionAttendanceTable)
          .select('''
            *,
            institute_master_list!inner(user_id, name, email, phone),
            marked_by_profile:profiles!marked_by(name, email)
          ''')
          .eq('session_id', _selectedSession!.id)
          .order('marked_at', ascending: false);

      List<List<String>> csvData = [
        [
          'Student ID', 'Name', 'Email', 'Phone',
          'Status', 'Marked By', 'Marked By Email',
          'Location (Lat)', 'Location (Long)', 'Distance (m)',
          'Marked At', 'Scan Count', 'Added During Session'
        ],
      ];

      for (var record in detailedRecords) {
        final user = record['institute_master_list'];
        final markedBy = record['marked_by_profile'];
        
        csvData.add([
          user['user_id'] ?? '',
          user['name'] ?? '',
          user['email'] ?? '',
          user['phone'] ?? '',
          record['status'] ?? 'not_marked',
          markedBy != null ? markedBy['name'] : '-',
          markedBy != null ? markedBy['email'] : '-',
          record['gps_latitude']?.toString() ?? '-',
          record['gps_longitude']?.toString() ?? '-',
          record['distance_from_institute']?.toString() ?? '-',
          record['marked_at'] != null
              ? AppHelpers.formatDateTime(DateTime.parse(record['marked_at']))
              : 'Not marked',
          record['scan_count']?.toString() ?? '0',
          record['added_during_session'] == true ? 'Yes' : 'No',
        ]);
      }

      String csv = const ListToCsvConverter().convert(csvData);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'attendance_${_selectedSession!.name.replaceAll(' ', '_')}_$timestamp.csv';

      if (Platform.isAndroid) {
        final downloadsDir = Directory('/storage/emulated/0/Download');
        if (await downloadsDir.exists()) {
          final filePath = '${downloadsDir.path}/$filename';
          final file = File(filePath);
          await file.writeAsString(csv);
          
          if (mounted) {
            showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusLg),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSizes.xs),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                    ),
                    child: Icon(
                      Icons.download_done_rounded,
                      color: AppColors.success,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSizes.sm),
                  Text(
                    'Report Downloaded',
                    style: TextStyle(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.folder_outlined,
                        color: AppColors.gray600,
                        size: 16,
                      ),
                      const SizedBox(width: AppSizes.xs),
                      Text(
                        'File saved to Downloads folder:',
                        style: TextStyle(
                          color: AppColors.gray700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.sm),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSizes.sm),
                    decoration: BoxDecoration(
                      color: AppColors.gray100,
                      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                    ),
                    child: Text(
                      filename,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppColors.gray700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.gray600,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.lg,
                      vertical: AppSizes.sm,
                    ),
                  ),
                  child: const Text('OK'),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await Share.shareXFiles(
                      [XFile(filePath)],
                      subject: 'Attendance Report - ${_selectedSession!.name}',
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gray700,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.lg,
                      vertical: AppSizes.sm,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    ),
                  ),
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Share'),
                ),
              ],
            ),
          );
          }
        }
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final path = '${directory.path}/$filename';
        final file = File(path);
        await file.writeAsString(csv);
        
        await Share.shareXFiles(
          [XFile(path)],
          subject: 'Attendance Report - ${_selectedSession!.name}',
        );
      }

      if (mounted) {
        AppHelpers.showSuccessToast('Report generated successfully!');
      }
    } catch (e) {
      AppHelpers.debugError('Download error: $e');
      if (mounted) {
        AppHelpers.showErrorToast('Failed to generate report');
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: LoadingWidget(message: 'Loading attendance data...'),
      );
    }

    if (_isScannerActive) {
      return _buildScannerView();
    }

    final isSessionEnded = !(_selectedSession?.canMarkAttendance ?? true);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(isSessionEnded),
      body: Column(
        children: [
          if (isSessionEnded) _buildWarningBanner(),
          if (_availableSessions.length > 1) _buildSessionSelector(),
          _buildSearchSection(),
          if (_selectedSession != null) _buildStatisticsSummary(),
          Expanded(child: _buildAttendanceList(isSessionEnded)),
        ],
      ),
      floatingActionButton: _buildFAB(isSessionEnded),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isSessionEnded) {
    return AppBar(
      title: Text(
        _selectedSession?.name ?? 'Mark Attendance',
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      backgroundColor: AppColors.gray800,
      foregroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Colors.white),
      elevation: 0,
      actions: [
        if (_selectedSession != null)
          IconButton(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditSessionScreen(session: _selectedSession!),
                ),
              );
              if (result == true) _loadData();
            },
            icon: const Icon(Icons.edit, color: Colors.white),
            tooltip: 'Edit Session',
          ),
        if (_selectedSession != null)
          IconButton(
            onPressed: _isDownloading ? null : _downloadReport,
            icon: _isDownloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const Icon(Icons.download, color: Colors.white),
            tooltip: 'Download Report',
          ),
        if (!isSessionEnded)
          IconButton(
            onPressed: _showManualAttendanceDialog,
            icon: const Icon(Icons.edit_note, color: Colors.white),
            tooltip: 'Manual Entry',
          ),
        IconButton(
          onPressed: _loadAttendanceRecords,
          icon: const Icon(Icons.refresh, color: Colors.white),
          tooltip: 'Refresh',
        ),
        const SizedBox(width: AppSizes.sm),
      ],
    );
  }

  Widget _buildWarningBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.md),
      color: AppColors.warning.withOpacity(0.2),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.warning),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Text(
              'This session has ended. View-only mode.',
              style: TextStyle(
                color: AppColors.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.gray200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Session',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          DropdownButtonFormField<String>(
            value: _selectedSession?.id,
            isExpanded: true,
            menuMaxHeight: 200,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSizes.md,
                vertical: AppSizes.sm,
              ),
            ),
            items: _availableSessions.map((session) {
              return DropdownMenuItem(
                value: session.id,
                child: Text(
                  '${session.name} • ${AppHelpers.formatDate(session.sessionDate)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (sessionId) {
              if (sessionId != null) {
                final session = _availableSessions.firstWhere(
                  (s) => s.id == sessionId,
                );
                setState(() => _selectedSession = session);
                _loadAttendanceRecords();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.gray200),
        ),
      ),
      child: Column(
        children: [
          CustomTextField(
            label: 'Search participants',
            controller: _searchController,
            prefixIcon: Icons.search,
            hint: 'Search by name or ID',
            onChanged: (_) => _applyFilters(),
          ),
          const SizedBox(height: AppSizes.md),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', 'all', _getStatusCount('all')),
                _buildFilterChip('Present', 'present', _getStatusCount('present')),
                _buildFilterChip('Absent', 'absent', _getStatusCount('absent')),
                _buildFilterChip('Not Marked', 'not_marked', _getStatusCount('not_marked')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, int count) {
    final isSelected = _statusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: AppSizes.sm),
      child: FilterChip(
        label: Text(
          '$label ($count)',
          style: TextStyle(
            color: isSelected ? AppColors.white : AppColors.gray700,
            fontWeight: FontWeight.w600,
          ),
        ),
        selected: isSelected,
        selectedColor: AppColors.gray700,
        backgroundColor: AppColors.gray100,
        checkmarkColor: AppColors.white,
        onSelected: (selected) {
          setState(() {
            _statusFilter = value;
            _applyFilters();
          });
        },
      ),
    );
  }

  Widget _buildStatisticsSummary() {
    final total = _attendanceRecords.length;
    final present = _attendanceRecords.where((r) => r['status'] == 'present').length;
    final absent = _attendanceRecords.where((r) => r['status'] == 'absent').length;
    final notMarked = _attendanceRecords.where((r) => r['status'] == 'not_marked').length;

    return Container(
      margin: const EdgeInsets.all(AppSizes.md),
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.gray700, AppColors.gray700.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildStatItem('Total', total.toString(), Icons.people, Colors.white),
          _buildStatItem('Present', present.toString(), Icons.check_circle, Colors.white),
          _buildStatItem('Absent', absent.toString(), Icons.cancel, Colors.white),
          _buildStatItem('Pending', notMarked.toString(), Icons.help_outline, Colors.white),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: AppSizes.iconMd),
          const SizedBox(height: AppSizes.xs),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceList(bool isReadOnly) {
    if (_filteredRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: AppColors.gray400,
            ),
            const SizedBox(height: AppSizes.md),
            Text(
              _attendanceRecords.isEmpty
                  ? 'No participants in session'
                  : 'No results found',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.gray600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSizes.md),
      itemCount: _filteredRecords.length,
      itemBuilder: (context, index) {
        return _buildAttendanceCard(_filteredRecords[index], isReadOnly: isReadOnly);
      },
    );
  }

  Widget _buildAttendanceCard(Map<String, dynamic> record, {bool isReadOnly = false}) {
    final user = record['user_detail'];
    final status = record['status'] as String;
    final scanCount = record['scan_count'] as int;
    final addedDuringSession = record['added_during_session'] as bool;

    Color statusColor;
    IconData statusIcon;
    
    switch (status) {
      case 'present':
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle;
        break;
      case 'absent':
        statusColor = AppColors.error;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = AppColors.gray500;
        statusIcon = Icons.help_outline;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.gray200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppSizes.md),
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.1),
          child: Icon(statusIcon, color: statusColor),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                user['name'],
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
            ),
            if (scanCount > 1)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.warning,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Scan #$scanCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ID: ${user['user_id']}',
              style: TextStyle(color: AppColors.gray600),
            ),
            if (addedDuringSession)
              Row(
                children: [
                  Icon(Icons.add_circle, size: 12, color: AppColors.info),
                  const SizedBox(width: 4),
                  Text(
                    'Added during session',
                    style: TextStyle(fontSize: 11, color: AppColors.info),
                  ),
                ],
              ),
          ],
        ),
        trailing: isReadOnly
            ? null
            : PopupMenuButton<String>(
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'present', child: Text('Mark Present')),
                  const PopupMenuItem(value: 'absent', child: Text('Mark Absent')),
                ],
                onSelected: (value) {
                  _markAttendance(record['master_list_id'], value);
                },
              ),
      ),
    );
  }

  Widget _buildScannerView() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Scan QR Code',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.gray800,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          onPressed: _stopScanning,
          icon: const Icon(Icons.close, color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSizes.md),
            color: AppColors.info.withOpacity(0.1),
            child: Column(
              children: [
                Icon(Icons.qr_code_scanner, color: AppColors.info, size: AppSizes.iconLg),
                const SizedBox(height: AppSizes.sm),
                Text(
                  'Point camera at QR code',
                  style: TextStyle(
                    color: AppColors.info,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'User will be added if not in session',
                  style: TextStyle(
                    color: AppColors.info,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: _onQRScanned,
                ),
                Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primary, width: 3),
                      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAB(bool isSessionEnded) {
    if (isSessionEnded) return const SizedBox.shrink();
    
    return FloatingActionButton.extended(
      onPressed: _startScanning,
      icon: const Icon(Icons.qr_code_scanner),
      label: const Text(
        'Scan QR',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      backgroundColor: AppColors.gray800,
      foregroundColor: Colors.white,
      elevation: 6,
    );
  }
}

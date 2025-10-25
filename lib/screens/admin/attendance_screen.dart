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

      // ⭐ Don't filter sessions - we'll handle restrictions in UI
      setState(() {
        _currentUser = user;
        _availableSessions =
            sessions; // ⭐ CHANGED: Show ALL sessions, not just active

        // ⭐ FIXED: Properly select the passed session
        if (widget.session != null) {
          // Find the exact session by ID
          _selectedSession = sessions.firstWhere(
            (s) => s.id == widget.session!.id,
            orElse: () =>
                widget.session!, // Use passed session if not found in list
          );
        } else {
          // No session passed - default to first active session
          final activeSessions =
              sessions.where((s) => s.canMarkAttendance).toList();
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


  // Future<void> _loadData() async {
  //   try {
  //     final authService = context.read<AuthService>();
  //     final databaseService = context.read<DatabaseService>();

  //     final user = await authService.getCurrentUserProfile();
  //     if (user == null) return;

  //     final sessions = await databaseService.getSessions(
  //       departmentId: user.departmentId,
  //     );

  //     final activeSessions = sessions.where((s) => s.canMarkAttendance).toList();

  //     setState(() {
  //       _currentUser = user;
  //       _availableSessions = activeSessions;
        
  //       // ⭐ FIX: Find session by ID to avoid duplicate object issue
  //       if (widget.session != null) {
  //         _selectedSession = activeSessions.firstWhere(
  //           (s) => s.id == widget.session!.id,
  //           orElse: () => activeSessions.isNotEmpty ? activeSessions.first : widget.session!,
  //         );
  //       } else if (activeSessions.isNotEmpty) {
  //         _selectedSession = activeSessions.first;
  //       }
        
  //       _isLoading = false;
  //     });

  //     if (_selectedSession != null) {
  //       await _loadAttendanceRecords();
  //     }
  //   } catch (e) {
  //     AppHelpers.debugError('Load attendance data error: $e');
  //     setState(() => _isLoading = false);
  //   }
  // }

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
        _applyFilters();
      });
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

        final matchesStatus =
            _statusFilter == 'all' || record['status'] == _statusFilter;

        return matchesSearch && matchesStatus;
      }).toList();
    });
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
        AppHelpers.debugLog('Plain text QR code: $userId');
      }

      if (userId.isEmpty) {
        AppHelpers.showErrorToast('Invalid QR code');
        setState(() => _isScanning = false);
        return;
      }

      AppHelpers.debugLog('QR scanned: user_id = $userId');

      final existingRecord = _attendanceRecords.firstWhere(
        (r) => r['user_id'].toString() == userId,
        orElse: () => {},
      );

      if (existingRecord.isEmpty) {
        _stopScanning();
        _showAddUserDialog(userId);
      } else {
        AppHelpers.debugLog('Using master_list_id: ${existingRecord['master_list_id']}');
        
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
        title: const Text('User Not in Session'),
        content: Text(
          'User ID "$scannedUserId" is not enrolled in this session.\n\nAdd them and mark present?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startScanning();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _addUserAndMarkAttendance(scannedUserId, 'present');
              _startScanning();
            },
            child: const Text('Add & Mark Present'),
          ),
        ],
      ),
    );
  }

  Future<void> _addUserAndMarkAttendance(
    String userIdFromInput,
    String status,
  ) async {
    if (_selectedSession == null || _currentUser == null) return;

    try {
      final databaseService = context.read<DatabaseService>();

      AppHelpers.debugLog('Searching for user_id: $userIdFromInput');

      final user = await databaseService.searchMasterListByUserId(
        instituteId: _currentUser!.instituteId!,
        userId: userIdFromInput,
      );

      if (user == null) {
        AppHelpers.showErrorToast('User ID "$userIdFromInput" not found in master list');
        return;
      }

      final masterListId = user['id'];
      AppHelpers.debugLog('Found user: ${user['name']} (master_list_id: $masterListId)');

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

  Future<void> _markAttendance(
    String masterListId,
    String status, {
    bool isScanned = false,
  }) async {
    if (_selectedSession == null || _currentUser == null) return;
    // ⭐ ADD THIS CHECK: Prevent marking if session has ended

    AppHelpers.debugLog('Session status: ${_selectedSession!.status}'); // ⭐ ADD THIS

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
          
          AppHelpers.debugLog('Admin location: $latitude, $longitude');
        } else {
          AppHelpers.debugLog('Location unavailable: ${locationResult.error}');
        }
      } catch (locationError) {
        AppHelpers.debugError('Location error: $locationError');
      }

      AppHelpers.debugLog('Marking attendance: master_list_id=$masterListId, status=$status');

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
            title: const Text('Change Status?'),
            content: Text(
              'User already marked as "$previousStatus".\n'
              'This is scan/entry #${result['scan_count']}.\n\n'
              'Change status from "$previousStatus" to "$status"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
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

      List<List<dynamic>> csvData = [
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
      final filename =
          'attendance_${_selectedSession!.name.replaceAll(' ', '_')}_$timestamp.csv';

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
                title: const Text('Report Downloaded'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('File saved to Downloads folder:'),
                    const SizedBox(height: 8),
                    Text(
                      filename,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
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
                    icon: const Icon(Icons.share),
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

  void _showManualAttendanceDialog() {
    if (_selectedSession == null) return;

    final userIdController = TextEditingController();
    String selectedStatus = 'present';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Manual Attendance Entry'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                label: 'User ID',
                controller: userIdController,
                hint: 'e.g., 202411073',
                prefixIcon: Icons.badge,
              ),
              const SizedBox(height: AppSizes.md),
              DropdownButtonFormField<String>(
                value: selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.check_circle),
                ),
                items: const [
                  DropdownMenuItem(value: 'present', child: Text('Present')),
                  DropdownMenuItem(value: 'absent', child: Text('Absent')),
                ],
                onChanged: (value) {
                  setDialogState(() {
                    selectedStatus = value!;
                  });
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
              child: const Text('Submit'),
            ),
          ],
        ),
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

    if (_isScannerActive) {
      return _buildScannerView(theme);
    }

    // ⭐ ADD: Check if session is ended
    final isSessionEnded = !(_selectedSession?.canMarkAttendance ?? true);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mark Attendance'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        actions: [
          if (_selectedSession != null)
            IconButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        EditSessionScreen(session: _selectedSession!),
                  ),
                );
                if (result == true) {
                  _loadData();
                }
              },
              icon: const Icon(Icons.edit),
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
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.download),
              tooltip: 'Download Report',
            ),
          // ⭐ HIDE manual entry button for ended sessions
          if (!isSessionEnded)
            IconButton(
              onPressed: _showManualAttendanceDialog,
              icon: const Icon(Icons.edit_note),
              tooltip: 'Manual Entry',
            ),
          IconButton(
            onPressed: _loadAttendanceRecords,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // ⭐ ADD: Warning banner for ended sessions
          if (isSessionEnded)
            Container(
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
            ),
    // return Scaffold(
    //   appBar: AppBar(
    //     title: const Text('Mark Attendance'),
    //     backgroundColor: theme.colorScheme.primary,
    //     foregroundColor: theme.colorScheme.onPrimary,
    //     actions: [
    //       if (_selectedSession != null)
    //         IconButton(
    //           onPressed: () async {
    //             final result = await Navigator.push(
    //               context,
    //               MaterialPageRoute(
    //                 builder: (context) => EditSessionScreen(session: _selectedSession!),
    //               ),
    //             );
    //             if (result == true) {
    //               _loadData();
    //             }
    //           },
    //           icon: const Icon(Icons.edit),
    //           tooltip: 'Edit Session',
    //         ),
    //       if (_selectedSession != null)
    //         IconButton(
    //           onPressed: _isDownloading ? null : _downloadReport,
    //           icon: _isDownloading
    //               ? const SizedBox(
    //                   width: 20,
    //                   height: 20,
    //                   child: CircularProgressIndicator(
    //                     strokeWidth: 2,
    //                     valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
    //                   ),
    //                 )
    //               : const Icon(Icons.download),
    //           tooltip: 'Download Report',
    //         ),
    //       IconButton(
    //         onPressed: _showManualAttendanceDialog,
    //         icon: const Icon(Icons.edit_note),
    //         tooltip: 'Manual Entry',
    //       ),
    //       IconButton(
    //         onPressed: _loadAttendanceRecords,
    //         icon: const Icon(Icons.refresh),
    //         tooltip: 'Refresh',
    //       ),
    //     ],
    //   ),
    //   body: Column(
    //     children: [
          // ⭐ FIXED DROPDOWN: Use String ID instead of SessionModel
          if (_availableSessions.length > 1)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSizes.md),
              color: theme.colorScheme.surfaceContainerHighest,
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
                  DropdownButtonFormField<String>( // ⭐ CHANGED to String
                    value: _selectedSession?.id, // ⭐ Use ID
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: AppSizes.md,
                        vertical: AppSizes.sm,
                      ),
                    ),
                    items: _availableSessions.map((session) {
                      return DropdownMenuItem<String>(
                        value: session.id, // ⭐ Use ID
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              session.name,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '${AppHelpers.formatDate(session.sessionDate)} • '
                              '${AppHelpers.formatTime(session.startDateTime)}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
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
            ),

          Container(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Column(
              children: [
                CustomTextField(
                  label: 'Search',
                  controller: _searchController,
                  prefixIcon: Icons.search,
                  hint: 'Search by name or ID',
                  onChanged: (_) => _applyFilters(),
                ),
                const SizedBox(height: AppSizes.sm),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', 'all'),
                      _buildFilterChip('Present', 'present'),
                      _buildFilterChip('Absent', 'absent'),
                      _buildFilterChip('Not Marked', 'not_marked'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (_selectedSession != null) _buildStatisticsSummary(theme),

          Expanded(
            child: _filteredRecords.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey),
                        const SizedBox(height: AppSizes.md),
                        Text(
                          _attendanceRecords.isEmpty
                              ? 'No participants in session'
                              : 'No results found',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(AppSizes.md),
                    itemCount: _filteredRecords.length,
                    itemBuilder: (context, index) {
                      return _buildAttendanceCard(
                        _filteredRecords[index],
                        theme,
                        isReadOnly: isSessionEnded, // ⭐ ADD THIS LINE
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: _selectedSession?.canMarkAttendance == true
          ? FloatingActionButton.extended(
              onPressed: _startScanning,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan QR'),
              backgroundColor: AppColors.success,
            )
          : null,
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _statusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: AppSizes.sm),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _statusFilter = value;
            _applyFilters();
          });
        },
      ),
    );
  }

  Widget _buildStatisticsSummary(ThemeData theme) {
    final total = _attendanceRecords.length;
    final present =
        _attendanceRecords.where((r) => r['status'] == 'present').length;
    final absent =
        _attendanceRecords.where((r) => r['status'] == 'absent').length;
    final notMarked =
        _attendanceRecords.where((r) => r['status'] == 'not_marked').length;

    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      margin: const EdgeInsets.symmetric(horizontal: AppSizes.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
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

  // Update the method signature to accept isReadOnly parameter:

  Widget _buildAttendanceCard(
    Map<String, dynamic> record,
    ThemeData theme, {
    bool isReadOnly = false, // ⭐ ADD parameter
  }) {
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
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.1),
          child: Icon(statusIcon, color: statusColor),
        ),
        title: Row(
          children: [
            Expanded(child: Text(user['name'])),
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
            Text('ID: ${user['user_id']}'),
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
        // ⭐ HIDE menu for ended sessions
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



  // Widget _buildAttendanceCard(Map<String, dynamic> record, ThemeData theme) {
  //   final user = record['user_detail'];
  //   final status = record['status'] as String;
  //   final scanCount = record['scan_count'] as int;
  //   final addedDuringSession = record['added_during_session'] as bool;

  //   Color statusColor;
  //   IconData statusIcon;
  //   switch (status) {
  //     case 'present':
  //       statusColor = AppColors.success;
  //       statusIcon = Icons.check_circle;
  //       break;
  //     case 'absent':
  //       statusColor = AppColors.error;
  //       statusIcon = Icons.cancel;
  //       break;
  //     default:
  //       statusColor = Colors.grey;
  //       statusIcon = Icons.help_outline;
  //   }

  //   return Card(
  //     margin: const EdgeInsets.only(bottom: AppSizes.sm),
  //     child: ListTile(
  //       leading: CircleAvatar(
  //         backgroundColor: statusColor.withOpacity(0.1),
  //         child: Icon(statusIcon, color: statusColor),
  //       ),
  //       title: Row(
  //         children: [
  //           Expanded(child: Text(user['name'])),
  //           if (scanCount > 1)
  //             Container(
  //               padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  //               decoration: BoxDecoration(
  //                 color: AppColors.warning,
  //                 borderRadius: BorderRadius.circular(4),
  //               ),
  //               child: Text(
  //                 'Scan #$scanCount',
  //                 style: const TextStyle(
  //                   color: Colors.white,
  //                   fontSize: 10,
  //                   fontWeight: FontWeight.bold,
  //                 ),
  //               ),
  //             ),
  //         ],
  //       ),
  //       subtitle: Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           Text('ID: ${user['user_id']}'),
  //           if (addedDuringSession)
  //             Row(
  //               children: [
  //                 Icon(Icons.add_circle, size: 12, color: AppColors.info),
  //                 const SizedBox(width: 4),
  //                 Text(
  //                   'Added during session',
  //                   style: TextStyle(fontSize: 11, color: AppColors.info),
  //                 ),
  //               ],
  //             ),
  //         ],
  //       ),
  //       trailing: PopupMenuButton<String>(
  //         itemBuilder: (context) => [
  //           const PopupMenuItem(value: 'present', child: Text('Mark Present')),
  //           const PopupMenuItem(value: 'absent', child: Text('Mark Absent')),
  //         ],
  //         onSelected: (value) {
  //           _markAttendance(record['master_list_id'], value);
  //         },
  //       ),
  //     ),
  //   );
  // }

  Widget _buildScannerView(ThemeData theme) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          onPressed: _stopScanning,
          icon: const Icon(Icons.close),
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
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.info,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'User will be added if not in session',
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.info),
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
}

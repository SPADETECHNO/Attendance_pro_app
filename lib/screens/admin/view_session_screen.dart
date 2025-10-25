// lib/screens/admin/view_session_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attendance_pro_app/services/database_service.dart';
import 'package:attendance_pro_app/services/auth_service.dart';
import 'package:attendance_pro_app/widgets/loading_widget.dart';
import 'package:attendance_pro_app/widgets/custom_button.dart';
import 'package:attendance_pro_app/widgets/custom_text_field.dart';
import 'package:attendance_pro_app/utils/constants.dart';
import 'package:attendance_pro_app/utils/helpers.dart';
import 'package:attendance_pro_app/models/session_model.dart';
import 'package:attendance_pro_app/models/user_model.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:attendance_pro_app/constants/app_constants.dart';
import 'package:attendance_pro_app/screens/admin/edit_session_screen.dart';

class ViewSessionScreen extends StatefulWidget {
  final SessionModel session;

  const ViewSessionScreen({
    super.key,
    required this.session,
  });

  @override
  State<ViewSessionScreen> createState() => _ViewSessionScreenState();
}

class _ViewSessionScreenState extends State<ViewSessionScreen> {
  UserModel? _currentUser;
  List<Map<String, dynamic>> _attendanceRecords = [];
  List<Map<String, dynamic>> _filteredRecords = [];

  bool _isLoading = true;
  bool _isDownloading = false;

  // Statistics
  int _totalParticipants = 0;
  int _presentCount = 0;
  int _absentCount = 0;
  int _notMarkedCount = 0;
  double _attendancePercentage = 0.0;

  // Search and filter
  final _searchController = TextEditingController();
  String _statusFilter = 'all'; // 'all', 'present', 'absent', 'not_marked'
  String _sortBy = 'name'; // 'name', 'user_id', 'marked_at', 'status'
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final authService = context.read<AuthService>();
      final databaseService = context.read<DatabaseService>();

      final user = await authService.getCurrentUserProfile();
      if (user == null) return;

      await _loadAttendanceData();

      setState(() {
        _currentUser = user;
        _isLoading = false;
      });
    } catch (e) {
      AppHelpers.debugError('Load view session data error: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAttendanceData() async {
    try {
      final databaseService = context.read<DatabaseService>();

      // Get all participants with attendance data
      final response = await databaseService.client
          .from(AppConstants.sessionParticipantsTable)
          .select('''
            id,
            user_id,
            added_at,
            profiles!inner(
              id,
              user_id,
              name,
              email,
              phone
            )
          ''')
          .eq('session_id', widget.session.id)
          .order('added_at', ascending: true);

      // Get attendance records
      final attendanceResponse = await databaseService.client
          .from(AppConstants.attendanceTable)
          .select('''
            id,
            user_id,
            status,
            marked_at,
            marked_by_user,
            marked_by_admin,
            scan_count,
            added_during_session,
            gps_latitude,
            gps_longitude,
            distance_from_institute
          ''').eq('session_id', widget.session.id);

      // Create attendance map
      final Map<String, Map<String, dynamic>> attendanceMap = {};
      for (var record in attendanceResponse as List) {
        attendanceMap[record['user_id']] = record;
      }

      // Combine data
      final List<Map<String, dynamic>> combinedRecords = [];
      for (var participant in response as List<Map<String, dynamic>>) {
        final userId = participant['profiles']['id'];
        final attendance = attendanceMap[userId];

        combinedRecords.add({
          'participant_id': participant['id'],
          'user_id': userId,
          'user_detail': participant['profiles'],
          'added_at': participant['added_at'],
          'attendance': attendance,
          'status': attendance?['status'] ?? 'not_marked',
          'marked_at': attendance?['marked_at'],
          'scan_count': attendance?['scan_count'] ?? 0,
          'added_during_session': attendance?['added_during_session'] ?? false,
          'gps_latitude': attendance?['gps_latitude'],
          'gps_longitude': attendance?['gps_longitude'],
          'distance_from_institute': attendance?['distance_from_institute'],
          'marked_by_user': attendance?['marked_by_user'] ?? false,
          'marked_by_admin': attendance?['marked_by_admin'] ?? false,
        });
      }

      // Calculate statistics
      final total = combinedRecords.length;
      final present =
          combinedRecords.where((r) => r['status'] == 'present').length;
      final absent =
          combinedRecords.where((r) => r['status'] == 'absent').length;
      final notMarked =
          combinedRecords.where((r) => r['status'] == 'not_marked').length;
      final percentage = total > 0 ? (present / total * 100) : 0.0;

      setState(() {
        _attendanceRecords = combinedRecords;
        _totalParticipants = total;
        _presentCount = present;
        _absentCount = absent;
        _notMarkedCount = notMarked;
        _attendancePercentage = percentage;
        _applyFilters();
      });
    } catch (e) {
      AppHelpers.debugError('Load attendance data error: $e');
    }
  }
  // Add this method to ViewSessionScreen

  Future<void> _showExtendSessionDialog() async {
    if (widget.session.status != 'live') {
      AppHelpers.showWarningToast('Only active sessions can be extended');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Extend Session'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Current end time: ${AppHelpers.formatTime(widget.session.endDateTime)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSizes.lg),
            const Text('Extend session by:'),
            const SizedBox(height: AppSizes.md),
            _buildExtensionOption(context, '15 minutes', 15),
            _buildExtensionOption(context, '30 minutes', 30),
            _buildExtensionOption(context, '1 hour', 60),
            _buildExtensionOption(context, 'Custom', -1),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildExtensionOption(
      BuildContext context, String label, int minutes) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm),
      child: ElevatedButton(
        onPressed: () async {
          Navigator.pop(context);

          if (minutes == -1) {
            // Show custom time picker
            await _showCustomExtensionDialog();
          } else {
            // Extend by preset minutes
            await _extendSession(minutes);
          }
        },
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
        ),
        child: Text(label),
      ),
    );
  }

  Future<void> _showCustomExtensionDialog() async {
    final customMinutes = await showDialog<int>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Custom Extension'),
          content: CustomTextField(
            label: 'Minutes',
            controller: controller,
            keyboardType: TextInputType.number,
            hint: 'Enter number of minutes',
            prefixIcon: Icons.timer,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final minutes = int.tryParse(controller.text);
                if (minutes != null && minutes > 0 && minutes <= 300) {
                  Navigator.pop(context, minutes);
                } else {
                  AppHelpers.showErrorToast(
                      'Please enter a valid number (1-300)');
                }
              },
              child: const Text('Extend'),
            ),
          ],
        );
      },
    );

    if (customMinutes != null) {
      await _extendSession(customMinutes);
    }
  }

  Future<void> _extendSession(int minutes) async {
    try {
      final databaseService = context.read<DatabaseService>();

      final newEndTime =
          widget.session.endDateTime.add(Duration(minutes: minutes));

      await databaseService.client.from(AppConstants.sessionsTable).update({
        'end_datetime': newEndTime.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.session.id);

      if (mounted) {
        AppHelpers.showSuccessToast(
          'Session extended by $minutes minutes!\nNew end time: ${AppHelpers.formatTime(newEndTime)}',
        );
        _loadData(); // Refresh data
      }
    } catch (e) {
      AppHelpers.debugError('Extend session error: $e');
      if (mounted) {
        AppHelpers.showErrorToast('Failed to extend session');
      }
    }
  }

  void _applyFilters() {
    String query = _searchController.text.toLowerCase();

    List<Map<String, dynamic>> filtered = _attendanceRecords.where((record) {
      final user = record['user_detail'];

      // Search filter
      final matchesSearch = query.isEmpty ||
          user['name'].toString().toLowerCase().contains(query) ||
          user['user_id'].toString().toLowerCase().contains(query) ||
          user['email'].toString().toLowerCase().contains(query);

      // Status filter
      final matchesStatus =
          _statusFilter == 'all' || record['status'] == _statusFilter;

      return matchesSearch && matchesStatus;
    }).toList();

    // Apply sorting
    filtered.sort((a, b) {
      int comparison = 0;

      switch (_sortBy) {
        case 'name':
          comparison = a['user_detail']['name']
              .toString()
              .toLowerCase()
              .compareTo(b['user_detail']['name'].toString().toLowerCase());
          break;
        case 'user_id':
          comparison = a['user_detail']['user_id']
              .toString()
              .compareTo(b['user_detail']['user_id'].toString());
          break;
        case 'status':
          comparison = a['status'].toString().compareTo(b['status'].toString());
          break;
        case 'marked_at':
          final aTime = a['marked_at'];
          final bTime = b['marked_at'];
          if (aTime == null && bTime == null) {
            comparison = 0;
          } else if (aTime == null) {
            comparison = 1;
          } else if (bTime == null) {
            comparison = -1;
          } else {
            comparison = DateTime.parse(aTime).compareTo(DateTime.parse(bTime));
          }
          break;
      }

      return _sortAscending ? comparison : -comparison;
    });

    setState(() {
      _filteredRecords = filtered;
    });
  }

  // lib/screens/admin/view_session_screen.dart
  // REPLACE _downloadReport method:

  Future<void> _downloadReport() async {
    setState(() => _isDownloading = true);

    try {
      final databaseService = context.read<DatabaseService>();

      // Get detailed attendance records with admin info
      final detailedRecords = await databaseService.client
          .from(AppConstants.sessionAttendanceTable)
          .select('''
            *,
            institute_master_list!inner(user_id, name, email, phone),
            marked_by_profile:profiles!marked_by(name, email)
          ''')
          .eq('session_id', widget.session.id)
          .order('marked_at', ascending: false);

      // Prepare CSV data
      List<List<dynamic>> csvData = [
        // ⭐ UPDATED HEADER with all required fields
        [
          'Student ID',
          'Name',
          'Email',
          'Phone',
          'Status',
          'Marked By',
          'Marked By Email',
          'Location (Lat)',
          'Location (Long)',
          'Distance (m)',
          'Marked At',
          'Scan Count',
          'Added During Session',
        ],
      ];

      // Data rows
      for (var record in detailedRecords) {
        final user = record['institute_master_list'];
        final markedByProfile = record['marked_by_profile'];
        
        csvData.add([
          user['user_id'] ?? '',                                    // Student ID
          user['name'] ?? '',                                       // Name
          user['email'] ?? '',                                      // Email
          user['phone'] ?? '',                                      // Phone
          record['status'] ?? 'not_marked',                         // Status
          markedByProfile != null ? markedByProfile['name'] : '-',  // Marked By Name
          markedByProfile != null ? markedByProfile['email'] : '-', // Marked By Email
          record['gps_latitude']?.toString() ?? '-',                // Latitude
          record['gps_longitude']?.toString() ?? '-',               // Longitude
          record['distance_from_institute']?.toString() ?? '-',     // Distance
          record['marked_at'] != null
              ? AppHelpers.formatDateTime(DateTime.parse(record['marked_at']))
              : 'Not marked',                                       // Marked At
          record['scan_count']?.toString() ?? '0',                  // Scan Count
          record['added_during_session'] == true ? 'Yes' : 'No',   // Added During Session
        ]);
      }

      String csv = const ListToCsvConverter().convert(csvData);

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'attendance_${widget.session.name.replaceAll(' ', '_')}_$timestamp.csv';
      final path = '${directory.path}/$filename';
      
      final file = File(path);
      await file.writeAsString(csv);

      await Share.shareXFiles(
        [XFile(path)],
        subject: 'Attendance Report - ${widget.session.name}',
        text: 'Attendance report for ${widget.session.name}\n'
              'Date: ${AppHelpers.formatDate(widget.session.sessionDate)}\n'
              'Present: $_presentCount/$_totalParticipants (${_attendancePercentage.toStringAsFixed(1)}%)',
      );

      if (mounted) {
        AppHelpers.showSuccessToast('Report downloaded successfully!');
      }
    } catch (e) {
      AppHelpers.debugError('Download error: $e');
      if (mounted) {
        AppHelpers.showErrorToast('Failed to download report');
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }



  // Future<void> _downloadReport() async {
  //   setState(() => _isDownloading = true);

  //   try {
  //     // Prepare CSV data
  //     List<List<dynamic>> csvData = [
  //       // Header row
  //       [
  //         'User ID',
  //         'Name',
  //         'Email',
  //         'Phone',
  //         'Status',
  //         'Marked At',
  //         'Marked By',
  //         'Scan Count',
  //         'Added During Session',
  //         'Distance (m)',
  //       ],
  //     ];

  //     // Data rows
  //     for (var record in _attendanceRecords) {
  //       final user = record['user_detail'];
  //       csvData.add([
  //         user['user_id'] ?? '',
  //         user['name'] ?? '',
  //         user['email'] ?? '',
  //         user['phone'] ?? '',
  //         record['status'] ?? 'not_marked',
  //         record['marked_at'] != null
  //             ? AppHelpers.formatDateTime(DateTime.parse(record['marked_at']))
  //             : 'Not marked',
  //         record['marked_by_admin'] == true
  //             ? 'Admin'
  //             : record['marked_by_user'] == true
  //                 ? 'Self'
  //                 : '-',
  //         record['scan_count']?.toString() ?? '0',
  //         record['added_during_session'] == true ? 'Yes' : 'No',
  //         record['distance_from_institute']?.toString() ?? '-',
  //       ]);
  //     }

  //     // Convert to CSV string
  //     String csv = const ListToCsvConverter().convert(csvData);

  //     // Save to file
  //     final directory = await getApplicationDocumentsDirectory();
  //     final timestamp = DateTime.now().millisecondsSinceEpoch;
  //     final filename =
  //         'attendance_${widget.session.name.replaceAll(' ', '_')}_$timestamp.csv';
  //     final path = '${directory.path}/$filename';

  //     final file = File(path);
  //     await file.writeAsString(csv);

  //     // Share the file
  //     await Share.shareXFiles(
  //       [XFile(path)],
  //       subject: 'Attendance Report - ${widget.session.name}',
  //       text: 'Attendance report for session: ${widget.session.name}\n'
  //           'Date: ${AppHelpers.formatDate(widget.session.sessionDate)}\n'
  //           'Present: $_presentCount/$_totalParticipants (${_attendancePercentage.toStringAsFixed(1)}%)',
  //     );

  //     if (mounted) {
  //       AppHelpers.showSuccessToast('Report downloaded successfully!');
  //     }
  //   } catch (e) {
  //     AppHelpers.debugError('Download report error: $e');
  //     if (mounted) {
  //       AppHelpers.showErrorToast('Failed to download report');
  //     }
  //   } finally {
  //     if (mounted) {
  //       setState(() => _isDownloading = false);
  //     }
  //   }
  // }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sort By',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppSizes.md),
            _buildSortOption('Name', 'name', Icons.person),
            _buildSortOption('User ID', 'user_id', Icons.badge),
            _buildSortOption('Status', 'status', Icons.check_circle),
            _buildSortOption('Marked Time', 'marked_at', Icons.access_time),
            const SizedBox(height: AppSizes.md),
            SwitchListTile(
              title: const Text('Ascending Order'),
              value: _sortAscending,
              onChanged: (value) {
                setState(() {
                  _sortAscending = value;
                  _applyFilters();
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(String label, String value, IconData icon) {
    final isSelected = _sortBy == value;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? AppColors.primary : null,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppColors.primary : null,
        ),
      ),
      trailing:
          isSelected ? const Icon(Icons.check, color: AppColors.primary) : null,
      onTap: () {
        setState(() {
          _sortBy = value;
          _applyFilters();
        });
        Navigator.pop(context);
      },
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
      // In ViewSessionScreen build method, update appBar actions:
      appBar: AppBar(
        title: Text(widget.session.name),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        actions: [
          // Show edit and extend only if user has permission
          if (widget.session.status == 'live' ||
              widget.session.status == 'upcoming')
            IconButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        EditSessionScreen(session: widget.session),
                  ),
                );
                if (result == true) {
                  _loadData(); // Refresh if edited
                }
              },
              icon: const Icon(Icons.edit),
              tooltip: 'Edit Session',
            ),
          if (widget.session.status == 'live')
            IconButton(
              onPressed: _showExtendSessionDialog,
              icon: const Icon(Icons.timer),
              tooltip: 'Extend Session',
            ),
          IconButton(
            onPressed: _showSortOptions,
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
          ),
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
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Session Info Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSizes.md),
            color: theme.colorScheme.surfaceContainerHighest,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.sm,
                        vertical: AppSizes.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AppHelpers.getSessionStatusColor(
                          widget.session.startDateTime,
                          widget.session.endDateTime,
                        ),
                        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                      ),
                      child: Text(
                        widget.session.status.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      widget.session.gpsValidationEnabled
                          ? Icons.location_on
                          : Icons.location_off,
                      size: 16,
                      color: widget.session.gpsValidationEnabled
                          ? AppColors.success
                          : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.session.gpsValidationEnabled
                          ? 'GPS Enabled'
                          : 'GPS Disabled',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.sm),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      AppHelpers.formatDate(
                        widget.session.sessionDate,
                        format: AppFormats.dateFull,
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(width: AppSizes.md),
                    Icon(Icons.access_time, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      '${AppHelpers.formatTime(widget.session.startDateTime)} - '
                      '${AppHelpers.formatTime(widget.session.endDateTime)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Statistics Cards
          Container(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total',
                    _totalParticipants.toString(),
                    Icons.people,
                    AppColors.primary,
                    theme,
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: _buildStatCard(
                    'Present',
                    _presentCount.toString(),
                    Icons.check_circle,
                    AppColors.success,
                    theme,
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: _buildStatCard(
                    'Absent',
                    _absentCount.toString(),
                    Icons.cancel,
                    AppColors.error,
                    theme,
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: _buildStatCard(
                    'Not Marked',
                    _notMarkedCount.toString(),
                    Icons.help_outline,
                    Colors.grey,
                    theme,
                  ),
                ),
              ],
            ),
          ),

          // Attendance Percentage
          Container(
            margin: const EdgeInsets.symmetric(horizontal: AppSizes.md),
            padding: const EdgeInsets.all(AppSizes.md),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.success,
                  AppColors.success.withOpacity(0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.trending_up,
                  color: Colors.white,
                  size: AppSizes.iconMd,
                ),
                const SizedBox(width: AppSizes.sm),
                Text(
                  'Attendance: ${_attendancePercentage.toStringAsFixed(1)}%',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSizes.md),

          // Search and Filter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
            child: Column(
              children: [
                CustomTextField(
                  label: 'Search',
                  controller: _searchController,
                  prefixIcon: Icons.search,
                  hint: 'Search by name, user ID, or email',
                  onChanged: (_) => _applyFilters(),
                ),
                const SizedBox(height: AppSizes.sm),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', 'all', _totalParticipants),
                      _buildFilterChip('Present', 'present', _presentCount),
                      _buildFilterChip('Absent', 'absent', _absentCount),
                      _buildFilterChip(
                          'Not Marked', 'not_marked', _notMarkedCount),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSizes.md),

          // Attendance List
          Expanded(
            child: _filteredRecords.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: AppSizes.md),
                        Text(
                          _attendanceRecords.isEmpty
                              ? 'No participants in this session'
                              : 'No results found',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSizes.md),
                    itemCount: _filteredRecords.length,
                    itemBuilder: (context, index) {
                      return _buildAttendanceCard(
                        _filteredRecords[index],
                        theme,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
    ThemeData theme,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.sm),
        child: Column(
          children: [
            Icon(icon, color: color, size: AppSizes.iconMd),
            const SizedBox(height: AppSizes.xs),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, int count) {
    final isSelected = _statusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: AppSizes.sm),
      child: FilterChip(
        label: Text('$label ($count)'),
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

  Widget _buildAttendanceCard(Map<String, dynamic> record, ThemeData theme) {
    final user = record['user_detail'];
    final status = record['status'] as String;
    final scanCount = record['scan_count'] as int;
    final addedDuringSession = record['added_during_session'] as bool;
    final markedAt = record['marked_at'];

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
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.1),
          child: Icon(statusIcon, color: statusColor),
        ),
        title: Row(
          children: [
            Expanded(child: Text(user['name'])),
            if (scanCount > 1)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
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
              'ID: ${user['user_id']} • ${user['email']}',
              style: theme.textTheme.bodySmall,
            ),
            if (addedDuringSession)
              Row(
                children: [
                  Icon(Icons.add_circle, size: 12, color: AppColors.info),
                  const SizedBox(width: 4),
                  Text(
                    'Added during session',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.info,
                    ),
                  ),
                ],
              ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Status', status.toUpperCase(), statusColor),
                if (markedAt != null)
                  _buildDetailRow(
                    'Marked At',
                    AppHelpers.formatDateTime(DateTime.parse(markedAt)),
                    null,
                  ),
                _buildDetailRow(
                  'Marked By',
                  record['marked_by_admin'] == true ? 'Admin' : 'Self',
                  null,
                ),
                if (record['distance_from_institute'] != null)
                  _buildDetailRow(
                    'Distance',
                    '${record['distance_from_institute']}m from institute',
                    null,
                  ),
                if (user['phone'] != null)
                  _buildDetailRow('Phone', user['phone'], null),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, Color? valueColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

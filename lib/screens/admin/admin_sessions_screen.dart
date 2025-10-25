// lib/screens/admin/admin_sessions_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attendance_pro_app/services/auth_service.dart';
import 'package:attendance_pro_app/services/database_service.dart';
import 'package:attendance_pro_app/screens/admin/create_session_screen.dart';
import 'package:attendance_pro_app/screens/admin/attendance_screen.dart'; // ⭐ CHANGED
import 'package:attendance_pro_app/widgets/loading_widget.dart';
import 'package:attendance_pro_app/utils/constants.dart';
import 'package:attendance_pro_app/utils/helpers.dart';
import 'package:attendance_pro_app/models/user_model.dart';
import 'package:attendance_pro_app/models/session_model.dart';

class AdminSessionsScreen extends StatefulWidget {
  const AdminSessionsScreen({super.key});

  @override
  State<AdminSessionsScreen> createState() => _AdminSessionsScreenState();
}

class _AdminSessionsScreenState extends State<AdminSessionsScreen> {
  UserModel? _currentUser;
  List<SessionModel> _sessions = [];
  List<SessionModel> _filteredSessions = [];
  bool _isLoading = true;

  final _searchController = TextEditingController();
  String _statusFilter = 'all'; // 'all', 'live', 'upcoming', 'ended'

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);

    try {
      final authService = context.read<AuthService>();
      final databaseService = context.read<DatabaseService>();

      final user = await authService.getCurrentUserProfile();
      if (user == null) return;

      // ⭐ CHANGED: Load ALL sessions (not filtered by status)
      final sessions = await databaseService.getSessions(
        departmentId: user.departmentId,
      );

      // ⭐ ADDED: Sort by date (newest first)
      sessions.sort((a, b) => b.sessionDate.compareTo(a.sessionDate));

      setState(() {
        _currentUser = user;
        _sessions = sessions;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      AppHelpers.debugError('Load sessions error: $e');
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    String query = _searchController.text.toLowerCase();

    setState(() {
      _filteredSessions = _sessions.where((session) {
        // Search filter
        final matchesSearch = query.isEmpty ||
            session.name.toLowerCase().contains(query) ||
            session.description?.toLowerCase().contains(query) == true;

        // Status filter
        final matchesStatus = _statusFilter == 'all' ||
            session.status == _statusFilter;

        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(
        body: LoadingWidget(message: 'Loading sessions...'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('All Sessions (${_sessions.length})'), // ⭐ ADDED: Show count
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        actions: [
          IconButton(
            onPressed: _loadSessions,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(AppSizes.md),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search sessions...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _applyFilters();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
              ),
              onChanged: (_) => _applyFilters(),
            ),
          ),

          // Filter Chips with counts
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
            child: Row(
              children: [
                _buildFilterChip(
                  'All',
                  'all',
                  _sessions.length,
                ),
                _buildFilterChip(
                  'Live',
                  'live',
                  _sessions.where((s) => s.status == 'live').length,
                ),
                _buildFilterChip(
                  'Upcoming',
                  'upcoming',
                  _sessions.where((s) => s.status == 'upcoming').length,
                ),
                _buildFilterChip(
                  'Ended',
                  'ended',
                  _sessions.where((s) => s.status == 'ended').length,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSizes.md),

          // Results count
          if (_filteredSessions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
              child: Row(
                children: [
                  Text(
                    'Showing ${_filteredSessions.length} session${_filteredSessions.length != 1 ? 's' : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: AppSizes.sm),

          // Sessions List
          Expanded(
            child: _filteredSessions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_note,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: AppSizes.md),
                        Text(
                          _sessions.isEmpty
                              ? 'No sessions yet'
                              : 'No results found',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                        if (_sessions.isEmpty) ...[
                          const SizedBox(height: AppSizes.sm),
                          Text(
                            'Create your first session to get started',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadSessions,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(AppSizes.md),
                      itemCount: _filteredSessions.length,
                      itemBuilder: (context, index) {
                        return _buildSessionCard(
                          _filteredSessions[index],
                          theme,
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateSessionScreen(),
            ),
          );
          if (result == true) {
            _loadSessions();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('New Session'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  // ⭐ UPDATED: Added count parameter
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

  Widget _buildSessionCard(SessionModel session, ThemeData theme) {
    final statusColor = AppHelpers.getSessionStatusColor(
      session.startDateTime,
      session.endDateTime,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.md),
      elevation: 2,
      child: InkWell(
        onTap: () {
          // ⭐ CHANGED: Navigate to AttendanceScreen instead
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AttendanceScreen(session: session),
            ),
          );
        },
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      session.name,
                      style: theme.textTheme.titleMedium?.copyWith(
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
                      color: statusColor,
                      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                    ),
                    child: Text(
                      session.status.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (session.description != null) ...[
                const SizedBox(height: AppSizes.xs),
                Text(
                  session.description!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: AppSizes.sm),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    AppHelpers.formatDate(session.sessionDate),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(width: AppSizes.md),
                  Icon(Icons.access_time, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${AppHelpers.formatTime(session.startDateTime)} - '
                      '${AppHelpers.formatTime(session.endDateTime)}',
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.xs),
              Row(
                children: [
                  Icon(
                    session.gpsValidationEnabled
                        ? Icons.location_on
                        : Icons.location_off,
                    size: 14,
                    color: session.gpsValidationEnabled
                        ? AppColors.success
                        : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    session.gpsValidationEnabled
                        ? 'GPS Enabled'
                        : 'GPS Disabled',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

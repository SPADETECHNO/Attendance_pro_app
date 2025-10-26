// lib/screens/admin/admin_sessions_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attendance_pro_app/services/auth_service.dart';
import 'package:attendance_pro_app/services/database_service.dart';
import 'package:attendance_pro_app/screens/admin/create_session_screen.dart';
import 'package:attendance_pro_app/screens/admin/attendance_screen.dart';
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
  // State Variables
  UserModel? _currentUser;
  List<SessionModel> _sessions = [];
  List<SessionModel> _filteredSessions = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();
  String _statusFilter = 'all';

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

  // Load sessions data
  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    try {
      final authService = context.read<AuthService>();
      final databaseService = context.read<DatabaseService>();
      final user = await authService.getCurrentUserProfile();
      
      if (user == null) return;

      final sessions = await databaseService.getSessions(
        departmentId: user.departmentId,
      );

      // Sort by date (newest first)
      sessions.sort((a, b) => b.sessionDate.compareTo(a.sessionDate));

      if (mounted) {
        setState(() {
          _currentUser = user;
          _sessions = sessions;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      AppHelpers.debugError('Load sessions error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Apply search and status filters
  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredSessions = _sessions.where((session) {
        final matchesSearch = query.isEmpty ||
            session.name.toLowerCase().contains(query) ||
            session.description?.toLowerCase().contains(query) == true;
        
        final matchesStatus = _statusFilter == 'all' ||
            session.status == _statusFilter;
        
        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  // Get session count by status
  int _getStatusCount(String status) {
    if (status == 'all') return _sessions.length;
    return _sessions.where((s) => s.status == status).length;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: LoadingWidget(message: 'Loading sessions...'),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildWelcomeCard(),
          const SizedBox(height: AppSizes.lg),
          _buildSearchSection(),
          const SizedBox(height: AppSizes.md),
          _buildFilterChips(),
          const SizedBox(height: AppSizes.md),
          _buildResultsHeader(),
          const SizedBox(height: AppSizes.sm),
          Expanded(child: _buildSessionsList()),
        ],
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  // App Bar
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        'All Sessions (${_sessions.length})',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      iconTheme: IconThemeData(color: AppColors.onPrimary),
      backgroundColor: AppColors.gray800,
      foregroundColor: AppColors.onPrimary,
      elevation: 0,
      actions: [
        IconButton(
          onPressed: _loadSessions,
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Refresh',
          color: Colors.white,
        ),
        const SizedBox(width: AppSizes.sm),
      ],
    );
  }

  // Welcome card similar to dashboard
  Widget _buildWelcomeCard() {
    return Container(
      margin: const EdgeInsets.all(AppSizes.md),
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.gray800, AppColors.gray700],
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
          Container(
            padding: const EdgeInsets.all(AppSizes.sm),
            decoration: BoxDecoration(
              color: AppColors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            child: Icon(
              Icons.event_rounded,
              color: AppColors.white,
              size: AppSizes.iconMd,
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Session Management',
                  style: TextStyle(
                    fontSize: 18,
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage all your sessions in one place',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Search section
  Widget _buildSearchSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSizes.md),
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.gray200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search sessions by name or description...',
          prefixIcon: Icon(Icons.search_rounded, color: AppColors.gray500),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear_rounded, color: AppColors.gray500),
                  onPressed: () {
                    _searchController.clear();
                    _applyFilters();
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            borderSide: BorderSide(color: AppColors.gray300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            borderSide: BorderSide(color: AppColors.gray300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
          filled: true,
          fillColor: AppColors.gray50,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md,
            vertical: AppSizes.sm,
          ),
        ),
        onChanged: (_) => _applyFilters(),
      ),
    );
  }

  // Filter chips
  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
      child: Row(
        children: [
          _buildFilterChip('All', 'all', _getStatusCount('all')),
          _buildFilterChip('Live', 'live', _getStatusCount('live')),
          _buildFilterChip('Upcoming', 'upcoming', _getStatusCount('upcoming')),
          _buildFilterChip('Ended', 'ended', _getStatusCount('ended')),
        ],
      ),
    );
  }

  // Individual filter chip
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

  // Results header
  Widget _buildResultsHeader() {
    if (_filteredSessions.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
      child: Row(
        children: [
          Icon(
            Icons.list_rounded,
            color: AppColors.gray600,
            size: 16,
          ),
          const SizedBox(width: AppSizes.xs),
          Text(
            'Showing ${_filteredSessions.length} session${_filteredSessions.length != 1 ? 's' : ''}',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.gray600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Sessions list
  Widget _buildSessionsList() {
    if (_filteredSessions.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadSessions,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSizes.md),
        itemCount: _filteredSessions.length,
        itemBuilder: (context, index) {
          return _buildSessionCard(_filteredSessions[index]);
        },
      ),
    );
  }

  // Empty state
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _sessions.isEmpty ? Icons.event_note_rounded : Icons.search_off_rounded,
              size: 80,
              color: AppColors.gray400,
            ),
            const SizedBox(height: AppSizes.lg),
            Text(
              _sessions.isEmpty ? 'No sessions yet' : 'No results found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.gray600,
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            Text(
              _sessions.isEmpty
                  ? 'Create your first session to get started'
                  : 'Try adjusting your search or filters',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.gray500,
              ),
              textAlign: TextAlign.center,
            ),
            if (_sessions.isEmpty) ...[
              const SizedBox(height: AppSizes.xl),
              ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateSessionScreen(),
                    ),
                  );
                  if (result == true) _loadSessions();
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create Session'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.lg,
                    vertical: AppSizes.md,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Session card
  Widget _buildSessionCard(SessionModel session) {
    final statusColor = AppHelpers.getSessionStatusColor(
      session.startDateTime,
      session.endDateTime,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.gray200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AttendanceScreen(session: session),
              ),
            );
          },
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        session.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.sm,
                        vertical: AppSizes.xs,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(AppSizes.radiusXs),
                      ),
                      child: Text(
                        session.status.toUpperCase(),
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                
                // Description
                if (session.description != null) ...[
                  const SizedBox(height: AppSizes.sm),
                  Text(
                    session.description!,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.gray600,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                
                const SizedBox(height: AppSizes.md),
                
                // Session info row
                Row(
                  children: [
                    _buildInfoItem(
                      Icons.calendar_today_rounded,
                      AppHelpers.formatDate(session.sessionDate),
                    ),
                    const SizedBox(width: AppSizes.lg),
                    _buildInfoItem(
                      Icons.access_time_rounded,
                      '${AppHelpers.formatTime(session.startDateTime)} - '
                      '${AppHelpers.formatTime(session.endDateTime)}',
                    ),
                  ],
                ),
                
                const SizedBox(height: AppSizes.sm),
                
                // GPS status
                Row(
                  children: [
                    _buildInfoItem(
                      session.gpsValidationEnabled
                          ? Icons.location_on_rounded
                          : Icons.location_off_rounded,
                      session.gpsValidationEnabled ? 'GPS Enabled' : 'GPS Disabled',
                      color: session.gpsValidationEnabled 
                          ? AppColors.success 
                          : AppColors.gray500,
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: AppColors.gray400,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Info item helper
  Widget _buildInfoItem(IconData icon, String text, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: color ?? AppColors.gray500,
        ),
        const SizedBox(width: AppSizes.xs),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: color ?? AppColors.gray600,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // Floating Action Button
  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CreateSessionScreen(),
          ),
        );
        if (result == true) _loadSessions();
      },
      icon: const Icon(Icons.add_rounded),
      label: const Text(
        'New Session',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      backgroundColor: AppColors.gray700,
      foregroundColor: AppColors.white,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
    );
  }
}

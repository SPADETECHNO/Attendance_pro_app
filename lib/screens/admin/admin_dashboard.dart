// lib/screens/admin/admin_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attendance_pro_app/services/auth_service.dart';
import 'package:attendance_pro_app/services/database_service.dart';
import 'package:attendance_pro_app/screens/admin/admin_sessions_screen.dart';
import 'package:attendance_pro_app/screens/admin/create_session_screen.dart';
import 'package:attendance_pro_app/screens/admin/attendance_screen.dart';
import 'package:attendance_pro_app/widgets/loading_widget.dart';
import 'package:attendance_pro_app/utils/constants.dart';
import 'package:attendance_pro_app/utils/helpers.dart';
import 'package:attendance_pro_app/models/user_model.dart';
import 'package:attendance_pro_app/models/session_model.dart';
import 'package:attendance_pro_app/constants/app_constants.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  UserModel? _currentUser;
  List<SessionModel> _recentSessions = [];
  bool _isLoading = true;

  // Statistics
  int _totalParticipants = 0;
  int _activeSessions = 0;
  int _todaySessions = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final authService = context.read<AuthService>();
      final databaseService = context.read<DatabaseService>();

      // Get current user
      final user = await authService.getCurrentUserProfile();
      if (user == null) return;

      // ⭐ Get total participants from master list (not profiles)
      final masterListResponse = await databaseService.client
          .from(AppConstants.instituteMasterListTable)
          .select('id')
          .eq('institute_id', user.instituteId!)
          .eq('account_status', 'active');

      final totalParticipants = masterListResponse.length;

      // Get recent sessions for admin's department
      final sessions = await databaseService.getSessions(
        departmentId: user.departmentId,
      );

      final recentSessions = sessions.take(5).toList();
      final activeSessions = sessions.where((s) => s.status == 'live').length;
      
      // Today's sessions
      final today = DateTime.now();
      final todaySessions = sessions.where((s) {
        return s.sessionDate.year == today.year &&
            s.sessionDate.month == today.month &&
            s.sessionDate.day == today.day;
      }).length;

      setState(() {
        _currentUser = user;
        _recentSessions = recentSessions;
        _totalParticipants = totalParticipants;
        _activeSessions = activeSessions;
        _todaySessions = todaySessions;
        _isLoading = false;
      });
    } catch (e) {
      AppHelpers.debugError('Load dashboard error: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(
        body: LoadingWidget(message: 'Loading dashboard...'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        actions: [
          IconButton(
            onPressed: _loadDashboardData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: () async {
              final authService = context.read<AuthService>();
              await authService.signOut();
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSizes.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Card
              _buildWelcomeCard(theme),
              const SizedBox(height: AppSizes.xl),

              // Statistics Cards
              Text(
                'Overview',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSizes.md),
              _buildStatisticsGrid(theme),
              const SizedBox(height: AppSizes.xl),

              // Quick Actions
              Text(
                'Quick Actions',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSizes.md),
              _buildQuickActions(theme),
              const SizedBox(height: AppSizes.xl),

              // Recent Sessions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Sessions',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AdminSessionsScreen(),
                        ),
                      );
                    },
                    child: const Text('View All'),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.md),
              _buildRecentSessions(theme),
            ],
          ),
        ),
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
            _loadDashboardData();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('New Session'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Widget _buildWelcomeCard(ThemeData theme) {
    return Card(
      elevation: 2,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSizes.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary,
              AppColors.primary.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome back!',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
              ),
            ),
            const SizedBox(height: AppSizes.xs),
            Text(
              _currentUser?.name ?? 'Admin',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSizes.xs),
            Text(
              _currentUser?.roleDisplayName ?? 'Administrator',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            if (_currentUser?.departmentName != null) ...[
              const SizedBox(height: AppSizes.xs),
              Row(
                children: [
                  Icon(
                    Icons.domain,
                    color: Colors.white.withOpacity(0.9),
                    size: 16,
                  ),
                  const SizedBox(width: AppSizes.xs),
                  Text(
                    _currentUser!.departmentName!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsGrid(ThemeData theme) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: AppSizes.md,
      crossAxisSpacing: AppSizes.md,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'Total Participants',
          _totalParticipants.toString(),
          Icons.people,
          AppColors.primary,
          theme,
        ),
        _buildStatCard(
          'Active Sessions',
          _activeSessions.toString(),
          Icons.play_circle,
          AppColors.success,
          theme,
        ),
        _buildStatCard(
          'Today\'s Sessions',
          _todaySessions.toString(),
          Icons.today,
          AppColors.info,
          theme,
        ),
        _buildStatCard(
          'Total Sessions',
          _recentSessions.length.toString(),
          Icons.event_note,
          AppColors.warning,
          theme,
        ),
      ],
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
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: AppSizes.iconLg),
            const SizedBox(height: AppSizes.sm),
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            'Create Session',
            Icons.add_circle,
            AppColors.primary,
            () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateSessionScreen(),
                ),
              );
              if (result == true) {
                _loadDashboardData();
              }
            },
          ),
        ),
        const SizedBox(width: AppSizes.md),
        Expanded(
          child: _buildActionButton(
            'Mark Attendance',
            Icons.check_circle,
            AppColors.success,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AttendanceScreen(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: Column(
            children: [
              Icon(icon, color: color, size: AppSizes.iconLg),
              const SizedBox(height: AppSizes.sm),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentSessions(ThemeData theme) {
    if (_recentSessions.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.xl),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.event_note,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: AppSizes.md),
                Text(
                  'No sessions yet',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: AppSizes.sm),
                Text(
                  'Create your first session to get started',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _recentSessions.length,
      itemBuilder: (context, index) {
        final session = _recentSessions[index];
        return Card(
          margin: const EdgeInsets.only(bottom: AppSizes.sm),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppHelpers.getSessionStatusColor(
                session.startDateTime,
                session.endDateTime,
              ),
              child: Icon(
                Icons.event,
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text(
              session.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppHelpers.formatDate(session.sessionDate),
                  style: theme.textTheme.bodySmall,
                ),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 12,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${AppHelpers.formatTime(session.startDateTime)} - '
                      '${AppHelpers.formatTime(session.endDateTime)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.sm,
                vertical: AppSizes.xs,
              ),
              decoration: BoxDecoration(
                color: AppHelpers.getSessionStatusColor(
                  session.startDateTime,
                  session.endDateTime,
                ),
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
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AttendanceScreen(session: session),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

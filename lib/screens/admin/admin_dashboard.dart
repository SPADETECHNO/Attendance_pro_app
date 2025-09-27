import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attendance_pro_app/services/auth_service.dart';
import 'package:attendance_pro_app/services/database_service.dart';
import 'package:attendance_pro_app/screens/admin/create_session_screen.dart';
import 'package:attendance_pro_app/screens/admin/attendance_screen.dart';
import 'package:attendance_pro_app/screens/auth/splash_screen.dart';
import 'package:attendance_pro_app/widgets/loading_widget.dart';
import 'package:attendance_pro_app/widgets/custom_button.dart';
import 'package:attendance_pro_app/utils/constants.dart';
import 'package:attendance_pro_app/utils/helpers.dart';
import 'package:attendance_pro_app/models/user_model.dart';
import 'package:attendance_pro_app/models/session_model.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  UserModel? _currentUser;
  List<SessionModel> _recentSessions = [];
  bool _isLoading = true;
  int _totalSessions = 0;
  int _totalUsers = 0;
  int _todaySessions = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final authService = context.read<AuthService>();
      final databaseService = context.read<DatabaseService>();

      // Get current user
      final user = await authService.getCurrentUserProfile();
      if (user == null) {
        _navigateToLogin();
        return;
      }

      // Get recent sessions for this department
      final sessions = await databaseService.getSessions(
        departmentId: user.departmentId,
      );

      // Get stats
      final departmentUserCount = await databaseService.getUsers(
        departmentId: user.departmentId,
        role: 'user',
      );

      final today = DateTime.now();
      final todaySessionsCount = sessions.where((session) {
        return session.sessionDate.year == today.year &&
               session.sessionDate.month == today.month &&
               session.sessionDate.day == today.day;
      }).length;

      setState(() {
        _currentUser = user;
        _recentSessions = sessions.take(5).toList();
        _totalSessions = sessions.length;
        _totalUsers = departmentUserCount.length;
        _todaySessions = todaySessionsCount;
        _isLoading = false;
      });
    } catch (e) {
      AppHelpers.debugError('Load dashboard error: $e');
      AppHelpers.showErrorToast('Failed to load dashboard');
      setState(() => _isLoading = false);
    }
  }

  void _navigateToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SplashScreen()),
    );
  }

  Future<void> _logout() async {
    try {
      final authService = context.read<AuthService>();
      await authService.signOut();
      _navigateToLogin();
    } catch (e) {
      AppHelpers.showErrorToast('Logout failed');
    }
  }

  void _navigateToCreateSession() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateSessionScreen()),
    ).then((_) => _loadDashboardData());
  }

  void _navigateToAttendanceScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AttendanceScreen()),
    );
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
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadDashboardData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          // ✅ Fixed: Added explicit generic type parameter
          PopupMenuButton<String>(
            icon: CircleAvatar(
              backgroundColor: theme.colorScheme.onPrimary.withAlpha((0.2 * 255).toInt()),
              child: Text(
                _currentUser?.initials ?? '?',
                style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // ✅ Fixed: Explicit return type for itemBuilder
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'profile',
                child: ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(_currentUser?.name ?? 'Unknown'),
                  subtitle: Text(_currentUser?.email ?? ''),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'logout',
                child: const ListTile(
                  leading: Icon(Icons.logout, color: AppColors.error),
                  title: Text('Logout'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'logout') {
                _logout();
              }
            },
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
              // Welcome Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSizes.lg),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withAlpha((0.8 * 255).toInt()),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back, ${_currentUser?.name.split(' ').first ?? 'Admin'}!',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSizes.sm),
                    Text(
                      'Manage your department attendance and sessions',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onPrimary.withAlpha((0.9 * 255).toInt()),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSizes.xl),

              // Stats Cards
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'Total Sessions',
                      value: '$_totalSessions',
                      icon: Icons.event,
                      color: AppColors.info,
                      theme: theme,
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: _buildStatCard(
                      title: 'Today\'s Sessions',
                      value: '$_todaySessions',
                      icon: Icons.today,
                      color: AppColors.success,
                      theme: theme,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSizes.md),

              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'Department Users',
                      value: '$_totalUsers',
                      icon: Icons.people,
                      color: AppColors.warning,
                      theme: theme,
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: _buildStatCard(
                      title: 'Active Sessions',
                      value: '${_recentSessions.where((s) => s.isLive).length}',
                      icon: Icons.live_tv,
                      color: AppColors.live,
                      theme: theme,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSizes.xl),

              // Quick Actions
              Text(
                'Quick Actions',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: AppSizes.md),

              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      text: 'Create Session',
                      onPressed: _navigateToCreateSession,
                      icon: Icons.add,
                      backgroundColor: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: CustomButton(
                      text: 'Mark Attendance',
                      onPressed: _navigateToAttendanceScreen,
                      icon: Icons.qr_code_scanner,
                      backgroundColor: AppColors.success,
                    ),
                  ),
                ],
              ),

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
                  if (_recentSessions.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        // Navigate to all sessions screen (implement as needed)
                        AppHelpers.showInfoToast('All sessions view coming soon');
                      },
                      child: const Text('View All'),
                    ),
                ],
              ),

              const SizedBox(height: AppSizes.md),

              if (_recentSessions.isEmpty)
                EmptyStateWidget(
                  icon: Icons.event_note,
                  title: 'No Sessions Yet',
                  subtitle: 'Create your first session to get started',
                  buttonText: 'Create Session',
                  onButtonPressed: _navigateToCreateSession,
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _recentSessions.length,
                  itemBuilder: (context, index) {
                    final session = _recentSessions[index];
                    return _buildSessionCard(session, theme);
                  },
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreateSession,
        backgroundColor: theme.colorScheme.primary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required ThemeData theme,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  icon,
                  color: color,
                  size: AppSizes.iconLg,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.sm,
                    vertical: AppSizes.xs,
                  ),
                  decoration: BoxDecoration(
                    color: color.withAlpha((0.1 * 255).toInt()),
                    borderRadius: BorderRadius.circular(AppSizes.radiusRound),
                  ),
                  child: Text(
                    value,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.sm),
            Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha((0.7 * 255).toInt()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(SessionModel session, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(AppSizes.sm),
          decoration: BoxDecoration(
            color: AppHelpers.getSessionStatusColor(
              session.startDateTime,
              session.endDateTime,
            ).withAlpha((0.1 * 255).toInt()),
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          child: Icon(
            AppHelpers.getSessionStatusIcon(
              session.startDateTime,
              session.endDateTime,
            ),
            color: AppHelpers.getSessionStatusColor(
              session.startDateTime,
              session.endDateTime,
            ),
          ),
        ),
        title: Text(
          session.name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppHelpers.formatDateTime(session.startDateTime),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSizes.xs),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.sm,
                vertical: AppSizes.xs,
              ),
              decoration: BoxDecoration(
                color: AppHelpers.getSessionStatusColor(
                  session.startDateTime,
                  session.endDateTime,
                ).withAlpha((0.1 * 255).toInt()),
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              child: Text(
                session.status,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppHelpers.getSessionStatusColor(
                    session.startDateTime,
                    session.endDateTime,
                  ),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        trailing: IconButton(
          onPressed: () {
            // Navigate to session details (implement as needed)
            AppHelpers.showInfoToast('Session details view coming soon');
          },
          icon: const Icon(Icons.chevron_right),
        ),
        onTap: () {
          if (session.canMarkAttendance) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AttendanceScreen(session: session),
              ),
            );
          }
        },
      ),
    );
  }
}

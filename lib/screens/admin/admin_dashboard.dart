// lib/screens/admin/admin_dashboard_screen.dart

import 'dart:math';
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

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with TickerProviderStateMixin {
  UserModel? _currentUser;
  List<SessionModel> _recentSessions = [];
  bool _isLoading = true;

  // Statistics
  int _totalParticipants = 0;
  int _activeSessions = 0;
  int _todaySessions = 0;

  AnimationController? _pieAnimationController;
  AnimationController? _fabAnimationController;
  Animation<double>? _pieAnimation;
  Animation<double>? _fabAnimation;
  
  bool _isFabExpanded = false;
  bool _animationsReady = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadDashboardData();
  }

  void _initializeAnimations() {
    try {
      _pieAnimationController = AnimationController(
        duration: const Duration(milliseconds: 2000),
        vsync: this,
      );
      
      _fabAnimationController = AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: this,
      );
      
      _pieAnimation = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _pieAnimationController!, curve: Curves.easeInOutCubic),
      );
      
      _fabAnimation = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _fabAnimationController!, curve: Curves.easeInOut),
      );
      
      setState(() {
        _animationsReady = true;
      });
    } catch (e) {
      debugPrint('Animation initialization error: $e');
    }
  }

  @override
  void dispose() {
    _pieAnimationController?.dispose();
    _fabAnimationController?.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final authService = context.read<AuthService>();
      final databaseService = context.read<DatabaseService>();

      final user = await authService.getCurrentUserProfile();
      if (user == null) return;

      final masterListResponse = await databaseService.client
          .from(AppConstants.instituteMasterListTable)
          .select('id')
          .eq('institute_id', user.instituteId!)
          .eq('account_status', 'active');

      final totalParticipants = masterListResponse.length;

      final sessions = await databaseService.getSessions(
        departmentId: user.departmentId,
      );

      final recentSessions = sessions.take(5).toList();
      final activeSessions = sessions.where((s) => s.status == 'live').length;

      final today = DateTime.now();
      final todaySessions = sessions.where((s) {
        return s.sessionDate.year == today.year &&
            s.sessionDate.month == today.month &&
            s.sessionDate.day == today.day;
      }).length;

      if (mounted) {
        setState(() {
          _currentUser = user;
          _recentSessions = recentSessions;
          _totalParticipants = totalParticipants;
          _activeSessions = activeSessions;
          _todaySessions = todaySessions;
          _isLoading = false;
        });
        
        if (_animationsReady && _pieAnimationController != null) {
          await Future.delayed(const Duration(milliseconds: 500));
          _pieAnimationController!.forward();
        }
      }
    } catch (e) {
      AppHelpers.debugError('Load dashboard error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _toggleFab() {
    if (!_animationsReady || _fabAnimationController == null) return;
    
    setState(() {
      _isFabExpanded = !_isFabExpanded;
    });
    
    if (_isFabExpanded) {
      _fabAnimationController!.forward();
    } else {
      _fabAnimationController!.reverse();
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
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        backgroundColor: AppColors.gray800,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () async {
              await _loadDashboardData();
              if (_animationsReady && _pieAnimationController != null) {
                _pieAnimationController!.reset();
                await Future.delayed(const Duration(milliseconds: 200));
                _pieAnimationController!.forward();
              }
            },
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Dashboard',
            color: Colors.white,
          ),
          IconButton(
            onPressed: () async {
              final shouldLogout = await showDialog<bool>(
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
                          Icons.logout_rounded,
                          color: AppColors.warning,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppSizes.sm),
                      Text(
                        'Logout',
                        style: TextStyle(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  content: Text(
                    'Are you sure you want to logout?',
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
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        elevation: 2,
                      ),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
              
              if (shouldLogout == true) {
                try {
                  final authService = context.read<AuthService>();
                  await authService.signOut();
                  if (mounted) {
                    // Clear the entire navigation stack and go to initial route
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/', // This should be your splash/initial screen route
                      (route) => false,
                    );
                  }
                } catch (e) {
                  AppHelpers.debugError('Logout error: $e');
                  if (mounted) {
                    AppHelpers.showErrorToast('Failed to logout. Please try again.');
                  }
                }
              }
            },
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign Out',
            color: Colors.white,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadDashboardData();
          if (_animationsReady && _pieAnimationController != null) {
            _pieAnimationController!.reset();
            await Future.delayed(const Duration(milliseconds: 200));
            _pieAnimationController!.forward();
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Compressed Welcome Section
              _buildCompactWelcomeCard(),
              const SizedBox(height: 32),

              // Pie Chart Statistics Overview
              Text(
                'Statistics Overview',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 16),
              _buildPieChart(),
              const SizedBox(height: 32),

              // Quick Actions
              Text(
                'Quick Actions',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 16),
              _buildQuickActions(theme),
              const SizedBox(height: 32),

              // Recent Sessions - Matching Welcome Card Theme
              Text(
                'Recent Sessions',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 16),
              _buildThemedRecentSessions(),
              
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildAnimatedFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // COMPRESSED WELCOME CARD
  Widget _buildCompactWelcomeCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E293B),
            const Color(0xFF334155),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.admin_panel_settings_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back,',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    _currentUser?.name ?? 'Admin',
                    style: const TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _currentUser?.roleDisplayName ?? 'Administrator',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (_currentUser?.departmentName != null) ...[
                        const SizedBox(width: 8),
                        const Text('•', style: TextStyle(color: Colors.white60)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _currentUser!.departmentName!,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.8),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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

  Widget _buildPieChart() {
    final total = _totalParticipants + _activeSessions + _todaySessions + _recentSessions.length;
    if (total == 0) {
      return _buildEmptyChart();
    }

    final data = [
      PieChartData('Participants', _totalParticipants, AppColors.primary),
      PieChartData('Active Sessions', _activeSessions, AppColors.success),
      PieChartData('Today\'s Sessions', _todaySessions, AppColors.info),
      PieChartData('Total Sessions', _recentSessions.length, AppColors.warning),
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Animated Pie Chart
              Expanded(
                flex: 2,
                child: Container(
                  height: 200,
                  child: _animationsReady && _pieAnimation != null
                      ? AnimatedBuilder(
                          animation: _pieAnimation!,
                          builder: (context, child) {
                            return CustomPaint(
                              painter: PieChartPainter(
                                data: data,
                                total: total,
                                animationValue: _pieAnimation!.value,
                              ),
                              size: const Size(200, 200),
                            );
                          },
                        )
                      : CustomPaint(
                          painter: PieChartPainter(
                            data: data,
                            total: total,
                            animationValue: 1.0, // Static version
                          ),
                          size: const Size(200, 200),
                        ),
                ),
              ),
              const SizedBox(width: 24),
              // Legend
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: data.map((item) {
                    final percentage = total > 0 ? (item.value / total * 100) : 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: item.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                '${item.value}   ',
                                // '${item.value} (${percentage.toStringAsFixed(1)}%)',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[800],
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  item.label,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: Color(0xFF1E293B),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChart() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.pie_chart_outline_rounded,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No data available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Statistics will appear once you have data',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // QUICK ACTIONS
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
            theme,
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
            theme,
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
    ThemeData theme,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(AppSizes.lg),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border.all(
              color: color.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSizes.md),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon, 
                  color: color, 
                  size: AppSizes.iconLg,
                ),
              ),
              const SizedBox(height: AppSizes.sm),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: color,
                  fontSize: 13,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // RECENT SESSIONS MATCHING WELCOME CARD THEME
  Widget _buildThemedRecentSessions() {
    if (_recentSessions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1E293B),
              const Color(0xFF334155),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_note_rounded,
                size: 48,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No sessions yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first session to get started',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E293B),
            const Color(0xFF334155),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Latest Activity',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.9),
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
                  child: Text(
                    'View All',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Sessions List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
            itemCount: _recentSessions.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final session = _recentSessions[index];
              return Material(
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
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppHelpers.getSessionStatusColor(
                              session.startDateTime,
                              session.endDateTime,
                            ).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.event_rounded,
                            color: AppHelpers.getSessionStatusColor(
                              session.startDateTime,
                              session.endDateTime,
                            ),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      session.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                        color: Colors.white.withOpacity(0.95),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppHelpers.getSessionStatusColor(
                                        session.startDateTime,
                                        session.endDateTime,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      session.status.toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                AppHelpers.formatDate(session.sessionDate),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 12,
                                    color: Colors.white.withOpacity(0.6),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '${AppHelpers.formatTime(session.startDateTime)} - '
                                      '${AppHelpers.formatTime(session.endDateTime)}',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.6),
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                          color: Colors.white.withOpacity(0.4),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ANIMATED FAB - Safe animation access
  Widget _buildAnimatedFAB() {
    if (!_animationsReady || _fabAnimation == null) {
      // Return simple FAB while animations initialize
      return FloatingActionButton(
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
        backgroundColor: AppColors.gray800,
        child: const Icon(
          Icons.add_rounded,
          color: Colors.white,
        ),
      );
    }

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        // Background overlay
        AnimatedBuilder(
          animation: _fabAnimation!,
          builder: (context, child) {
            if (_fabAnimation!.value == 0) return const SizedBox.shrink();
            
            return Positioned.fill(
              child: GestureDetector(
                onTap: _toggleFab,
                child: Container(
                  color: Colors.black.withOpacity(0.3 * _fabAnimation!.value),
                ),
              ),
            );
          },
        ),
        
        // Animated buttons
        AnimatedBuilder(
          animation: _fabAnimation!,
          builder: (context, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.translate(
                  offset: Offset(0, -80 * _fabAnimation!.value),
                  child: Transform.scale(
                    scale: _fabAnimation!.value,
                    child: Opacity(
                      opacity: _fabAnimation!.value,
                      child: FloatingActionButton(
                        heroTag: "create_session",
                        onPressed: () async {
                          _toggleFab();
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
                        backgroundColor: AppColors.primary,
                        child: const Icon(Icons.add_rounded, color: Colors.white),
                      ),
                    ),
                  ),
                ),
                
                Transform.translate(
                  offset: Offset(0, -20 * _fabAnimation!.value),
                  child: Transform.scale(
                    scale: _fabAnimation!.value,
                    child: Opacity(
                      opacity: _fabAnimation!.value,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: FloatingActionButton(
                          heroTag: "mark_attendance",
                          onPressed: () {
                            _toggleFab();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AttendanceScreen(),
                              ),
                            );
                          },
                          backgroundColor: AppColors.success,
                          child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
                
                FloatingActionButton(
                  heroTag: "main_fab",
                  onPressed: _toggleFab,
                  backgroundColor: AppColors.gray800,
                  child: AnimatedRotation(
                    turns: _isFabExpanded ? 0.125 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      _isFabExpanded ? Icons.close_rounded : Icons.menu_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// PIE CHART DATA MODEL
class PieChartData {
  final String label;
  final int value;
  final Color color;

  PieChartData(this.label, this.value, this.color);
}

// CUSTOM PIE CHART PAINTER
class PieChartPainter extends CustomPainter {
  final List<PieChartData> data;
  final int total;
  final double animationValue;

  PieChartPainter({
    required this.data,
    required this.total,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 20;
    
    double startAngle = -pi / 2;
    
    for (final item in data) {
      if (item.value == 0) continue;
      
      final sweepAngle = (item.value / total) * 2 * pi * animationValue;
      
      final paint = Paint()
        ..color = item.color
        ..style = PaintingStyle.fill;
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );
      
      // White separator
      final separatorPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        separatorPaint,
      );
      
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

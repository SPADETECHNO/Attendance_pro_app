// lib/screens/institute_admin/institute_dashboard.dart

import 'package:attendance_pro_app/models/academic_year_model.dart';
import 'package:attendance_pro_app/screens/institute_admin/manage_academic_years_screen.dart';
import 'package:attendance_pro_app/screens/institute_admin/manage_master_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attendance_pro_app/services/auth_service.dart';
import 'package:attendance_pro_app/services/database_service.dart';
import 'package:attendance_pro_app/services/location_service.dart';
import 'package:attendance_pro_app/screens/institute_admin/manage_departments_screen.dart';
import 'package:attendance_pro_app/screens/institute_admin/upload_csv_screen.dart';
import 'package:attendance_pro_app/screens/auth/splash_screen.dart';
import 'package:attendance_pro_app/widgets/loading_widget.dart';
import 'package:attendance_pro_app/widgets/custom_button.dart';
import 'package:attendance_pro_app/widgets/custom_text_field.dart';
import 'package:attendance_pro_app/utils/constants.dart';
import 'package:attendance_pro_app/utils/helpers.dart';
import 'package:attendance_pro_app/models/user_model.dart';
import 'package:attendance_pro_app/models/institute_model.dart';
import 'package:attendance_pro_app/models/department_model.dart';

class InstituteDashboard extends StatefulWidget {
  const InstituteDashboard({super.key});

  @override
  State<InstituteDashboard> createState() => _InstituteDashboardState();
}

class _InstituteDashboardState extends State<InstituteDashboard> with TickerProviderStateMixin {
  UserModel? _currentUser;
  InstituteModel? _institute;
  List<DepartmentModel> _departments = [];
  List<Map<String, dynamic>> _instituteAdmins = [];
  List<AcademicYearModel> _academicYears = [];
  AcademicYearModel? _selectedAcademicYear;
  bool _isLoading = true;
  int _totalDepartments = 0;
  int _totalAdmins = 0;
  int _totalUsers = 0;
  int _activeSessions = 0;
  int _totalAcademicYears = 0;

  AnimationController? _animationController;
  List<Animation<double>>? _animations;
  bool _animationsInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadDashboardData();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _animations = List.generate(5, (index) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _animationController!,
          curve: Interval(
            index * 0.2,
            1.0,
            curve: Curves.elasticOut,
          ),
        ),
      );
    });
    
    setState(() {
      _animationsInitialized = true;
    });
  }

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    try {
      final authService = context.read<AuthService>();
      final databaseService = context.read<DatabaseService>();
      final user = await authService.getCurrentUserProfile();
      
      if (user == null || user.instituteId == null) {
        _navigateToLogin();
        return;
      }

      final institute = await databaseService.getInstituteById(user.instituteId!);
      if (institute == null) {
        _navigateToLogin();
        return;
      }

      final academicYears = await databaseService.getAcademicYears(user.instituteId!);
      final currentYear = academicYears.isNotEmpty
          ? academicYears.firstWhere((year) => year.isCurrent, orElse: () => academicYears.first)
          : null;

      final departments = await databaseService.getDepartmentsByInstitute(user.instituteId!);

      List<Map<String, dynamic>> departmentAdmins;
      try {
        if (currentYear != null) {
          departmentAdmins = await databaseService.getDepartmentAdminsByAcademicYear(
            user.instituteId!,
            currentYear.id
          );
          
          if (departmentAdmins.isEmpty) {
            departmentAdmins = await databaseService.getDepartmentAdmins(user.instituteId!);
          }
        } else {
          departmentAdmins = await databaseService.getDepartmentAdmins(user.instituteId!);
        }
      } catch (e) {
        departmentAdmins = await databaseService.getDepartmentAdmins(user.instituteId!);
      }

      final instituteAdmins = await databaseService.getInstituteAdmins(user.instituteId!);
      
      final users = await databaseService.getUsers(
        instituteId: user.instituteId!,
        academicYearId: currentYear?.id,
      );
      final userCount = users.where((u) => u.role == 'user').length;

      int activeSessionCount = 0;
      if (currentYear != null) {
        try {
          for (final dept in departments) {
            final sessionCount = await databaseService.getSessionCountByDepartmentAndYear(
              dept.id,
              currentYear.id
            );
            activeSessionCount += sessionCount;
          }
        } catch (e) {
          try {
            for (final dept in departments) {
              final sessionCount = await databaseService.getSessionCountByDepartment(dept.id);
              activeSessionCount += sessionCount;
            }
          } catch (fallbackError) {
            activeSessionCount = 0;
          }
        }
      } else {
        try {
          for (final dept in departments) {
            final sessionCount = await databaseService.getSessionCountByDepartment(dept.id);
            activeSessionCount += sessionCount;
          }
        } catch (e) {
          activeSessionCount = 0;
        }
      }

      setState(() {
        _currentUser = user;
        _institute = institute;
        _academicYears = academicYears;
        _selectedAcademicYear = currentYear;
        _departments = departments;
        _instituteAdmins = instituteAdmins.take(5).toList();
        _totalDepartments = departments.length;
        _totalAcademicYears = academicYears.length;
        _totalAdmins = departmentAdmins.length;
        _totalUsers = userCount;
        _activeSessions = activeSessionCount;
        _isLoading = false;
      });

      if (mounted && _animationController != null && _animationsInitialized) {
        _animationController!.forward();
      }

      AppHelpers.debugLog('Dashboard loaded successfully:');
      AppHelpers.debugLog('- Academic Years: ${academicYears.length}');
      AppHelpers.debugLog('- Departments: ${departments.length}');
      AppHelpers.debugLog('- Department Admins: ${departmentAdmins.length}');
      AppHelpers.debugLog('- Institute Admins: ${instituteAdmins.length}');
      AppHelpers.debugLog('- Users: $userCount');
      AppHelpers.debugLog('- Sessions: $activeSessionCount');
      AppHelpers.debugLog('- Current Year: ${currentYear?.yearLabel}');
    } catch (e) {
      AppHelpers.debugError('Load institute dashboard error: $e');
      AppHelpers.showErrorToast('Failed to load dashboard');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _onAcademicYearChanged(AcademicYearModel? year) async {
    if (year == null || year == _selectedAcademicYear) return;
    
    try {
      final databaseService = context.read<DatabaseService>();
      await databaseService.setCurrentAcademicYear(
        instituteId: _currentUser!.instituteId!,
        yearId: year.id,
      );

      AppHelpers.showSuccessToast('${year.yearLabel} set as current year');
      setState(() => _isLoading = true);
      await _loadDashboardData();
    } catch (e) {
      AppHelpers.showErrorToast('Failed to set current year');
    }
  }

  void _navigateToManageAcademicYears() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ManageAcademicYearsScreen()),
    ).then((_) => _loadDashboardData());
  }

  void _navigateToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SplashScreen()),
    );
  }

  Future<void> _logout() async {
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
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/',
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
  }

  void _navigateToManageDepartments() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ManageDepartmentsScreen()),
    ).then((_) => _loadDashboardData());
  }

  void _navigateToUploadCsv() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UploadCsvScreen()),
    ).then((_) => _loadDashboardData());
  }

  void _showInstituteSettings() {
    showDialog(
      context: context,
      builder: (context) => InstituteSettingsDialog(
        institute: _institute!,
        onUpdated: _loadDashboardData,
      ),
    );
  }

  void _navigateToMasterList() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ManageMasterListScreen()),
    ).then((_) => _loadDashboardData());
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: LoadingWidget(message: 'Loading institute dashboard...'),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Institute Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.gray800,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadDashboardData,
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            icon: CircleAvatar(
              backgroundColor: Colors.white.withOpacity(0.2),
              child: Text(
                _currentUser?.initials ?? '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              PopupMenuItem(
                value: 'profile',
                child: ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(
                    _currentUser?.name ?? 'Unknown',
                    style: TextStyle(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    _currentUser?.email ?? '',
                    style: TextStyle(
                      color: AppColors.gray600,
                      fontSize: 12,
                    ),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings, color: AppColors.gray700),
                  title: Text(
                    'Institute Settings',
                    style: TextStyle(color: AppColors.onSurface),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: const ListTile(
                  leading: Icon(Icons.logout, color: AppColors.error),
                  title: Text('Logout', style: TextStyle(color: AppColors.error)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
            onSelected: (value) {
              switch (value) {
                case 'settings':
                  _showInstituteSettings();
                  break;
                case 'logout':
                  _logout();
                  break;
              }
            },
          ),
          const SizedBox(width: AppSizes.sm),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        color: AppColors.gray700,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSizes.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeSection(),
              const SizedBox(height: AppSizes.xl),
              
              if (_academicYears.isNotEmpty) ...[
                _buildAcademicYearSelector(),
                const SizedBox(height: AppSizes.xl),
              ],
              
              _buildStatsOverview(),
              const SizedBox(height: AppSizes.xl),
              
              _buildQuickActions(),
              const SizedBox(height: AppSizes.xl),
              
              _buildDepartmentsSection(),
              const SizedBox(height: AppSizes.xl),
              
              if (_instituteAdmins.isNotEmpty) _buildInstituteAdminsSection(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToManageDepartments,
        icon: const Icon(Icons.add),
        label: const Text('Add Department'),
        backgroundColor: AppColors.gray800,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      width: double.infinity,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSizes.sm),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                child: Icon(
                  Icons.business,
                  color: Colors.white,
                  size: AppSizes.iconLg,
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _institute?.name ?? 'Institute',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_institute?.address?.isNotEmpty == true)
                      Text(
                        _institute!.address!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: _institute?.hasGpsCoordinates == true
                              ? Colors.green[300]
                              : Colors.orange[300],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _institute?.hasGpsCoordinates == true
                              ? 'GPS Set (${_institute?.radiusDisplayText})'
                              : 'GPS Not Set',
                          style: TextStyle(
                            color: _institute?.hasGpsCoordinates == true
                                ? Colors.green[300]
                                : Colors.orange[300],
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          Text(
            'Welcome back, ${_currentUser?.name ?? 'Institute Admin'}!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            'Manage departments, admins, and institute settings',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcademicYearSelector() {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.school, color: AppColors.gray700),
              const SizedBox(width: AppSizes.sm),
              Text(
                'Academic Year:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.gray700,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _navigateToManageAcademicYears,
                icon: Icon(Icons.settings, color: AppColors.gray700),
                tooltip: 'Manage Academic Years',
                iconSize: 20,
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          DropdownButtonFormField<AcademicYearModel>(
            value: _selectedAcademicYear,
            isExpanded: true,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSizes.sm,
                vertical: AppSizes.xs,
              ),
              isDense: true,
            ),
            items: _academicYears.map((year) {
              return DropdownMenuItem(
                value: year,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        year.displayLabel,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (year.isCurrent) ...[
                      const SizedBox(width: AppSizes.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'CURRENT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
            onChanged: _onAcademicYearChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsOverview() {
    if (!_animationsInitialized || _animations == null) {
      return _buildSimpleStatsOverview();
    }

    final List<StatData> stats = [
      // Commented out Academic Years as requested
      // StatData(
      //   title: 'Academic Years',
      //   value: _totalAcademicYears,
      //   icon: Icons.school,
      //   color: AppColors.gray700,
      //   percentage: _totalAcademicYears > 0 ? 100.0 : 0.0,
      // ),
      StatData(
        title: 'Departments',
        value: _totalDepartments,
        icon: Icons.domain,
        color: AppColors.info,
      ),
      StatData(
        title: 'Dept Admins',
        value: _totalAdmins,
        icon: Icons.admin_panel_settings,
        color: AppColors.warning,
      ),
      StatData(
        title: 'Students',
        value: _totalUsers,
        icon: Icons.people,
        color: AppColors.success,
      ),
      StatData(
        title: 'Total Sessions',
        value: _activeSessions,
        icon: Icons.event,
        color: AppColors.primary,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.gray800,
            AppColors.gray700.withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSizes.sm),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                child: Icon(
                  Icons.analytics_rounded,
                  color: Colors.white,
                  size: AppSizes.iconMd,
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Institute Analytics',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Real-time overview of your institute',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSizes.xl),
          
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: AppSizes.md,
              mainAxisSpacing: AppSizes.md,
              childAspectRatio: 1.1,
            ),
            itemCount: stats.length,
            itemBuilder: (context, index) {
              return AnimatedBuilder(
                animation: _animations![index],
                builder: (context, child) {
                  return Transform.scale(
                    scale: _animations![index].value,
                    child: Opacity(
                      opacity: _animations![index].value,
                      child: _buildModernStatCard(stats[index], index),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleStatsOverview() {
    final List<StatData> stats = [
      // Commented out Academic Years as requested
      // StatData(
      //   title: 'Academic Years',
      //   value: _totalAcademicYears,
      //   icon: Icons.school,
      //   color: AppColors.gray700,
      // ),
      StatData(
        title: 'Departments',
        value: _totalDepartments,
        icon: Icons.domain,
        color: AppColors.info,
      ),
      StatData(
        title: 'Dept Admins',
        value: _totalAdmins,
        icon: Icons.admin_panel_settings,
        color: AppColors.warning,
      ),
      StatData(
        title: 'Students',
        value: _totalUsers,
        icon: Icons.people,
        color: AppColors.success,
      ),
      StatData(
        title: 'Total Sessions',
        value: _activeSessions,
        icon: Icons.event,
        color: AppColors.primary,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.gray800,
            AppColors.gray700.withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSizes.sm),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                child: Icon(
                  Icons.analytics_rounded,
                  color: Colors.white,
                  size: AppSizes.iconMd,
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Institute Analytics',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Real-time overview of your institute',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSizes.xl),
          
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: AppSizes.md,
              mainAxisSpacing: AppSizes.md,
              childAspectRatio: 1.1,
            ),
            itemCount: stats.length,
            itemBuilder: (context, index) {
              return _buildModernStatCard(stats[index], index);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildModernStatCard(StatData stat, int index) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      stat.color.withOpacity(0.15),
                      stat.color.withOpacity(0.08),
                    ],
                  ),
                ),
              ),
            ),
            
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      stat.color.withOpacity(0.5),
                      stat.color,
                    ],
                  ),
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(AppSizes.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSizes.sm),
                    decoration: BoxDecoration(
                      color: stat.color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    ),
                    child: Icon(
                      stat.icon,
                      color: stat.color,
                      size: AppSizes.iconMd,
                    ),
                  ),
                  
                  const Spacer(),
                  
                  Text(
                    stat.value.toString(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: AppSizes.xs),
                  
                  Text(
                    stat.title,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
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

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: AppSizes.md),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: AppSizes.md,
          crossAxisSpacing: AppSizes.md,
          childAspectRatio: 1.5,
          children: [
            _buildActionCard(
              title: 'Academic Years',
              subtitle: 'Manage yearly sessions',
              icon: Icons.school,
              color: AppColors.gray700,
              onTap: _navigateToManageAcademicYears,
            ),
            _buildActionCard(
              title: 'Manage Departments',
              subtitle: 'Create & assign admins',
              icon: Icons.domain,
              color: AppColors.info,
              onTap: _navigateToManageDepartments,
            ),
            _buildActionCard(
              title: 'Upload Users',
              subtitle: 'Bulk CSV import',
              icon: Icons.upload_file,
              color: AppColors.success,
              onTap: _navigateToUploadCsv,
            ),
            _buildActionCard(
              title: 'Master List',
              subtitle: 'Manage institute users',
              icon: Icons.people,
              color: AppColors.gray700,
              onTap: _navigateToMasterList,
            ),
            _buildActionCard(
              title: 'Institute Settings',
              subtitle: 'Location & preferences',
              icon: Icons.settings,
              color: AppColors.warning,
              onTap: _showInstituteSettings,
            ),
            _buildActionCard(
              title: 'Reports',
              subtitle: 'Analytics & exports',
              icon: Icons.analytics,
              color: AppColors.gray700,
              onTap: () {
                AppHelpers.showInfoToast('Reports feature coming soon');
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
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
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSizes.sm),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: AppSizes.iconMd,
                  ),
                ),
                const Spacer(),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.gray600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDepartmentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Departments',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
              ),
            ),
            if (_departments.isNotEmpty)
              TextButton(
                onPressed: _navigateToManageDepartments,
                child: const Text('Manage All'),
              ),
          ],
        ),
        const SizedBox(height: AppSizes.md),
        if (_departments.isEmpty)
          EmptyStateWidget(
            icon: Icons.domain,
            title: 'No Departments Yet',
            subtitle: 'Create departments to organize your institute',
            buttonText: 'Create Department',
            onButtonPressed: _navigateToManageDepartments,
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _departments.take(3).length,
            itemBuilder: (context, index) {
              return _buildDepartmentCard(_departments[index]);
            },
          ),
        if (_departments.length > 3) ...[
          const SizedBox(height: AppSizes.sm),
          Center(
            child: TextButton(
              onPressed: _navigateToManageDepartments,
              child: Text('View all ${_departments.length} departments'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDepartmentCard(DepartmentModel department) {
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
        leading: Container(
          padding: const EdgeInsets.all(AppSizes.sm),
          decoration: BoxDecoration(
            color: AppColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          child: const Icon(
            Icons.domain,
            color: AppColors.info,
          ),
        ),
        title: Text(
          department.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.onSurface,
          ),
        ),
        subtitle: Text(
          department.displayDescription,
          style: TextStyle(color: AppColors.gray600),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          _navigateToManageDepartments();
        },
      ),
    );
  }

  Widget _buildInstituteAdminsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Institute Admins',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: AppSizes.md),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _instituteAdmins.length,
          itemBuilder: (context, index) {
            return _buildInstituteAdminCard(_instituteAdmins[index]);
          },
        ),
      ],
    );
  }

  Widget _buildInstituteAdminCard(Map<String, dynamic> admin) {
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
        leading: CircleAvatar(
          backgroundColor: AppColors.gray700.withOpacity(0.1),
          child: Text(
            AppHelpers.getInitials(admin['name'] ?? 'Unknown'),
            style: TextStyle(
              color: AppColors.gray700,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          admin['name'] ?? 'Unknown',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.onSurface,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              admin['email'] ?? '',
              style: TextStyle(color: AppColors.gray600),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.gray700.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Institute Admin',
                style: TextStyle(
                  color: AppColors.gray700,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
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
            color: AppHelpers.getAccountStatusColor(
              admin['account_status'] ?? 'inactive',
              admin['temp_password_used'] ?? true,
            ).withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          ),
          child: Text(
            AppHelpers.getAccountStatusText(
              admin['account_status'] ?? 'inactive',
              admin['temp_password_used'] ?? true,
            ),
            style: TextStyle(
              color: AppHelpers.getAccountStatusColor(
                admin['account_status'] ?? 'inactive',
                admin['temp_password_used'] ?? true,
              ),
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ),
      ),
    );
  }
}

class InstituteSettingsDialog extends StatefulWidget {
  final InstituteModel institute;
  final VoidCallback onUpdated;

  const InstituteSettingsDialog({
    super.key,
    required this.institute,
    required this.onUpdated,
  });

  @override
  State<InstituteSettingsDialog> createState() => _InstituteSettingsDialogState();
}

class _InstituteSettingsDialogState extends State<InstituteSettingsDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _radiusController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  bool _isLoading = false;
  bool _isGettingLocation = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.institute.name;
    _addressController.text = widget.institute.address ?? '';
    _phoneController.text = widget.institute.phone ?? '';
    _radiusController.text = widget.institute.allowedRadius.toString();
    if (widget.institute.hasGpsCoordinates) {
      _latitudeController.text = widget.institute.gpsLatitude!.toStringAsFixed(8);
      _longitudeController.text = widget.institute.gpsLongitude!.toStringAsFixed(8);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _radiusController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      final result = await LocationService.getCurrentLocation();
      if (result.hasLocation) {
        setState(() {
          _latitudeController.text = result.latitude!.toStringAsFixed(8);
          _longitudeController.text = result.longitude!.toStringAsFixed(8);
        });
        AppHelpers.showSuccessToast('Location retrieved successfully!');
      } else {
        AppHelpers.showErrorToast(result.error ?? 'Failed to get location');
      }
    } catch (e) {
      AppHelpers.showErrorToast('Location error: ${e.toString()}');
    } finally {
      setState(() => _isGettingLocation = false);
    }
  }

  void _clearLocation() {
    setState(() {
      _latitudeController.clear();
      _longitudeController.clear();
    });
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    try {
      final databaseService = context.read<DatabaseService>();
      
      double? latitude;
      double? longitude;
      if (_latitudeController.text.isNotEmpty && _longitudeController.text.isNotEmpty) {
        latitude = double.tryParse(_latitudeController.text);
        longitude = double.tryParse(_longitudeController.text);
        if (latitude == null || longitude == null) {
          AppHelpers.showErrorToast('Invalid GPS coordinates');
          return;
        }
      }

      await databaseService.updateInstituteWithGPS(
        id: widget.institute.id,
        name: _nameController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        allowedRadius: int.parse(_radiusController.text),
        gpsLatitude: latitude,
        gpsLongitude: longitude,
      );

      AppHelpers.showSuccessToast('Settings updated successfully');
      Navigator.pop(context);
      widget.onUpdated();
    } catch (e) {
      AppHelpers.showErrorToast('Failed to update settings');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSizes.md),
              decoration: BoxDecoration(
                color: AppColors.gray800,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppSizes.radiusLg),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.settings,
                    color: Colors.white,
                    size: AppSizes.iconMd,
                  ),
                  const SizedBox(width: AppSizes.sm),
                  const Text(
                    'Institute Settings',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSizes.md),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomTextField(
                        label: 'Institute Name',
                        controller: _nameController,
                        validator: (value) => AppHelpers.validateRequired(value, 'Institute name'),
                        prefixIcon: Icons.business,
                      ),
                      const SizedBox(height: AppSizes.lg),
                      CustomTextField(
                        label: 'Address',
                        controller: _addressController,
                        maxLines: 2,
                        prefixIcon: Icons.location_on,
                      ),
                      const SizedBox(height: AppSizes.lg),
                      CustomTextField(
                        label: 'Phone',
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        validator: AppHelpers.validatePhone,
                        prefixIcon: Icons.phone,
                      ),
                      const SizedBox(height: AppSizes.lg),
                      CustomTextField(
                        label: 'GPS Radius (meters)',
                        controller: _radiusController,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value?.isEmpty == true) return 'Radius is required';
                          final radius = int.tryParse(value!);
                          if (radius == null || radius < 10 || radius > 1000) {
                            return 'Radius must be between 10 and 1000 meters';
                          }
                          return null;
                        },
                        prefixIcon: Icons.radar,
                        helperText: 'Students must be within this distance to mark attendance',
                      ),
                      const SizedBox(height: AppSizes.lg),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'GPS Location',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.onSurface,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSizes.sm),
                          Wrap(
                            spacing: AppSizes.sm,
                            runSpacing: AppSizes.xs,
                            children: [
                              TextButton.icon(
                                onPressed: _isGettingLocation ? null : _getCurrentLocation,
                                icon: _isGettingLocation
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.my_location, size: 16),
                                label: const Text('Get Current'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.gray700,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _clearLocation,
                                icon: const Icon(Icons.clear, size: 16),
                                label: const Text('Clear'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.gray700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.sm),
                      Row(
                        children: [
                          Expanded(
                            child: CustomTextField(
                              label: 'Latitude',
                              controller: _latitudeController,
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              prefixIcon: Icons.gps_fixed,
                              validator: (value) {
                                if (value?.isNotEmpty == true) {
                                  final lat = double.tryParse(value!);
                                  if (lat == null || lat < -90 || lat > 90) {
                                    return 'Invalid latitude';
                                  }
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: AppSizes.md),
                          Expanded(
                            child: CustomTextField(
                              label: 'Longitude',
                              controller: _longitudeController,
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              prefixIcon: Icons.gps_fixed,
                              validator: (value) {
                                if (value?.isNotEmpty == true) {
                                  final lng = double.tryParse(value!);
                                  if (lng == null || lng < -180 || lng > 180) {
                                    return 'Invalid longitude';
                                  }
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.sm),
                      Container(
                        padding: const EdgeInsets.all(AppSizes.sm),
                        decoration: BoxDecoration(
                          color: AppColors.info.withOpacity(0.1),
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
                            const Expanded(
                              child: Text(
                                'GPS location is used to verify student attendance. '
                                'Students must be within the specified radius to mark attendance.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(AppSizes.md),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gray300,
                        foregroundColor: AppColors.gray700,
                        elevation: 0,
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gray700,
                        foregroundColor: Colors.white,
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.save, size: 16),
                                SizedBox(width: AppSizes.xs),
                                Text('Save'),
                              ],
                            ),
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

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onButtonPressed;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          children: [
            Icon(
              icon,
              size: 64,
              color: AppColors.gray400,
            ),
            const SizedBox(height: AppSizes.md),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.gray600,
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.gray500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.xl),
            ElevatedButton(
              onPressed: onButtonPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gray700,
                foregroundColor: Colors.white,
              ),
              child: Text(buttonText),
            ),
          ],
        ),
      ),
    );
  }
}

class StatData {
  final String title;
  final int value;
  final IconData icon;
  final Color color;

  StatData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;

  CircularProgressPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    final backgroundPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * 3.14159 * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

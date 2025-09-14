import 'package:attendance_pro_app/models/academic_year_model.dart';
import 'package:attendance_pro_app/screens/institute_admin/manage_academic_years_screen.dart';
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

class _InstituteDashboardState extends State<InstituteDashboard> {
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

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
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

      // ✅ Load academic years FIRST
      final academicYears = await databaseService.getAcademicYears(user.instituteId!);
      final currentYear = academicYears.isNotEmpty
          ? academicYears.firstWhere((year) => year.isCurrent, orElse: () => academicYears.first)
          : null;

      // Get departments
      final departments = await databaseService.getDepartmentsByInstitute(user.instituteId!);

      // ✅ Get department admins - try both filtered and unfiltered approaches
      List<Map<String, dynamic>> departmentAdmins;
      try {
        if (currentYear != null) {
          // Try to get admins filtered by academic year
          departmentAdmins = await databaseService.getDepartmentAdminsByAcademicYear(
            user.instituteId!, 
            currentYear.id
          );
          
          // ✅ If no admins found with academic year filter, get all admins
          if (departmentAdmins.isEmpty) {
            print('No admins found for current year, getting all admins...');
            departmentAdmins = await databaseService.getDepartmentAdmins(user.instituteId!);
          }
        } else {
          departmentAdmins = await databaseService.getDepartmentAdmins(user.instituteId!);
        }
      } catch (e) {
        print('Error getting filtered admins, falling back to all admins: $e');
        departmentAdmins = await databaseService.getDepartmentAdmins(user.instituteId!);
      }

      final instituteAdmins = await databaseService.getInstituteAdmins(user.instituteId!);

      // Get users count for current year
      final users = await databaseService.getUsers(
        instituteId: user.instituteId!,
        academicYearId: currentYear?.id,
      );
      final userCount = users.where((u) => u.role == 'user').length;

      // ✅ Get sessions count for current year - FIXED
      int activeSessionCount = 0;
      if (currentYear != null) {
        try {
          for (final dept in departments) {
            final sessionCount = await databaseService.getSessionCountByDepartmentAndYear(
              dept.id, 
              currentYear.id
            );
            activeSessionCount += sessionCount; // ✅ Now both are int
          }
        } catch (e) {
          print('Error getting session count by year: $e');
          // Fallback to get all sessions for departments
          try {
            for (final dept in departments) {
              final sessionCount = await databaseService.getSessionCountByDepartment(dept.id);
              activeSessionCount += sessionCount; // ✅ Now both are int
            }
          } catch (fallbackError) {
            print('Error in fallback session count: $fallbackError');
            activeSessionCount = 0; // Set to 0 if both fail
          }
        }
      } else {
        // No current year, get all sessions
        try {
          for (final dept in departments) {
            final sessionCount = await databaseService.getSessionCountByDepartment(dept.id);
            activeSessionCount += sessionCount;
          }
        } catch (e) {
          print('Error getting all session counts: $e');
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
        _totalAdmins = departmentAdmins.length; // ✅ This should now update correctly
        _totalUsers = userCount;
        _activeSessions = activeSessionCount;
        _isLoading = false;
      });

      // ✅ Debug logging
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
      
      // Update the current year in database
      await databaseService.setCurrentAcademicYear(
        instituteId: _currentUser!.instituteId!,
        yearId: year.id,
      );
      
      AppHelpers.showSuccessToast('${year.yearLabel} set as current year');
      
      // Reload all data for the new year
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
    try {
      final authService = context.read<AuthService>();
      await authService.signOut();
      _navigateToLogin();
    } catch (e) {
      AppHelpers.showErrorToast('Logout failed');
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(
        body: LoadingWidget(message: 'Loading institute dashboard...'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Institute Dashboard'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadDashboardData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
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
              PopupMenuItem<String>(
                value: 'settings',
                child: const ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('Institute Settings'),
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
              // Welcome Section with Institute Info
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSizes.lg),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.instituteAdmin,
                      AppColors.instituteAdmin.withAlpha((0.8 * 255).toInt()),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSizes.sm),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha((0.2 * 255).toInt()),
                            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                          ),
                          child: const Icon(
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
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_institute?.address?.isNotEmpty == true)
                                Text(
                                  _institute!.address!,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withAlpha((0.9 * 255).toInt()),
                                  ),
                                ),
                              // ✅ GPS Status
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 16,
                                    color: _institute?.hasGpsCoordinates == true
                                        ? Colors.green[300]
                                        : Colors.orange[4],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _institute?.hasGpsCoordinates == true
                                        ? 'GPS Set (${_institute?.radiusDisplayText})'
                                        : 'GPS Not Set',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: _institute?.hasGpsCoordinates == true
                                          ? Colors.green[300]
                                          : Colors.orange[300],
                                      fontWeight: FontWeight.w600,
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
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Manage departments, admins, and institute settings',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSizes.xl),

              if (_academicYears.isNotEmpty) ...[
                const SizedBox(height: AppSizes.lg),
                Container(
                  padding: const EdgeInsets.all(AppSizes.md),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                    border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.school, color: AppColors.primary),
                      const SizedBox(width: AppSizes.sm),
                      Text(
                        'Academic Year:',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: AppSizes.md),
                      Expanded(
                        child: DropdownButtonFormField<AcademicYearModel>(
                          value: _selectedAcademicYear,
                          isExpanded: true, // ✅ This prevents overflow
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: AppSizes.sm,
                              vertical: AppSizes.xs,
                            ),
                            isDense: true,
                          ),
                          items: _academicYears.map((year) {
                            return DropdownMenuItem(
                              value: year,
                              child: Row(
                                mainAxisSize: MainAxisSize.min, // ✅ Prevent row expansion
                                children: [
                                  Flexible( // ✅ Allow text to wrap/truncate
                                    child: Text(
                                      year.displayLabel,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis, // ✅ Handle long text
                                    ),
                                  ),
                                  if (year.isCurrent) ...[
                                    const SizedBox(width: AppSizes.xs),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 2,
                                      ),
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
                      ),
                      const SizedBox(width: AppSizes.sm), // ✅ Add spacing before icon
                      IconButton(
                        onPressed: _navigateToManageAcademicYears,
                        icon: const Icon(Icons.settings, color: AppColors.primary),
                        tooltip: 'Manage Academic Years',
                        iconSize: 20, // ✅ Slightly smaller icon
                        padding: const EdgeInsets.all(8), // ✅ Reduce padding
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40), // ✅ Control button size
                      ),
                    ],
                  ),
                ),
              ],


              const SizedBox(height: AppSizes.xl),

              // Stats Overview
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'Academic Years',
                      value: '$_totalAcademicYears',
                      icon: Icons.school,
                      color: AppColors.primary,
                      theme: theme,
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: _buildStatCard(
                      title: 'Departments',
                      value: '$_totalDepartments',
                      icon: Icons.domain,
                      color: AppColors.info,
                      theme: theme,
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: _buildStatCard(
                      title: 'Dept Admins',
                      value: '$_totalAdmins',
                      icon: Icons.admin_panel_settings,
                      color: AppColors.warning,
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
                      title: 'Students',
                      value: '$_totalUsers',
                      icon: Icons.people,
                      color: AppColors.success,
                      theme: theme,
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: _buildStatCard(
                      title: 'Total Sessions',
                      value: '$_activeSessions',
                      icon: Icons.event,
                      color: AppColors.primary,
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
                    color: AppColors.primary,
                    onTap: _navigateToManageAcademicYears,
                    theme: theme,
                  ),
                  _buildActionCard(
                    title: 'Manage Departments',
                    subtitle: 'Create & assign admins',
                    icon: Icons.domain,
                    color: AppColors.info,
                    onTap: _navigateToManageDepartments,
                    theme: theme,
                  ),
                  _buildActionCard(
                    title: 'Upload Users',
                    subtitle: 'Bulk CSV import',
                    icon: Icons.upload_file,
                    color: AppColors.success,
                    onTap: _navigateToUploadCsv,
                    theme: theme,
                  ),
                  _buildActionCard(
                    title: 'Institute Settings',
                    subtitle: 'Location & preferences',
                    icon: Icons.settings,
                    color: AppColors.warning,
                    onTap: _showInstituteSettings,
                    theme: theme,
                  ),
                  _buildActionCard(
                    title: 'Reports',
                    subtitle: 'Analytics & exports',
                    icon: Icons.analytics,
                    color: AppColors.primary,
                    onTap: () {
                      AppHelpers.showInfoToast('Reports feature coming soon');
                    },
                    theme: theme,
                  ),
                ],
              ),

              const SizedBox(height: AppSizes.xl),

              // Departments Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Departments',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
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
                  itemCount: _departments.take(3).length, // Show only first 3
                  itemBuilder: (context, index) {
                    final department = _departments[index];
                    return _buildDepartmentCard(department, theme);
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

              const SizedBox(height: AppSizes.xl),

              if (_instituteAdmins.isNotEmpty) ...[
                Text(
                  'Institute Admins',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _instituteAdmins.length,
                  itemBuilder: (context, index) {
                    final admin = _instituteAdmins[index];
                    return _buildInstituteAdminCard(admin, theme);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToManageDepartments,
        icon: const Icon(Icons.add),
        label: const Text('Add Department'),
        backgroundColor: theme.colorScheme.primary,
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

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return Card(
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
                  color: color.withAlpha((0.1 * 255).toInt()),
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
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha((0.6 * 255).toInt()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDepartmentCard(DepartmentModel department, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(AppSizes.sm),
          decoration: BoxDecoration(
            color: AppColors.info.withAlpha((0.1 * 255).toInt()),
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          child: const Icon(
            Icons.domain,
            color: AppColors.info,
          ),
        ),
        title: Text(
          department.name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          department.displayDescription,
          style: theme.textTheme.bodySmall,
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

  // ✅ New method for institute admins
  Widget _buildInstituteAdminCard(Map<String, dynamic> admin, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.instituteAdmin.withAlpha((0.1 * 255).toInt()),
          child: Text(
            AppHelpers.getInitials(admin['name'] ?? 'Unknown'),
            style: const TextStyle(
              color: AppColors.instituteAdmin,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          admin['name'] ?? 'Unknown',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              admin['email'] ?? '',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.instituteAdmin.withAlpha((0.1 * 255).toInt()),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Institute Admin',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.instituteAdmin,
                  fontWeight: FontWeight.w600,
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
            ).withAlpha((0.1 * 255).toInt()),
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          ),
          child: Text(
            AppHelpers.getAccountStatusText(
              admin['account_status'] ?? 'inactive',
              admin['temp_password_used'] ?? true,
            ),
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppHelpers.getAccountStatusColor(
                admin['account_status'] ?? 'inactive',
                admin['temp_password_used'] ?? true,
              ),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

// ✅ Updated Institute Settings Dialog with GPS
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
      
      // Parse GPS coordinates
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
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(AppSizes.md),
              decoration: BoxDecoration(
                color: AppColors.instituteAdmin,
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

            // Content
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

                      // GPS Coordinates Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'GPS Location',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
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
                              ),
                              TextButton.icon(
                                onPressed: _clearLocation,
                                icon: const Icon(Icons.clear, size: 16),
                                label: const Text('Clear'),
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
                          color: AppColors.info.withAlpha((0.1 * 255).toInt()),
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

            // Actions
            Container(
              padding: const EdgeInsets.all(AppSizes.md),
              child: Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      text: 'Cancel',
                      onPressed: () => Navigator.pop(context),
                      isOutlined: true,
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: CustomButton(
                      text: 'Save Settings',
                      onPressed: _isLoading ? null : _saveSettings,
                      isLoading: _isLoading,
                      icon: Icons.save,
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

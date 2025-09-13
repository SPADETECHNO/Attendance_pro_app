import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attendance_pro_app/services/auth_service.dart';
import 'package:attendance_pro_app/services/database_service.dart';
import 'package:attendance_pro_app/screens/super_admin/manage_institutes_screen.dart';
import 'package:attendance_pro_app/screens/auth/splash_screen.dart';
import 'package:attendance_pro_app/widgets/loading_widget.dart';
import 'package:attendance_pro_app/widgets/custom_button.dart';
import 'package:attendance_pro_app/utils/constants.dart';
import 'package:attendance_pro_app/utils/helpers.dart';
import 'package:attendance_pro_app/models/user_model.dart';
import 'package:attendance_pro_app/models/institute_model.dart';

class SuperDashboard extends StatefulWidget {
  const SuperDashboard({super.key});

  @override
  State<SuperDashboard> createState() => _SuperDashboardState();
}

class _SuperDashboardState extends State<SuperDashboard> {
  UserModel? _currentUser;
  List<InstituteModel> _institutes = [];
  
  bool _isLoading = true;
  int _totalInstitutes = 0;
  int _totalAdmins = 0;
  int _totalDepartments = 0;
  int _totalUsers = 0;

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

      // Get all institutes
      final institutes = await databaseService.getInstitutes();
      
      // Calculate statistics across all institutes
      int totalAdmins = 0;
      int totalDepartments = 0;
      int totalUsers = 0;
      
      for (final institute in institutes) {
        // Get institute admins
        final admins = await databaseService.getInstituteAdmins(institute.id);
        totalAdmins += admins.length;
        
        // Get departments for this institute
        final departments = await databaseService.getDepartmentsByInstitute(institute.id);
        totalDepartments += departments.length;
        
        // Get users for this institute
        final users = await databaseService.getUsers(instituteId: institute.id);
        final instituteUsers = users.where((u) => u.role == 'user').length;
        totalUsers += instituteUsers;
      }

      setState(() {
        _currentUser = user;
        _institutes = institutes;
        _totalInstitutes = institutes.length;
        _totalAdmins = totalAdmins;
        _totalDepartments = totalDepartments;
        _totalUsers = totalUsers;
        _isLoading = false;
      });
    } catch (e) {
      AppHelpers.debugError('Load super dashboard error: $e');
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

  void _navigateToManageInstitutes() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ManageInstitutesScreen()),
    ).then((_) => _loadDashboardData());
  }

  void _showSystemSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('System Settings'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.backup),
              title: Text('Database Backup'),
              subtitle: Text('Manage system backups'),
              contentPadding: EdgeInsets.zero,
            ),
            ListTile(
              leading: Icon(Icons.security),
              title: Text('Security Settings'),
              subtitle: Text('System security configuration'),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              AppHelpers.showInfoToast('System settings feature coming soon');
            },
            child: const Text('Configure'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(
        body: LoadingWidget(message: 'Loading super admin dashboard...'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSizes.xs),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha((0.2 * 255).toInt()),
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              child: const Icon(
                Icons.admin_panel_settings,
                color: Colors.white,
                size: AppSizes.iconSm,
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            const Text('Super Admin'),
          ],
        ),
        backgroundColor: AppColors.superAdmin,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadDashboardData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            icon: CircleAvatar(
              backgroundColor: Colors.white.withAlpha((0.2 * 255).toInt()),
              child: Text(
                _currentUser?.initials ?? '?',
                style: const TextStyle(
                  color: Colors.white,
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
                  title: Text('System Settings'),
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
                  _showSystemSettings();
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
              // Welcome Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSizes.lg),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.superAdmin,
                      AppColors.superAdmin.withAlpha((0.8 * 255).toInt()),
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
                          padding: const EdgeInsets.all(AppSizes.md),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha((0.2 * 255).toInt()),
                            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                          ),
                          child: const Icon(
                            Icons.admin_panel_settings,
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
                                'Super Administrator',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Welcome back, ${_currentUser?.name?.split(' ').first ?? 'Admin'}!',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: Colors.white.withAlpha((0.9 * 255).toInt()),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.md),
                    Text(
                      'System-wide management and oversight',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withAlpha((0.8 * 255).toInt()),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSizes.xl),

              // System Statistics
              Text(
                'System Overview',
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
                childAspectRatio: 1.3,
                children: [
                  _buildStatCard(
                    title: 'Institutes',
                    value: '$_totalInstitutes',
                    icon: Icons.business,
                    color: AppColors.primary,
                    subtitle: 'Active organizations',
                    theme: theme,
                  ),
                  _buildStatCard(
                    title: 'Institute Admins',
                    value: '$_totalAdmins',
                    icon: Icons.admin_panel_settings,
                    color: AppColors.info,
                    subtitle: 'Institute administrators',
                    theme: theme,
                  ),
                  _buildStatCard(
                    title: 'Departments',
                    value: '$_totalDepartments',
                    icon: Icons.domain,
                    color: AppColors.warning,
                    subtitle: 'Across all institutes',
                    theme: theme,
                  ),
                  _buildStatCard(
                    title: 'Students',
                    value: '$_totalUsers',
                    icon: Icons.people,
                    color: AppColors.success,
                    subtitle: 'Total registered users',
                    theme: theme,
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
                    title: 'Manage Institutes',
                    subtitle: 'Create & configure',
                    icon: Icons.business,
                    color: AppColors.primary,
                    onTap: _navigateToManageInstitutes,
                    theme: theme,
                  ),
                  _buildActionCard(
                    title: 'System Settings',
                    subtitle: 'Configuration & security',
                    icon: Icons.settings,
                    color: AppColors.info,
                    onTap: _showSystemSettings,
                    theme: theme,
                  ),
                  _buildActionCard(
                    title: 'Analytics',
                    subtitle: 'Reports & insights',
                    icon: Icons.analytics,
                    color: AppColors.success,
                    onTap: () {
                      AppHelpers.showInfoToast('Analytics feature coming soon');
                    },
                    theme: theme,
                  ),
                  _buildActionCard(
                    title: 'System Health',
                    subtitle: 'Monitor & maintain',
                    icon: Icons.health_and_safety,
                    color: AppColors.warning,
                    onTap: () {
                      AppHelpers.showInfoToast('System health monitoring coming soon');
                    },
                    theme: theme,
                  ),
                ],
              ),

              const SizedBox(height: AppSizes.xl),

              // Recent Institutes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Institutes',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_institutes.isNotEmpty)
                    TextButton(
                      onPressed: _navigateToManageInstitutes,
                      child: const Text('Manage All'),
                    ),
                ],
              ),

              const SizedBox(height: AppSizes.md),

              if (_institutes.isEmpty)
                EmptyStateWidget(
                  icon: Icons.business,
                  title: 'No Institutes Yet',
                  subtitle: 'Create your first institute to get started',
                  buttonText: 'Add Institute',
                  onButtonPressed: _navigateToManageInstitutes,
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _institutes.take(5).length, // Show only first 5
                  itemBuilder: (context, index) {
                    final institute = _institutes[index];
                    return _buildInstituteCard(institute, theme);
                  },
                ),

              if (_institutes.length > 5) ...[
                const SizedBox(height: AppSizes.sm),
                Center(
                  child: TextButton(
                    onPressed: _navigateToManageInstitutes,
                    child: Text('View all ${_institutes.length} institutes'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToManageInstitutes,
        icon: const Icon(Icons.add),
        label: const Text('Add Institute'),
        backgroundColor: AppColors.superAdmin,
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
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
                Text(
                  value,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
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

  Widget _buildInstituteCard(InstituteModel institute, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(AppSizes.sm),
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha((0.1 * 255).toInt()),
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          child: const Icon(
            Icons.business,
            color: AppColors.primary,
          ),
        ),
        title: Text(
          institute.name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (institute.address?.isNotEmpty == true)
              Text(
                institute.address!,
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: AppSizes.xs),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.xs,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withAlpha((0.1 * 255).toInt()),
                    borderRadius: BorderRadius.circular(AppSizes.radiusXs),
                  ),
                  child: Text(
                    'Active',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                Icon(
                  Icons.location_on,
                  size: AppSizes.iconXs,
                  color: institute.hasGpsCoordinates 
                      ? AppColors.success 
                      : AppColors.gray400,
                ),
                Text(
                  institute.hasGpsCoordinates ? 'GPS Set' : 'No GPS',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: institute.hasGpsCoordinates 
                        ? AppColors.success 
                        : AppColors.gray500,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _navigateToManageInstitutes(),
      ),
    );
  }
}

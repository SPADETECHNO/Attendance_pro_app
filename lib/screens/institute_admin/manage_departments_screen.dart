import 'package:attendance_pro_app/models/academic_year_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:attendance_pro_app/services/auth_service.dart';
import 'package:attendance_pro_app/services/database_service.dart';
import 'package:attendance_pro_app/widgets/loading_widget.dart';
import 'package:attendance_pro_app/widgets/custom_button.dart';
import 'package:attendance_pro_app/widgets/custom_text_field.dart';
import 'package:attendance_pro_app/utils/constants.dart';
import 'package:attendance_pro_app/utils/helpers.dart';
import 'package:attendance_pro_app/models/user_model.dart';
import 'package:attendance_pro_app/models/department_model.dart';
import 'package:attendance_pro_app/constants/app_constants.dart';

class ManageDepartmentsScreen extends StatefulWidget {
  const ManageDepartmentsScreen({super.key});

  @override
  State createState() => _ManageDepartmentsScreenState();
}

class _ManageDepartmentsScreenState extends State<ManageDepartmentsScreen>
    with SingleTickerProviderStateMixin {
  UserModel? _currentUser;
  List<DepartmentModel> _departments = [];
  List<Map<String, dynamic>> _departmentAdmins = [];
  Map<String, List<Map<String, dynamic>>> _adminsByDepartment = {};
  bool _isLoading = true;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDepartments();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future _loadDepartments() async {
    try {
      final authService = context.read<AuthService>();
      final databaseService = context.read<DatabaseService>();
      final user = await authService.getCurrentUserProfile();
      if (user == null || user.instituteId == null) return;

      final departments =
          await databaseService.getDepartmentsByInstitute(user.instituteId!);
      final admins =
          await databaseService.getDepartmentAdmins(user.instituteId!);

      final Map<String, List<Map<String, dynamic>>> adminsByDept = {};
      for (final admin in admins) {
        final deptId = admin['department_id'] as String?;
        if (deptId != null) {
          adminsByDept.putIfAbsent(deptId, () => []).add(admin);
        }
      }

      setState(() {
        _currentUser = user;
        _departments = departments;
        _departmentAdmins = admins;
        _adminsByDepartment = adminsByDept;
        _isLoading = false;
      });
    } catch (e) {
      AppHelpers.debugError('Load departments error: $e');
      setState(() => _isLoading = false);
    }
  }

  void _showCreateDepartmentDialog() {
    showDialog(
      context: context,
      builder: (context) => CreateDepartmentDialog(
        instituteId: _currentUser!.instituteId!,
        createdBy: _currentUser!.id,
        onCreated: _loadDepartments,
      ),
    );
  }

  void _showCreateAdminDialog([DepartmentModel? selectedDept]) {
    if (_departments.isEmpty) {
      AppHelpers.showWarningToast(
          'Please create at least one department first');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => CreateAdminDialog(
        departments: _departments,
        instituteId: _currentUser!.instituteId!,
        selectedDepartment: selectedDept,
        onCreated: _loadDepartments,
      ),
    );
  }

  void _showEditAdminDialog(Map<String, dynamic> admin) {
    showDialog(
      context: context,
      builder: (context) => EditAdminDialog(
        admin: admin,
        departments: _departments,
        onUpdated: _loadDepartments,
      ),
    );
  }

  // Show all admins for a specific department
  void _showDepartmentAdmins(DepartmentModel department) {
    final admins = _adminsByDepartment[department.id] ?? [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(AppSizes.md),
                decoration: BoxDecoration(
                  color: AppColors.info,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.people, color: Colors.white),
                    const SizedBox(width: AppSizes.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Department Admins',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            department.name,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showCreateAdminDialog(department);
                      },
                      icon: const Icon(Icons.person_add, color: Colors.white),
                      tooltip: 'Add Admin',
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: admins.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.admin_panel_settings_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: AppSizes.md),
                            Text('No Admins Assigned',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(color: Colors.grey)),
                            const SizedBox(height: AppSizes.sm),
                            Text('Add an admin to manage this department',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: Colors.grey)),
                            const SizedBox(height: AppSizes.lg),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _showCreateAdminDialog(department);
                              },
                              icon: const Icon(Icons.person_add),
                              label: const Text('Add Admin'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(AppSizes.md),
                        itemCount: admins.length,
                        itemBuilder: (context, index) {
                          final admin = admins[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: AppSizes.sm),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.admin
                                    .withAlpha((0.1 * 255).toInt()),
                                child: Text(
                                  AppHelpers.getInitials(admin['name'] ?? ''),
                                  style: const TextStyle(
                                    color: AppColors.admin,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                admin['name'] ?? 'Unknown',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(admin['email'] ?? ''),
                                  if (admin['phone'] != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      admin['phone'],
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600]),
                                    ),
                                  ],
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  switch (value) {
                                    case 'details':
                                      _showAdminDetailsDialog(admin);
                                      break;
                                    case 'edit':
                                      Navigator.pop(context);
                                      _showEditAdminDialog(admin);
                                      break;
                                    case 'delete':
                                      _confirmDeleteAdmin(admin);
                                      break;
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'details',
                                    child: ListTile(
                                      leading: Icon(Icons.info),
                                      title: Text('View Details'),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: ListTile(
                                      leading: Icon(Icons.edit),
                                      title: Text('Edit Admin'),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                  const PopupMenuDivider(),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: ListTile(
                                      leading: Icon(Icons.delete,
                                          color: AppColors.error),
                                      title: Text('Remove Admin'),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add New',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppSizes.lg),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'Add Department',
                    onPressed: () {
                      Navigator.pop(context);
                      _showCreateDepartmentDialog();
                    },
                    icon: Icons.domain,
                    isOutlined: true,
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: CustomButton(
                    text: 'Add Admin',
                    onPressed: () {
                      Navigator.pop(context);
                      _showCreateAdminDialog();
                    },
                    icon: Icons.person_add,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteDepartment(DepartmentModel department) async {
    if (!mounted) return;
    final confirmed = await AppHelpers.showConfirmDialog(
      context,
      title: 'Delete Department',
      message:
          'Are you sure you want to delete "${department.name}"? This action cannot be undone.',
      confirmText: 'Delete',
      isDestructive: true,
    );
    if (confirmed && mounted) {
      try {
        final databaseService = context.read<DatabaseService>();
        await databaseService.deleteDepartment(department.id);
        if (mounted) {
          AppHelpers.showSuccessToast('Department deleted successfully');
          _loadDepartments();
        }
      } catch (e) {
        if (mounted) {
          AppHelpers.showErrorToast('Failed to delete department');
        }
      }
    }
  }

  void _confirmDeleteAdmin(Map admin) async {
    if (!mounted) return;
    final confirmed = await AppHelpers.showConfirmDialog(
      context,
      title: 'Remove Admin',
      message:
          'Are you sure you want to remove "${admin['name']}" as department admin? They will lose admin access but their account will remain active.',
      confirmText: 'Remove',
      isDestructive: true,
    );
    if (confirmed && mounted) {
      try {
        final databaseService = context.read<DatabaseService>();
        await databaseService.deleteAdmin(admin['id']);
        if (mounted) {
          AppHelpers.showSuccessToast('Admin removed successfully');
          _loadDepartments();
        }
      } catch (e) {
        if (mounted) {
          AppHelpers.showErrorToast('Failed to remove admin');
        }
      }
    }
  }

  void _showAdminDetailsDialog(Map admin) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(admin['name'] ?? 'Admin Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.email),
              title: Text(admin['email'] ?? ''),
              textColor: AppColors.black,
              contentPadding: EdgeInsets.zero,
            ),
            if (admin['phone'] != null)
              ListTile(
                leading: const Icon(Icons.phone),
                title: Text(admin['phone']),
                textColor: AppColors.black,
                contentPadding: EdgeInsets.zero,
              ),
            ListTile(
              leading: const Icon(Icons.domain),
              title: Text(admin['department_name'] ?? 'No department'),
              textColor: AppColors.black,
              contentPadding: EdgeInsets.zero,
            ),
            ListTile(
              leading: const Icon(Icons.lock),
              title: Text(
                  'Password: temp_${admin['email']?.split('@').first ?? 'admin'}'),
              textColor: AppColors.black,
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
              _confirmDeleteAdmin(admin);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove Admin'),
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
        body: LoadingWidget(message: 'Loading departments...'),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manage Departments'),
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.domain), text: 'Departments'),
              Tab(icon: Icon(Icons.admin_panel_settings), text: 'Admins'),
            ],
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
          ),
          actions: [
            PopupMenuButton(
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'add_department',
                  child: const ListTile(
                    leading: Icon(Icons.add),
                    title: Text('Add Department'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'add_admin',
                  child: const ListTile(
                    leading: Icon(Icons.person_add),
                    title: Text('Add Admin'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
              onSelected: (value) {
                switch (value) {
                  case 'add_department':
                    _showCreateDepartmentDialog();
                    break;
                  case 'add_admin':
                    _showCreateAdminDialog();
                    break;
                }
              },
            ),
          ],
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // Departments Tab
            RefreshIndicator(
              onRefresh: _loadDepartments,
              child: _buildDepartmentsTab(theme),
            ),
            // Admins Tab
            RefreshIndicator(
              onRefresh: _loadDepartments,
              child: _buildAdminsTab(theme),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showAddOptions,
          backgroundColor: theme.colorScheme.primary,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildDepartmentsTab(ThemeData theme) {
    if (_departments.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.domain,
        title: 'No Departments',
        subtitle: 'Create your first department to get started',
        buttonText: 'Add Department',
        onButtonPressed: _showCreateDepartmentDialog,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSizes.md),
      itemCount: _departments.length,
      itemBuilder: (context, index) {
        final department = _departments[index];
        final admins = _adminsByDepartment[department.id] ?? [];
        return Card(
          margin: const EdgeInsets.only(bottom: AppSizes.md),
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSizes.sm),
                      decoration: BoxDecoration(
                        color: AppColors.info.withAlpha((0.1 * 255).toInt()),
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      ),
                      child: const Icon(
                        Icons.domain,
                        color: AppColors.info,
                        size: AppSizes.iconMd,
                      ),
                    ),
                    const SizedBox(width: AppSizes.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            department.name,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (department.hasDescription)
                            Text(
                              department.description!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withAlpha((0.7 * 255).toInt())),
                            ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        switch (value) {
                          case 'view_admins':
                            _showDepartmentAdmins(department);
                            break;
                          case 'assign_admin':
                            _showCreateAdminDialog(department);
                            break;
                          case 'edit':
                            AppHelpers.showInfoToast(
                                'Edit feature coming soon');
                            break;
                          case 'delete':
                            _confirmDeleteDepartment(department);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'view_admins',
                          child: ListTile(
                            leading: Icon(Icons.people),
                            title: Text('View Admins'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'assign_admin',
                          child: ListTile(
                            leading: Icon(Icons.person_add),
                            title: Text('Add Admin'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: ListTile(
                            leading: Icon(Icons.edit),
                            title: Text('Edit'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            leading: Icon(Icons.delete, color: AppColors.error),
                            title: Text('Delete'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.md),
                if (admins.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSizes.sm),
                    decoration: BoxDecoration(
                      color: AppColors.success.withAlpha((0.1 * 255).toInt()),
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${admins.length} Admin${admins.length > 1 ? 's' : ''} assigned',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextButton(
                              onPressed: () =>
                                  _showDepartmentAdmins(department),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: AppSizes.sm),
                                minimumSize: const Size(0, 32),
                              ),
                              child: Text(
                                'View All (${admins.length})',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSizes.xs),
                        ...admins.take(3).map(
                              (admin) => Padding(
                                padding:
                                    const EdgeInsets.only(bottom: AppSizes.xs),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 12,
                                      backgroundColor: AppColors.success
                                          .withAlpha((0.2 * 255).toInt()),
                                      child: Text(
                                        AppHelpers.getInitials(
                                            admin['name'] ?? ''),
                                        style: const TextStyle(
                                          color: AppColors.success,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: AppSizes.xs),
                                    Expanded(
                                      child: Text(
                                        admin['name'] ?? 'Unknown',
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: AppColors.success,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        if (admins.length > 3)
                          Text(
                            'and ${admins.length - 3} more...',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.success
                                  .withAlpha((0.8 * 255).toInt()),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),
                if (admins.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSizes.sm),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withAlpha((0.1 * 255).toInt()),
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber,
                          color: AppColors.warning,
                          size: AppSizes.iconSm,
                        ),
                        const SizedBox(width: AppSizes.sm),
                        Expanded(
                          child: Text(
                            'No admin assigned',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _showCreateAdminDialog(department),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSizes.sm),
                          ),
                          child: const Text('Assign'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAdminsTab(ThemeData theme) {
    if (_departmentAdmins.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.admin_panel_settings,
        title: 'No Admins',
        subtitle: 'Create department admins to manage attendance',
        buttonText: 'Add Admin',
        onButtonPressed: () => _showCreateAdminDialog(),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppSizes.md),
      itemCount: _departmentAdmins.length,
      itemBuilder: (context, index) {
        final admin = _departmentAdmins[index];
        return Card(
          margin: const EdgeInsets.only(bottom: AppSizes.sm),
          color: theme.colorScheme.surface,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.admin.withAlpha((0.1 * 255).toInt()),
              child: Text(
                AppHelpers.getInitials(admin['name'] ?? ''),
                style: const TextStyle(
                  color: AppColors.admin,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              admin['name'] ?? 'Unknown',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  admin['email'] ?? '',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface
                        .withAlpha((0.7 * 255).toInt()),
                  ),
                ),
                if (admin['department_name'] != null) ...[
                  const SizedBox(height: AppSizes.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.xs,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.info.withAlpha((0.1 * 255).toInt()),
                      borderRadius: BorderRadius.circular(AppSizes.radiusXs),
                    ),
                    child: Text(
                      admin['department_name'],
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.info,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'details':
                    _showAdminDetailsDialog(admin);
                    break;
                  case 'edit':
                    _showEditAdminDialog(admin);
                    break;
                  case 'delete':
                    _confirmDeleteAdmin(admin);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'details',
                  child: ListTile(
                    leading: Icon(Icons.info),
                    title: Text('View Details'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit),
                    title: Text('Edit Admin'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete, color: AppColors.error),
                    title: Text('Remove Admin'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

//Dialog starts here.....

class EditAdminDialog extends StatefulWidget {
  final Map<String, dynamic> admin;
  final List<DepartmentModel> departments;
  final VoidCallback onUpdated;

  const EditAdminDialog({
    super.key,
    required this.admin,
    required this.departments,
    required this.onUpdated,
  });

  @override
  State<EditAdminDialog> createState() => _EditAdminDialogState();
}

class _EditAdminDialogState extends State<EditAdminDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  DepartmentModel? _selectedDepartment;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.admin['name'] ?? '';
    _phoneController.text = widget.admin['phone'] ?? '';
    _selectedDepartment = widget.departments.firstWhere(
      (dept) => dept.id == widget.admin['department_id'],
      orElse: () => widget.departments.first,
    );
  }

  Future<void> _updateAdmin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final databaseService = context.read<DatabaseService>();
      await databaseService.updateAdmin(
        adminId: widget.admin['id'],
        name: _nameController.text.trim(),
        departmentId: _selectedDepartment!.id,
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        email: '${widget.admin['email']}',
      );
      AppHelpers.showSuccessToast('Admin updated successfully!');
      Navigator.pop(context);
      widget.onUpdated();
    } catch (e) {
      AppHelpers.showErrorToast('Failed to update admin!');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxHeight: 500),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(AppSizes.md),
              decoration: BoxDecoration(
                color: AppColors.admin,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppSizes.radiusLg),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit, color: Colors.white),
                  const SizedBox(width: AppSizes.sm),
                  const Text(
                    'Edit Admin',
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
            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSizes.md),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      CustomTextField(
                        label: 'Admin Name',
                        controller: _nameController,
                        validator: (value) =>
                            AppHelpers.validateRequired(value, 'Admin name'),
                        prefixIcon: Icons.person,
                      ),
                      const SizedBox(height: AppSizes.md),
                      CustomTextField(
                        label: 'Phone (Optional)',
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        validator: AppHelpers.validatePhone,
                        prefixIcon: Icons.phone,
                      ),
                      const SizedBox(height: AppSizes.md),
                      DropdownButtonFormField<DepartmentModel>(
                        value: _selectedDepartment,
                        decoration: const InputDecoration(
                          labelText: 'Department',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.domain),
                        ),
                        items: widget.departments.map((dept) {
                          return DropdownMenuItem(
                            value: dept,
                            child: Text(dept.name),
                          );
                        }).toList(),
                        onChanged: (dept) =>
                            setState(() => _selectedDepartment = dept),
                        validator: (value) =>
                            value == null ? 'Please select a department' : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Action buttons
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
                      text: 'Update Admin',
                      onPressed: _isLoading ? null : _updateAdmin,
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

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}

class CreateDepartmentDialog extends StatefulWidget {
  final String instituteId;
  final String createdBy;
  final VoidCallback onCreated;

  const CreateDepartmentDialog({
    super.key,
    required this.instituteId,
    required this.createdBy,
    required this.onCreated,
  });

  @override
  State<CreateDepartmentDialog> createState() => _CreateDepartmentDialogState();
}

class _CreateDepartmentDialogState extends State<CreateDepartmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createDepartment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final databaseService = context.read<DatabaseService>();
      await databaseService.createDepartment(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        instituteId: widget.instituteId,
        createdBy: widget.createdBy,
      );

      AppHelpers.showSuccessToast('Department created successfully!');
      Navigator.pop(context);
      widget.onCreated();
    } catch (e) {
      AppHelpers.debugError('Create department error: $e');
      AppHelpers.showErrorToast('Failed to create department');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Department'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomTextField(
              label: 'Department Name',
              hint: 'Enter department name',
              controller: _nameController,
              validator: (value) =>
                  AppHelpers.validateRequired(value, 'Department name'),
              prefixIcon: Icons.domain,
            ),
            const SizedBox(height: AppSizes.md),
            CustomTextField(
              label: 'Description (Optional)',
              hint: 'Enter department description',
              controller: _descriptionController,
              maxLines: 3,
              prefixIcon: Icons.description,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createDepartment,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}

// ✅ Updated Create Admin Dialog with temp password
class CreateAdminDialog extends StatefulWidget {
  final List<DepartmentModel> departments;
  final String instituteId;
  final VoidCallback onCreated;
  final DepartmentModel? selectedDepartment;

  const CreateAdminDialog({
    super.key,
    required this.departments,
    required this.instituteId,
    required this.onCreated,
    this.selectedDepartment,
  });

  @override
  State<CreateAdminDialog> createState() => _CreateAdminDialogState();
}

class _CreateAdminDialogState extends State<CreateAdminDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _userIdController = TextEditingController();
  final _passwordController = TextEditingController();
  DepartmentModel? _selectedDepartment;
  bool _isLoading = false;
  bool _useTempPassword = true;
  bool _obscurePassword = true;
  List<AcademicYearModel> _academicYears = [];
  AcademicYearModel? _selectedAcademicYear;

  @override
  void initState() {
    super.initState();
    _selectedDepartment = widget.selectedDepartment;
    _loadAcademicYears();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _userIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadAcademicYears() async {
    try {
      final databaseService = context.read<DatabaseService>();
      final academicYears = await databaseService.getAcademicYears(widget.instituteId);
      
      setState(() {
        _academicYears = academicYears;
        _selectedAcademicYear = academicYears.isNotEmpty
            ? academicYears.firstWhere((year) => year.isCurrent, orElse: () => academicYears.first)
            : null;
      });
    } catch (e) {
      AppHelpers.debugError('Load academic years for admin error: $e');
    }
  }

  String _getGeneratedPassword() {
    final email = _emailController.text.trim();
    if (email.isEmpty) return 'temp_admin';
    return AppConstants.generateTempPassword(email);
  }

  Future<void> _createAdmin() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDepartment == null) {
      AppHelpers.showWarningToast('Please select a department');
      return;
    }

    if (!_useTempPassword && _passwordController.text.trim().isEmpty) {
      AppHelpers.showWarningToast('Please enter a password');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = context.read<AuthService>();
      final password = _getGeneratedPassword();

      await authService.createUserAccountWithInvitation(
        email: _emailController.text.trim(),
        userId: _userIdController.text.trim(),
        name: _nameController.text.trim(),
        role: AppConstants.adminRole,
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        instituteId: widget.instituteId,
        departmentId: _selectedDepartment!.id,
        academicYearId: _selectedAcademicYear?.id,
      );

      AppHelpers.showSuccessToast('Admin created successfully!');

      // Show password dialog
      _showPasswordDialog(password, _emailController.text.trim());
    } catch (e) {
      AppHelpers.debugError('Create admin error: $e');
      AppHelpers.showErrorToast('Failed to create admin');
      setState(() => _isLoading = false);
    }
  }

  void _showPasswordDialog(String password, String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle,
                color: AppColors.success, size: AppSizes.iconMd),
            const SizedBox(width: AppSizes.sm),
            const Text('Admin Created!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Admin account created successfully.'),
            const SizedBox(height: AppSizes.md),
            const Text('Login Credentials:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSizes.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSizes.md),
              decoration: BoxDecoration(
                color: AppColors.info.withAlpha((0.1 * 255).toInt()),
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Email row with copy button
                  Row(
                    children: [
                      Expanded(child: Text('Email: $email')),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 16),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: email));
                          AppHelpers.showSuccessToast('Email copied!');
                        },
                      ),
                    ],
                  ),
                  // Password row with copy button
                  Row(
                    children: [
                      Expanded(child: Text('Password: $password')),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 16),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: password));
                          AppHelpers.showSuccessToast('Password copied!');
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            Container(
              padding: const EdgeInsets.all(AppSizes.sm),
              decoration: BoxDecoration(
                color: AppColors.warning.withAlpha((0.1 * 255).toInt()),
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              child: const Text(
                '⚠️ IMPORTANT: Copy these credentials exactly as shown. Use the copy buttons to avoid typos.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              setState(() => _isLoading = false);
              widget.onCreated();
            },
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
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
                color: AppColors.admin,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppSizes.radiusLg),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_add,
                    color: Colors.white,
                    size: AppSizes.iconMd,
                  ),
                  const SizedBox(width: AppSizes.sm),
                  const Text(
                    'Create Department Admin',
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
                        label: 'Admin Name',
                        hint: 'Enter admin full name',
                        controller: _nameController,
                        validator: (value) =>
                            AppHelpers.validateRequired(value, 'Admin name'),
                        prefixIcon: Icons.person,
                      ),

                      const SizedBox(height: AppSizes.md),

                      CustomTextField(
                        label: 'User ID',
                        hint: 'Enter unique user ID',
                        controller: _userIdController,
                        validator: AppHelpers.validateUserId,
                        prefixIcon: Icons.badge,
                      ),

                      const SizedBox(height: AppSizes.md),

                      CustomTextField(
                        label: 'Email',
                        hint: 'Enter email address',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: AppHelpers.validateEmail,
                        prefixIcon: Icons.email,
                        onChanged: (_) =>
                            setState(() {}), // Refresh password preview
                      ),

                      const SizedBox(height: AppSizes.md),

                      CustomTextField(
                        label: 'Phone (Optional)',
                        hint: 'Enter phone number',
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        validator: AppHelpers.validatePhone,
                        prefixIcon: Icons.phone,
                      ),

                      const SizedBox(height: AppSizes.md),

                      DropdownButtonFormField<AcademicYearModel>(
                        value: _selectedAcademicYear,
                        decoration: const InputDecoration(
                          labelText: 'Academic Year',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.school),
                        ),
                        items: _academicYears.map((year) {
                          return DropdownMenuItem(
                            value: year,
                            child: Row(
                              children: [
                                Text(year.displayLabel),
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
                        onChanged: (year) => setState(() => _selectedAcademicYear = year),
                        validator: (value) {
                          if (value == null) return 'Please select an academic year';
                          return null;
                        },
                      ),

                      const SizedBox(height: AppSizes.md),

                      DropdownButtonFormField<DepartmentModel>(
                        value: _selectedDepartment,
                        decoration: const InputDecoration(
                          labelText: 'Department',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.domain),
                        ),
                        items: widget.departments.map((dept) {
                          return DropdownMenuItem(
                            value: dept,
                            child: Text(dept.name),
                          );
                        }).toList(),
                        onChanged: (dept) {
                          setState(() => _selectedDepartment = dept);
                        },
                        validator: (value) {
                          if (value == null)
                            return 'Please select a department';
                          return null;
                        },
                      ),

                      const SizedBox(height: AppSizes.lg),

                      // Password Preview
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSizes.md),
                        decoration: BoxDecoration(
                          color: AppColors.info.withAlpha((0.05 * 255).toInt()),
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusMd),
                          border: Border.all(
                            color:
                                AppColors.info.withAlpha((0.2 * 255).toInt()),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Password Settings',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.info,
                                  ),
                            ),
                            const SizedBox(height: AppSizes.sm),

                            // ✅ Checkbox for temp password
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Use temporary password'),
                              subtitle: Text(
                                _useTempPassword
                                    ? 'Admin will be prompted to change password on first login'
                                    : 'Set a custom password for the admin',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              value: _useTempPassword,
                              onChanged: (value) {
                                setState(() {
                                  _useTempPassword = value ?? true;
                                  if (_useTempPassword) {
                                    _passwordController.clear();
                                  }
                                });
                              },
                              controlAffinity: ListTileControlAffinity.leading,
                            ),

                            // ✅ Custom password field (shown when checkbox is unchecked)
                            if (!_useTempPassword) ...[
                              const SizedBox(height: AppSizes.md),
                              CustomTextField(
                                label: 'Custom Password',
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                prefixIcon: Icons.lock,
                                suffixIcon: _obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                onSuffixIconTap: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                                validator: !_useTempPassword
                                    ? AppHelpers.validatePassword
                                    : null,
                                helperText:
                                    'Password must be at least 6 characters long',
                              ),
                            ],

                            // ✅ Show generated temp password preview
                            if (_useTempPassword &&
                                _emailController.text.isNotEmpty) ...[
                              const SizedBox(height: AppSizes.sm),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(AppSizes.sm),
                                decoration: BoxDecoration(
                                  color: AppColors.warning
                                      .withAlpha((0.1 * 255).toInt()),
                                  borderRadius:
                                      BorderRadius.circular(AppSizes.radiusSm),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      size: AppSizes.iconSm,
                                      color: AppColors.warning,
                                    ),
                                    const SizedBox(width: AppSizes.sm),
                                    Expanded(
                                      child: Text(
                                        'Temp password: ${AppConstants.generateTempPassword(_emailController.text)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: AppColors.warning,
                                              fontFamily: 'monospace',
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
                      text: 'Create Admin',
                      onPressed: _isLoading ? null : _createAdmin,
                      isLoading: _isLoading,
                      icon: Icons.person_add,
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

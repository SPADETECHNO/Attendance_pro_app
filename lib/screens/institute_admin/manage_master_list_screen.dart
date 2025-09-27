import 'package:attendance_pro_app/models/academic_year_model.dart';
import 'package:attendance_pro_app/models/department_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attendance_pro_app/services/auth_service.dart';
import 'package:attendance_pro_app/services/database_service.dart';
import 'package:attendance_pro_app/widgets/loading_widget.dart';
import 'package:attendance_pro_app/utils/constants.dart';
import 'package:attendance_pro_app/utils/helpers.dart';
import 'package:attendance_pro_app/models/user_model.dart';
import 'package:attendance_pro_app/models/institute_master_list_model.dart';
import 'package:attendance_pro_app/widgets/custom_text_field.dart';

class ManageMasterListScreen extends StatefulWidget {
  const ManageMasterListScreen({super.key});

  @override
  State<ManageMasterListScreen> createState() => _ManageMasterListScreenState();
}

class _ManageMasterListScreenState extends State<ManageMasterListScreen> {
  UserModel? _currentUser;
  List<InstituteMasterListModel> _masterList = [];
  List<InstituteMasterListModel> _filteredList = [];
  bool _isLoading = true;
  bool _isSearching = false;
  
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'all';

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
    try {
      final authService = context.read<AuthService>();
      final databaseService = context.read<DatabaseService>();
      final user = await authService.getCurrentUserProfile();
      
      if (user?.instituteId != null) {
        final masterList = await databaseService.getInstituteMasterList(user!.instituteId!);

        if (mounted) {
          setState(() {
            _currentUser = user;
            _masterList = masterList;
            _filteredList = masterList;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      AppHelpers.debugError('Load master list error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterList() {
    setState(() {
      _filteredList = _masterList.where((user) {
        final matchesSearch = _searchQuery.isEmpty ||
            user.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            user.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            user.userId.toLowerCase().contains(_searchQuery.toLowerCase());

        final matchesFilter = _selectedFilter == 'all' ||
            (_selectedFilter == 'active' && user.isActive) ||
            (_selectedFilter == 'inactive' && !user.isActive) ||
            (_selectedFilter == 'pending_password' && user.needsPasswordChange);

        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
    });
    _filterList();
  }

  void _onFilterChanged(String value) {
    setState(() {
      _selectedFilter = value;
    });
    _filterList();
  }

  Future<void> _searchByUserId(String userId) async {
    if (userId.trim().isEmpty) {
      setState(() {
        _searchQuery = '';
        _searchController.clear();
      });
      _filterList();
      return;
    }

    setState(() => _isSearching = true);
    try {
      final databaseService = context.read<DatabaseService>();
      final user = await databaseService.searchInstituteMasterListByUserId(
        _currentUser!.instituteId!,
        userId.trim(),
      );

      if (mounted) {
        setState(() => _isSearching = false);
        
        if (user != null) {
          setState(() {
            _filteredList = [user];
            _searchController.text = userId;
            _searchQuery = userId;
          });
        } else {
          AppHelpers.showInfoToast('User ID "$userId" not found in master list');
          setState(() {
            _filteredList = [];
          });
        }
      }
    } catch (e) {
      AppHelpers.debugError('Search by user ID error: $e');
      AppHelpers.showErrorToast('Search failed');
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _showUserDetails(InstituteMasterListModel user) {
    showDialog(
      context: context,
      builder: (context) => _UserDetailsDialog(
        user: user,
        onUpdated: _loadData,
      ),
    );
  }

  void _showAddUserDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddUserDialog(
        instituteId: _currentUser!.instituteId!,
        createdBy: _currentUser!.id,
        onAdded: _loadData,
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: _searchController,
                label: 'Search by name, email, or user ID',
                hint: 'Enter search term...',
                prefixIcon: Icons.search,
                onChanged: _onSearchChanged,
              ),
            ),
            const SizedBox(width: AppSizes.md),
            // Use standard button to avoid constraint issues
            SizedBox(
              width: 140,
              child: OutlinedButton.icon(
                onPressed: _isSearching ? null : () => _showSearchByIdDialog(),
                icon: _isSearching 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.person_search),
                label: const Text('Search by ID'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('All', 'all', _masterList.length),
              const SizedBox(width: AppSizes.sm),
              _buildFilterChip('Active', 'active', _masterList.where((u) => u.isActive).length),
              const SizedBox(width: AppSizes.sm),
              _buildFilterChip('Inactive', 'inactive', _masterList.where((u) => !u.isActive).length),
              const SizedBox(width: AppSizes.sm),
              _buildFilterChip('Password Pending', 'pending_password', _masterList.where((u) => u.needsPasswordChange).length),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value, int count) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) _onFilterChanged(value);
      },
      backgroundColor: Colors.transparent,
      selectedColor: AppColors.primary.withAlpha((0.2 * 255).toInt()),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : null,
        fontWeight: isSelected ? FontWeight.bold : null,
      ),
    );
  }

  void _showSearchByIdDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search by User ID'),
        content: CustomTextField(
          controller: controller,
          label: 'User ID',
          hint: 'Enter exact user ID',
          prefixIcon: Icons.badge,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _searchByUserId(controller.text);
            },
            child: const Text('Search'),
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
        body: LoadingWidget(message: 'Loading master list...'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Institute Master List'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSizes.md),
              child: _buildSearchAndFilters(),
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Showing ${_filteredList.length} of ${_masterList.length} users',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha((0.7 * 255).toInt()),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty || _selectedFilter != 'all')
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                          _selectedFilter = 'all';
                          _searchController.clear();
                        });
                        _filterList();
                      },
                      child: const Text('Clear Filters'),
                    ),
                ],
              ),
            ),
            
            Expanded(
              child: _filteredList.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(AppSizes.md),
                      itemCount: _filteredList.length,
                      itemBuilder: (context, index) {
                        final user = _filteredList[index];
                        return _buildUserCard(user, theme);
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddUserDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add User'),
        backgroundColor: theme.colorScheme.primary,
      ),
    );
  }

  Widget _buildEmptyState() {
    if (_searchQuery.isNotEmpty || _selectedFilter != 'all') {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: AppSizes.md),
            Text(
              'No users found matching your criteria',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            Text(
              'Try adjusting your search or filters',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: AppSizes.md),
          Text(
            'No users in master list yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          Text(
            'Upload a CSV file or add users manually',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(InstituteMasterListModel user, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: user.isActive 
              ? AppColors.success.withAlpha((0.1 * 255).toInt())
              : AppColors.warning.withAlpha((0.1 * 255).toInt()),
          child: Text(
            user.initials,
            style: TextStyle(
              color: user.isActive ? AppColors.success : AppColors.warning,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          user.name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ID: ${user.userId} • ${user.email}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: user.isActive
                        ? AppColors.success.withAlpha((0.1 * 255).toInt())
                        : AppColors.warning.withAlpha((0.1 * 255).toInt()),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    user.isActive ? 'Active' : 'Inactive',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: user.isActive ? AppColors.success : AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (user.needsPasswordChange) ...[
                  const SizedBox(width: AppSizes.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.info.withAlpha((0.1 * 255).toInt()),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Password Pending',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.info,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                if (user.departmentId != null) ...[
                  const SizedBox(width: AppSizes.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha((0.1 * 255).toInt()),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      user.displayDepartment,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showUserDetails(user),
      ),
    );
  }
}

class _UserDetailsDialog extends StatefulWidget {
  final InstituteMasterListModel user;
  final VoidCallback onUpdated;

  const _UserDetailsDialog({
    required this.user,
    required this.onUpdated,
  });

  @override
  State<_UserDetailsDialog> createState() => _UserDetailsDialogState();
}

class _UserDetailsDialogState extends State<_UserDetailsDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _departmentController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.user.name;
    _emailController.text = widget.user.email;
    _phoneController.text = widget.user.phone ?? '';
    _departmentController.text = widget.user.departmentId ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  Future<void> _updateUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final databaseService = context.read<DatabaseService>();
      await databaseService.updateInstituteMasterListUser(
        id: widget.user.id,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        departmentId: _departmentController.text.trim().isEmpty ? null : _departmentController.text.trim(),
      );

      AppHelpers.showSuccessToast('User updated successfully');
      if (mounted) {
        Navigator.pop(context);
        widget.onUpdated();
      }
    } catch (e) {
      AppHelpers.debugError('Update user error: $e');
      AppHelpers.showErrorToast('Failed to update user');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteUser() async {
    final confirmed = await AppHelpers.showConfirmDialog(
      context,
      title: 'Delete User',
      message: 'Are you sure you want to remove ${widget.user.name} from the master list? This action cannot be undone.',
    );

    if (!confirmed) return;

    setState(() => _isLoading = true);
    try {
      final databaseService = context.read<DatabaseService>();
      await databaseService.deleteFromInstituteMasterList(widget.user.id);

      AppHelpers.showSuccessToast('User removed from master list');
      if (mounted) {
        Navigator.pop(context);
        widget.onUpdated();
      }
    } catch (e) {
      AppHelpers.debugError('Delete user error: $e');
      AppHelpers.showErrorToast('Failed to remove user');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSizes.md),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppSizes.radiusLg),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white.withAlpha((0.2 * 255).toInt()),
                    child: Text(
                      widget.user.initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.user.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'ID: ${widget.user.userId}',
                          style: TextStyle(
                            color: Colors.white.withAlpha((0.9 * 255).toInt()),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                        label: 'Name',
                        controller: _nameController,
                        validator: (value) => AppHelpers.validateRequired(value, 'Name'),
                        prefixIcon: Icons.person,
                      ),
                      const SizedBox(height: AppSizes.lg),
                      CustomTextField(
                        label: 'Email',
                        controller: _emailController,
                        validator: AppHelpers.validateEmail,
                        prefixIcon: Icons.email,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: AppSizes.lg),
                      CustomTextField(
                        label: 'Phone',
                        controller: _phoneController,
                        validator: AppHelpers.validatePhone,
                        prefixIcon: Icons.phone,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: AppSizes.lg),
                      CustomTextField(
                        label: 'Department (Optional)',
                        controller: _departmentController,
                        prefixIcon: Icons.domain,
                        helperText: 'For organizational purposes only',
                      ),
                      const SizedBox(height: AppSizes.lg),

                      Container(
                        padding: const EdgeInsets.all(AppSizes.md),
                        decoration: BoxDecoration(
                          color: Colors.grey.withAlpha((0.1 * 255).toInt()),
                          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Account Information',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: AppSizes.sm),
                            Row(
                              children: [
                                Icon(
                                  widget.user.isActive ? Icons.check_circle : Icons.cancel,
                                  color: widget.user.isActive ? AppColors.success : AppColors.warning,
                                  size: 16,
                                ),
                                const SizedBox(width: AppSizes.xs),
                                Text(
                                  'Status: ${widget.user.isActive ? 'Active' : 'Inactive'}',
                                  style: TextStyle(
                                    color: widget.user.isActive ? AppColors.success : AppColors.warning,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSizes.xs),
                            Row(
                              children: [
                                Icon(
                                  widget.user.needsPasswordChange ? Icons.lock_clock : Icons.lock,
                                  color: widget.user.needsPasswordChange ? AppColors.info : AppColors.success,
                                  size: 16,
                                ),
                                const SizedBox(width: AppSizes.xs),
                                Text(
                                  'Password: ${widget.user.needsPasswordChange ? 'Pending Change' : 'Set'}',
                                  style: TextStyle(
                                    color: widget.user.needsPasswordChange ? AppColors.info : AppColors.success,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSizes.xs),
                            Text(
                              'Added: ${AppHelpers.formatDate(widget.user.createdAt)}',
                              style: Theme.of(context).textTheme.bodySmall,
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
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _deleteUser,
                      icon: const Icon(Icons.delete),
                      label: const Text('Delete'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _updateUser,
                      icon: _isLoading 
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save),
                      label: const Text('Update User'),
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

class _AddUserDialog extends StatefulWidget {
  final String instituteId;
  final String createdBy;
  final VoidCallback onAdded;

  const _AddUserDialog({
    required this.instituteId,
    required this.createdBy,
    required this.onAdded,
  });

  @override
  State<_AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<_AddUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _userIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  
  // OPTIONAL fields - can be null
  String? _selectedDepartmentId;
  String? _selectedAcademicYearId;
  List<DepartmentModel> _departments = [];
  List<AcademicYearModel> _academicYears = [];
  
  bool _isLoading = false;
  bool _isLoadingData = true;
  bool _sendEmailInvitation = true;

  @override
  void initState() {
    super.initState();
    _loadDropdownData();
  }

  Future<void> _loadDropdownData() async {
    try {
      final databaseService = context.read<DatabaseService>();
      final departments = await databaseService.getDepartmentsByInstitute(widget.instituteId);
      final academicYears = await databaseService.getAcademicYears(widget.instituteId);
      
      if (mounted) {
        setState(() {
          _departments = departments;
          _academicYears = academicYears;
          _isLoadingData = false;
        });
      }
    } catch (e) {
      AppHelpers.debugError('Load dropdown data error: $e');
      if (mounted) {
        setState(() => _isLoadingData = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return const Dialog(
        child: SizedBox(height: 200, child: LoadingWidget(message: 'Loading data...')),
      );
    }

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
                color: AppColors.success,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSizes.radiusLg)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_add, color: Colors.white, size: AppSizes.iconMd),
                  const SizedBox(width: AppSizes.sm),
                  const Expanded(
                    child: Text(
                      'Add User to Institute',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
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
                      // Info Card
                      Container(
                        padding: const EdgeInsets.all(AppSizes.md),
                        decoration: BoxDecoration(
                          color: AppColors.info.withAlpha((0.1 * 255).toInt()),
                          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                          border: Border.all(color: AppColors.info.withAlpha((0.3 * 255).toInt())),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info, color: AppColors.info, size: AppSizes.iconSm),
                            const SizedBox(width: AppSizes.sm),
                            Expanded(
                              child: Text(
                                'Users are added to the institute pool. Department assignment is optional and can be done later.',
                                style: TextStyle(color: AppColors.info, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSizes.lg),

                      // Required Fields
                      CustomTextField(
                        label: 'User ID',
                        controller: _userIdController,
                        validator: (value) => AppHelpers.validateRequired(value, 'User ID'),
                        prefixIcon: Icons.badge,
                        helperText: 'Unique identifier for the user',
                      ),
                      const SizedBox(height: AppSizes.lg),
                      
                      CustomTextField(
                        label: 'Name',
                        controller: _nameController,
                        validator: (value) => AppHelpers.validateRequired(value, 'Name'),
                        prefixIcon: Icons.person,
                      ),
                      const SizedBox(height: AppSizes.lg),
                      
                      CustomTextField(
                        label: 'Email',
                        controller: _emailController,
                        validator: AppHelpers.validateEmail,
                        prefixIcon: Icons.email,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: AppSizes.lg),
                      
                      CustomTextField(
                        label: 'Phone (Optional)',
                        controller: _phoneController,
                        prefixIcon: Icons.phone,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: AppSizes.lg),

                      // Optional Organization Fields
                      Text(
                        'Optional Organization Details',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        'These can be assigned later or left empty',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: AppSizes.md),

                      // Department Dropdown (Optional)
                      DropdownButtonFormField<String>(
                        value: _selectedDepartmentId,
                        decoration: const InputDecoration(
                          labelText: 'Department (Optional)',
                          hintText: 'Select Department or Leave Empty',
                          prefixIcon: Icon(Icons.domain),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('No Department Assigned'),
                          ),
                          ..._departments.map((dept) => DropdownMenuItem<String>(
                            value: dept.id,
                            child: Text(dept.name),
                          )),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedDepartmentId = value);
                        },
                      ),
                      const SizedBox(height: AppSizes.lg),

                      // Academic Year Dropdown (Optional)
                      DropdownButtonFormField<String>(
                        value: _selectedAcademicYearId,
                        decoration: const InputDecoration(
                          labelText: 'Academic Year (Optional)',
                          hintText: 'Select Academic Year or Leave Empty',
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('No Academic Year Assigned'),
                          ),
                          ..._academicYears.map((year) => DropdownMenuItem<String>(
                            value: year.id,
                            child: Text(year.yearLabel),
                          )),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedAcademicYearId = value);
                        },
                      ),
                      const SizedBox(height: AppSizes.xl),

                      // Email invitation toggle
                      Container(
                        padding: const EdgeInsets.all(AppSizes.md),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha((0.05 * 255).toInt()),
                          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Send Email Invitation',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: AppSizes.xs),
                                  Text(
                                    _sendEmailInvitation
                                        ? 'User will receive login credentials via email'
                                        : 'You will share credentials manually',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: _sendEmailInvitation,
                              onChanged: (value) {
                                setState(() => _sendEmailInvitation = value);
                              },
                              activeColor: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Action Buttons
            Container(
              padding: const EdgeInsets.all(AppSizes.md),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _addUser,
                      icon: _isLoading
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.add),
                      label: const Text('Add to Institute'),
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

  Future<void> _addUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final databaseService = context.read<DatabaseService>();
      await databaseService.addToInstituteMasterList(
        userId: _userIdController.text.trim(),
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        instituteId: widget.instituteId,
        departmentId: _selectedDepartmentId, // Can be null
        academicYearId: _selectedAcademicYearId, // Can be null
        createdBy: widget.createdBy,
        sendEmailInvitation: _sendEmailInvitation,
      );

      AppHelpers.showSuccessToast('User added to institute successfully');
      if (mounted) {
        Navigator.pop(context);
        widget.onAdded();
      }
    } catch (e) {
      AppHelpers.debugError('Add user error: $e');
      AppHelpers.showErrorToast('Failed to add user: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _userIdController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
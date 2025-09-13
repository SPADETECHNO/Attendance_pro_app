import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attendance_pro_app/services/auth_service.dart';
import 'package:attendance_pro_app/services/database_service.dart';
import 'package:attendance_pro_app/widgets/loading_widget.dart';
import 'package:attendance_pro_app/widgets/custom_button.dart';
import 'package:attendance_pro_app/widgets/custom_text_field.dart';
import 'package:attendance_pro_app/utils/constants.dart';
import 'package:attendance_pro_app/utils/helpers.dart';
import 'package:attendance_pro_app/models/user_model.dart';
import 'package:attendance_pro_app/models/institute_model.dart';
import 'package:attendance_pro_app/constants/app_constants.dart';

class ManageInstitutesScreen extends StatefulWidget {
  const ManageInstitutesScreen({super.key});

  @override
  State<ManageInstitutesScreen> createState() => _ManageInstitutesScreenState();
}

class _ManageInstitutesScreenState extends State<ManageInstitutesScreen> {
  UserModel? _currentUser;
  List<InstituteModel> _institutes = [];
  List<InstituteModel> _filteredInstitutes = [];
  Map<String, List<Map<String, dynamic>>> _instituteAdmins = {};
  final TextEditingController _searchController = TextEditingController();
  
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadInstitutes();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filteredInstitutes = _institutes.where((institute) {
        return institute.name.toLowerCase().contains(_searchQuery) ||
               (institute.address?.toLowerCase().contains(_searchQuery) ?? false);
      }).toList();
    });
  }

  Future<void> _loadInstitutes() async {
    try {
      final authService = context.read<AuthService>();
      final databaseService = context.read<DatabaseService>();

      // Get current user
      final user = await authService.getCurrentUserProfile();
      if (user == null) return;

      // Get all institutes
      final institutes = await databaseService.getInstitutes();

      // Get admins for each institute
      final Map<String, List<Map<String, dynamic>>> adminsMap = {};
      for (final institute in institutes) {
        final admins = await databaseService.getInstituteAdmins(institute.id);
        adminsMap[institute.id] = admins;
      }

      setState(() {
        _currentUser = user;
        _institutes = institutes;
        _filteredInstitutes = institutes;
        _instituteAdmins = adminsMap;
        _isLoading = false;
      });
    } catch (e) {
      AppHelpers.debugError('Load institutes error: $e');
      setState(() => _isLoading = false);
    }
  }

  void _showCreateInstituteDialog() {
    showDialog(
      context: context,
      builder: (context) => CreateInstituteDialog(
        onCreated: _loadInstitutes,
      ),
    );
  }

  void _showEditInstituteDialog(InstituteModel institute) {
    showDialog(
      context: context,
      builder: (context) => EditInstituteDialog(
        institute: institute,
        onUpdated: _loadInstitutes,
      ),
    );
  }

  void _showAddAdminDialog(InstituteModel institute) {
    showDialog(
      context: context,
      builder: (context) => AddInstituteAdminDialog(
        institute: institute,
        onAdded: _loadInstitutes,
      ),
    );
  }

  void _showInstituteDetails(InstituteModel institute) {
    final admins = _instituteAdmins[institute.id] ?? [];
    
    showDialog(
      context: context,
      builder: (context) => InstituteDetailsDialog(
        institute: institute,
        admins: admins,
        onAddAdmin: () {
          Navigator.pop(context);
          _showAddAdminDialog(institute);
        },
        onEdit: () {
          Navigator.pop(context);
          _showEditInstituteDialog(institute);
        },
      ),
    );
  }

  Future<void> _confirmDeleteInstitute(InstituteModel institute) async {
    final confirmed = await AppHelpers.showConfirmDialog(
      context,
      title: 'Delete Institute',
      message: 'Are you sure you want to delete "${institute.name}"? '
               'This will permanently delete all associated data including departments, '
               'users, and sessions. This action cannot be undone.',
      confirmText: 'Delete Permanently',
      isDestructive: true,
    );

    if (confirmed) {
      try {
        final databaseService = context.read<DatabaseService>();
        await databaseService.deleteInstitute(institute.id);
        AppHelpers.showSuccessToast('Institute deleted successfully');
        _loadInstitutes();
      } catch (e) {
        AppHelpers.showErrorToast('Failed to delete institute');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(
        body: LoadingWidget(message: 'Loading institutes...'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Institutes'),
        backgroundColor: AppColors.superAdmin,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _showCreateInstituteDialog,
            icon: const Icon(Icons.add),
            tooltip: 'Add Institute',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(AppSizes.md),
            color: theme.colorScheme.surfaceContainerHighest.withAlpha((0.5 * 255).toInt()),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search institutes...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchController.clear();
                              },
                              icon: const Icon(Icons.clear),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.sm,
                    vertical: AppSizes.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.info.withAlpha((0.1 * 255).toInt()),
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                  child: Text(
                    '${_filteredInstitutes.length} institutes',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.info,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Institutes List
          Expanded(
            child: _filteredInstitutes.isEmpty
                ? _searchQuery.isNotEmpty
                    ? EmptyStateWidget(
                        icon: Icons.search_off,
                        title: 'No Results Found',
                        subtitle: 'No institutes match your search criteria',
                        buttonText: 'Clear Search',
                        onButtonPressed: () => _searchController.clear(),
                      )
                    : EmptyStateWidget(
                        icon: Icons.business,
                        title: 'No Institutes Yet',
                        subtitle: 'Create your first institute to get started',
                        buttonText: 'Add Institute',
                        onButtonPressed: _showCreateInstituteDialog,
                      )
                : RefreshIndicator(
                    onRefresh: _loadInstitutes,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(AppSizes.md),
                      itemCount: _filteredInstitutes.length,
                      itemBuilder: (context, index) {
                        final institute = _filteredInstitutes[index];
                        final admins = _instituteAdmins[institute.id] ?? [];
                        return _buildInstituteCard(institute, admins, theme);
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateInstituteDialog,
        backgroundColor: AppColors.superAdmin,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildInstituteCard(
    InstituteModel institute, 
    List<Map<String, dynamic>> admins, 
    ThemeData theme
  ) {
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
                    color: AppColors.primary.withAlpha((0.1 * 255).toInt()),
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                  child: const Icon(
                    Icons.business,
                    color: AppColors.primary,
                    size: AppSizes.iconMd,
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        institute.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (institute.address?.isNotEmpty == true)
                        Text(
                          institute.address!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withAlpha((0.7 * 255).toInt()),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  itemBuilder: (context) => <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'details',
                      child: const ListTile(
                        leading: Icon(Icons.info),
                        title: Text('View Details'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'add_admin',
                      child: const ListTile(
                        leading: Icon(Icons.person_add),
                        title: Text('Add Admin'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'edit',
                      child: const ListTile(
                        leading: Icon(Icons.edit),
                        title: Text('Edit'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: const ListTile(
                        leading: Icon(Icons.delete, color: AppColors.error),
                        title: Text('Delete'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    switch (value) {
                      case 'details':
                        _showInstituteDetails(institute);
                        break;
                      case 'add_admin':
                        _showAddAdminDialog(institute);
                        break;
                      case 'edit':
                        _showEditInstituteDialog(institute);
                        break;
                      case 'delete':
                        _confirmDeleteInstitute(institute);
                        break;
                    }
                  },
                ),
              ],
            ),
            
            const SizedBox(height: AppSizes.md),
            
            // Institute Info Row
            Row(
              children: [
                if (institute.phone?.isNotEmpty == true) ...[
                  Icon(
                    Icons.phone,
                    size: AppSizes.iconXs,
                    color: theme.colorScheme.onSurface.withAlpha((0.6 * 255).toInt()),
                  ),
                  const SizedBox(width: AppSizes.xs),
                  Text(
                    institute.phone!,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(width: AppSizes.md),
                ],
                Icon(
                  Icons.location_on,
                  size: AppSizes.iconXs,
                  color: institute.hasGpsCoordinates 
                      ? AppColors.success 
                      : AppColors.gray400,
                ),
                const SizedBox(width: AppSizes.xs),
                Text(
                  institute.hasGpsCoordinates 
                      ? 'GPS Set'
                      : 'GPS Not Set',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: institute.hasGpsCoordinates 
                        ? AppColors.success 
                        : AppColors.gray500,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: AppSizes.md),
            
            // Admins Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSizes.sm),
              decoration: BoxDecoration(
                color: admins.isNotEmpty 
                    ? AppColors.success.withAlpha((0.05 * 255).toInt())
                    : AppColors.warning.withAlpha((0.05 * 255).toInt()),
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                border: Border.all(
                  color: admins.isNotEmpty 
                      ? AppColors.success.withAlpha((0.2 * 255).toInt())
                      : AppColors.warning.withAlpha((0.2 * 255).toInt()),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    admins.isNotEmpty ? Icons.people : Icons.person_add,
                    size: AppSizes.iconSm,
                    color: admins.isNotEmpty ? AppColors.success : AppColors.warning,
                  ),
                  const SizedBox(width: AppSizes.sm),
                  Expanded(
                    child: Text(
                      admins.isNotEmpty 
                          ? '${admins.length} Admin${admins.length > 1 ? 's' : ''}: ${admins.map((a) => a['name']).join(', ')}'
                          : 'No admins assigned',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: admins.isNotEmpty ? AppColors.success : AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () => _showAddAdminDialog(institute),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm),
                    ),
                    child: Text(admins.isEmpty ? 'Add Admin' : 'Add More'),
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

// Create Institute Dialog (Basic info only)
class CreateInstituteDialog extends StatefulWidget {
  final VoidCallback onCreated;

  const CreateInstituteDialog({
    super.key,
    required this.onCreated,
  });

  @override
  State<CreateInstituteDialog> createState() => _CreateInstituteDialogState();
}

class _CreateInstituteDialogState extends State<CreateInstituteDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _radiusController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _radiusController.text = AppConstants.defaultRadius.toString();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _createInstitute() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final databaseService = context.read<DatabaseService>();
      
      await databaseService.createInstitute(
        name: _nameController.text.trim(),
        address: _addressController.text.trim().isEmpty 
            ? null 
            : _addressController.text.trim(),
        phone: _phoneController.text.trim().isEmpty 
            ? null 
            : _phoneController.text.trim(),
        allowedRadius: int.parse(_radiusController.text),
      );

      AppHelpers.showSuccessToast('Institute created successfully!');
      Navigator.pop(context);
      widget.onCreated();
    } catch (e) {
      AppHelpers.debugError('Create institute error: $e');
      AppHelpers.showErrorToast('Failed to create institute');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(AppSizes.md),
              decoration: BoxDecoration(
                color: AppColors.superAdmin,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppSizes.radiusLg),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.business,
                    color: Colors.white,
                    size: AppSizes.iconMd,
                  ),
                  const SizedBox(width: AppSizes.sm),
                  const Text(
                    'Create New Institute',
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
                        hint: 'Enter institute name',
                        controller: _nameController,
                        validator: (value) => AppHelpers.validateRequired(value, 'Institute name'),
                        prefixIcon: Icons.business,
                      ),

                      const SizedBox(height: AppSizes.lg),

                      CustomTextField(
                        label: 'Address (Optional)',
                        hint: 'Enter institute address',
                        controller: _addressController,
                        maxLines: 2,
                        prefixIcon: Icons.location_on,
                      ),

                      const SizedBox(height: AppSizes.lg),

                      CustomTextField(
                        label: 'Phone (Optional)',
                        hint: 'Enter institute phone',
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        validator: AppHelpers.validatePhone,
                        prefixIcon: Icons.phone,
                      ),

                      const SizedBox(height: AppSizes.lg),

                      CustomTextField(
                        label: 'Default GPS Radius (meters)',
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
                      ),

                      const SizedBox(height: AppSizes.md),

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
                                'GPS coordinates will be set by institute admin later. '
                                'You can add institute admins after creating the institute.',
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
                      text: 'Create Institute',
                      onPressed: _isLoading ? null : _createInstitute,
                      isLoading: _isLoading,
                      icon: Icons.business,
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

// Edit Institute Dialog
class EditInstituteDialog extends StatefulWidget {
  final InstituteModel institute;
  final VoidCallback onUpdated;

  const EditInstituteDialog({
    super.key,
    required this.institute,
    required this.onUpdated,
  });

  @override
  State<EditInstituteDialog> createState() => _EditInstituteDialogState();
}

class _EditInstituteDialogState extends State<EditInstituteDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _radiusController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.institute.name;
    _addressController.text = widget.institute.address ?? '';
    _phoneController.text = widget.institute.phone ?? '';
    _radiusController.text = widget.institute.allowedRadius.toString();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _updateInstitute() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final databaseService = context.read<DatabaseService>();
      
      await databaseService.updateInstitute(
        id: widget.institute.id,
        name: _nameController.text.trim(),
        address: _addressController.text.trim().isEmpty 
            ? null 
            : _addressController.text.trim(),
        phone: _phoneController.text.trim().isEmpty 
            ? null 
            : _phoneController.text.trim(),
        allowedRadius: int.parse(_radiusController.text),
      );

      AppHelpers.showSuccessToast('Institute updated successfully!');
      Navigator.pop(context);
      widget.onUpdated();
    } catch (e) {
      AppHelpers.debugError('Update institute error: $e');
      AppHelpers.showErrorToast('Failed to update institute');
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
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(AppSizes.md),
              decoration: BoxDecoration(
                color: AppColors.superAdmin,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppSizes.radiusLg),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.edit,
                    color: Colors.white,
                    size: AppSizes.iconMd,
                  ),
                  const SizedBox(width: AppSizes.sm),
                  const Text(
                    'Edit Institute',
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
                        hint: 'Enter institute name',
                        controller: _nameController,
                        validator: (value) => AppHelpers.validateRequired(value, 'Institute name'),
                        prefixIcon: Icons.business,
                      ),

                      const SizedBox(height: AppSizes.lg),

                      CustomTextField(
                        label: 'Address (Optional)',
                        hint: 'Enter institute address',
                        controller: _addressController,
                        maxLines: 2,
                        prefixIcon: Icons.location_on,
                      ),

                      const SizedBox(height: AppSizes.lg),

                      CustomTextField(
                        label: 'Phone (Optional)',
                        hint: 'Enter institute phone',
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
                      ),

                      if (widget.institute.hasGpsCoordinates) ...[
                        const SizedBox(height: AppSizes.md),
                        Container(
                          padding: const EdgeInsets.all(AppSizes.sm),
                          decoration: BoxDecoration(
                            color: AppColors.success.withAlpha((0.1 * 255).toInt()),
                            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                color: AppColors.success,
                                size: AppSizes.iconSm,
                              ),
                              const SizedBox(width: AppSizes.sm),
                              Expanded(
                                child: Text(
                                  'GPS: ${widget.institute.coordinates}',
                                  style: TextStyle(
                                    color: AppColors.success,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
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
                      text: 'Update Institute',
                      onPressed: _isLoading ? null : _updateInstitute,
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

// Add Institute Admin Dialog
class AddInstituteAdminDialog extends StatefulWidget {
  final InstituteModel institute;
  final VoidCallback onAdded;

  const AddInstituteAdminDialog({
    super.key,
    required this.institute,
    required this.onAdded,
  });

  @override
  State<AddInstituteAdminDialog> createState() => _AddInstituteAdminDialogState();
}

class _AddInstituteAdminDialogState extends State<AddInstituteAdminDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _createAdmin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = context.read<AuthService>();
      await authService.createInstituteAdmin(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty 
            ? null 
            : _phoneController.text.trim(),
        instituteId: widget.institute.id,
      );

      AppHelpers.showSuccessToast('Institute admin created successfully!');
      Navigator.pop(context);
      widget.onAdded();
    } catch (e) {
      AppHelpers.debugError('Create institute admin error: $e');
      AppHelpers.showErrorToast('Failed to create admin: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(AppSizes.md),
              decoration: BoxDecoration(
                color: AppColors.superAdmin,
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add Institute Admin',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.institute.name,
                          style: const TextStyle(
                            color: Colors.white70,
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
                        validator: (value) => AppHelpers.validateRequired(value, 'Admin name'),
                        prefixIcon: Icons.person,
                      ),

                      const SizedBox(height: AppSizes.lg),

                      CustomTextField(
                        label: 'Email',
                        hint: 'Enter email address',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: AppHelpers.validateEmail,
                        prefixIcon: Icons.email,
                      ),

                      const SizedBox(height: AppSizes.lg),

                      CustomTextField(
                        label: 'Password',
                        hint: 'Enter secure password',
                        controller: _passwordController,
                        obscureText: true,
                        validator: (value) {
                          if (value?.isEmpty == true) return 'Password is required';
                          if (value!.length < 6) return 'Password must be at least 6 characters';
                          return null;
                        },
                        prefixIcon: Icons.lock,
                      ),

                      const SizedBox(height: AppSizes.lg),

                      CustomTextField(
                        label: 'Phone (Optional)',
                        hint: 'Enter phone number',
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        validator: AppHelpers.validatePhone,
                        prefixIcon: Icons.phone,
                      ),

                      const SizedBox(height: AppSizes.md),

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
                                'The admin will use these credentials to login. '
                                'They can set GPS location and manage their institute.',
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

// Institute Details Dialog
class InstituteDetailsDialog extends StatelessWidget {
  final InstituteModel institute;
  final List<Map<String, dynamic>> admins;
  final VoidCallback onAddAdmin;
  final VoidCallback onEdit;

  const InstituteDetailsDialog({
    super.key,
    required this.institute,
    required this.admins,
    required this.onAddAdmin,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          children: [
            // Header
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
                  const Icon(
                    Icons.business,
                    color: Colors.white,
                    size: AppSizes.iconMd,
                  ),
                  const SizedBox(width: AppSizes.sm),
                  Expanded(
                    child: Text(
                      institute.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSizes.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Institute Details
                    _buildDetailRow('Address', institute.displayAddress, Icons.location_on),
                    _buildDetailRow('Phone', institute.displayPhone, Icons.phone),
                    _buildDetailRow('GPS Location', institute.coordinates, Icons.gps_fixed),
                    _buildDetailRow(
                      'Attendance Radius',
                      institute.radiusDisplayText,
                      Icons.radar,
                    ),
                    _buildDetailRow(
                      'Created',
                      AppHelpers.formatDateTime(institute.createdAt),
                      Icons.schedule,
                    ),

                    const SizedBox(height: AppSizes.xl),

                    // Admins Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Institute Admins',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: onAddAdmin,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Admin'),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSizes.sm),

                    if (admins.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSizes.md),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withAlpha((0.1 * 255).toInt()),
                          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                          border: Border.all(
                            color: AppColors.warning.withAlpha((0.3 * 255).toInt()),
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.person_add,
                              color: AppColors.warning,
                              size: AppSizes.iconMd,
                            ),
                            const SizedBox(height: AppSizes.sm),
                            Text(
                              'No admins assigned yet',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: AppColors.warning,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Add admins to manage this institute',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.warning,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: admins.length,
                        itemBuilder: (context, index) {
                          final admin = admins[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: AppSizes.sm),
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
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                admin['email'] ?? '',
                                style: theme.textTheme.bodySmall,
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
                        },
                      ),
                  ],
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
                      text: 'Edit Institute',
                      onPressed: onEdit,
                      icon: Icons.edit,
                      isOutlined: true,
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: CustomButton(
                      text: 'Close',
                      onPressed: () => Navigator.pop(context),
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

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: AppSizes.iconSm,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: AppColors.gray600,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

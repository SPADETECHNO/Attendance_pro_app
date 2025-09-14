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
import 'package:attendance_pro_app/models/academic_year_model.dart';

class ManageAcademicYearsScreen extends StatefulWidget {
  const ManageAcademicYearsScreen({super.key});

  @override
  State<ManageAcademicYearsScreen> createState() => _ManageAcademicYearsScreenState();
}

class _ManageAcademicYearsScreenState extends State<ManageAcademicYearsScreen> {
  UserModel? _currentUser;
  List<AcademicYearModel> _academicYears = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAcademicYears();
  }

  Future<void> _loadAcademicYears() async {
    try {
      final authService = context.read<AuthService>();
      final databaseService = context.read<DatabaseService>();
      
      final user = await authService.getCurrentUserProfile();
      if (user == null || user.instituteId == null) return;

      final academicYears = await databaseService.getAcademicYears(user.instituteId!);

      setState(() {
        _currentUser = user;
        _academicYears = academicYears;
        _isLoading = false;
      });
    } catch (e) {
      AppHelpers.debugError('Load academic years error: $e');
      setState(() => _isLoading = false);
    }
  }

  void _showEditAcademicYearDialog(AcademicYearModel year) {
    showDialog(
      context: context,
      builder: (context) => EditAcademicYearDialog(
        academicYear: year,
        onUpdated: _loadAcademicYears,
      ),
    );
  }

  Future<void> _confirmDeleteAcademicYear(AcademicYearModel year) async {
    final confirmed = await AppHelpers.showConfirmDialog(
      context,
      title: 'Delete Academic Year',
      message: 'Are you sure you want to delete "${year.yearLabel}"? This action cannot be undone.\n\nNote: You cannot delete years with existing sessions or assigned admins.',
      confirmText: 'Delete',
      isDestructive: true,
    );

    if (confirmed) {
      try {
        final databaseService = context.read<DatabaseService>();
        await databaseService.deleteAcademicYear(year.id);
        
        AppHelpers.showSuccessToast('Academic year deleted successfully');
        _loadAcademicYears();
      } catch (e) {
        AppHelpers.showErrorToast(e.toString().contains('Cannot delete') 
            ? e.toString().replaceAll('Exception: ', '')
            : 'Failed to delete academic year');
      }
    }
  }

  void _showCreateAcademicYearDialog() {
    showDialog(
      context: context,
      builder: (context) => CreateAcademicYearDialog(
        instituteId: _currentUser!.instituteId!,
        onCreated: _loadAcademicYears,
      ),
    );
  }

  Future<void> _setCurrentYear(AcademicYearModel year) async {
    try {
      final databaseService = context.read<DatabaseService>();
      
      // Update current year in database
      await databaseService.setCurrentAcademicYear(
        instituteId: _currentUser!.instituteId!,
        yearId: year.id,
      );
      
      AppHelpers.showSuccessToast('${year.yearLabel} set as current year');
      _loadAcademicYears();
    } catch (e) {
      AppHelpers.showErrorToast('Failed to set current year');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_isLoading) {
      return const Scaffold(
        body: LoadingWidget(message: 'Loading academic years...'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Academic Years'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: RefreshIndicator(
        onRefresh: _loadAcademicYears,
        child: _academicYears.isEmpty
            ? EmptyStateWidget(
                icon: Icons.school,
                title: 'No Academic Years',
                subtitle: 'Create your first academic year to get started',
                buttonText: 'Add Academic Year',
                onButtonPressed: _showCreateAcademicYearDialog,
              )
                : ListView.builder(
                padding: const EdgeInsets.all(AppSizes.md),
                itemCount: _academicYears.length,
                itemBuilder: (context, index) {
                  final year = _academicYears[index];
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
                                  color: year.isCurrent 
                                      ? AppColors.success.withOpacity(0.1)
                                      : AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                                ),
                                child: Icon(
                                  year.isCurrent ? Icons.stars : Icons.school,
                                  color: year.isCurrent ? AppColors.success : AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: AppSizes.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          year.yearLabel,
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (year.isCurrent) ...[
                                          const SizedBox(width: AppSizes.sm),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: AppSizes.sm,
                                              vertical: AppSizes.xs,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.success,
                                              borderRadius: BorderRadius.circular(AppSizes.radiusRound),
                                            ),
                                            child: const Text(
                                              'CURRENT',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: AppSizes.xs),
                                    Text(
                                      '${AppHelpers.formatDate(year.startDate)} - ${AppHelpers.formatDate(year.endDate)}',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                    Text(
                                      'Status: ${year.status} • ${year.durationInDays} days',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Action buttons
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!year.isCurrent)
                                    TextButton(
                                      onPressed: () => _setCurrentYear(year),
                                      child: const Text('Set Current'),
                                    ),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert),
                                    onSelected: (value) {
                                      switch (value) {
                                        case 'edit':
                                          _showEditAcademicYearDialog(year);
                                          break;
                                        case 'set_current':
                                          _setCurrentYear(year);
                                          break;
                                        case 'delete':
                                          _confirmDeleteAcademicYear(year);
                                          break;
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: ListTile(
                                          leading: Icon(Icons.edit),
                                          title: Text('Edit Year'),
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                      if (!year.isCurrent) ...[
                                        const PopupMenuItem(
                                          value: 'set_current',
                                          child: ListTile(
                                            leading: Icon(Icons.stars, color: AppColors.success),
                                            title: Text('Set as Current'),
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                        ),
                                      ],
                                      const PopupMenuDivider(),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: ListTile(
                                          leading: Icon(Icons.delete, color: AppColors.error),
                                          title: Text('Delete Year'),
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                          // Progress indicator for active years
                          if (year.isActive) ...[
                            const SizedBox(height: AppSizes.md),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Academic Year Progress',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onSurface.withOpacity(0.8),
                                      ),
                                    ),
                                    Text(
                                      '${year.progressPercentage.toStringAsFixed(1)}%',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: year.progressPercentage < 80 
                                            ? AppColors.success 
                                            : AppColors.warning,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSizes.xs),
                                LinearProgressIndicator(
                                  value: year.progressPercentage / 100,
                                  backgroundColor: Colors.grey[300],
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    year.progressPercentage < 80 
                                        ? AppColors.success 
                                        : AppColors.warning,
                                  ),
                                ),
                                const SizedBox(height: AppSizes.xs),
                                Text(
                                  year.timeRemaining,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          // Status indicators for upcoming/ended years
                          if (year.isUpcoming) ...[
                            const SizedBox(height: AppSizes.sm),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSizes.sm,
                                vertical: AppSizes.xs,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.info.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.schedule,
                                    size: AppSizes.iconSm,
                                    color: AppColors.info,
                                  ),
                                  const SizedBox(width: AppSizes.xs),
                                  Text(
                                    year.timeRemaining,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.info,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (year.hasEnded) ...[
                            const SizedBox(height: AppSizes.sm),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSizes.sm,
                                vertical: AppSizes.xs,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle_outline,
                                    size: AppSizes.iconSm,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: AppSizes.xs),
                                  Text(
                                    'Academic year completed',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateAcademicYearDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Year'),
        backgroundColor: theme.colorScheme.primary,
      ),
    );
  }
}

class EditAcademicYearDialog extends StatefulWidget {
  final AcademicYearModel academicYear;
  final VoidCallback onUpdated;

  const EditAcademicYearDialog({
    super.key,
    required this.academicYear,
    required this.onUpdated,
  });

  @override
  State<EditAcademicYearDialog> createState() => _EditAcademicYearDialogState();
}

class _EditAcademicYearDialogState extends State<EditAcademicYearDialog> {
  final _formKey = GlobalKey<FormState>();
  final _yearLabelController = TextEditingController();
  final _startYearController = TextEditingController();
  final _endYearController = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  bool _isCurrent = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final year = widget.academicYear;
    _yearLabelController.text = year.yearLabel;
    _startYearController.text = year.startYear.toString();
    _endYearController.text = year.endYear.toString();
    _startDate = year.startDate;
    _endDate = year.endDate;
    _isCurrent = year.isCurrent;
  }

  @override
  void dispose() {
    _yearLabelController.dispose();
    _startYearController.dispose();
    _endYearController.dispose();
    super.dispose();
  }

  Future<void> _updateAcademicYear() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final databaseService = context.read<DatabaseService>();

      // If setting as current, handle the current year switch
      if (_isCurrent && !widget.academicYear.isCurrent) {
        await databaseService.setCurrentAcademicYear(
          instituteId: widget.academicYear.instituteId,
          yearId: widget.academicYear.id,
        );
      }

      await databaseService.updateAcademicYear(
        yearId: widget.academicYear.id,
        yearLabel: _yearLabelController.text.trim(),
        startYear: int.parse(_startYearController.text),
        endYear: int.parse(_endYearController.text),
        startDate: _startDate,
        endDate: _endDate,
        isCurrent: _isCurrent,
      );

      AppHelpers.showSuccessToast('Academic year updated successfully');
      Navigator.pop(context);
      widget.onUpdated();
    } catch (e) {
      AppHelpers.showErrorToast('Failed to update academic year');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date != null) {
      setState(() => _startDate = date);
    }
  }

  Future<void> _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2030),
    );
    if (date != null) {
      setState(() => _endDate = date);
    }
  }

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
                color: AppColors.warning,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppSizes.radiusLg),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit, color: Colors.white),
                  const SizedBox(width: AppSizes.sm),
                  const Text(
                    'Edit Academic Year',
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
            // Content - Same as create dialog but with pre-filled values
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSizes.md),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      CustomTextField(
                        label: 'Year Label',
                        hint: 'e.g., 2024-25',
                        controller: _yearLabelController,
                        validator: (value) => AppHelpers.validateRequired(value, 'Year label'),
                        prefixIcon: Icons.label,
                      ),
                      // ... rest of the form fields (same as create dialog)
                      const SizedBox(height: AppSizes.md),
                      Row(
                        children: [
                          Expanded(
                            child: CustomTextField(
                              label: 'Start Year',
                              controller: _startYearController,
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value?.isEmpty == true) return 'Required';
                                final year = int.tryParse(value!);
                                if (year == null || year < 2020 || year > 2030) {
                                  return 'Invalid year';
                                }
                                return null;
                              },
                              prefixIcon: Icons.calendar_month,
                            ),
                          ),
                          const SizedBox(width: AppSizes.md),
                          Expanded(
                            child: CustomTextField(
                              label: 'End Year',
                              controller: _endYearController,
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value?.isEmpty == true) return 'Required';
                                final year = int.tryParse(value!);
                                if (year == null || year < 2020 || year > 2030) {
                                  return 'Invalid year';
                                }
                                final startYear = int.tryParse(_startYearController.text);
                                if (startYear != null && year <= startYear) {
                                  return 'Must be after start year';
                                }
                                return null;
                              },
                              prefixIcon: Icons.event,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.md),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: _selectStartDate,
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Start Date',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.calendar_today),
                                ),
                                child: Text(
                                  AppHelpers.formatDate(_startDate),
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSizes.md),
                          Expanded(
                            child: InkWell(
                              onTap: _selectEndDate,
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'End Date',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.event),
                                ),
                                child: Text(
                                  AppHelpers.formatDate(_endDate),
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.md),
                      SwitchListTile(
                        title: const Text('Set as Current Year'),
                        subtitle: Text(
                          _isCurrent 
                              ? 'This is the active academic year'
                              : 'Set as the active academic year'
                        ),
                        value: _isCurrent,
                        onChanged: (value) => setState(() => _isCurrent = value),
                        secondary: const Icon(Icons.stars),
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
                      text: 'Update Year',
                      onPressed: _isLoading ? null : _updateAcademicYear,
                      isLoading: _isLoading,
                      icon: Icons.update,
                      backgroundColor: AppColors.warning,
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

// Create Academic Year Dialog
class CreateAcademicYearDialog extends StatefulWidget {
  final String instituteId;
  final VoidCallback onCreated;

  const CreateAcademicYearDialog({
    super.key,
    required this.instituteId,
    required this.onCreated,
  });

  @override
  State<CreateAcademicYearDialog> createState() => _CreateAcademicYearDialogState();
}

class _CreateAcademicYearDialogState extends State<CreateAcademicYearDialog> {
  final _formKey = GlobalKey<FormState>();
  final _yearLabelController = TextEditingController();
  final _startYearController = TextEditingController();
  final _endYearController = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 365));
  bool _isCurrent = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final currentYear = DateTime.now().year;
    _startYearController.text = currentYear.toString();
    _endYearController.text = (currentYear + 1).toString();
    _yearLabelController.text = '$currentYear-${currentYear + 1}';
    _startDate = DateTime(currentYear, 6, 1); // June 1st
    _endDate = DateTime(currentYear + 1, 5, 31); // May 31st next year
  }

  @override
  void dispose() {
    _yearLabelController.dispose();
    _startYearController.dispose();
    _endYearController.dispose();
    super.dispose();
  }

  Future<void> _createAcademicYear() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final databaseService = context.read<DatabaseService>();

      await databaseService.createAcademicYear(
        yearLabel: _yearLabelController.text.trim(),
        startYear: int.parse(_startYearController.text),
        endYear: int.parse(_endYearController.text),
        startDate: _startDate,
        endDate: _endDate,
        instituteId: widget.instituteId,
        isCurrent: _isCurrent,
      );

      AppHelpers.showSuccessToast('Academic year created successfully');
      Navigator.pop(context);
      widget.onCreated();
    } catch (e) {
      AppHelpers.showErrorToast('Failed to create academic year');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date != null) {
      setState(() => _startDate = date);
    }
  }

  Future<void> _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2030),
    );
    if (date != null) {
      setState(() => _endDate = date);
    }
  }

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
                  const Icon(Icons.school, color: Colors.white),
                  const SizedBox(width: AppSizes.sm),
                  const Text(
                    'Create Academic Year',
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
                    children: [
                      CustomTextField(
                        label: 'Year Label',
                        hint: 'e.g., 2024-25',
                        controller: _yearLabelController,
                        validator: (value) => AppHelpers.validateRequired(value, 'Year label'),
                        prefixIcon: Icons.label,
                      ),
                      const SizedBox(height: AppSizes.md),
                      Row(
                        children: [
                          Expanded(
                            child: CustomTextField(
                              label: 'Start Year',
                              controller: _startYearController,
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value?.isEmpty == true) return 'Required';
                                final year = int.tryParse(value!);
                                if (year == null || year < 2020 || year > 2030) {
                                  return 'Invalid year';
                                }
                                return null;
                              },
                              prefixIcon: Icons.calendar_month,
                            ),
                          ),
                          const SizedBox(width: AppSizes.md),
                          Expanded(
                            child: CustomTextField(
                              label: 'End Year',
                              controller: _endYearController,
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value?.isEmpty == true) return 'Required';
                                final year = int.tryParse(value!);
                                if (year == null || year < 2020 || year > 2030) {
                                  return 'Invalid year';
                                }
                                final startYear = int.tryParse(_startYearController.text);
                                if (startYear != null && year <= startYear) {
                                  return 'Must be after start year';
                                }
                                return null;
                              },
                              prefixIcon: Icons.event,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.md),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: _selectStartDate,
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Start Date',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.calendar_today),
                                ),
                                child: Text(
                                  AppHelpers.formatDate(_startDate),
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSizes.md),
                          Expanded(
                            child: InkWell(
                              onTap: _selectEndDate,
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'End Date',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.event),
                                ),
                                child: Text(
                                  AppHelpers.formatDate(_endDate),
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.md),
                      SwitchListTile(
                        title: const Text('Set as Current Year'),
                        subtitle: const Text('This will be the active academic year'),
                        value: _isCurrent,
                        onChanged: (value) => setState(() => _isCurrent = value),
                        secondary: const Icon(Icons.stars),
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
                      text: 'Create Year',
                      onPressed: _isLoading ? null : _createAcademicYear,
                      isLoading: _isLoading,
                      icon: Icons.add,
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

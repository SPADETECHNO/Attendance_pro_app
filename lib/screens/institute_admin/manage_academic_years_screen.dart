// lib/screens/institute_admin/manage_academic_years_screen.dart

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
    final confirmed = await showDialog<bool>(
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
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              child: Icon(
                Icons.delete_rounded,
                color: AppColors.error,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            Text(
              'Delete Academic Year',
              style: TextStyle(
                color: AppColors.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSizes.sm),
              decoration: BoxDecoration(
                color: AppColors.gray100,
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              child: Text(
                year.yearLabel,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.gray700,
                ),
              ),
            ),
            const SizedBox(height: AppSizes.md),
            Text(
              'Are you sure you want to delete this academic year? This action cannot be undone.',
              style: TextStyle(
                color: AppColors.gray700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            Container(
              padding: const EdgeInsets.all(AppSizes.sm),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_rounded,
                    color: AppColors.warning,
                    size: 16,
                  ),
                  const SizedBox(width: AppSizes.xs),
                  Expanded(
                    child: Text(
                      'Note: You cannot delete years with existing sessions or assigned admins.',
                      style: TextStyle(
                        color: AppColors.warning,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
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
    if (_isLoading) {
      return const Scaffold(
        body: LoadingWidget(message: 'Loading academic years...'),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Manage Academic Years',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.gray800,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: _loadAcademicYears,
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAcademicYears,
        color: AppColors.gray700,
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
                  return Container(
                    margin: const EdgeInsets.only(bottom: AppSizes.md),
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
                                      : AppColors.gray700.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                                ),
                                child: Icon(
                                  year.isCurrent ? Icons.stars : Icons.school,
                                  color: year.isCurrent ? AppColors.success : AppColors.gray700,
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
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                            color: AppColors.onSurface,
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
                                      style: TextStyle(
                                        color: AppColors.gray600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      'Status: ${year.status} • ${year.durationInDays} days',
                                      style: TextStyle(
                                        color: AppColors.gray600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!year.isCurrent)
                                    TextButton(
                                      onPressed: () => _setCurrentYear(year),
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.gray700,
                                      ),
                                      child: const Text('Set Current'),
                                    ),
                                  PopupMenuButton<String>(
                                    icon: Icon(Icons.more_vert, color: AppColors.gray600),
                                    color: AppColors.surface,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                                    ),
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
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: ListTile(
                                          leading: Icon(Icons.edit, color: AppColors.gray700),
                                          title: Text(
                                            'Edit Year',
                                            style: TextStyle(color: AppColors.onSurface),
                                          ),
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                      if (!year.isCurrent) ...[
                                        PopupMenuItem(
                                          value: 'set_current',
                                          child: ListTile(
                                            leading: const Icon(Icons.stars, color: AppColors.success),
                                            title: Text(
                                              'Set as Current',
                                              style: TextStyle(color: AppColors.onSurface),
                                            ),
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                        ),
                                      ],
                                      const PopupMenuDivider(),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: const ListTile(
                                          leading: Icon(Icons.delete, color: AppColors.error),
                                          title: Text(
                                            'Delete Year',
                                            style: TextStyle(color: AppColors.error),
                                          ),
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
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.gray700,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      '${year.progressPercentage.toStringAsFixed(1)}%',
                                      style: TextStyle(
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
                                  backgroundColor: AppColors.gray200,
                                  valueColor: AlwaysStoppedAnimation(
                                    year.progressPercentage < 80
                                        ? AppColors.success
                                        : AppColors.warning,
                                  ),
                                ),
                                const SizedBox(height: AppSizes.xs),
                                Text(
                                  year.timeRemaining,
                                  style: TextStyle(
                                    color: AppColors.gray600,
                                    fontStyle: FontStyle.italic,
                                    fontSize: 12,
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
                                    style: TextStyle(
                                      color: AppColors.info,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
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
                                color: AppColors.gray300.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle_outline,
                                    size: AppSizes.iconSm,
                                    color: AppColors.gray600,
                                  ),
                                  const SizedBox(width: AppSizes.xs),
                                  Text(
                                    'Academic year completed',
                                    style: TextStyle(
                                      color: AppColors.gray600,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
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
        backgroundColor: AppColors.gray800,
        foregroundColor: Colors.white,
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
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          children: [
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
                                  style: TextStyle(color: AppColors.onSurface),
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
                                  style: TextStyle(color: AppColors.onSurface),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.md),
                      SwitchListTile(
                        title: Text(
                          'Set as Current Year',
                          style: TextStyle(color: AppColors.onSurface),
                        ),
                        subtitle: Text(
                          _isCurrent
                              ? 'This is the active academic year'
                              : 'Set as the active academic year',
                          style: TextStyle(color: AppColors.gray600),
                        ),
                        value: _isCurrent,
                        onChanged: (value) => setState(() => _isCurrent = value),
                        secondary: const Icon(Icons.stars),
                        activeColor: AppColors.warning,
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
                      onPressed: _isLoading ? null : _updateAcademicYear,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warning,
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
                                Icon(Icons.update, size: 16),
                                SizedBox(width: AppSizes.xs),
                                Text('Update Year'),
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
    _startDate = DateTime(currentYear, 6, 1);
    _endDate = DateTime(currentYear + 1, 5, 31);
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
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSizes.md),
              decoration: BoxDecoration(
                color: AppColors.gray700,
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
                                  style: TextStyle(color: AppColors.onSurface),
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
                                  style: TextStyle(color: AppColors.onSurface),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.md),
                      SwitchListTile(
                        title: Text(
                          'Set as Current Year',
                          style: TextStyle(color: AppColors.onSurface),
                        ),
                        subtitle: Text(
                          'This will be the active academic year',
                          style: TextStyle(color: AppColors.gray600),
                        ),
                        value: _isCurrent,
                        onChanged: (value) => setState(() => _isCurrent = value),
                        secondary: const Icon(Icons.stars),
                        activeColor: AppColors.gray700,
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
                      onPressed: _isLoading ? null : _createAcademicYear,
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
                                Icon(Icons.add, size: 16),
                                SizedBox(width: AppSizes.xs),
                                Text('Create Year'),
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
          mainAxisAlignment: MainAxisAlignment.center,
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

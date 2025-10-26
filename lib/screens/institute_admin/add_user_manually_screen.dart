// lib/screens/institute_admin/add_user_manually_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attendance_pro_app/services/auth_service.dart';
import 'package:attendance_pro_app/services/database_service.dart';
import 'package:attendance_pro_app/models/user_model.dart';
import 'package:attendance_pro_app/models/department_model.dart';
import 'package:attendance_pro_app/models/academic_year_model.dart';
import 'package:attendance_pro_app/widgets/custom_button.dart';
import 'package:attendance_pro_app/widgets/custom_text_field.dart';
import 'package:attendance_pro_app/widgets/loading_widget.dart';
import 'package:attendance_pro_app/utils/constants.dart';
import 'package:attendance_pro_app/utils/helpers.dart';

class AddUserManuallyScreen extends StatefulWidget {
  const AddUserManuallyScreen({super.key});

  @override
  State<AddUserManuallyScreen> createState() => _AddUserManuallyScreenState();
}

class _AddUserManuallyScreenState extends State<AddUserManuallyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  UserModel? currentUser;
  List<DepartmentModel> departments = [];
  List<AcademicYearModel> academicYears = [];
  String? selectedDepartmentId;
  String? selectedAcademicYearId;
  bool sendInvitation = false;
  bool isLoading = false;
  bool isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final authService = context.read<AuthService>();
      final databaseService = context.read<DatabaseService>();
      final user = await authService.getCurrentUserProfile();

      if (user == null || user.instituteId == null) return;

      final depts = await databaseService.getDepartmentsByInstitute(user.instituteId!);
      final years = await databaseService.getAcademicYears(user.instituteId!);

      setState(() {
        currentUser = user;
        departments = depts;
        academicYears = years;
        // Pre-select current academic year
        final currentYear = years.firstWhere(
          (y) => y.isCurrent,
          orElse: () => years.isNotEmpty ? years.first : throw StateError('No academic years'),
        );
        selectedAcademicYearId = currentYear.id;
        isLoadingData = false;
      });
    } catch (e) {
      AppHelpers.showErrorToast('Failed to load data: ${e.toString()}');
      setState(() => isLoadingData = false);
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedDepartmentId == null) {
      AppHelpers.showErrorToast('Please select a department');
      return;
    }

    final confirmed = await _showConfirmationDialog();
    if (!confirmed) return;

    setState(() => isLoading = true);
    try {
      final databaseService = context.read<DatabaseService>();

      // Check if user ID already exists
      final existing = await databaseService.searchInstituteMasterListByUserId(
        currentUser!.instituteId!,
        _userIdController.text.trim(),
      );

      if (existing != null) {
        AppHelpers.showErrorToast('User ID already exists in the system');
        setState(() => isLoading = false);
        return;
      }

      // Add to master list
      await databaseService.addToInstituteMasterList(
        userId: _userIdController.text.trim(),
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        instituteId: currentUser!.instituteId!,
        departmentId: selectedDepartmentId,
        academicYearId: selectedAcademicYearId,
        createdBy: currentUser!.id,
      );

      AppHelpers.showSuccessToast(sendInvitation
          ? 'User added and invitation sent successfully!'
          : 'User added to master list successfully!');
      Navigator.pop(context, true);
    } catch (e) {
      AppHelpers.showErrorToast('Failed to add user: ${e.toString()}');
      setState(() => isLoading = false);
    }
  }

  Future<bool> _showConfirmationDialog() async {
    final result = await showDialog<bool>(
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
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              child: Icon(
                Icons.person_add_rounded,
                color: AppColors.success,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            Text(
              'Add User Confirmation',
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
                _nameController.text.trim(),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.gray700,
                ),
              ),
            ),
            const SizedBox(height: AppSizes.md),
            Text(
              'Are you sure you want to add "${_nameController.text.trim()}" to the master list?',
              style: TextStyle(
                color: AppColors.gray700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            Container(
              padding: const EdgeInsets.all(AppSizes.sm),
              decoration: BoxDecoration(
                color: sendInvitation ? AppColors.info.withOpacity(0.1) : AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              child: Row(
                children: [
                  Icon(
                    sendInvitation ? Icons.email : Icons.person_add,
                    color: sendInvitation ? AppColors.info : AppColors.warning,
                    size: 16,
                  ),
                  const SizedBox(width: AppSizes.xs),
                  Expanded(
                    child: Text(
                      sendInvitation
                          ? 'An invitation email will be sent to the user'
                          : 'User will be added without email invitation',
                      style: TextStyle(
                        color: sendInvitation ? AppColors.info : AppColors.warning,
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
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              elevation: 2,
            ),
            child: const Text('Add User'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  void dispose() {
    _userIdController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingData) {
      return const Scaffold(
        body: LoadingWidget(message: 'Loading data...'),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Add User Manually',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.gray800,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.md),
          children: [
            // Info card
            Container(
              padding: const EdgeInsets.all(AppSizes.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                border: Border.all(color: AppColors.info.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSizes.sm),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    ),
                    child: const Icon(
                      Icons.info_outline,
                      color: AppColors.info,
                    ),
                  ),
                  const SizedBox(width: AppSizes.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add Individual User',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.onSurface,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add a single user to the institute master list. Users can be activated later by sending invitations.',
                          style: TextStyle(
                            color: AppColors.gray600,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.xl),

            // User Details Section
            Text(
              'User Information',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: AppSizes.md),

            // User ID
            CustomTextField(
              label: 'User ID',
              controller: _userIdController,
              validator: (value) => AppHelpers.validateRequired(value, 'User ID'),
              prefixIcon: Icons.badge,
              helperText: 'Unique identifier for the user (e.g., STU001)',
            ),
            const SizedBox(height: AppSizes.lg),

            // Name
            CustomTextField(
              label: 'Full Name',
              controller: _nameController,
              validator: (value) => AppHelpers.validateRequired(value, 'Name'),
              prefixIcon: Icons.person,
            ),
            const SizedBox(height: AppSizes.lg),

            // Email
            CustomTextField(
              label: 'Email Address',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              validator: AppHelpers.validateEmail,
              prefixIcon: Icons.email,
            ),
            const SizedBox(height: AppSizes.lg),

            // Phone
            CustomTextField(
              label: 'Phone Number (Optional)',
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              validator: AppHelpers.validatePhone,
              prefixIcon: Icons.phone,
            ),
            const SizedBox(height: AppSizes.xl),

            // Assignment Section
            Text(
              'Assignment Information',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: AppSizes.md),

            // Department
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Department',
                prefixIcon: const Icon(Icons.domain),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
              ),
              value: selectedDepartmentId,
              items: departments.map((dept) {
                return DropdownMenuItem(
                  value: dept.id,
                  child: Text(dept.name),
                );
              }).toList(),
              onChanged: (value) => setState(() => selectedDepartmentId = value),
              validator: (value) => value == null ? 'Please select a department' : null,
            ),
            const SizedBox(height: AppSizes.lg),

            // Academic Year
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Academic Year',
                prefixIcon: const Icon(Icons.calendar_today),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
              ),
              value: selectedAcademicYearId,
              items: academicYears.map((year) {
                return DropdownMenuItem(
                  value: year.id,
                  child: Row(
                    children: [
                      Text(year.yearLabel),
                      if (year.isCurrent) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'CURRENT',
                            style: TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) => setState(() => selectedAcademicYearId = value),
            ),
            const SizedBox(height: AppSizes.xl),

            // Invitation Settings
            Container(
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
                      Container(
                        padding: const EdgeInsets.all(AppSizes.sm),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                        ),
                        child: Icon(
                          Icons.email,
                          color: AppColors.warning,
                          size: AppSizes.iconMd,
                        ),
                      ),
                      const SizedBox(width: AppSizes.sm),
                      Text(
                        'Invitation Settings',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSurface,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.md),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sendInvitation
                                  ? 'Send email invitation to user'
                                  : 'Add to master list without invitation',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: AppColors.onSurface,
                              ),
                            ),
                            const SizedBox(height: AppSizes.xs),
                            Text(
                              sendInvitation
                                  ? 'User will receive login credentials via email automatically'
                                  : 'You will need to share login credentials manually when needed',
                              style: TextStyle(
                                color: AppColors.gray600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSizes.md),
                      Switch.adaptive(
                        value: sendInvitation,
                        onChanged: (value) => setState(() => sendInvitation = value),
                        activeColor: AppColors.warning,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.xl),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : _submitForm,
                icon: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(sendInvitation ? Icons.email : Icons.person_add, size: 16),
                label: Text(
                  sendInvitation ? 'Add User & Send Invitation' : 'Add User to Master List',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gray800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

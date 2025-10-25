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

      final depts =
          await databaseService.getDepartmentsByInstitute(user.instituteId!);
      final years = await databaseService.getAcademicYears(user.instituteId!);

      setState(() {
        currentUser = user;
        departments = depts;
        academicYears = years;

        // Pre-select current academic year
        final currentYear = years.firstWhere(
          (y) => y.isCurrent,
          orElse: () => years.isNotEmpty
              ? years.first
              : throw StateError('No academic years'),
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

    setState(() => isLoading = true);

    try {
      final databaseService = context.read<DatabaseService>();
      final authService = context.read<AuthService>();

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
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        instituteId: currentUser!.instituteId!,
        departmentId: selectedDepartmentId,
        academicYearId: selectedAcademicYearId,
        createdBy: currentUser!.id
      );

      AppHelpers.showSuccessToast(sendInvitation
          ? 'User added and invitation sent successfully!'
          : 'User added to master list successfully!');

      Navigator.pop(context, true); // Return true to indicate success
    } catch (e) {
      AppHelpers.showErrorToast('Failed to add user: ${e.toString()}');
      setState(() => isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoadingData) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Add User Manually'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add User Manually'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.md),
          children: [
            // Info card
            Card(
              color: AppColors.info.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.md),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.info),
                    const SizedBox(width: AppSizes.sm),
                    Expanded(
                      child: Text(
                        'Add a single user to the master list. Users can be activated later by sending invitations.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSizes.lg),

            // User ID
            CustomTextField(
              label: 'User ID *',
              controller: _userIdController,
              validator: (value) =>
                  AppHelpers.validateRequired(value, 'User ID'),
              prefixIcon: Icons.badge,
              helperText: 'Unique identifier for the user (e.g., STU001)',
            ),
            const SizedBox(height: AppSizes.lg),

            // Name
            CustomTextField(
              label: 'Full Name *',
              controller: _nameController,
              validator: (value) => AppHelpers.validateRequired(value, 'Name'),
              prefixIcon: Icons.person,
            ),
            const SizedBox(height: AppSizes.lg),

            // Email
            CustomTextField(
              label: 'Email Address *',
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
            const SizedBox(height: AppSizes.lg),

            // Department
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Department *',
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
              onChanged: (value) =>
                  setState(() => selectedDepartmentId = value),
              validator: (value) =>
                  value == null ? 'Please select a department' : null,
            ),
            const SizedBox(height: AppSizes.lg),

            // Academic Year
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Academic Year *',
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
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
              onChanged: (value) =>
                  setState(() => selectedAcademicYearId = value),
            ),
            const SizedBox(height: AppSizes.xl),

            // Invitation checkbox
            Card(
              child: CheckboxListTile(
                title: const Text('Create auth account and send invitation'),
                subtitle: const Text(
                  'If checked, an account will be created and an invitation email will be sent to the user.',
                  style: TextStyle(fontSize: 12),
                ),
                value: sendInvitation,
                onChanged: (value) =>
                    setState(() => sendInvitation = value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),
            const SizedBox(height: AppSizes.xl),

            // Submit button
            CustomButton(
              text: sendInvitation
                  ? 'Add User & Send Invitation'
                  : 'Add User to Master List',
              onPressed: isLoading ? null : _submitForm,
              isLoading: isLoading,
              icon: Icons.person_add,
            ),
          ],
        ),
      ),
    );
  }
}

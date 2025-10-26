// lib/screens/admin/create_session_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attendance_pro_app/services/auth_service.dart';
import 'package:attendance_pro_app/services/database_service.dart';
import 'package:attendance_pro_app/widgets/custom_button.dart';
import 'package:attendance_pro_app/widgets/custom_text_field.dart';
import 'package:attendance_pro_app/widgets/loading_widget.dart';
import 'package:attendance_pro_app/widgets/select_participants_widget.dart';
import 'package:attendance_pro_app/utils/constants.dart';
import 'package:attendance_pro_app/utils/helpers.dart';
import 'package:attendance_pro_app/models/user_model.dart';
import 'package:attendance_pro_app/models/academic_year_model.dart';
import 'package:attendance_pro_app/constants/app_constants.dart';

class CreateSessionScreen extends StatefulWidget {
  const CreateSessionScreen({super.key});

  @override
  State<CreateSessionScreen> createState() => _CreateSessionScreenState();
}

class _CreateSessionScreenState extends State<CreateSessionScreen> {
  // Form Controllers
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  // State Variables
  UserModel? _currentUser;
  AcademicYearModel? _currentAcademicYear;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  late TimeOfDay _endTime;
  bool _gpsValidationEnabled = true;
  bool _isLoading = true;
  bool _isCreating = false;
  List<Map<String, dynamic>> _selectedParticipants = [];

  @override
  void initState() {
    super.initState();
    _endTime = _calculateEndTime(TimeOfDay.now());
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // Load initial data
  Future<void> _loadData() async {
    try {
      final authService = context.read<AuthService>();
      final databaseService = context.read<DatabaseService>();
      final user = await authService.getCurrentUserProfile();

      if (user == null) return;

      final academicYears =
          await databaseService.getAcademicYears(user.instituteId!);
      final currentYear = academicYears.firstWhere(
        (year) => year.isCurrent,
        orElse: () => academicYears.isNotEmpty
            ? academicYears.first
            : throw Exception('No academic years configured'),
      );

      if (mounted) {
        setState(() {
          _currentUser = user;
          _currentAcademicYear = currentYear;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppHelpers.debugError('Load error: $e');
      if (mounted) {
        AppHelpers.showErrorToast('Failed to load: ${e.toString()}');
        Navigator.pop(context);
      }
    }
  }

  // Date selection
  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  // Time selection methods
  Future<void> _selectStartTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _startTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                ),
          ),
          child: child!,
        );
      },
    );
    if (time != null) {
      setState(() {
        _startTime = time;
        _endTime = _calculateEndTime(time);
      });
    }
  }

  Future<void> _selectEndTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _endTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                ),
          ),
          child: child!,
        );
      },
    );
    if (time != null) {
      final startMinutes = _startTime.hour * 60 + _startTime.minute;
      final endMinutes = time.hour * 60 + time.minute;
      if (endMinutes <= startMinutes) {
        AppHelpers.showWarningToast('End time must be after start time');
        return;
      }
      setState(() => _endTime = time);
    }
  }

  // Calculate end time (2 hours after start)
  TimeOfDay _calculateEndTime(TimeOfDay startTime) {
    int newHour = (startTime.hour + 2) % 24;
    return TimeOfDay(hour: newHour, minute: startTime.minute);
  }

  // Create session
  Future<void> _createSession() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedParticipants.isEmpty) {
      AppHelpers.showErrorToast('Please select at least one participant');
      return;
    }

    setState(() => _isCreating = true);
    try {
      final databaseService = context.read<DatabaseService>();
      final startDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _startTime.hour,
        _startTime.minute,
      );
      final endDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _endTime.hour,
        _endTime.minute,
      );

      final duration = endDateTime.difference(startDateTime);
      if (duration.inMinutes < 15) {
        AppHelpers.showWarningToast('Session must be at least 15 minutes');
        return;
      }
      if (duration.inHours > 12) {
        AppHelpers.showWarningToast('Session cannot exceed 12 hours');
        return;
      }

      final masterListIds =
          _selectedParticipants.map((user) => user['id'] as String).toList();

      await databaseService.createSessionWithAttendance(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        startDateTime: startDateTime,
        endDateTime: endDateTime,
        academicYearId: _currentAcademicYear!.id,
        departmentId: _currentUser!.departmentId!,
        createdBy: _currentUser!.id,
        gpsValidationEnabled: _gpsValidationEnabled,
        masterListIds: masterListIds,
      );

      if (mounted) {
        AppHelpers.showSuccessToast(
          'Session created with ${masterListIds.length} participants!',
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      AppHelpers.debugError('Create session error: $e');
      if (mounted) {
        AppHelpers.showErrorToast('Failed: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: LoadingWidget(message: 'Loading...'),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeCard(),
              const SizedBox(height: AppSizes.xl),
              _buildSectionTitle('Session Details', Icons.event_rounded),
              const SizedBox(height: AppSizes.md),
              _buildBasicInfoSection(),
              const SizedBox(height: AppSizes.xl),
              _buildSectionTitle('Schedule', Icons.schedule_rounded),
              const SizedBox(height: AppSizes.md),
              _buildScheduleSection(),
              const SizedBox(height: AppSizes.xl),
              _buildSectionTitle('Settings', Icons.settings_rounded),
              const SizedBox(height: AppSizes.md),
              _buildSettingsSection(),
              const SizedBox(height: AppSizes.xl),
              _buildSectionTitle('Participants', Icons.group_rounded),
              const SizedBox(height: AppSizes.md),
              _buildParticipantsSection(),
              const SizedBox(height: AppSizes.xl),
              _buildCreateButton(),
              const SizedBox(height: AppSizes.lg),
            ],
          ),
        ),
      ),
    );
  }

  // App Bar
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'Create Session',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      iconTheme: IconThemeData(color: AppColors.onPrimary),
      backgroundColor: AppColors.gray800,
      foregroundColor: AppColors.onPrimary,
      elevation: 0,
    );
  }

  // Section title helper
  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSizes.sm),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          ),
          child: Icon(
            icon,
            color: AppColors.primary,
            size: AppSizes.iconSm,
          ),
        ),
        const SizedBox(width: AppSizes.sm),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
          ),
        ),
      ],
    );
  }

  // Welcome card with user info
  Widget _buildWelcomeCard() {
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
                  color: AppColors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                child: Icon(
                  Icons.person_add_rounded,
                  color: AppColors.white,
                  size: AppSizes.iconMd,
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create New Session',
                      style: TextStyle(
                        fontSize: 20,
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Set up attendance tracking for your participants',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          Container(
            padding: const EdgeInsets.all(AppSizes.md),
            decoration: BoxDecoration(
              color: AppColors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    'Department',
                    _currentUser?.departmentName ?? 'Unknown',
                    Icons.domain_rounded,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: AppColors.white.withOpacity(0.2),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: _buildInfoItem(
                    'Academic Year',
                    _currentAcademicYear?.yearLabel ?? 'Unknown',
                    Icons.calendar_today_rounded,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Info item helper
  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              color: AppColors.white.withOpacity(0.7),
              size: 14,
            ),
            const SizedBox(width: AppSizes.xs),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.white.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.xs),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.white,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // Basic info section
  Widget _buildBasicInfoSection() {
    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
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
        children: [
          CustomTextField(
            label: 'Session Name',
            hint: 'e.g., Morning Lecture, Lab Session',
            controller: _nameController,
            validator: (value) =>
                AppHelpers.validateRequired(value, 'Session name'),
            prefixIcon: Icons.title_rounded,
          ),
          const SizedBox(height: AppSizes.lg),
          CustomTextField(
            label: 'Description (Optional)',
            hint: 'Brief description of the session',
            controller: _descriptionController,
            maxLines: 3,
            prefixIcon: Icons.description_rounded,
          ),
        ],
      ),
    );
  }

  // Schedule section
  Widget _buildScheduleSection() {
    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
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
        children: [
          // Date selector
          InkWell(
            onTap: _selectDate,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            child: Container(
              padding: const EdgeInsets.all(AppSizes.md),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.gray300),
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_month_rounded,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Session Date',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.gray600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          AppHelpers.formatDate(_selectedDate),
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    color: AppColors.gray500,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          // Time selectors
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _selectStartTime,
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  child: Container(
                    padding: const EdgeInsets.all(AppSizes.md),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.gray300),
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: AppSizes.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Start Time',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.gray600,
                                ),
                              ),
                              Text(
                                _startTime.format(context),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onSurface,
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
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: InkWell(
                  onTap: _selectEndTime,
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  child: Container(
                    padding: const EdgeInsets.all(AppSizes.md),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.gray300),
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time_filled_rounded,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: AppSizes.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'End Time',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.gray600,
                                ),
                              ),
                              Text(
                                _endTime.format(context),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onSurface,
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
            ],
          ),
        ],
      ),
    );
  }

  // Settings section
  Widget _buildSettingsSection() {
    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
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
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          'GPS Validation',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.onSurface,
          ),
        ),
        subtitle: Text(
          'Require location verification for attendance',
          style: TextStyle(
            color: AppColors.gray600,
            fontSize: 13,
          ),
        ),
        value: _gpsValidationEnabled,
        onChanged: (value) => setState(() => _gpsValidationEnabled = value),
        secondary: Container(
          padding: const EdgeInsets.all(AppSizes.sm),
          decoration: BoxDecoration(
            color: AppColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          ),
          child: Icon(
            Icons.location_on_rounded,
            color: AppColors.info,
          ),
        ),
        activeColor: AppColors.primary,
      ),
    );
  }

  // Participants section
  Widget _buildParticipantsSection() {
  return SelectParticipantsWidget(
    instituteId: _currentUser!.instituteId!,
    departmentId: null,
    academicYearId: null,
    onSelectionChanged: (selected) {
      setState(() => _selectedParticipants = selected);
    },
  );
}

  // Create button
  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      child: CustomButton(
        text: 'Create Session',
        onPressed: _createSession,
        isLoading: _isCreating,
        icon: Icons.add_rounded,
        backgroundColor: AppColors.gray800,
      ),
    );
  }
}

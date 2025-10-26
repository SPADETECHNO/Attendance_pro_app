// lib/screens/admin/edit_session_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attendance_pro_app/services/auth_service.dart';
import 'package:attendance_pro_app/services/database_service.dart';
import 'package:attendance_pro_app/widgets/loading_widget.dart';
import 'package:attendance_pro_app/widgets/custom_button.dart';
import 'package:attendance_pro_app/widgets/custom_text_field.dart';
import 'package:attendance_pro_app/utils/constants.dart';
import 'package:attendance_pro_app/utils/helpers.dart';
import 'package:attendance_pro_app/models/session_model.dart';
import 'package:attendance_pro_app/models/user_model.dart';

class EditSessionScreen extends StatefulWidget {
  final SessionModel session;

  const EditSessionScreen({
    super.key,
    required this.session,
  });

  @override
  State<EditSessionScreen> createState() => _EditSessionScreenState();
}

class _EditSessionScreenState extends State<EditSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  UserModel? _currentUser;
  late DateTime _selectedDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late bool _gpsValidationEnabled;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.session.name);
    _descriptionController = TextEditingController(text: widget.session.description ?? '');
    _selectedDate = widget.session.sessionDate;
    _startTime = TimeOfDay.fromDateTime(widget.session.startDateTime);
    _endTime = TimeOfDay.fromDateTime(widget.session.endDateTime);
    _gpsValidationEnabled = widget.session.gpsValidationEnabled;
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final authService = context.read<AuthService>();
      final user = await authService.getCurrentUserProfile();
      setState(() {
        _currentUser = user;
        _isLoading = false;
      });
    } catch (e) {
      AppHelpers.debugError('Load error: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final firstDate = widget.session.sessionDate.isBefore(now)
        ? widget.session.sessionDate
        : now;
    
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: firstDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.gray700,
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

  Future<void> _selectStartTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _startTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.gray700,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (time != null) {
      setState(() {
        _startTime = time;
        // Auto-adjust end time if needed
        final startMinutes = time.hour * 60 + time.minute;
        final endMinutes = _endTime.hour * 60 + _endTime.minute;
        if (endMinutes <= startMinutes) {
          _endTime = TimeOfDay(
            hour: (time.hour + 2) % 24,
            minute: time.minute,
          );
        }
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
              primary: AppColors.gray700,
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

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
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
        setState(() => _isSaving = false);
        return;
      }

      await databaseService.updateSession(
        sessionId: widget.session.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        startDateTime: startDateTime,
        endDateTime: endDateTime,
        gpsValidationEnabled: _gpsValidationEnabled,
      );

      if (mounted) {
        AppHelpers.showSuccessToast('Session updated successfully!');
        Navigator.pop(context, true);
      }
    } catch (e) {
      AppHelpers.debugError('Update session error: $e');
      if (mounted) {
        AppHelpers.showErrorToast('Failed to update session');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteSession() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Delete Session?',
          style: TextStyle(
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This will permanently delete the session and all attendance records. '
          'This action cannot be undone.',
          style: TextStyle(
            color: AppColors.gray700,
            height: 1.4,
          ),
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
    
    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    try {
      final databaseService = context.read<DatabaseService>();
      await databaseService.deleteSession(widget.session.id);
      if (mounted) {
        AppHelpers.showSuccessToast('Session deleted');
        Navigator.pop(context, true);
      }
    } catch (e) {
      AppHelpers.debugError('Delete session error: $e');
      if (mounted) {
        AppHelpers.showErrorToast('Failed to delete session');
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
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

    final canEdit = widget.session.status != 'ended';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Edit Session',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.gray800,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          if (canEdit)
            IconButton(
              onPressed: _isDeleting ? null : _deleteSession,
              icon: _isDeleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(Icons.delete, color: Colors.white),
              tooltip: 'Delete Session',
            ),
          const SizedBox(width: AppSizes.sm),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSessionInfoCard(),
              const SizedBox(height: AppSizes.xl),
              
              if (!canEdit) _buildWarningCard(),
              if (!canEdit) const SizedBox(height: AppSizes.xl),
              
              _buildSectionTitle('Session Details', Icons.event_rounded),
              const SizedBox(height: AppSizes.md),
              _buildBasicInfoSection(canEdit),
              const SizedBox(height: AppSizes.xl),
              
              _buildSectionTitle('Schedule', Icons.schedule_rounded),
              const SizedBox(height: AppSizes.md),
              _buildScheduleSection(canEdit),
              const SizedBox(height: AppSizes.xl),
              
              _buildSectionTitle('Settings', Icons.settings_rounded),
              const SizedBox(height: AppSizes.md),
              _buildSettingsSection(canEdit),
              const SizedBox(height: AppSizes.xl),
              
              if (canEdit) _buildSaveButton(),
              const SizedBox(height: AppSizes.lg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionInfoCard() {
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
                  Icons.edit_rounded,
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
                      widget.session.name,
                      style: TextStyle(
                        fontSize: 20,
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Status: ${widget.session.status.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.white.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
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
                    'Date',
                    AppHelpers.formatDate(widget.session.sessionDate),
                    Icons.calendar_today_rounded,
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
                    'Duration',
                    '${AppHelpers.formatTime(widget.session.startDateTime)} - ${AppHelpers.formatTime(widget.session.endDateTime)}',
                    Icons.access_time_rounded,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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

  Widget _buildWarningCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.warning),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Text(
              'This session has ended and cannot be edited.',
              style: TextStyle(
                color: AppColors.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSizes.sm),
          decoration: BoxDecoration(
            color: AppColors.gray700.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          ),
          child: Icon(
            icon,
            color: AppColors.gray700,
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

  Widget _buildBasicInfoSection(bool canEdit) {
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
            hint: 'e.g., Morning Lecture',
            controller: _nameController,
            validator: (value) => AppHelpers.validateRequired(value, 'Session name'),
            prefixIcon: Icons.title_rounded,
            enabled: canEdit,
          ),
          const SizedBox(height: AppSizes.lg),
          CustomTextField(
            label: 'Description (Optional)',
            hint: 'Session description',
            controller: _descriptionController,
            maxLines: 3,
            prefixIcon: Icons.description_rounded,
            enabled: canEdit,
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleSection(bool canEdit) {
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
          InkWell(
            onTap: canEdit ? _selectDate : null,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            child: Container(
              padding: const EdgeInsets.all(AppSizes.md),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.gray300),
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                color: canEdit ? AppColors.surface : AppColors.gray100,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_month_rounded,
                    color: canEdit ? AppColors.gray700 : AppColors.gray500,
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
                  if (canEdit)
                    Icon(
                      Icons.arrow_drop_down_rounded,
                      color: AppColors.gray500,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: canEdit ? _selectStartTime : null,
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  child: Container(
                    padding: const EdgeInsets.all(AppSizes.md),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.gray300),
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      color: canEdit ? AppColors.surface : AppColors.gray100,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          color: canEdit ? AppColors.success : AppColors.gray500,
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
                  onTap: canEdit ? _selectEndTime : null,
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  child: Container(
                    padding: const EdgeInsets.all(AppSizes.md),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.gray300),
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      color: canEdit ? AppColors.surface : AppColors.gray100,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time_filled_rounded,
                          color: canEdit ? AppColors.error : AppColors.gray500,
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

  Widget _buildSettingsSection(bool canEdit) {
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
        onChanged: canEdit 
            ? (value) => setState(() => _gpsValidationEnabled = value)
            : null,
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
        activeColor: AppColors.gray700,
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: CustomButton(
        text: 'Save Changes',
        onPressed: _saveChanges,
        isLoading: _isSaving,
        icon: Icons.save_rounded,
      ),
    );
  }
}

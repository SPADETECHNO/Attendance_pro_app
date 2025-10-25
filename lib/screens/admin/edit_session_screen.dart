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
    // Can only extend future, not change past sessions
    final now = DateTime.now();
    final firstDate = widget.session.sessionDate.isBefore(now)
        ? widget.session.sessionDate
        : now;

    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: firstDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _selectStartTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _startTime,
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
        title: const Text('Delete Session?'),
        content: const Text(
          'This will permanently delete the session and all attendance records. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
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
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(
        body: LoadingWidget(message: 'Loading...'),
      );
    }

    // Check if session can be edited (only live or upcoming)
    final canEdit = widget.session.status != 'ended';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Session'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
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
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.delete),
              tooltip: 'Delete Session',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Warning for ended sessions
              if (!canEdit)
                Card(
                  color: AppColors.warning.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.md),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.warning),
                        const SizedBox(width: AppSizes.sm),
                        Expanded(
                          child: Text(
                            'This session has ended and cannot be edited.',
                            style: TextStyle(color: AppColors.warning),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              if (!canEdit) const SizedBox(height: AppSizes.md),

              // Session Info
              Card(
                color: AppColors.info.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: AppColors.info),
                          const SizedBox(width: AppSizes.sm),
                          Text(
                            'Session Status',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.info,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.sm),
                      Text(
                        'Status: ${widget.session.status.toUpperCase()}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Created: ${AppHelpers.formatDateTime(widget.session.createdAt)}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.xl),

              // Session Name
              CustomTextField(
                label: 'Session Name',
                hint: 'e.g., Morning Lecture',
                controller: _nameController,
                validator: (value) => AppHelpers.validateRequired(value, 'Session name'),
                prefixIcon: Icons.event,
                enabled: canEdit,
              ),
              const SizedBox(height: AppSizes.lg),

              // Description
              CustomTextField(
                label: 'Description (Optional)',
                hint: 'Session description',
                controller: _descriptionController,
                maxLines: 3,
                prefixIcon: Icons.description,
                enabled: canEdit,
              ),
              const SizedBox(height: AppSizes.xl),

              // Date
              InkWell(
                onTap: canEdit ? _selectDate : null,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Session Date',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.calendar_month),
                    suffixIcon: canEdit ? const Icon(Icons.arrow_drop_down) : null,
                    enabled: canEdit,
                  ),
                  child: Text(
                    AppHelpers.formatDate(_selectedDate, format: AppFormats.dateFull),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.lg),

              // Time
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: canEdit ? _selectStartTime : null,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Start',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.access_time),
                          enabled: canEdit,
                        ),
                        child: Text(_startTime.format(context)),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: InkWell(
                      onTap: canEdit ? _selectEndTime : null,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'End',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.access_time_filled),
                          enabled: canEdit,
                        ),
                        child: Text(_endTime.format(context)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.xl),

              // GPS Setting
              SwitchListTile(
                title: const Text('GPS Validation'),
                subtitle: const Text('Require location verification'),
                value: _gpsValidationEnabled,
                onChanged: canEdit
                    ? (value) => setState(() => _gpsValidationEnabled = value)
                    : null,
                secondary: const Icon(Icons.location_on),
              ),
              const SizedBox(height: AppSizes.xl),

              // Save Button
              if (canEdit)
                SizedBox(
                  width: double.infinity,
                  child: CustomButton(
                    text: 'Save Changes',
                    onPressed: _saveChanges,
                    isLoading: _isSaving,
                    icon: Icons.save,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

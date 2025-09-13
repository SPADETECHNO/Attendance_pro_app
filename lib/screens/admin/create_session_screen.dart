import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attendance_pro_app/services/auth_service.dart';
import 'package:attendance_pro_app/services/database_service.dart';
import 'package:attendance_pro_app/widgets/custom_button.dart';
import 'package:attendance_pro_app/widgets/custom_text_field.dart';
import 'package:attendance_pro_app/widgets/loading_widget.dart';
import 'package:attendance_pro_app/utils/constants.dart';
import 'package:attendance_pro_app/utils/helpers.dart';
import 'package:attendance_pro_app/models/user_model.dart';
import 'package:attendance_pro_app/models/academic_year_model.dart';
import 'package:attendance_pro_app/services/csv_service.dart';

class CreateSessionScreen extends StatefulWidget {
  const CreateSessionScreen({super.key});

  @override
  State<CreateSessionScreen> createState() => _CreateSessionScreenState();
}

class _CreateSessionScreenState extends State<CreateSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _academicYearController = TextEditingController();
  String? _selectedSemester;
  CsvFileResult? _selectedParticipantsFile;
  ParticipantValidationResult? _participantValidation;

  UserModel? _currentUser;
  List<AcademicYearModel> _academicYears = [];
  AcademicYearModel? _selectedAcademicYear;

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  late TimeOfDay _endTime;
  bool _gpsValidationEnabled = true;
  bool _isLoading = true;
  bool _isCreating = false;

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
    _academicYearController.dispose();
    super.dispose();
  }

  Future _loadData() async {
    try {
      final authService = context.read<AuthService>();
      final databaseService = context.read<DatabaseService>();

      // Get current user
      final user = await authService.getCurrentUserProfile();
      if (user == null) return;

      // Get academic years for the institute
      final academicYears =
          await databaseService.getAcademicYears(user.instituteId!);

      // Fix the null check issue
      final currentYear = academicYears.isNotEmpty
          ? academicYears.firstWhere(
              (year) => year.isCurrent,
              orElse: () => academicYears.first,
            )
          : null;

      setState(() {
        _currentUser = user;
        _academicYears = academicYears;
        _selectedAcademicYear = currentYear;
        _isLoading = false;
      });
    } catch (e) {
      AppHelpers.debugError('Load create session data error: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null && date != _selectedDate) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _selectStartTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (time != null && time != _startTime) {
      setState(() {
        _startTime = time;
        // Use the helper method to calculate end time safely
        _endTime = _calculateEndTime(time);
      });
    }
  }

  TimeOfDay _calculateEndTime(TimeOfDay startTime) {
    int newHour = startTime.hour + 2;
    int newMinute = startTime.minute;

    if (newMinute >= 60) {
      newHour += newMinute ~/ 60;
      newMinute = newMinute % 60;
    }

    if (newHour >= 24) {
      newHour = newHour - 24;
    }

    return TimeOfDay(hour: newHour, minute: newMinute);
  }

  Future<void> _selectEndTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );

    if (time != null && time != _endTime) {
      // Validate that end time is after start time
      final startMinutes = _startTime.hour * 60 + _startTime.minute;
      final endMinutes = time.hour * 60 + time.minute;

      if (endMinutes <= startMinutes) {
        AppHelpers.showWarningToast('End time must be after start time');
        return;
      }

      setState(() => _endTime = time);
    }
  }

  Future<void> _pickParticipantsFile() async {
    try {
      final file = await CsvService.pickCsvFile();
      if (file == null) return;

      setState(() => _selectedParticipantsFile = file);
      await _validateParticipants();
    } catch (e) {
      AppHelpers.showErrorToast('Failed to pick file: $e');
    }
  }

  Future<void> _validateParticipants() async {
    if (_selectedParticipantsFile == null || _currentUser == null) return;

    try {
      final databaseService = context.read<DatabaseService>();

      // Parse CSV - expect simple format: user_id
      final csvData =
          CsvService.parseParticipantsCsv(_selectedParticipantsFile!.content);

      // Validate against master list (existing users in this institute/department)
      final validation = await databaseService.validateParticipants(
        userIds: csvData.map((row) => row['user_id'] as String).toList(),
        instituteId: _currentUser!.instituteId!,
        departmentId: _currentUser!.departmentId!,
      );

      setState(() => _participantValidation = validation);

      if (validation.invalidUsers.isNotEmpty) {
        AppHelpers.showWarningToast(
            '${validation.invalidUsers.length} users not found in master list');
      } else {
        AppHelpers.showSuccessToast(
            '${validation.validUsers.length} participants validated successfully');
      }
    } catch (e) {
      AppHelpers.showErrorToast('Validation failed: $e');
    }
  }

  Widget _buildParticipantValidation(ThemeData theme) {
    final validation = _participantValidation!;

    return Column(
      children: [
        // Valid participants
        if (validation.validUsers.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(AppSizes.sm),
            decoration: BoxDecoration(
              color: AppColors.success.withAlpha((0.1 * 255).toInt()),
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.success, size: 16),
                const SizedBox(width: AppSizes.xs),
                Text('${validation.validUsers.length} valid participants'),
              ],
            ),
          ),

        // Invalid participants
        if (validation.invalidUsers.isNotEmpty) ...[
          const SizedBox(height: AppSizes.xs),
          Container(
            padding: const EdgeInsets.all(AppSizes.sm),
            decoration: BoxDecoration(
              color: AppColors.error.withAlpha((0.1 * 255).toInt()),
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.error_outline, color: AppColors.error, size: 16),
                    const SizedBox(width: AppSizes.xs),
                    Text(
                        '${validation.invalidUsers.length} users not found in master list:'),
                  ],
                ),
                const SizedBox(height: AppSizes.xs),
                Text(
                  validation.invalidUsers.join(', '),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.error),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _createSession() async {
  if (!_formKey.currentState!.validate()) return;
  
  setState(() => _isCreating = true);
  
  try {
    final databaseService = context.read<DatabaseService>();
    
    // CREATE THESE DATETIME OBJECTS - THIS WAS MISSING
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

    // Validate session duration
    final duration = endDateTime.difference(startDateTime);
    if (duration.inMinutes < 15) {
      AppHelpers.showWarningToast('Session must be at least 15 minutes long');
      return;
    }

    if (duration.inHours > 12) {
      AppHelpers.showWarningToast('Session cannot be longer than 12 hours');
      return;
    }

    // Create session with academic year
    final sessionId = await databaseService.createSessionWithParticipants(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty 
          ? null 
          : _descriptionController.text.trim(),
      startDateTime: startDateTime,
      endDateTime: endDateTime,
      academicYear: _academicYearController.text.trim(),
      semester: _selectedSemester,
      departmentId: _currentUser!.departmentId!,
      createdBy: _currentUser!.id,
      gpsValidationEnabled: _gpsValidationEnabled,
      participantUserIds: _participantValidation?.validUsers,
    );
    
    if (mounted) {
      AppHelpers.showSuccessToast(
        _participantValidation != null
            ? 'Session created with ${_participantValidation!.validUsers.length} participants!'
            : 'Session created successfully!'
      );
      Navigator.pop(context);
    }
  } catch (e) {
    AppHelpers.debugError('Create session error: $e');
    if (mounted) {
      AppHelpers.showErrorToast('Failed to create session');
    }
  } finally {
    if (mounted) setState(() => _isCreating = false);
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Session'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Session Details Section
              _buildSectionHeader('Session Details', theme),
              const SizedBox(height: AppSizes.md),

              CustomTextField(
                label: 'Session Name',
                hint: 'Enter session name',
                controller: _nameController,
                validator: (value) =>
                    AppHelpers.validateRequired(value, 'Session name'),
                prefixIcon: Icons.event,
              ),

              const SizedBox(height: AppSizes.lg),

              CustomTextField(
                label: 'Description (Optional)',
                hint: 'Enter session description',
                controller: _descriptionController,
                maxLines: 3,
                prefixIcon: Icons.description,
              ),

              const SizedBox(height: AppSizes.xl),

              // Academic Year Section
              _buildSectionHeader('Academic Year', theme),
              const SizedBox(height: AppSizes.md),

              if (_academicYears.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSizes.md),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    border:
                        Border.all(color: AppColors.warning.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning,
                        color: AppColors.warning,
                        size: AppSizes.iconSm,
                      ),
                      const SizedBox(width: AppSizes.sm),
                      Expanded(
                        child: Text(
                          'No academic years found. Please contact your institute admin.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                DropdownButtonFormField<AcademicYearModel>(
                  value: _selectedAcademicYear,
                  decoration: const InputDecoration(
                    labelText: 'Academic Year',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  items: _academicYears.map((year) {
                    return DropdownMenuItem(
                      value: year,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            year.displayLabel,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${AppHelpers.formatDate(year.startDate)} - ${AppHelpers.formatDate(year.endDate)}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (year) {
                    setState(() => _selectedAcademicYear = year);
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Please select an academic year';
                    }
                    return null;
                  },
                ),

              const SizedBox(height: AppSizes.xl),

              // Schedule Section
              _buildSectionHeader('Schedule', theme),
              const SizedBox(height: AppSizes.md),

              // Date Selection
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Session Date',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_month),
                    suffixIcon: Icon(Icons.arrow_drop_down),
                  ),
                  child: Text(
                    AppHelpers.formatDate(_selectedDate,
                        format: AppFormats.dateFull),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),

              const SizedBox(height: AppSizes.lg),

              // Time Selection
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _selectStartTime,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Start Time',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.access_time),
                          suffixIcon: Icon(Icons.arrow_drop_down),
                        ),
                        child: Text(
                          _startTime.format(context),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: InkWell(
                      onTap: _selectEndTime,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'End Time',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.access_time_filled),
                          suffixIcon: Icon(Icons.arrow_drop_down),
                        ),
                        child: Text(
                          _endTime.format(context),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSizes.sm),

              // Duration Display
              Container(
                padding: const EdgeInsets.all(AppSizes.sm),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: AppSizes.iconSm,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    Text(
                      'Duration: ${_getDurationText()}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSizes.xl),

              // Settings Section
              _buildSectionHeader('Settings', theme),
              const SizedBox(height: AppSizes.md),

              SwitchListTile(
                title: const Text(
                  'GPS Validation',
                  style: TextStyle(color: Colors.black),
                ),
                subtitle: const Text(
                  'Require students to be within institute location',
                  style: TextStyle(color: Colors.black54),
                ),
                value: _gpsValidationEnabled,
                onChanged: (value) {
                  setState(() => _gpsValidationEnabled = value);
                },
                secondary: const Icon(Icons.location_on),
              ),

              const SizedBox(height: AppSizes.xxxl),

              _buildSectionHeader('Participants (Optional)', theme),
              const SizedBox(height: AppSizes.md),

              // CSV Upload Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.people, color: AppColors.info),
                          const SizedBox(width: AppSizes.sm),
                          Text('Upload Participant List',
                              style: theme.textTheme.titleMedium),
                        ],
                      ),
                      const SizedBox(height: AppSizes.sm),
                      Text(
                        'Upload a CSV with User IDs to enroll specific students. Leave empty to allow all department students.',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSizes.md),
                      if (_selectedParticipantsFile == null)
                        CustomButton(
                          text: 'Choose CSV File',
                          onPressed: _pickParticipantsFile,
                          icon: Icons.upload_file,
                          isOutlined: true,
                        )
                      else
                        Column(
                          children: [
                            ListTile(
                              leading: Icon(Icons.insert_drive_file,
                                  color: AppColors.success),
                              title: Text(_selectedParticipantsFile!.fileName),
                              subtitle: Text(
                                  '${_participantValidation?.validCount ?? 0} valid participants'),
                              trailing: IconButton(
                                onPressed: () => setState(() {
                                  _selectedParticipantsFile = null;
                                  _participantValidation = null;
                                }),
                                icon: Icon(Icons.close),
                              ),
                            ),

                            // Show validation results
                            if (_participantValidation != null)
                              _buildParticipantValidation(theme),
                          ],
                        ),
                    ],
                  ),
                ),
              ),

              // Create Button
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  text: 'Create Session',
                  onPressed: _academicYears.isNotEmpty ? _createSession : null,
                  isLoading: _isCreating,
                  icon: Icons.add,
                ),
              ),

              const SizedBox(height: AppSizes.lg),

              // Info Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSizes.md),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                  border: Border.all(color: AppColors.info.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info,
                      color: AppColors.info,
                      size: AppSizes.iconSm,
                    ),
                    const SizedBox(width: AppSizes.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Session Information',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: AppColors.info,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppSizes.xs),
                          Text(
                            '• Students can mark attendance during the session time\n'
                            '• QR codes will be generated for student scanning\n'
                            '• GPS validation helps prevent proxy attendance\n'
                            '• You can also manually mark attendance',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.info,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: AppSizes.sm),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }

  String _getDurationText() {
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    final durationMinutes = endMinutes - startMinutes;

    if (durationMinutes <= 0) {
      return 'Invalid duration';
    }

    final hours = durationMinutes ~/ 60;
    final minutes = durationMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

void _showCsvFormatInfo() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('CSV Format'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CSV file should contain one column:'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'user_id\nSTU001\nSTU002\nSTU003',
              style: TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          const Text('• First row should be header: user_id\n• Each row contains one User ID\n• User IDs must exist in your department'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}

}

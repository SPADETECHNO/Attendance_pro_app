import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attendance_pro_app/services/auth_service.dart';
import 'package:attendance_pro_app/services/database_service.dart';
import 'package:attendance_pro_app/services/csv_service.dart';
import 'package:attendance_pro_app/widgets/loading_widget.dart';
import 'package:attendance_pro_app/widgets/custom_button.dart';
import 'package:attendance_pro_app/utils/constants.dart';
import 'package:attendance_pro_app/utils/helpers.dart';
import 'package:attendance_pro_app/models/user_model.dart';
import 'package:attendance_pro_app/models/department_model.dart';
import 'package:attendance_pro_app/constants/app_constants.dart';

class UploadCsvScreen extends StatefulWidget {
  const UploadCsvScreen({super.key});

  @override
  State<UploadCsvScreen> createState() => _UploadCsvScreenState();
}

class _UploadCsvScreenState extends State<UploadCsvScreen> {
  UserModel? _currentUser;
  List<DepartmentModel> _departments = [];
  DepartmentModel? _selectedDepartment;
  
  CsvFileResult? _selectedFile;
  List<Map<String, dynamic>> _csvData = [];
  CsvValidationResult? _validationResult;
  
  bool _isLoading = true;
  bool _isProcessing = false;
  bool _showValidationResults = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final authService = context.read<AuthService>();
      final databaseService = context.read<DatabaseService>();

      final user = await authService.getCurrentUserProfile();
      if (user == null || user.instituteId == null) return;

      final departments = await databaseService.getDepartmentsByInstitute(user.instituteId!);

      setState(() {
        _currentUser = user;
        _departments = departments;
        _isLoading = false;
      });
    } catch (e) {
      AppHelpers.debugError('Load CSV upload data error: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickCsvFile() async {
    try {
      final file = await CsvService.pickCsvFile();
      if (file == null) return;

      setState(() {
        _selectedFile = file;
        _csvData = [];
        _validationResult = null;
        _showValidationResults = false;
      });

      // Parse CSV immediately
      await _parseCsvFile();
    } catch (e) {
      AppHelpers.debugError('Pick CSV file error: $e');
      AppHelpers.showErrorToast(e.toString());
    }
  }

  Future<void> _parseCsvFile() async {
    if (_selectedFile == null) return;

    setState(() => _isProcessing = true);

    try {
      // Parse CSV content
      final data = CsvService.parseUsersCsv(_selectedFile!.content);
      
      // Validate data
      final validation = CsvService.validateUsersData(data);

      setState(() {
        _csvData = data;
        _validationResult = validation;
        _showValidationResults = true;
        _isProcessing = false;
      });

      if (validation.isValid) {
        AppHelpers.showSuccessToast('CSV file parsed successfully! ${validation.validRows} valid records found.');
      } else {
        AppHelpers.showWarningToast('CSV file has ${validation.errorCount} errors. Please review and fix them.');
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      AppHelpers.debugError('Parse CSV error: $e');
      AppHelpers.showErrorToast('Failed to parse CSV file: ${e.toString()}');
    }
  }

  Future<void> _uploadUsers() async {
    if (_selectedDepartment == null) {
      AppHelpers.showWarningToast('Please select a department');
      return;
    }

    if (_validationResult == null || !_validationResult!.isValid) {
      AppHelpers.showWarningToast('Please fix all validation errors first');
      return;
    }

    final databaseService = context.read<DatabaseService>();
    final academicYears = await databaseService.getAcademicYears(_currentUser!.instituteId!);
    final currentYear = academicYears.isNotEmpty
        ? academicYears.firstWhere((year) => year.isCurrent, orElse: () => academicYears.first)
        : null;

    if (currentYear == null) {
      AppHelpers.showWarningToast('No current academic year set. Please create one first.');
      return;
    }

    final confirmed = await AppHelpers.showConfirmDialog(
      context,
      title: 'Upload Users',
      message: 'Are you sure you want to upload ${_validationResult!.validRows} users? '
          'They will be assigned to academic year: ${currentYear.displayLabel}',
    );

    if (!confirmed) return;

    setState(() => _isProcessing = true);

    try {
      final authService = context.read<AuthService>();
      
      int successCount = 0;
      int errorCount = 0;
      final errors = <String>[];

      // Process users in batches
      for (int i = 0; i < _csvData.length; i += AppConstants.userCreationBatchSize) {
        final batch = _csvData.skip(i).take(AppConstants.userCreationBatchSize).toList();
        
        for (final userData in batch) {
          try {
            await authService.createUserAccount(
              email: userData['email'],
              userId: userData['user_id'],
              name: userData['name'],
              role: AppConstants.userRole,
              phone: userData['phone']?.toString().trim().isEmpty == true 
                  ? null 
                  : userData['phone'],
              instituteId: _currentUser!.instituteId!,
              departmentId: _selectedDepartment!.id,
              academicYearId: currentYear.id,
            );
            successCount++;
          } catch (e) {
            errorCount++;
            final rowNumber = userData['_row_number'] ?? 'Unknown';
            errors.add('Row $rowNumber: ${e.toString()}');
          }
        }

        // Add small delay between batches
        if (i + AppConstants.userCreationBatchSize < _csvData.length) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      setState(() => _isProcessing = false);

      if (errorCount == 0) {
        AppHelpers.showSuccessToast('All $successCount users uploaded successfully!');
        
        // Show success dialog with next steps
        _showUploadSuccessDialog(successCount);
        
        // Reset form
        setState(() {
          _selectedFile = null;
          _csvData = [];
          _validationResult = null;
          _showValidationResults = false;
          _selectedDepartment = null;
        });
      } else {
        AppHelpers.showWarningToast('$successCount successful, $errorCount failed');
        _showUploadErrorsDialog(successCount, errors);
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      AppHelpers.debugError('Upload users error: $e');
      AppHelpers.showErrorToast('Failed to upload users');
    }
  }

  void _showUploadSuccessDialog(int successCount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSizes.sm),
              decoration: BoxDecoration(
                color: AppColors.success.withAlpha((0.1 * 255).toInt()),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: AppColors.success,
                size: AppSizes.iconMd,
              ),
            ),
            const SizedBox(width: AppSizes.md),
            const Text('Upload Successful!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$successCount users have been successfully uploaded.'),
            const SizedBox(height: AppSizes.md),
            const Text('Next steps:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSizes.sm),
            const Text('• Users have been created with temporary passwords'),
            const Text('• Share login credentials with users'),
            const Text('• Users will be prompted to change passwords on first login'),
            const Text('• Users can then start marking attendance'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  void _showUploadErrorsDialog(int successCount, List<String> errors) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upload Results'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$successCount users uploaded successfully.'),
              const SizedBox(height: AppSizes.md),
              if (errors.isNotEmpty) ...[
                Text('${errors.length} errors occurred:'),
                const SizedBox(height: AppSizes.sm),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: errors.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSizes.xs),
                      child: Text(
                        errors[index],
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _downloadSampleCsv() async {
    try {
      final sampleCsv = CsvService.generateSampleUsersCsv();
      final fileName = 'sample_users_${DateTime.now().millisecondsSinceEpoch}.csv';
      
      // In a real app, you would save this to the downloads folder
      // For now, we'll just show the content in a dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sample CSV Format'),
          content: SingleChildScrollView(
            child: Text(
              sampleCsv,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                AppHelpers.showInfoToast('Sample CSV content shown above');
              },
              child: const Text('Copy Format'),
            ),
          ],
        ),
      );
    } catch (e) {
      AppHelpers.showErrorToast('Failed to generate sample CSV');
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
        title: const Text('Upload CSV'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        actions: [
          IconButton(
            onPressed: _downloadSampleCsv,
            icon: const Icon(Icons.download),
            tooltip: 'Download Sample CSV',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Instructions Card
            Card(
              color: AppColors.info.withAlpha((0.1 * 255).toInt()),
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info,
                          color: AppColors.info,
                          size: AppSizes.iconMd,
                        ),
                        const SizedBox(width: AppSizes.sm),
                        Text(
                          'CSV Upload Instructions',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.info,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.sm),
                    const Text(
                      '• CSV file must have headers: user_id, name, email, phone, department\n'
                      '• Maximum 1,000 users per upload\n'
                      '• Temporary passwords will be generated automatically\n'
                      '• Users will need to change password on first login',
                      style: TextStyle(height: 1.5),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSizes.xl),

            // Department Selection
            if (_departments.isNotEmpty) ...[
              Text(
                'Select Department',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSizes.sm),
              DropdownButtonFormField<DepartmentModel>(
                value: _selectedDepartment,
                decoration: const InputDecoration(
                  labelText: 'Department',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.domain),
                ),
                items: _departments.map((dept) {
                  return DropdownMenuItem(
                    value: dept,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dept.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (dept.hasDescription)
                          Text(
                            dept.description!,
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (dept) {
                  setState(() => _selectedDepartment = dept);
                },
              ),
              const SizedBox(height: AppSizes.xl),
            ],

            // File Selection
            Text(
              'CSV File Selection',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSizes.md),

            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'Choose CSV File',
                    onPressed: _pickCsvFile,
                    icon: Icons.upload_file,
                    isOutlined: true,
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: CustomButton(
                    text: 'Sample CSV',
                    onPressed: _downloadSampleCsv,
                    icon: Icons.download,
                    isOutlined: true,
                  ),
                ),
              ],
            ),

            if (_selectedFile != null) ...[
              const SizedBox(height: AppSizes.md),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.insert_drive_file),
                  title: Text(_selectedFile!.fileName),
                  subtitle: Text(
                    'Size: ${AppHelpers.formatFileSize(_selectedFile!.size)}',
                  ),
                  trailing: IconButton(
                    onPressed: () {
                      setState(() {
                        _selectedFile = null;
                        _csvData = [];
                        _validationResult = null;
                        _showValidationResults = false;
                      });
                    },
                    icon: const Icon(Icons.close),
                  ),
                ),
              ),
            ],

            if (_isProcessing) ...[
              const SizedBox(height: AppSizes.xl),
              const LoadingWidget(message: 'Processing CSV file...'),
            ],

            if (_showValidationResults && _validationResult != null) ...[
              const SizedBox(height: AppSizes.xl),
              _buildValidationResults(theme),
            ],

            if (_validationResult?.isValid == true && _selectedDepartment != null) ...[
              const SizedBox(height: AppSizes.xl),
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  text: 'Upload ${_validationResult!.validRows} Users',
                  onPressed: _isProcessing ? null : _uploadUsers,
                  isLoading: _isProcessing,
                  icon: Icons.cloud_upload,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildValidationResults(ThemeData theme) {
    final result = _validationResult!;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  result.isValid ? Icons.check_circle : Icons.error,
                  color: result.isValid ? AppColors.success : AppColors.error,
                ),
                const SizedBox(width: AppSizes.sm),
                Text(
                  'Validation Results',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: result.isValid ? AppColors.success : AppColors.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.md),
            
            // Statistics
            Row(
              children: [
                Expanded(
                  child: _buildStatChip(
                    'Total Rows',
                    result.totalRows.toString(),
                    AppColors.info,
                    theme,
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: _buildStatChip(
                    'Valid',
                    result.validRows.toString(),
                    AppColors.success,
                    theme,
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: _buildStatChip(
                    'Errors',
                    result.errorCount.toString(),
                    AppColors.error,
                    theme,
                  ),
                ),
              ],
            ),

            if (result.errors.isNotEmpty) ...[
              const SizedBox(height: AppSizes.md),
              Text(
                'Errors to Fix:',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: AppSizes.sm),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: result.errors.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSizes.xs),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: AppSizes.iconSm,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: AppSizes.xs),
                        Expanded(
                          child: Text(
                            result.errors[index],
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            if (result.warnings.isNotEmpty) ...[
              const SizedBox(height: AppSizes.md),
              Text(
                'Warnings:',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(height: AppSizes.sm),
              ...result.warnings.map((warning) => Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber,
                      size: AppSizes.iconSm,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: AppSizes.xs),
                    Expanded(
                      child: Text(
                        warning,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sm,
        vertical: AppSizes.xs,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha((0.1 * 255).toInt()),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

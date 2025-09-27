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

class UploadCsvScreen extends StatefulWidget {
  const UploadCsvScreen({super.key});

  @override
  State<UploadCsvScreen> createState() => _UploadCsvScreenState();
}

class _UploadCsvScreenState extends State<UploadCsvScreen> {
  UserModel? _currentUser;
  CsvFileResult? _selectedFile;
  List<Map<String, dynamic>> _csvData = [];
  CsvValidationResult? _validationResult;
  bool _isLoading = true;
  bool _isProcessing = false;
  bool _showValidationResults = false;
  bool _sendEmailInvitations = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final authService = context.read<AuthService>();
      final user = await authService.getCurrentUserProfile();
      
      if (mounted && user?.instituteId != null) {
        setState(() {
          _currentUser = user;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppHelpers.debugError('Load CSV upload data error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
      final data = CsvService.parseInstituteMasterListCsv(_selectedFile!.content);
      final validation = CsvService.validateInstituteMasterListData(data);

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
    if (_validationResult == null || !_validationResult!.isValid) {
      AppHelpers.showWarningToast('Please fix all validation errors first');
      return;
    }

    final confirmed = await AppHelpers.showConfirmDialog(
      context,
      title: 'Upload Users to Master List',
      message: 'Are you sure you want to upload ${_validationResult!.validRows} users to the institute master list?',
    );
    if (!confirmed) return;

    setState(() => _isProcessing = true);
    try {
      final databaseService = context.read<DatabaseService>();
      
      if (_sendEmailInvitations) {
        // Process individually for email invitations
        int successCount = 0;
        int errorCount = 0;
        final errors = <String>[];

        for (final userData in _csvData) {
          try {
            await databaseService.addToInstituteMasterList(
              userId: userData['user_id'],
              name: userData['name'],
              email: userData['email'],
              phone: userData['phone']?.toString().trim().isEmpty == true ? null : userData['phone'],
              instituteId: _currentUser!.instituteId!,
              departmentId: userData['department_id']?.toString().trim().isEmpty == true ? null : userData['department_id'],
              academicYearId: userData['academic_year_id']?.toString().trim().isEmpty == true ? null : userData['academic_year_id'],
              createdBy: _currentUser!.id,
              sendEmailInvitation: true,
            );
            successCount++;
          } catch (e) {
            errorCount++;
            final rowNumber = userData['_row_number'] ?? 'Unknown';
            errors.add('Row $rowNumber: ${e.toString()}');
          }
        }

        if (mounted) {
          setState(() => _isProcessing = false);
          if (errorCount == 0) {
            AppHelpers.showSuccessToast('All $successCount users uploaded successfully!');
            _showUploadSuccessDialog(successCount);
            _resetForm();
          } else {
            AppHelpers.showWarningToast('$successCount successful, $errorCount failed');
            _showUploadErrorsDialog(successCount, errors);
          }
        }
      } else {
        // Bulk insert for no email invitations
        await databaseService.bulkAddToInstituteMasterList(
          _csvData,
          _currentUser!.instituteId!,
          _currentUser!.id,
          false, // Will use createUserAccount without invitation
        );

        if (mounted) {
          setState(() => _isProcessing = false);
          AppHelpers.showSuccessToast('All ${_csvData.length} users uploaded successfully!');
          _showUploadSuccessDialog(_csvData.length);
          _resetForm();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        AppHelpers.debugError('Upload users error: $e');
        AppHelpers.showErrorToast('Failed to upload users');
      }
    }
  }

  void _resetForm() {
    setState(() {
      _selectedFile = null;
      _csvData = [];
      _validationResult = null;
      _showValidationResults = false;
    });
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
            Text('$successCount users have been successfully added to the institute master list.'),
            const SizedBox(height: AppSizes.md),
            Text(_sendEmailInvitations 
                ? '• Invitation emails have been sent to all users'
                : '• Users have been added to master list without emails'),
            const SizedBox(height: AppSizes.md),
            const Text(
              'Next steps:\n'
              '• Users can now be assigned to departments by admins\n'
              '• Department admins can create sessions and include these users\n'
              '• View and manage users in the Master List section',
              style: TextStyle(fontSize: 12),
            ),
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
      final sampleCsv = CsvService.generateSampleInstituteMasterListCsv();
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

  Widget _buildEmailToggleCard(ThemeData theme) {
    return Card(
      color: AppColors.primary.withAlpha((0.05 * 255).toInt()),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.email,
                  color: AppColors.primary,
                  size: AppSizes.iconMd,
                ),
                const SizedBox(width: AppSizes.sm),
                Text(
                  'Email Invitations',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
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
                        _sendEmailInvitations 
                            ? 'Send email invitations to users'
                            : 'Add to master list without sending emails',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: AppSizes.xs),
                      Text(
                        _sendEmailInvitations
                            ? 'Users will receive login credentials via email automatically'
                            : 'You will need to share login credentials manually when needed',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha((0.7 * 255).toInt()),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Switch.adaptive(
                  value: _sendEmailInvitations,
                  onChanged: (value) {
                    setState(() {
                      _sendEmailInvitations = value;
                    });
                  },
                  activeColor: AppColors.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
        title: const Text('Upload to Master List'),
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
                          'Institute Master List Upload',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.info,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.sm),
                    const Text(
                      '• CSV file must have headers: user_id, name, email, phone, department (optional)\n'
                      '• Maximum 1,000 users per upload\n'
                      '• Users will be added to institute master list\n'
                      '• Department field is optional for organizational purposes\n'
                      '• Users can be assigned to specific departments later by department admins',
                      style: TextStyle(height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSizes.xl),

            // Email Toggle Card
            _buildEmailToggleCard(theme),
            const SizedBox(height: AppSizes.xl),

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

            if (_validationResult?.isValid == true) ...[
              const SizedBox(height: AppSizes.xl),
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  text: _sendEmailInvitations 
                      ? 'Add ${_validationResult!.validRows} Users (With Email)'
                      : 'Add ${_validationResult!.validRows} Users (No Email)',
                  onPressed: _isProcessing ? null : _uploadUsers,
                  isLoading: _isProcessing,
                  icon: _sendEmailInvitations ? Icons.email : Icons.cloud_upload,
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

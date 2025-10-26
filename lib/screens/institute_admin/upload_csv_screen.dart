// lib/screens/institute_admin/upload_csv_screen.dart

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

    final confirmed = await _showUploadConfirmationDialog();
    if (!confirmed) return;

    setState(() => _isProcessing = true);
    try {
      final databaseService = context.read<DatabaseService>();
      if (_sendEmailInvitations) {
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
        await databaseService.bulkAddToInstituteMasterList(
          _csvData,
          _currentUser!.instituteId!,
          _currentUser!.id,
          false,
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

  Future<bool> _showUploadConfirmationDialog() async {
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
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              child: Icon(
                Icons.cloud_upload_rounded,
                color: AppColors.warning,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            Text(
              'Upload Users to Master List',
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
                '${_validationResult!.validRows} users will be uploaded',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.gray700,
                ),
              ),
            ),
            const SizedBox(height: AppSizes.md),
            Text(
              'Are you sure you want to upload ${_validationResult!.validRows} users to the institute master list?',
              style: TextStyle(
                color: AppColors.gray700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            Container(
              padding: const EdgeInsets.all(AppSizes.sm),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              child: Row(
                children: [
                  Icon(
                    _sendEmailInvitations ? Icons.email : Icons.no_encryption,
                    color: AppColors.info,
                    size: 16,
                  ),
                  const SizedBox(width: AppSizes.xs),
                  Expanded(
                    child: Text(
                      _sendEmailInvitations
                          ? 'Email invitations will be sent to all users'
                          : 'Users will be added without email notifications',
                      style: TextStyle(
                        color: AppColors.info,
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
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
              elevation: 2,
            ),
            child: const Text('Upload'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showUploadSuccessDialog(int successCount) {
    showDialog(
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
                Icons.check_circle_rounded,
                color: AppColors.success,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            Text(
              'Upload Successful!',
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
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              child: Text(
                '$successCount users successfully added',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.success,
                ),
              ),
            ),
            const SizedBox(height: AppSizes.md),
            Text(
              '$successCount users have been successfully added to the institute master list.',
              style: TextStyle(
                color: AppColors.gray700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSizes.md),
            Row(
              children: [
                Icon(
                  _sendEmailInvitations ? Icons.email : Icons.group_add,
                  color: AppColors.info,
                  size: 16,
                ),
                const SizedBox(width: AppSizes.xs),
                Expanded(
                  child: Text(
                    _sendEmailInvitations
                        ? 'Invitation emails have been sent to all users'
                        : 'Users have been added to master list without emails',
                    style: TextStyle(
                      color: AppColors.info,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.md),
            Container(
              padding: const EdgeInsets.all(AppSizes.sm),
              decoration: BoxDecoration(
                color: AppColors.gray100,
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next steps:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.gray700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: AppSizes.xs),
                  Text(
                    '• Users can now be assigned to departments by admins\n'
                    '• Department admins can create sessions and include these users\n'
                    '• View and manage users in the Master List section',
                    style: TextStyle(
                      color: AppColors.gray600,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              elevation: 2,
            ),
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
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSizes.xs),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              child: Icon(
                Icons.warning_rounded,
                color: AppColors.warning,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            Text(
              'Upload Results',
              style: TextStyle(
                color: AppColors.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSizes.sm),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
                child: Text(
                  '$successCount users uploaded successfully',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.md),
              if (errors.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSizes.sm),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                  ),
                  child: Text(
                    '${errors.length} errors occurred',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.sm),
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: errors.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSizes.xs),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: AppColors.error,
                            size: 16,
                          ),
                          const SizedBox(width: AppSizes.xs),
                          Expanded(
                            child: Text(
                              errors[index],
                              style: TextStyle(
                                color: AppColors.error,
                                fontSize: 12,
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
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gray700,
              foregroundColor: Colors.white,
              elevation: 2,
            ),
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
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSizes.xs),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
                child: Icon(
                  Icons.file_download_rounded,
                  color: AppColors.info,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              Text(
                'Sample CSV Format',
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(maxHeight: 400),
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(AppSizes.sm),
                decoration: BoxDecoration(
                  color: AppColors.gray100,
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
                child: Text(
                  sampleCsv,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: AppColors.gray700,
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.gray600,
              ),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                AppHelpers.showInfoToast('Sample CSV format displayed above');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.info,
                foregroundColor: Colors.white,
                elevation: 2,
              ),
              child: const Text('Copy Format'),
            ),
          ],
        ),
      );
    } catch (e) {
      AppHelpers.showErrorToast('Failed to generate sample CSV');
    }
  }

  Widget _buildEmailToggleCard() {
    return Container(
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
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                child: Icon(
                  Icons.email,
                  color: AppColors.info,
                  size: AppSizes.iconMd,
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              Text(
                'Email Invitations',
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
                      _sendEmailInvitations
                          ? 'Send email invitations to users'
                          : 'Add to master list without sending emails',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSizes.xs),
                    Text(
                      _sendEmailInvitations
                          ? 'Users will receive login credentials via email automatically'
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
                value: _sendEmailInvitations,
                onChanged: (value) {
                  setState(() {
                    _sendEmailInvitations = value;
                  });
                },
                activeColor: AppColors.info,
              ),
            ],
          ),
        ],
      ),
    );
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
      appBar: AppBar(
        title: const Text(
          'Upload to Master List',
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
            onPressed: _downloadSampleCsv,
            icon: const Icon(Icons.download, color: Colors.white),
            tooltip: 'Download Sample CSV',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                          Icons.info,
                          color: AppColors.warning,
                          size: AppSizes.iconMd,
                        ),
                      ),
                      const SizedBox(width: AppSizes.sm),
                      Text(
                        'Institute Master List Upload',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSurface,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.sm),
                  Text(
                    '• CSV file must have headers: user_id, name, email, phone, department (optional)\n'
                    '• Maximum 1,000 users per upload\n'
                    '• Users will be added to institute master list\n'
                    '• Department field is optional for organizational purposes\n'
                    '• Users can be assigned to specific departments later by department admins',
                    style: TextStyle(
                      height: 1.5,
                      color: AppColors.gray700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.xl),

            _buildEmailToggleCard(),
            const SizedBox(height: AppSizes.xl),

            Text(
              'CSV File Selection',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: AppSizes.md),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickCsvFile,
                    icon: const Icon(Icons.upload_file, size: 16),
                    label: const Text('Choose CSV File'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gray700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _downloadSampleCsv,
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Sample CSV'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.info,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            if (_selectedFile != null) ...[
              const SizedBox(height: AppSizes.md),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                  border: Border.all(color: AppColors.gray200),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(AppSizes.sm),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    ),
                    child: const Icon(
                      Icons.insert_drive_file,
                      color: AppColors.success,
                    ),
                  ),
                  title: Text(
                    _selectedFile!.fileName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'Size: ${AppHelpers.formatFileSize(_selectedFile!.size)}',
                    style: TextStyle(color: AppColors.gray600),
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
                    icon: Icon(Icons.close, color: AppColors.gray600),
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
              _buildValidationResults(),
            ],
            if (_validationResult?.isValid == true) ...[
              const SizedBox(height: AppSizes.xl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _uploadUsers,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(_sendEmailInvitations ? Icons.email : Icons.cloud_upload, size: 16),
                  label: Text(
                    _sendEmailInvitations
                        ? 'Add ${_validationResult!.validRows} Users (With Email)'
                        : 'Add ${_validationResult!.validRows} Users (No Email)',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildValidationResults() {
    final result = _validationResult!;
    return Container(
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
                  color: (result.isValid ? AppColors.success : AppColors.error).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                child: Icon(
                  result.isValid ? Icons.check_circle : Icons.error,
                  color: result.isValid ? AppColors.success : AppColors.error,
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              Text(
                'Validation Results',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: result.isValid ? AppColors.success : AppColors.error,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          Row(
            children: [
              Expanded(
                child: _buildStatChip('Total Rows', result.totalRows.toString(), AppColors.info),
              ),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: _buildStatChip('Valid', result.validRows.toString(), AppColors.success),
              ),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: _buildStatChip('Errors', result.errorCount.toString(), AppColors.error),
              ),
            ],
          ),
          if (result.errors.isNotEmpty) ...[
            const SizedBox(height: AppSizes.md),
            Text(
              'Errors to Fix:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.error,
                fontSize: 14,
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
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 12,
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
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sm,
        vertical: AppSizes.xs,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

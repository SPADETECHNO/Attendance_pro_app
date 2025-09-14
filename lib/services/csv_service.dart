import 'dart:io';
import 'dart:convert';
import 'package:attendance_pro_app/utils/constants.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:attendance_pro_app/constants/app_constants.dart';
import 'package:attendance_pro_app/utils/helpers.dart';

class CsvService {
  /// Pick CSV file from device storage
  static Future<CsvFileResult?> pickCsvFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: AppConstants.allowedCsvExtensions,
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      final file = result.files.single;
      
      // Check file size
      if (file.size > AppConstants.maxCsvSize) {
        throw CsvException('File size exceeds ${AppHelpers.formatFileSize(AppConstants.maxCsvSize)}');
      }

      // Read file content
      String csvContent;
      if (file.path != null) {
        csvContent = await File(file.path!).readAsString();
      } else if (file.bytes != null) {
        csvContent = utf8.decode(file.bytes!);
      } else {
        throw CsvException('Unable to read file content');
      }

      return CsvFileResult(
        fileName: file.name,
        filePath: file.path,
        content: csvContent,
        size: file.size,
      );
    } catch (e) {
      AppHelpers.debugError('Pick CSV file error: $e');
      rethrow;
    }
  }

  /// Parse participant CSV (simple user_id format)
  static List<Map<String, dynamic>> parseParticipantCsv(String csvContent) {
    return parseCsvContent(
      csvContent,
      expectedHeaders: ['user_id'],
      hasHeaderRow: true,
    );
  }

  /// Parse CSV content to list of maps
  static List<Map<String, dynamic>> parseCsvContent(
    String csvContent, {
    List<String>? expectedHeaders,
    bool hasHeaderRow = true,
  }) {
    try {
      // Parse CSV content
      final List<List<dynamic>> rows = const CsvToListConverter().convert(
        csvContent,
        eol: '\n',
        fieldDelimiter: ',',
      );

      if (rows.isEmpty) {
        throw CsvException('CSV file is empty');
      }

      // Check if we have enough rows
      if (hasHeaderRow && rows.length < 2) {
        throw CsvException('CSV file must have at least one data row');
      }

      List<String> headers;
      List<List<dynamic>> dataRows;

      if (hasHeaderRow) {
        headers = rows[0].map((e) => e.toString().trim().toLowerCase()).toList();
        dataRows = rows.sublist(1);
      } else {
        if (expectedHeaders == null) {
          throw CsvException('Expected headers must be provided when CSV has no header row');
        }
        headers = expectedHeaders.map((e) => e.toLowerCase()).toList();
        dataRows = rows;
      }

      // Validate headers if expected headers provided
      if (expectedHeaders != null) {
        final expectedLower = expectedHeaders.map((e) => e.toLowerCase()).toList();
        for (final expectedHeader in expectedLower) {
          if (!headers.contains(expectedHeader)) {
            throw CsvException('Missing required column: $expectedHeader');
          }
        }
      }

      // Limit number of rows
      if (dataRows.length > AppConstants.maxCsvRows) {
        throw CsvException('CSV file exceeds maximum allowed rows (${AppConstants.maxCsvRows})');
      }

      // Convert to list of maps
      final List<Map<String, dynamic>> result = [];
      
      for (int i = 0; i < dataRows.length; i++) {
        final row = dataRows[i];
        final Map<String, dynamic> rowMap = {};
        
        for (int j = 0; j < headers.length && j < row.length; j++) {
          final value = row[j]?.toString().trim() ?? '';
          rowMap[headers[j]] = value;
        }
        
        // Skip empty rows
        if (rowMap.values.any((value) => value.toString().isNotEmpty)) {
          rowMap['_row_number'] = i + 2; // +2 because 1-indexed and header row
          result.add(rowMap);
        }
      }

      return result;
    } catch (e) {
      AppHelpers.debugError('Parse CSV content error: $e');
      if (e is CsvException) {
        rethrow;
      }
      throw CsvException('Failed to parse CSV: ${e.toString()}');
    }
  }

  /// Parse users CSV
  static List<Map<String, dynamic>> parseUsersCsv(String csvContent) {
    return parseCsvContent(
      csvContent,
      expectedHeaders: AppConstants.userCsvHeaders,
    );
  }

  /// Parse sessions CSV
  static List<Map<String, dynamic>> parseSessionsCsv(String csvContent) {
    return parseCsvContent(
      csvContent,
      expectedHeaders: AppConstants.sessionCsvHeaders,
    );
  }

  /// Convert list of maps to CSV content
  static String convertToCsv(
    List<Map<String, dynamic>> data,
    List<String> headers, {
    bool includeHeaders = true,
  }) {
    try {
      if (data.isEmpty) {
        return includeHeaders ? headers.join(',') : '';
      }

      final List<List<dynamic>> csvData = [];
      
      // Add headers if required
      if (includeHeaders) {
        csvData.add(headers);
      }

      // Add data rows
      for (final row in data) {
        final csvRow = headers.map((header) {
          final value = row[header];
          if (value == null) {
            return '';
          }
          // Handle special characters and commas
          final stringValue = value.toString();
          if (stringValue.contains(',') || 
              stringValue.contains('"') || 
              stringValue.contains('\n')) {
            return '"${stringValue.replaceAll('"', '""')}"';
          }
          return stringValue;
        }).toList();
        
        csvData.add(csvRow);
      }

      return const ListToCsvConverter().convert(csvData);
    } catch (e) {
      AppHelpers.debugError('Convert to CSV error: $e');
      throw CsvException('Failed to convert data to CSV: ${e.toString()}');
    }
  }

  /// Export attendance data to CSV
  static String exportAttendanceCsv(List<Map<String, dynamic>> attendanceData) {
    return convertToCsv(attendanceData, AppConstants.attendanceCsvHeaders);
  }

  /// Export users data to CSV
  static String exportUsersCsv(List<Map<String, dynamic>> usersData) {
    return convertToCsv(usersData, AppConstants.userCsvHeaders);
  }

  /// Save CSV file to device storage
  static Future<String> saveCsvFile({
    required String content,
    required String fileName,
    String? directory,
  }) async {
    try {
      Directory? targetDirectory;
      
      if (directory != null) {
        targetDirectory = Directory(directory);
      } else {
        targetDirectory = await getDownloadsDirectory() ?? 
                         await getApplicationDocumentsDirectory();
      }

      // Ensure directory exists
      if (!await targetDirectory.exists()) {
        await targetDirectory.create(recursive: true);
      }

      // Create file with timestamp if name already exists
      String finalFileName = fileName;
      if (!fileName.toLowerCase().endsWith('.csv')) {
        finalFileName = '$fileName.csv';
      }

      final file = File('${targetDirectory.path}/$finalFileName');
      
      // Add timestamp if file already exists
      int counter = 1;
      while (await file.exists()) {
        final nameWithoutExt = fileName.replaceAll('.csv', '');
        finalFileName = '${nameWithoutExt}_$counter.csv';
        counter++;
      }

      final finalFile = File('${targetDirectory.path}/$finalFileName');
      await finalFile.writeAsString(content);

      return finalFile.path;
    } catch (e) {
      AppHelpers.debugError('Save CSV file error: $e');
      throw CsvException('Failed to save CSV file: ${e.toString()}');
    }
  }

  /// Validate CSV data for users import
  static CsvValidationResult validateUsersData(List<Map<String, dynamic>> data) {
    final errors = <String>[];
    final warnings = <String>[];
    int validRows = 0;

    for (final row in data) {
      final rowNumber = row['_row_number'] ?? 0;
      bool hasErrors = false;

      // Validate required fields
      final userId = row['user_id']?.toString().trim() ?? '';
      final name = row['name']?.toString().trim() ?? '';
      final email = row['email']?.toString().trim() ?? '';

      if (userId.isEmpty) {
        errors.add('Row $rowNumber: User ID is required');
        hasErrors = true;
      } else if (!AppRegex.userId.hasMatch(userId)) {
        errors.add('Row $rowNumber: Invalid User ID format');
        hasErrors = true;
      }

      if (name.isEmpty) {
        errors.add('Row $rowNumber: Name is required');
        hasErrors = true;
      } else if (name.length < AppConstants.minNameLength) {
        errors.add('Row $rowNumber: Name too short');
        hasErrors = true;
      }

      if (email.isEmpty) {
        errors.add('Row $rowNumber: Email is required');
        hasErrors = true;
      } else if (!AppRegex.email.hasMatch(email)) {
        errors.add('Row $rowNumber: Invalid email format');
        hasErrors = true;
      }

      // Validate optional phone
      final phone = row['phone']?.toString().trim() ?? '';
      if (phone.isNotEmpty && !AppRegex.phone.hasMatch(phone)) {
        warnings.add('Row $rowNumber: Invalid phone format');
      }

      if (!hasErrors) {
        validRows++;
      }
    }

    return CsvValidationResult(
      isValid: errors.isEmpty,
      totalRows: data.length,
      validRows: validRows,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Generate sample users CSV
  static String generateSampleUsersCsv() {
    final sampleData = [
      {
        'user_id': 'STU001',
        'name': 'John Doe',
        'email': 'john.doe@example.com',
        'phone': '+1234567890',
        'department': 'Computer Science',
      },
      {
        'user_id': 'STU002',
        'name': 'Jane Smith',
        'email': 'jane.smith@example.com',
        'phone': '+1234567891',
        'department': 'Information Technology',
      },
    ];

    return convertToCsv(sampleData, AppConstants.userCsvHeaders);
  }

  /// Get CSV file info
  static Future<CsvFileInfo> getCsvFileInfo(String filePath) async {
    try {
      final file = File(filePath);
      final stat = await file.stat();
      final content = await file.readAsString();
      final lines = content.split('\n').where((line) => line.trim().isNotEmpty).length;

      return CsvFileInfo(
        path: filePath,
        name: file.path.split('/').last,
        size: stat.size,
        lastModified: stat.modified,
        lineCount: lines,
        isValid: lines > 1, // At least header + 1 data row
      );
    } catch (e) {
      AppHelpers.debugError('Get CSV file info error: $e');
      rethrow;
    }
  }

  static parseParticipantsCsv(String content) {}
}

// ================== RESULT CLASSES ==================

class CsvFileResult {
  final String fileName;
  final String? filePath;
  final String content;
  final int size;

  CsvFileResult({
    required this.fileName,
    this.filePath,
    required this.content,
    required this.size,
  });

  @override
  String toString() {
    return 'CsvFileResult(fileName: $fileName, size: ${AppHelpers.formatFileSize(size)})';
  }
}

class CsvValidationResult {
  final bool isValid;
  final int totalRows;
  final int validRows;
  final List<String> errors;
  final List<String> warnings;

  CsvValidationResult({
    required this.isValid,
    required this.totalRows,
    required this.validRows,
    required this.errors,
    required this.warnings,
  });

  int get errorCount => errors.length;
  int get warningCount => warnings.length;
  int get invalidRows => totalRows - validRows;

  @override
  String toString() {
    return 'CsvValidationResult(valid: $isValid, total: $totalRows, valid: $validRows, errors: $errorCount)';
  }
}

class CsvFileInfo {
  final String path;
  final String name;
  final int size;
  final DateTime lastModified;
  final int lineCount;
  final bool isValid;

  CsvFileInfo({
    required this.path,
    required this.name,
    required this.size,
    required this.lastModified,
    required this.lineCount,
    required this.isValid,
  });

  @override
  String toString() {
    return 'CsvFileInfo(name: $name, size: ${AppHelpers.formatFileSize(size)}, lines: $lineCount)';
  }
}

/// Custom exception for CSV operations
class CsvException implements Exception {
  final String message;
  CsvException(this.message);
  
  @override
  String toString() => 'CsvException: $message';
}

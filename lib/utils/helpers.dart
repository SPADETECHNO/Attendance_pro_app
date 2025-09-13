import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:attendance_pro_app/utils/constants.dart';

class AppHelpers {
  // ================== DATE & TIME HELPERS ==================
  
  /// Format date with custom format
  static String formatDate(DateTime date, {String format = AppFormats.dateMedium}) {
    return DateFormat(format).format(date);
  }
  
  /// Format time with 12-hour format
  static String formatTime(DateTime time, {bool use24Hour = false}) {
    return DateFormat(use24Hour ? AppFormats.time24 : AppFormats.time12).format(time);
  }
  
  /// Format date and time together
  static String formatDateTime(DateTime dateTime) {
    return DateFormat(AppFormats.dateTime).format(dateTime);
  }
  
  /// Get relative time (e.g., "2 hours ago", "Just now")
  static String getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '${years} year${years == 1 ? '' : 's'} ${AppStrings.ago}';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '${months} month${months == 1 ? '' : 's'} ${AppStrings.ago}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ${AppStrings.ago}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ${AppStrings.ago}';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ${AppStrings.ago}';
    } else {
      return AppStrings.justNow;
    }
  }
  
  /// Get duration between two dates
  static String getDuration(DateTime start, DateTime end) {
    final duration = end.difference(start);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
  
  /// Get time remaining until target date
  static String getTimeRemaining(DateTime targetTime) {
    final now = DateTime.now();
    final difference = targetTime.difference(now);
    
    if (difference.isNegative) {
      return AppStrings.ended;
    }
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ${difference.inHours % 24}h ${AppStrings.remaining}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ${difference.inMinutes % 60}m ${AppStrings.remaining}';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ${AppStrings.remaining}';
    } else {
      return AppStrings.startingSoon;
    }
  }
  
  /// Check if date is today
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && 
           date.month == now.month && 
           date.day == now.day;
  }
  
  /// Check if date is yesterday
  static bool isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year && 
           date.month == yesterday.month && 
           date.day == yesterday.day;
  }
  
  // ================== SESSION STATUS HELPERS ==================
  
  /// Get session status based on start and end times
  static String getSessionStatus(DateTime startTime, DateTime endTime) {
    final now = DateTime.now();
    
    if (now.isBefore(startTime)) {
      return AppStrings.upcoming;
    } else if (now.isAfter(startTime) && now.isBefore(endTime)) {
      return AppStrings.live;
    } else {
      return AppStrings.ended;
    }
  }
  
  /// Get session status color
  static Color getSessionStatusColor(DateTime startTime, DateTime endTime) {
    final status = getSessionStatus(startTime, endTime);
    
    switch (status) {
      case AppStrings.live:
        return AppColors.live;
      case AppStrings.upcoming:
        return AppColors.upcoming;
      case AppStrings.ended:
        return AppColors.ended;
      default:
        return AppColors.gray500;
    }
  }
  
  /// Get session status icon
  static IconData getSessionStatusIcon(DateTime startTime, DateTime endTime) {
    final status = getSessionStatus(startTime, endTime);
    
    switch (status) {
      case AppStrings.live:
        return Icons.live_tv;
      case AppStrings.upcoming:
        return Icons.schedule;
      case AppStrings.ended:
        return Icons.history;
      default:
        return Icons.event;
    }
  }
  
  // ================== ATTENDANCE STATUS HELPERS ==================
  
  /// Get attendance status color
  static Color getAttendanceStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return AppColors.present;
      case 'absent':
        return AppColors.absent;
      case 'pending':
        return AppColors.pending;
      default:
        return AppColors.notMarked;
    }
  }
  
  /// Get attendance status icon
  static IconData getAttendanceStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return Icons.check_circle;
      case 'absent':
        return Icons.cancel;
      case 'pending':
        return Icons.pending;
      default:
        return Icons.help_outline;
    }
  }
  
  // ================== ACCOUNT STATUS HELPERS ==================
  
  /// Get account status color with temp password consideration
  static Color getAccountStatusColor(String status, bool tempPasswordUsed) {
    if (tempPasswordUsed) {
      return AppColors.warning;
    }
    
    switch (status.toLowerCase()) {
      case 'active':
        return AppColors.success;
      case 'inactive':
        return AppColors.error;
      default:
        return AppColors.gray500;
    }
  }
  
  /// Get account status display text
  static String getAccountStatusText(String status, bool tempPasswordUsed) {
    if (tempPasswordUsed) {
      return 'Password Change Required';
    }
    
    return status.toTitleCase();
  }
  
  // ================== VALIDATION HELPERS ==================
  
  /// Validate email address
  static String? validateEmail(String? value) {
    if (value?.isEmpty ?? true) {
      return AppStrings.requiredField;
    }
    if (!AppRegex.email.hasMatch(value!)) {
      return AppStrings.invalidEmail;
    }
    return null;
  }
  
  /// Validate password
  static String? validatePassword(String? value) {
    if (value?.isEmpty ?? true) {
      return AppStrings.requiredField;
    }
    if (value!.length < AppConfig.minPasswordLength) {
      return AppStrings.passwordTooShort;
    }
    return null;
  }
  
  /// Validate password confirmation
  static String? validateConfirmPassword(String? value, String? originalPassword) {
    if (value?.isEmpty ?? true) {
      return AppStrings.requiredField;
    }
    if (value != originalPassword) {
      return AppStrings.passwordsNotMatch;
    }
    return null;
  }
  
  /// Validate phone number
  static String? validatePhone(String? value) {
    if (value?.isEmpty ?? true) {
      return null; // Phone is often optional
    }
    if (!AppRegex.phone.hasMatch(value!)) {
      return AppStrings.invalidPhone;
    }
    return null;
  }
  
  /// Validate required field
  static String? validateRequired(String? value, [String? fieldName]) {
    if (value?.isEmpty ?? true) {
      return fieldName != null ? '$fieldName is required' : AppStrings.requiredField;
    }
    return null;
  }
  
  /// Validate user ID
  static String? validateUserId(String? value) {
    if (value?.isEmpty ?? true) {
      return AppStrings.requiredField;
    }
    if (!AppRegex.userId.hasMatch(value!)) {
      return AppStrings.invalidUserId;
    }
    return null;
  }
  
  // ================== TOAST HELPERS ==================
  
  /// Show success toast
  static void showSuccessToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      backgroundColor: AppColors.success,
      textColor: AppColors.onSuccess,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );
  }
  
  /// Show error toast
  static void showErrorToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      backgroundColor: AppColors.error,
      textColor: AppColors.onError,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
    );
  }
  
  /// Show warning toast
  static void showWarningToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      backgroundColor: AppColors.warning,
      textColor: AppColors.onWarning,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );
  }
  
  /// Show info toast
  static void showInfoToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      backgroundColor: AppColors.info,
      textColor: AppColors.onInfo,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );
  }
  
  // ================== DIALOG HELPERS ==================
  
  /// Show confirmation dialog
  static Future<bool> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = AppStrings.confirm,
    String cancelText = AppStrings.cancel,
    Color? confirmColor,
    bool isDestructive = false,
  }) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive 
                  ? AppColors.error 
                  : confirmColor ?? AppColors.primary,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    ) ?? false;
  }
  
  /// Show info dialog
  static void showInfoDialog(
    BuildContext context, {
    required String title,
    required String message,
    String buttonText = 'OK',
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }
  
  // ================== STRING HELPERS ==================
  
  /// Capitalize first letter
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }
  
  /// Get user initials from name
  static String getInitials(String name, {int maxLength = 2}) {
    final words = name.trim().split(' ');
    String initials = '';
    
    for (int i = 0; i < words.length && i < maxLength; i++) {
      if (words[i].isNotEmpty) {
        initials += words[i][0].toUpperCase();
      }
    }
    
    return initials.isEmpty ? '?' : initials;
  }
  
  /// Truncate text with ellipsis
  static String truncateText(String text, int maxLength, {String suffix = '...'}) {
    if (text.length <= maxLength) return text;
    return text.substring(0, maxLength - suffix.length) + suffix;
  }
  
  /// Remove extra whitespaces
  static String cleanText(String text) {
    return text.trim().replaceAll(RegExp(r'\s+'), ' ');
  }
  
  // ================== NUMBER HELPERS ==================
  
  /// Format number with thousands separator
  static String formatNumber(int number) {
    return NumberFormat('#,##0').format(number);
  }
  
  /// Format percentage
  static String formatPercentage(double value, {int decimals = 1}) {
    return '${(value * 100).toStringAsFixed(decimals)}%';
  }
  
  /// Format file size
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }
  
  // ================== GPS & LOCATION HELPERS ==================
  
  /// Format GPS coordinates
  static String formatCoordinates(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) {
      return 'Location not available';
    }
    return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  }
  
  /// Format distance in meters/kilometers
  static String formatDistance(int? distanceInMeters) {
    if (distanceInMeters == null) return 'Unknown distance';
    
    if (distanceInMeters >= 1000) {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)} km';
    } else {
      return '$distanceInMeters m';
    }
  }
  
  /// Check if distance is within allowed radius
  static bool isWithinRadius(double distance, double allowedRadius) {
    return distance <= allowedRadius;
  }
  
  // ================== THEME HELPERS ==================
  
  /// Check if current theme is dark mode
  static bool isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }
  
  /// Get adaptive color based on theme
  static Color getAdaptiveColor(BuildContext context, Color lightColor, Color darkColor) {
    return isDarkMode(context) ? darkColor : lightColor;
  }
  
  /// Get contrast color (black or white) for given background
  static Color getContrastColor(Color backgroundColor) {
    // Calculate relative luminance
    final luminance = backgroundColor.computeLuminance();
    // Return black for light backgrounds, white for dark backgrounds
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
  
  // ================== ROLE HELPERS ==================
  
  /// Get display name for user role
  static String getRoleDisplayName(String role) {
    switch (role) {
      case 'super_admin':
        return AppStrings.superAdmin;
      case 'institute_admin':
        return AppStrings.instituteAdmin;
      case 'admin':
        return AppStrings.admin;
      case 'user':
        return AppStrings.user;
      default:
        return role.toTitleCase();
    }
  }
  
  /// Get icon for user role
  static IconData getRoleIcon(String role) {
    switch (role) {
      case 'super_admin':
        return Icons.admin_panel_settings;
      case 'institute_admin':
        return Icons.business;
      case 'admin':
        return Icons.supervisor_account;
      case 'user':
        return Icons.person;
      default:
        return Icons.help_outline;
    }
  }
  
  /// Get color for user role
  static Color getRoleColor(String role) {
    switch (role) {
      case 'super_admin':
        return AppColors.superAdmin;
      case 'institute_admin':
        return AppColors.instituteAdmin;
      case 'admin':
        return AppColors.admin;
      case 'user':
        return AppColors.user;
      default:
        return AppColors.gray500;
    }
  }
  
  // ================== RESPONSIVE HELPERS ==================
  
  /// Check if screen is mobile size
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < AppSizes.mobileBreakpoint;
  }
  
  /// Check if screen is tablet size
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= AppSizes.mobileBreakpoint && width < AppSizes.tabletBreakpoint;
  }
  
  /// Check if screen is desktop size
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= AppSizes.desktopBreakpoint;
  }
  
  /// Get responsive value based on screen size
  static T getResponsiveValue<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop(context) && desktop != null) {
      return desktop;
    } else if (isTablet(context) && tablet != null) {
      return tablet;
    } else {
      return mobile;
    }
  }
  
  // ================== DEBUG HELPERS ==================
  
  /// Log debug message
  static void debugLog(String message, [String? tag]) {
    debugPrint('${tag != null ? '[$tag] ' : '[DEBUG] '}$message');
  }
  
  /// Log error message
  static void debugError(String error, [StackTrace? stackTrace]) {
    debugPrint('[ERROR] $error');
    if (stackTrace != null) {
      debugPrint('[STACK TRACE] $stackTrace');
    }
  }
  
  // ================== DEVICE HELPERS ==================
  
  /// Get device screen size category
  static String getDeviceType(BuildContext context) {
    if (isMobile(context)) return 'mobile';
    if (isTablet(context)) return 'tablet';
    return 'desktop';
  }
  
  /// Check if keyboard is visible
  static bool isKeyboardVisible(BuildContext context) {
    return MediaQuery.of(context).viewInsets.bottom > 0;
  }
}

// ================== STRING EXTENSIONS ==================

extension StringExtension on String {
  /// Capitalize first letter of string
  String toCapitalized() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }
  
  /// Convert to title case (capitalize each word)
  String toTitleCase() {
    return split(' ')
        .map((word) => word.toCapitalized())
        .join(' ');
  }
  
  /// Check if string is email
  bool get isEmail => AppRegex.email.hasMatch(this);
  
  /// Check if string is phone number
  bool get isPhone => AppRegex.phone.hasMatch(this);
  
  /// Check if string contains only numbers
  bool get isNumeric => AppRegex.numbers.hasMatch(this);
  
  /// Check if string is alphanumeric
  bool get isAlphanumeric => AppRegex.alphanumeric.hasMatch(this);
}

// ================== DATE TIME EXTENSIONS ==================

extension DateTimeExtension on DateTime {
  /// Check if date is today
  bool get isToday => AppHelpers.isToday(this);
  
  /// Check if date is yesterday
  bool get isYesterday => AppHelpers.isYesterday(this);
  
  /// Get time ago string
  String get timeAgo => AppHelpers.getTimeAgo(this);
  
  /// Format as time only
  String get timeString => AppHelpers.formatTime(this);
  
  /// Format as date only
  String get dateString => AppHelpers.formatDate(this);
  
  /// Format as date and time
  String get dateTimeString => AppHelpers.formatDateTime(this);
}

// ================== NUMBER EXTENSIONS ==================

extension IntExtension on int {
  /// Format number with thousands separator
  String get formatted => AppHelpers.formatNumber(this);
  
  /// Format as file size
  String get fileSize => AppHelpers.formatFileSize(this);
  
  /// Format as distance
  String get distance => AppHelpers.formatDistance(this);
}

extension DoubleExtension on double {
  /// Format as percentage
  String toPercentage({int decimals = 1}) => AppHelpers.formatPercentage(this, decimals: decimals);
}

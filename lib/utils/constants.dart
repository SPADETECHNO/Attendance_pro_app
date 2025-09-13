import 'package:flutter/material.dart';

// App Information
class AppInfo {
  static const String name = 'Attendance Pro';
  static const String version = '1.0.0';
  static const String description = 'Smart Attendance Management System';
  static const String company = 'SpadeTech Solutions';
}

// App Colors (Material Design 3)
class AppColors {
  // Primary Brand Colors
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryLight = Color(0xFF8B7CF6);
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color onPrimary = Color(0xFFFFFFFF);
  
  // Secondary Colors
  static const Color secondary = Color(0xFF14B8A6);
  static const Color secondaryLight = Color(0xFF5EEAD4);
  static const Color secondaryDark = Color(0xFF0F766E);
  static const Color onSecondary = Color(0xFFFFFFFF);
  
  // Surface Colors
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF8FAFC);
  static const Color onSurface = Color(0xFF1E293B);
  static const Color onSurfaceVariant = Color(0xFF64748B);
  
  // Background Colors
  static const Color background = Color(0xFFFAFAFA);
  static const Color onBackground = Color(0xFF1E293B);
  
  // Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFF6EE7B7);
  static const Color successDark = Color(0xFF047857);
  static const Color onSuccess = Color(0xFFFFFFFF);
  
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFBBF24);
  static const Color warningDark = Color(0xFFD97706);
  static const Color onWarning = Color(0xFFFFFFFF);
  
  static const Color error = Color(0xFFF87171);
  static const Color errorLight = Color(0xFFFCA5A5);
  static const Color errorDark = Color(0xFFDC2626);
  static const Color onError = Color(0xFFFFFFFF);
  
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFF93C5FD);
  static const Color infoDark = Color(0xFF2563EB);
  static const Color onInfo = Color(0xFFFFFFFF);
  
  // Neutral/Gray Scale
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color transparent = Colors.transparent;
  
  static const Color gray50 = Color(0xFFF9FAFB);
  static const Color gray100 = Color(0xFFF3F4F6);
  static const Color gray200 = Color(0xFFE5E7EB);
  static const Color gray300 = Color(0xFFD1D5DB);
  static const Color gray400 = Color(0xFF9CA3AF);
  static const Color gray500 = Color(0xFF6B7280);
  static const Color gray600 = Color(0xFF4B5563);
  static const Color gray700 = Color(0xFF374151);
  static const Color gray800 = Color(0xFF1F2937);
  static const Color gray900 = Color(0xFF111827);
  
  // Attendance Specific Colors
  static const Color present = success;
  static const Color absent = error;
  static const Color pending = warning;
  static const Color notMarked = gray400;
  
  // Session Status Colors
  static const Color live = Color(0xFFDC2626);
  static const Color upcoming = warning;
  static const Color ended = gray500;
  
  // Role Colors
  static const Color superAdmin = Color(0xFF7C3AED);
  static const Color instituteAdmin = Color(0xFF0891B2);
  static const Color admin = Color(0xFF059669);
  static const Color user = Color(0xFF2563EB);
}

// App Sizes and Spacing
class AppSizes {
  // Spacing Scale (8px base)
  static const double xs = 4.0;   // 0.5x
  static const double sm = 8.0;   // 1x
  static const double md = 16.0;  // 2x
  static const double lg = 24.0;  // 3x
  static const double xl = 32.0;  // 4x
  static const double xxl = 40.0; // 5x
  static const double xxxl = 48.0; // 6x
  
  // Component Sizes
  static const double buttonHeightSm = 36.0;
  static const double buttonHeightMd = 44.0;
  static const double buttonHeightLg = 56.0;
  static const double buttonHeightXl = 64.0;
  
  // Border Radius
  static const double radiusXs = 4.0;
  static const double radiusSm = 6.0;
  static const double radiusMd = 8.0;
  static const double radiusLg = 12.0;
  static const double radiusXl = 16.0;
  static const double radiusXxl = 24.0;
  static const double radiusRound = 999.0;
  
  // Icon Sizes
  static const double iconXs = 16.0;
  static const double iconSm = 20.0;
  static const double iconMd = 24.0;
  static const double iconLg = 32.0;
  static const double iconXl = 40.0;
  static const double iconXxl = 48.0;
  
  // Avatar Sizes
  static const double avatarSm = 32.0;
  static const double avatarMd = 40.0;
  static const double avatarLg = 56.0;
  static const double avatarXl = 80.0;
  
  // Container Sizes
  static const double cardMinHeight = 120.0;
  static const double listItemHeight = 72.0;
  static const double appBarHeight = 56.0;
  static const double tabBarHeight = 48.0;
  
  // Breakpoints for Responsive Design
  static const double mobileBreakpoint = 600.0;
  static const double tabletBreakpoint = 900.0;
  static const double desktopBreakpoint = 1200.0;
}

// Typography Sizes
class AppTextSizes {
  static const double xs = 12.0;   // Caption
  static const double sm = 14.0;   // Body Small
  static const double md = 16.0;   // Body Medium
  static const double lg = 18.0;   // Body Large
  static const double xl = 20.0;   // Title Medium
  static const double xxl = 24.0;  // Title Large
  static const double xxxl = 28.0; // Headline Small
  static const double xxxxl = 32.0; // Headline Medium
}

// App Strings
class AppStrings {
  // App Info
  static const String appName = AppInfo.name;
  static const String appVersion = AppInfo.version;
  static const String appDescription = AppInfo.description;
  
  // Common Actions
  static const String save = 'Save';
  static const String cancel = 'Cancel';
  static const String delete = 'Delete';
  static const String edit = 'Edit';
  static const String create = 'Create';
  static const String update = 'Update';
  static const String submit = 'Submit';
  static const String confirm = 'Confirm';
  static const String back = 'Back';
  static const String next = 'Next';
  static const String done = 'Done';
  static const String close = 'Close';
  static const String retry = 'Retry';
  static const String refresh = 'Refresh';
  static const String viewAll = 'View All';
  static const String seeMore = 'See More';
  static const String showLess = 'Show Less';
  static const String loading = 'Loading...';
  static const String processing = 'Processing...';
  static const String uploading = 'Uploading...';
  static const String downloading = 'Downloading...';
  
  // Authentication
  static const String login = 'Login';
  static const String logout = 'Logout';
  static const String signIn = 'Sign In';
  static const String signUp = 'Sign Up';
  static const String signOut = 'Sign Out';
  static const String register = 'Register';
  static const String forgotPassword = 'Forgot Password?';
  static const String resetPassword = 'Reset Password';
  static const String changePassword = 'Change Password';
  static const String currentPassword = 'Current Password';
  static const String newPassword = 'New Password';
  static const String confirmPassword = 'Confirm Password';
  static const String welcomeBack = 'Welcome Back!';
  static const String createAccount = 'Create Account';
  static const String alreadyHaveAccount = 'Already have an account?';
  static const String dontHaveAccount = "Don't have an account?";
  
  // Form Labels
  static const String name = 'Name';
  static const String fullName = 'Full Name';
  static const String firstName = 'First Name';
  static const String lastName = 'Last Name';
  static const String email = 'Email';
  static const String emailAddress = 'Email Address';
  static const String phone = 'Phone';
  static const String phoneNumber = 'Phone Number';
  static const String password = 'Password';
  static const String userId = 'User ID';
  static const String studentId = 'Student ID';
  static const String description = 'Description';
  static const String address = 'Address';
  static const String location = 'Location';
  static const String date = 'Date';
  static const String time = 'Time';
  static const String startTime = 'Start Time';
  static const String endTime = 'End Time';
  static const String duration = 'Duration';
  
  // Roles
  static const String superAdmin = 'Super Admin';
  static const String instituteAdmin = 'Institute Admin';
  static const String admin = 'Admin';
  static const String user = 'User';
  static const String student = 'Student';
  
  // Status
  static const String active = 'Active';
  static const String inactive = 'Inactive';
  static const String present = 'Present';
  static const String absent = 'Absent';
  static const String pending = 'Pending';
  static const String completed = 'Completed';
  static const String cancelled = 'Cancelled';
  static const String approved = 'Approved';
  static const String rejected = 'Rejected';
  static const String draft = 'Draft';
  static const String published = 'Published';
  
  // Session Status
  static const String live = 'LIVE';
  static const String liveNow = 'LIVE NOW';
  static const String upcoming = 'UPCOMING';
  static const String ended = 'ENDED';
  static const String offline = 'OFFLINE';
  static const String scheduled = 'SCHEDULED';
  
  // Attendance
  static const String attendance = 'Attendance';
  static const String markAttendance = 'Mark Attendance';
  static const String attendanceMarked = 'Attendance Marked';
  static const String notMarked = 'Not Marked';
  static const String selfMarked = 'Self-marked';
  static const String markedByAdmin = 'Marked by Admin';
  
  // Navigation & Screens
  static const String dashboard = 'Dashboard';
  static const String home = 'Home';
  static const String profile = 'Profile';
  static const String settings = 'Settings';
  static const String sessions = 'Sessions';
  static const String mySessions = 'My Sessions';
  static const String institutes = 'Institutes';
  static const String departments = 'Departments';
  static const String users = 'Users';
  static const String reports = 'Reports';
  static const String analytics = 'Analytics';
  
  // Error Messages
  static const String errorGeneric = 'Something went wrong. Please try again.';
  static const String errorNetwork = 'Network error. Please check your connection.';
  static const String errorAuth = 'Authentication failed. Please login again.';
  static const String errorPermission = 'You don\'t have permission to perform this action.';
  static const String errorValidation = 'Please check your input and try again.';
  static const String errorNotFound = 'Requested item not found.';
  static const String errorTimeout = 'Request timed out. Please try again.';
  static const String errorLocationPermission = 'Location permission is required for this feature.';
  static const String errorLocationUnavailable = 'Current location is unavailable.';
  static const String errorCameraPermission = 'Camera permission is required for QR scanning.';
  
  // Success Messages
  static const String successSaved = 'Saved successfully!';
  static const String successUpdated = 'Updated successfully!';
  static const String successDeleted = 'Deleted successfully!';
  static const String successCreated = 'Created successfully!';
  static const String successUploaded = 'Uploaded successfully!';
  static const String successDownloaded = 'Downloaded successfully!';
  static const String successMarked = 'Attendance marked successfully!';
  static const String successLogin = 'Logged in successfully!';
  static const String successLogout = 'Logged out successfully!';
  static const String successRegistration = 'Account created successfully!';
  
  // Validation Messages
  static const String requiredField = 'This field is required';
  static const String invalidEmail = 'Please enter a valid email address';
  static const String invalidPhone = 'Please enter a valid phone number';
  static const String passwordTooShort = 'Password must be at least 6 characters long';
  static const String passwordsNotMatch = 'Passwords do not match';
  static const String invalidUserId = 'User ID can only contain letters, numbers, and underscores';
  
  // Loading Messages
  static const String loadingData = 'Loading data...';
  static const String loadingDashboard = 'Loading dashboard...';
  static const String loadingSession = 'Loading session...';
  static const String loadingAttendance = 'Loading attendance...';
  static const String loadingUsers = 'Loading users...';
  static const String loadingInstitutes = 'Loading institutes...';
  static const String loadingDepartments = 'Loading departments...';
  static const String creatingSession = 'Creating session...';
  static const String markingAttendance = 'Marking attendance...';
  static const String uploadingFile = 'Uploading file...';
  static const String processingCsv = 'Processing CSV...';
  
  // Empty States
  static const String noData = 'No data available';
  static const String noResults = 'No results found';
  static const String noSessions = 'No sessions found';
  static const String noSessionsYet = 'No sessions yet';
  static const String noAttendance = 'No attendance records';
  static const String noUsers = 'No users found';
  static const String noUsersYet = 'No users yet';
  static const String noDepartments = 'No departments found';
  static const String noDepartmentsYet = 'No departments yet';
  static const String noInstitutes = 'No institutes found';
  static const String noInstitutesYet = 'No institutes yet';
  
  // Instructions & Help
  static const String scanQrCode = 'Scan QR code to mark attendance';
  static const String pointCameraAtQr = 'Point camera at QR code';
  static const String uploadCsvInstruction = 'Upload CSV file with user data';
  static const String gpsValidationRequired = 'GPS validation is required for this session';
  static const String approachAdminForAttendance = 'Please approach your admin to mark attendance';
  
  // Confirmation Messages
  static const String confirmDelete = 'Are you sure you want to delete this item?';
  static const String confirmLogout = 'Are you sure you want to logout?';
  static const String confirmCancel = 'Are you sure you want to cancel?';
  static const String actionCannotBeUndone = 'This action cannot be undone.';
  
  // Time & Date
  static const String today = 'Today';
  static const String yesterday = 'Yesterday';
  static const String tomorrow = 'Tomorrow';
  static const String thisWeek = 'This Week';
  static const String thisMonth = 'This Month';
  static const String remaining = 'remaining';
  static const String ago = 'ago';
  static const String justNow = 'Just now';
  static const String startingSoon = 'Starting soon';
}

// Animation Durations
class AppDurations {
  static const Duration instant = Duration.zero;
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration verySlow = Duration(milliseconds: 800);
  
  // Specific Use Cases
  static const Duration buttonPress = Duration(milliseconds: 100);
  static const Duration pageTransition = Duration(milliseconds: 300);
  static const Duration modalTransition = Duration(milliseconds: 250);
  static const Duration loadingDelay = Duration(milliseconds: 500);
  static const Duration toastDisplay = Duration(seconds: 3);
  static const Duration scannerCooldown = Duration(seconds: 2);
  
  // Network Timeouts
  static const Duration requestTimeout = Duration(seconds: 30);
  static const Duration uploadTimeout = Duration(minutes: 5);
  static const Duration downloadTimeout = Duration(minutes: 10);
}

// Date & Time Formats
class AppFormats {
  // Date Formats
  static const String dateShort = 'MM/dd/yyyy';        // 01/15/2025
  static const String dateMedium = 'MMM dd, yyyy';     // Jan 15, 2025
  static const String dateLong = 'MMMM dd, yyyy';      // January 15, 2025
  static const String dateFull = 'EEEE, MMMM dd, yyyy'; // Monday, January 15, 2025
  
  // Time Formats
  static const String time12 = 'hh:mm a';              // 02:30 PM
  static const String time24 = 'HH:mm';                // 14:30
  static const String timeWithSeconds = 'hh:mm:ss a';  // 02:30:45 PM
  
  // Date Time Formats
  static const String dateTime = 'MMM dd, yyyy • hh:mm a'; // Jan 15, 2025 • 02:30 PM
  static const String dateTimeShort = 'MM/dd/yy hh:mm a';  // 01/15/25 02:30 PM
  static const String dateTimeFull = 'EEEE, MMM dd, yyyy at hh:mm a'; // Monday, Jan 15, 2025 at 02:30 PM
  
  // ISO Formats
  static const String isoDate = 'yyyy-MM-dd';
  static const String isoDateTime = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'";
  
  // Custom App Formats
  static const String sessionTime = 'hh:mm a';
  static const String sessionDate = 'MMM dd, yyyy';
  static const String sessionDateTime = 'MMM dd, yyyy • hh:mm a';
  static const String attendanceTime = 'hh:mm a';
  static const String reportDate = 'MMM dd, yyyy';
}

// Regular Expressions for Validation
class AppRegex {
  static final RegExp email = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );
  
  static final RegExp phone = RegExp(
    r'^\+?[1-9]\d{1,14}$',
  );
  
  static final RegExp password = RegExp(
    r'^.{6,}$',
  );
  
  static final RegExp userId = RegExp(
    r'^[a-zA-Z0-9_-]+$',
  );
  
  static final RegExp name = RegExp(
    r'^[a-zA-Z\s]+$',
  );
  
  static final RegExp numbers = RegExp(
    r'^[0-9]+$',
  );
  
  static final RegExp alphanumeric = RegExp(
    r'^[a-zA-Z0-9]+$',
  );
}

// App Configuration
class AppConfig {
  // GPS Settings
  static const double defaultGpsRadius = 100.0; // meters
  static const double maxGpsRadius = 1000.0; // meters
  static const double minGpsRadius = 10.0; // meters
  
  // File Upload Settings
  static const int maxFileSize = 10 * 1024 * 1024; // 10MB
  static const List<String> allowedImageTypes = ['jpg', 'jpeg', 'png'];
  static const List<String> allowedDocumentTypes = ['pdf', 'doc', 'docx'];
  static const List<String> allowedCsvTypes = ['csv'];
  
  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
  
  // Session Settings
  static const int maxSessionDurationHours = 12;
  static const int minSessionDurationMinutes = 15;
  
  // User Settings
  static const int maxUsersPerBatch = 1000;
  static const int minPasswordLength = 6;
  static const int maxPasswordLength = 128;
  
  // UI Settings
  static const int maxToastLength = 100;
  static const int defaultAnimationDurationMs = 300;
  static const double defaultElevation = 2.0;
}

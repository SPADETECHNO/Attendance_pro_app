class AppConstants {
  // ================== DATABASE TABLE NAMES ==================
  
  // Supabase Table Names (matching your schema)
  static const String institutesTable = 'institutes';
  static const String academicYearsTable = 'academic_years';
  static const String profilesTable = 'profiles';
  static const String departmentsTable = 'departments';
  static const String sessionsTable = 'sessions';
  static const String sessionParticipantsTable = 'session_participants';
  static const String attendanceTable = 'attendance';
  
  // ================== USER ROLES ==================
  
  static const String superAdminRole = 'super_admin';
  static const String instituteAdminRole = 'institute_admin';
  static const String adminRole = 'admin';
  static const String userRole = 'user';
  
  // Role Display Names
  static const Map<String, String> roleDisplayNames = {
    superAdminRole: 'Super Admin',
    instituteAdminRole: 'Institute Admin',
    adminRole: 'Admin',
    userRole: 'User',
  };
  
  // Role Hierarchy (for permission checks)
  static const Map<String, int> roleHierarchy = {
    superAdminRole: 4,
    instituteAdminRole: 3,
    adminRole: 2,
    userRole: 1,
  };
  
  // ================== ACCOUNT STATUS ==================
  
  static const String activeStatus = 'active';
  static const String inactiveStatus = 'inactive';
  
  static const List<String> accountStatuses = [
    activeStatus,
    inactiveStatus,
  ];
  
  // ================== ATTENDANCE STATUS ==================
  
  static const String presentStatus = 'present';
  static const String absentStatus = 'absent';
  
  static const List<String> attendanceStatuses = [
    presentStatus,
    absentStatus,
  ];
  
  // ================== SESSION STATUS ==================
  
  static const String liveSessionStatus = 'live';
  static const String upcomingSessionStatus = 'upcoming';
  static const String endedSessionStatus = 'ended';
  static const String scheduledSessionStatus = 'scheduled';
  
  static const List<String> sessionStatuses = [
    liveSessionStatus,
    upcomingSessionStatus,
    endedSessionStatus,
    scheduledSessionStatus,
  ];
  
  // ================== GPS & LOCATION ==================
  
  // Default GPS settings
  static const double defaultRadius = 100.0; // meters
  static const double minRadius = 10.0; // meters
  static const double maxRadius = 1000.0; // meters
  
  // Location accuracy
  static const double locationAccuracyThreshold = 50.0; // meters
  static const int locationTimeoutSeconds = 30;
  
  // ================== FILE UPLOAD LIMITS ==================
  
  // File size limits (in bytes)
  static const int maxImageSize = 5 * 1024 * 1024; // 5MB
  static const int maxCsvSize = 10 * 1024 * 1024; // 10MB
  static const int maxDocumentSize = 20 * 1024 * 1024; // 20MB
  
  // Allowed file extensions
  static const List<String> allowedImageExtensions = [
    'jpg', 'jpeg', 'png', 'gif', 'webp'
  ];
  
  static const List<String> allowedCsvExtensions = [
    'csv'
  ];
  
  static const List<String> allowedDocumentExtensions = [
    'pdf', 'doc', 'docx', 'txt'
  ];
  
  // ================== SESSION SETTINGS ==================
  
  // Session duration limits
  static const int minSessionDurationMinutes = 15;
  static const int maxSessionDurationHours = 24;
  static const int defaultSessionDurationHours = 2;
  
  // Session scheduling
  static const int maxFutureSessionDays = 365; // 1 year
  static const int sessionReminderMinutes = 15;
  
  // ================== BULK OPERATIONS ==================
  
  // CSV processing
  static const int maxCsvRows = 10000;
  static const int csvBatchSize = 100;
  static const int maxCsvProcessingTimeSeconds = 300; // 5 minutes
  
  // Bulk user creation
  static const int maxBulkUsers = 1000;
  static const int userCreationBatchSize = 10;
  
  // ================== VALIDATION RULES ==================
  
  // Password validation
  static const int minPasswordLength = 6;
  static const int maxPasswordLength = 128;
  static const String tempPasswordPrefix = 'temp_';
  
  // User ID validation
  static const int minUserIdLength = 3;
  static const int maxUserIdLength = 50;
  
  // Name validation
  static const int minNameLength = 2;
  static const int maxNameLength = 100;
  
  // Email validation
  static const int maxEmailLength = 255;
  
  // Phone validation
  static const int minPhoneLength = 10;
  static const int maxPhoneLength = 15;
  
  // Description validation
  static const int maxDescriptionLength = 500;
  
  // Address validation
  static const int maxAddressLength = 200;
  
  // ================== PAGINATION ==================
  
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
  static const int minPageSize = 5;
  
  // Dashboard limits
  static const int dashboardRecentSessionsLimit = 5;
  static const int dashboardRecentUsersLimit = 10;
  static const int dashboardStatsLimit = 100;
  
  // ================== TIMEOUTS & INTERVALS ==================
  
  // Network timeouts
  static const int defaultTimeoutSeconds = 30;
  static const int uploadTimeoutSeconds = 120;
  static const int downloadTimeoutSeconds = 60;
  
  // Refresh intervals
  static const int dashboardRefreshSeconds = 30;
  static const int sessionRefreshSeconds = 10;
  static const int attendanceRefreshSeconds = 5;
  
  // Cache durations
  static const int userCacheDurationMinutes = 15;
  static const int sessionCacheDurationMinutes = 5;
  static const int instituteCacheDurationMinutes = 60;
  
  // ================== QR CODE SETTINGS ==================
  
  // QR code configuration
  static const int qrCodeSize = 200;
  static const String qrCodeFormat = 'json';
  static const int qrCodeVersion = 1;
  
  // QR scanning
  static const int qrScanTimeoutSeconds = 30;
  static const int qrScanCooldownSeconds = 2;
  
  // ================== NOTIFICATION SETTINGS ==================
  
  // Push notification types
  static const String sessionReminderNotification = 'session_reminder';
  static const String attendanceReminderNotification = 'attendance_reminder';
  static const String systemAnnouncementNotification = 'system_announcement';
  
  // Notification priorities
  static const String highPriority = 'high';
  static const String normalPriority = 'normal';
  static const String lowPriority = 'low';
  
  // ================== ERROR CODES ==================
  
  // Authentication errors
  static const String authInvalidCredentials = 'auth_invalid_credentials';
  static const String authUserNotFound = 'auth_user_not_found';
  static const String authUserDisabled = 'auth_user_disabled';
  static const String authPasswordResetRequired = 'auth_password_reset_required';
  
  // Authorization errors
  static const String authInsufficientPermissions = 'auth_insufficient_permissions';
  static const String authTokenExpired = 'auth_token_expired';
  static const String authSessionTimeout = 'auth_session_timeout';
  
  // Validation errors
  static const String validationInvalidEmail = 'validation_invalid_email';
  static const String validationInvalidPhone = 'validation_invalid_phone';
  static const String validationPasswordTooWeak = 'validation_password_too_weak';
  static const String validationUserIdExists = 'validation_user_id_exists';
  
  // Network errors
  static const String networkConnectionFailed = 'network_connection_failed';
  static const String networkTimeout = 'network_timeout';
  static const String networkServerError = 'network_server_error';
  
  // File operation errors
  static const String fileNotFound = 'file_not_found';
  static const String fileTooLarge = 'file_too_large';
  static const String fileInvalidFormat = 'file_invalid_format';
  static const String fileUploadFailed = 'file_upload_failed';
  
  // Location errors
  static const String locationPermissionDenied = 'location_permission_denied';
  static const String locationServiceDisabled = 'location_service_disabled';
  static const String locationOutOfRange = 'location_out_of_range';
  static const String locationAccuracyLow = 'location_accuracy_low';
  
  // Session errors
  static const String sessionNotFound = 'session_not_found';
  static const String sessionNotActive = 'session_not_active';
  static const String sessionAlreadyEnded = 'session_already_ended';
  static const String sessionNotStarted = 'session_not_started';
  
  // Attendance errors
  static const String attendanceAlreadyMarked = 'attendance_already_marked';
  static const String attendanceNotAllowed = 'attendance_not_allowed';
  static const String attendanceLocationRequired = 'attendance_location_required';
  
  // ================== SUCCESS MESSAGES ==================
  
  static const String successLogin = 'Login successful';
  static const String successLogout = 'Logged out successfully';
  static const String successRegistration = 'Account created successfully';
  static const String successPasswordChange = 'Password changed successfully';
  static const String successProfileUpdate = 'Profile updated successfully';
  
  static const String successSessionCreated = 'Session created successfully';
  static const String successSessionUpdated = 'Session updated successfully';
  static const String successSessionDeleted = 'Session deleted successfully';
  
  static const String successAttendanceMarked = 'Attendance marked successfully';
  static const String successAttendanceUpdated = 'Attendance updated successfully';
  
  static const String successUserCreated = 'User created successfully';
  static const String successUserUpdated = 'User updated successfully';
  static const String successUserDeleted = 'User deleted successfully';
  
  static const String successFileUploaded = 'File uploaded successfully';
  static const String successFileDeleted = 'File deleted successfully';
  static const String successCsvProcessed = 'CSV processed successfully';
  
  static const String successInstituteCreated = 'Institute created successfully';
  static const String successDepartmentCreated = 'Department created successfully';
  
  // ================== DEFAULT VALUES ==================
  
  // Default user settings
  static const String defaultUserRole = userRole;
  static const String defaultAccountStatus = inactiveStatus;
  static const bool defaultTempPasswordUsed = true;
  
  // Default session settings
  static const bool defaultGpsValidationEnabled = true;
  static const bool defaultSessionActive = true;
  
  // Default academic year
  static const bool defaultIsCurrentAcademicYear = false;
  
  // ================== FEATURE FLAGS ==================
  
  // Feature toggles
  static const bool enableQrCodeScanning = true;
  static const bool enableGpsValidation = true;
  static const bool enableBulkOperations = true;
  static const bool enableNotifications = true;
  static const bool enableFileUploads = true;
  static const bool enableExports = true;
  static const bool enableAnalytics = true;
  static const bool enableDarkMode = true;
  
  // Debug features
  static const bool enableDebugMode = false;
  static const bool enableVerboseLogging = false;
  static const bool enablePerformanceMetrics = false;
  
  // ================== API ENDPOINTS ==================
  
  // Supabase RPC functions (if you create any)
  static const String rpcCreateBulkUsers = 'create_bulk_users';
  static const String rpcGenerateReport = 'generate_attendance_report';
  static const String rpcCalculateDistance = 'calculate_distance';
  static const String rpcGetDashboardStats = 'get_dashboard_stats';
  
  // ================== STORAGE BUCKETS ==================
  
  // Supabase storage bucket names
  static const String profileImagesBucket = 'profile_images';
  static const String instituteLogo = 'institute_logos';
  static const String csvFilesBucket = 'csv_files';
  static const String exportsBucket = 'exports';
  static const String documentsBucket = 'documents';
  
  // ================== REGEX PATTERNS ==================
  
  // Email validation
  static const String emailPattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
  
  // Phone validation (international format)
  static const String phonePattern = r'^\+?[1-9]\d{1,14}$';
  
  // User ID validation (alphanumeric with underscores and hyphens)
  static const String userIdPattern = r'^[a-zA-Z0-9_-]+$';
  
  // Name validation (letters and spaces only)
  static const String namePattern = r'^[a-zA-Z\s]+$';
  
  // Password validation (at least 6 characters)
  static const String passwordPattern = r'^.{6,}$';
  
  // Numeric validation
  static const String numericPattern = r'^[0-9]+$';
  
  // Alphanumeric validation
  static const String alphanumericPattern = r'^[a-zA-Z0-9]+$';
  
  // ================== DATE FORMATS ==================
  
  // Display formats
  static const String displayDateFormat = 'MMM dd, yyyy';
  static const String displayTimeFormat = 'hh:mm a';
  static const String displayDateTimeFormat = 'MMM dd, yyyy • hh:mm a';
  static const String displayFullDateFormat = 'EEEE, MMMM dd, yyyy';
  
  // API formats
  static const String apiDateFormat = 'yyyy-MM-dd';
  static const String apiTimeFormat = 'HH:mm:ss';
  static const String apiDateTimeFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'";
  
  // File name formats
  static const String filenameDateFormat = 'yyyyMMdd_HHmmss';
  
  // ================== CSV HEADERS ==================
  
  // User CSV headers
  static const List<String> userCsvHeaders = [
    'user_id',
    'name',
    'email',
    'phone',
    'department',
  ];
  
  // Session CSV headers
  static const List<String> sessionCsvHeaders = [
    'session_name',
    'start_datetime',
    'end_datetime',
    'department',
    'description',
  ];
  
  // Attendance CSV headers
  static const List<String> attendanceCsvHeaders = [
    'session_name',
    'user_id',
    'name',
    'email',
    'status',
    'marked_at',
    'marked_by_user',
    'marked_by_admin',
  ];
  
  // ================== LOCAL STORAGE KEYS ==================
  
  static const String storageUserPreferences = 'user_preferences';
  static const String storageLastLogin = 'last_login';
  static const String storageThemeMode = 'theme_mode';
  static const String storageLanguage = 'language';
  static const String storageNotificationSettings = 'notification_settings';
  static const String storageCachedUser = 'cached_user';
  static const String storageCachedSessions = 'cached_sessions';
  
  // ================== APP METADATA ==================
  
  static const String appName = 'Attendance Pro';
  static const String appVersion = '1.0.0';
  static const String appBuildNumber = '1';
  static const String appDescription = 'Smart Attendance Management System';
  static const String appDeveloper = 'SpadeTech Solutions';
  static const String appWebsite = 'https://spadetech.com';
  static const String appSupportEmail = 'support@spadetech.com';
  
  // ================== ENVIRONMENT CONFIGS ==================
  
  // Environment types
  static const String developmentEnv = 'development';
  static const String stagingEnv = 'staging';
  static const String productionEnv = 'production';
  
  // Default environment
  static const String defaultEnvironment = developmentEnv;
  
  // ================== HELPER METHODS ==================
  
  /// Check if a role has sufficient permissions
  static bool hasPermission(String userRole, String requiredRole) {
    final userLevel = roleHierarchy[userRole] ?? 0;
    final requiredLevel = roleHierarchy[requiredRole] ?? 0;
    return userLevel >= requiredLevel;
  }
  
  /// Check if user is admin or higher
  static bool isAdminOrHigher(String role) {
    return hasPermission(role, adminRole);
  }
  
  /// Check if user is institute admin or higher
  static bool isInstituteAdminOrHigher(String role) {
    return hasPermission(role, instituteAdminRole);
  }
  
  /// Check if user is super admin
  static bool isSuperAdmin(String role) {
    return role == superAdminRole;
  }
  
  /// Get role display name
  static String getRoleDisplayName(String role) {
    return roleDisplayNames[role] ?? role;
  }
  
  /// Validate file size
  static bool isValidFileSize(int fileSizeBytes, String fileType) {
    switch (fileType.toLowerCase()) {
      case 'image':
        return fileSizeBytes <= maxImageSize;
      case 'csv':
        return fileSizeBytes <= maxCsvSize;
      case 'document':
        return fileSizeBytes <= maxDocumentSize;
      default:
        return false;
    }
  }
  
  /// Validate file extension
  static bool isValidFileExtension(String extension, String fileType) {
    switch (fileType.toLowerCase()) {
      case 'image':
        return allowedImageExtensions.contains(extension.toLowerCase());
      case 'csv':
        return allowedCsvExtensions.contains(extension.toLowerCase());
      case 'document':
        return allowedDocumentExtensions.contains(extension.toLowerCase());
      default:
        return false;
    }
  }
  
  /// Check if session is currently live
  static bool isSessionLive(DateTime startTime, DateTime endTime) {
    final now = DateTime.now();
    return now.isAfter(startTime) && now.isBefore(endTime);
  }
  
  /// Check if session is upcoming
  static bool isSessionUpcoming(DateTime startTime) {
    return DateTime.now().isBefore(startTime);
  }
  
  /// Check if session has ended
  static bool isSessionEnded(DateTime endTime) {
    return DateTime.now().isAfter(endTime);
  }
  
  /// Generate temp password
  static String generateTempPassword(String email) {
    try {
      // Extract everything before @ symbol
      final emailPrefix = email.split('@').first;
      
      // Clean the prefix (remove any special characters except underscore)
      final cleanPrefix = emailPrefix
          .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '')
          .toLowerCase();
      
      return '$tempPasswordPrefix$cleanPrefix';
    } catch (e) {
      // Fallback if email parsing fails
      return '${tempPasswordPrefix}user123';
    }
  }
  
  /// Check if password is temporary
  static bool isTempPassword(String password) {
    return password.startsWith(tempPasswordPrefix);
  }
  
  /// Get QR code data for user
  static Map<String, dynamic> getQrCodeData(String userId, String sessionId) {
    return {
      'user_id': userId,
      'session_id': sessionId,
      'timestamp': DateTime.now().toIso8601String(),
      'version': qrCodeVersion,
    };
  }
}

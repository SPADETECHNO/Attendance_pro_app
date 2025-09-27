import 'package:attendance_pro_app/models/institute_master_list_model.dart';
import 'package:attendance_pro_app/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:attendance_pro_app/models/user_model.dart';
import 'package:attendance_pro_app/models/institute_model.dart';
import 'package:attendance_pro_app/models/session_model.dart';
import 'package:attendance_pro_app/models/attendance_model.dart';
import 'package:attendance_pro_app/models/department_model.dart';
import 'package:attendance_pro_app/models/academic_year_model.dart';
import 'package:attendance_pro_app/constants/app_constants.dart';
import 'package:attendance_pro_app/utils/helpers.dart';

class ParticipantValidationResult {
  final List<String> validUsers;
  final List<String> invalidUsers;
  
  ParticipantValidationResult({
    required this.validUsers,
    required this.invalidUsers,
  });
  
  int get validCount => validUsers.length;
  int get invalidCount => invalidUsers.length;
  bool get hasInvalidUsers => invalidUsers.isNotEmpty;
}

class DatabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  // ================== INSTITUTES ==================

  /// Get all institutes
  Future<List<InstituteModel>> getInstitutes() async {
    try {
      final response = await _client
          .from(AppConstants.institutesTable)
          .select()
          .order('created_at', ascending: false);

      if (response == null) return [];
      
      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => InstituteModel.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      AppHelpers.debugError('Get institutes error: $e');
      rethrow;
    }
  }

  /// Create institute (basic info only)
  Future<String> createInstitute({
    required String name,
    String? address,
    String? phone,
    required int allowedRadius,
  }) async {
    try {
      final response = await _client
          .from(AppConstants.institutesTable)
          .insert({
            'name': name,
            'address': address,
            'phone': phone,
            'allowed_radius': allowedRadius,
            'created_by': null,
          })
          .select('id')
          .single();

      return response['id'] as String;
    } catch (e) {
      AppHelpers.debugError('Create institute error: $e');
      rethrow;
    }
  }

  /// Update institute
  Future<void> updateInstitute({
    required String id,
    required String name,
    String? address,
    String? phone,
    required int allowedRadius,
  }) async {
    try {
      await _client
          .from(AppConstants.institutesTable)
          .update({
            'name': name,
            'address': address,
            'phone': phone,
            'allowed_radius': allowedRadius,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);
    } catch (e) {
      AppHelpers.debugError('Update institute error: $e');
      rethrow;
    }
  }

  /// Delete institute
  Future<void> deleteInstitute(String id) async {
    try {
      await _client
          .from(AppConstants.institutesTable)
          .delete()
          .eq('id', id);
    } catch (e) {
      AppHelpers.debugError('Delete institute error: $e');
      rethrow;
    }
  }

  /// Get institute admins for a specific institute
  Future<List<Map<String, dynamic>>> getInstituteAdmins(String instituteId) async {
    try {
      final response = await _client
          .from(AppConstants.profilesTable)
          .select('''
            id,
            name,
            email,
            phone,
            account_status,
            temp_password_used,
            created_at
          ''')
          .eq('institute_id', instituteId)
          .eq('role', AppConstants.instituteAdminRole)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      AppHelpers.debugError('Get institute admins error: $e');
      return [];
    }
  }

  Future<InstituteModel?> getInstituteById(String id) async {
  try {
    final response = await _client
        .from(AppConstants.institutesTable)
        .select()
        .eq('id', id)
        .maybeSingle(); // Use maybeSingle() instead of single()

    if (response == null) {
      AppHelpers.debugError('Institute not found with ID: $id');
      return null;
    }

    // Debug what we're getting from the database
    AppHelpers.debugLog('Raw institute data: $response');

    // Ensure all required fields are present and not null
    if (response['id'] == null || response['name'] == null) {
      AppHelpers.debugError('Institute data incomplete: $response');
      return null;
    }

    return InstituteModel.fromJson(response);
  } catch (e) {
    AppHelpers.debugError('Get institute by ID error: $e');
    return null;
  }
}



  /// Update admin details
  Future<void> updateAdmin({
    required String adminId,
    required String name,
    required String email,
    String? phone,
    required String departmentId,
  }) async {
    try {
      await _client
          .from(AppConstants.profilesTable)
          .update({
            'name': name,
            'phone': phone,
            'department_id': departmentId,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', adminId);
    } catch (e) {
      AppHelpers.debugError('Update admin error: $e');
      rethrow;
    }
  }

  /// Get all institute admins across system (for super admin)
  Future<List<Map<String, dynamic>>> getAllInstituteAdmins() async {
    try {
      final response = await _client
          .from(AppConstants.profilesTable)
          .select('''
            id, name, email, phone, account_status, temp_password_used, created_at,
            institutes!inner(id, name)
          ''')
          .eq('role', AppConstants.instituteAdminRole)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      AppHelpers.debugError('Get all institute admins error: $e');
      return [];
    }
  }

  Future createDepartmentAdmin({
  required String name,
  required String userId,
  required String email,
  String? phone,
  required String departmentId,
  required String instituteId,
  required String academicYearId, // ✅ Add academic year parameter
  required String password,
}) async {
  try {
    final authService = AuthService();
    
    // Create auth user
    final authResponse = await _client.auth.signUp(
      email: email,
      password: password,
    );
    
    if (authResponse.user == null) {
      throw Exception('Failed to create admin account');
    }

    // Create admin profile with academic year mapping
    await _client.from(AppConstants.profilesTable).insert({
      'id': authResponse.user!.id,
      'user_id': userId,
      'name': name,
      'email': email,
      'phone': phone,
      'role': AppConstants.adminRole,
      'institute_id': instituteId,
      'department_id': departmentId,
      'academic_year_id': academicYearId, // ✅ Map to academic year
      'account_status': 'active',
      'temp_password_used': false,
    });
  } catch (e) {
    AppHelpers.debugError('Create department admin error: $e');
    rethrow;
  }
}

// ================== INSTITUTE MASTER LIST ==================

/// Get institute master list
Future<List<InstituteMasterListModel>> getInstituteMasterList(String instituteId) async {
  try {
    final response = await _client
        .from('institute_master_list')
        .select()
        .eq('institute_id', instituteId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => InstituteMasterListModel.fromJson(json))
        .toList();
  } catch (e) {
    AppHelpers.debugError('Get institute master list error: $e');
    rethrow;
  }
}

/// Add user to institute master list
Future<void> addToInstituteMasterList({
  required String userId,
  required String name,
  required String email,
  String? phone,
  required String instituteId,
  String? departmentId,
  String? academicYearId,
  required String createdBy,
  bool sendEmailInvitation = true,
}) async {
  try {
    // Check if user ID already exists in this institute
    final existing = await _client
        .from('institute_master_list')
        .select('id')
        .eq('institute_id', instituteId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) {
      throw Exception('User ID already exists in this institute');
    }

    // Check if email already exists in this institute
    final existingEmail = await _client
        .from('institute_master_list')
        .select('id')
        .eq('institute_id', instituteId)
        .eq('email', email)
        .maybeSingle();

    if (existingEmail != null) {
      throw Exception('Email already exists in this institute');
    }

    // Add to master list first
    await _client.from('institute_master_list').insert({
      'user_id': userId,
      'name': name,
      'email': email,
      'phone': phone,
      'role': 'user', // Always 'user' for master list
      'institute_id': instituteId,
      'department_id': departmentId,
      'academic_year_id': academicYearId,
      'account_status': 'active',
      'temp_password_used': !sendEmailInvitation,
      'created_by': createdBy,
    });

    // Create profile using existing auth service method
    if (sendEmailInvitation) {
      try {
        final authService = AuthService();
        // Use existing method with email invitation
        await authService.createUserAccountWithInvitation(
          email: email,
          userId: userId,
          name: name,
          role: 'user', // Always 'user'
          phone: phone,
          instituteId: instituteId,
          departmentId: departmentId,
          academicYearId: academicYearId,
        );
      } catch (authError) {
        AppHelpers.debugError('Auth creation failed but user added to master list: $authError');
      }
    } else {
      try {
        final authService = AuthService();
        // Use existing method without email invitation
        await authService.createUserAccount(
          email: email,
          userId: userId,
          name: name,
          role: 'user', // Always 'user'
          phone: phone,
          instituteId: instituteId,
          departmentId: departmentId,
          academicYearId: academicYearId,
        );
      } catch (authError) {
        AppHelpers.debugError('Auth creation failed but user added to master list: $authError');
      }
    }
  } catch (e) {
    AppHelpers.debugError('Add to institute master list error: $e');
    rethrow;
  }
}

/// Search master list by user ID
Future<InstituteMasterListModel?> searchInstituteMasterListByUserId(
  String instituteId,
  String userId,
) async {
  try {
    final response = await _client
        .from('institute_master_list')
        .select()
        .eq('institute_id', instituteId)
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) return null;
    return InstituteMasterListModel.fromJson(response);
  } catch (e) {
    AppHelpers.debugError('Search master list by user ID error: $e');
    rethrow;
  }
}

/// Update master list user
Future<void> updateInstituteMasterListUser({
  required String id,
  required String name,
  required String email,
  String? phone,
  String? departmentId,
  String? academicYearId,
}) async {
  try {
    await _client
        .from('institute_master_list')
        .update({
          'name': name,
          'email': email,
          'phone': phone,
          'department_id': departmentId,
          'academic_year_id': academicYearId,
          'updated_at': DateTime.now().toIso8601String(),
          // Note: role is not updated as it's always 'user'
        })
        .eq('id', id);
  } catch (e) {
    AppHelpers.debugError('Update master list user error: $e');
    rethrow;
  }
}


/// Delete from master list
Future<void> deleteFromInstituteMasterList(String id) async {
  try {
    await _client
        .from('institute_master_list')
        .delete()
        .eq('id', id);
  } catch (e) {
    AppHelpers.debugError('Delete from master list error: $e');
    rethrow;
  }
}

/// Bulk add to master list from CSV
Future<void> bulkAddToInstituteMasterList(
  List<Map<String, dynamic>> users,
  String instituteId,
  String createdBy,
  bool sendEmailInvitations,
) async {
  try {
    // First, add all to master list
    final records = users.map((user) => {
      'user_id': user['user_id'],
      'name': user['name'],
      'email': user['email'],
      'phone': user['phone'],
      'role': 'user', // Always 'user'
      'institute_id': instituteId,
      'department_id': user['department_id'],
      'academic_year_id': user['academic_year_id'],
      'account_status': 'active',
      'temp_password_used': !sendEmailInvitations,
      'created_by': createdBy,
    }).toList();

    await _client.from('institute_master_list').insert(records);

    // Then create profiles using existing auth service
    if (sendEmailInvitations) {
      final authService = AuthService();
      for (final user in users) {
        try {
          await authService.createUserAccountWithInvitation(
            email: user['email'],
            userId: user['user_id'],
            name: user['name'],
            role: 'user',
            phone: user['phone'],
            instituteId: instituteId,
            departmentId: user['department_id'],
            academicYearId: user['academic_year_id'],
          );
        } catch (authError) {
          AppHelpers.debugError('Auth creation failed for user ${user['user_id']}: $authError');
        }
      }
    }
  } catch (e) {
    AppHelpers.debugError('Bulk add to master list error: $e');
    rethrow;
  }
}


  // ================== DEPARTMENTS ==================

  /// Get departments by institute
  Future<List<DepartmentModel>> getDepartmentsByInstitute(String instituteId) async {
    try {
      final response = await _client
          .from(AppConstants.departmentsTable)
          .select()
          .eq('institute_id', instituteId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => DepartmentModel.fromJson(json))
          .toList();
    } catch (e) {
      AppHelpers.debugError('Get departments error: $e');
      rethrow;
    }
  }

  /// Create department
  Future<void> createDepartment({
    required String name,
    String? description,
    required String instituteId,
    required String createdBy,
  }) async {
    try {
      await _client.from(AppConstants.departmentsTable).insert({
        'name': name,
        'description': description,
        'institute_id': instituteId,
        'created_by': createdBy,
      });
    } catch (e) {
      AppHelpers.debugError('Create department error: $e');
      rethrow;
    }
  }

  /// Get department admins
  Future<List<Map<String, dynamic>>> getDepartmentAdmins(String instituteId) async {
  try {
    print('[DBG] Querying profiles for institute: $instituteId');
    print('[DBG] Admin role constant: ${AppConstants.adminRole}');
    
    final response = await _client
        .from(AppConstants.profilesTable)
        .select('''
          id,
          name,
          email,
          phone,
          department_id,
          account_status,
          temp_password_used,
          created_at
        ''')
        .eq('institute_id', instituteId)
        .eq('role', AppConstants.adminRole)
        .order('created_at');

    print('[DBG] Raw response: $response');
    print('[DBG] Response type: ${response.runtimeType}');

    if (response is List) {
      print('[DBG] Found ${response.length} department admins');
      
      final List<Map<String, dynamic>> result = [];
      for (int i = 0; i < response.length; i++) {
        final admin = response[i];
        print('[DBG] Processing admin $i: ${admin['name']} (${admin['email']})');
        
        final Map<String, dynamic> adminData = Map.from(admin);
        
        if (admin['department_id'] != null) {
          try {
            print('[DBG] Looking up department for ID: ${admin['department_id']}');
            final deptResponse = await _client
                .from(AppConstants.departmentsTable)
                .select('name')
                .eq('id', admin['department_id'])
                .single();
            adminData['department_name'] = deptResponse['name'];
            print('[DBG] Found department name: ${deptResponse['name']}');
          } catch (e) {
            print('[DBG] Department lookup failed: $e');
            adminData['department_name'] = 'Unknown Department';
          }
        } else {
          adminData['department_name'] = 'No Department';
        }
        
        result.add(adminData);
      }

      print('[DBG] Final result count: ${result.length}');
      return result;
    } else {
      print('[DBG] Response is NOT a List! It is: ${response.runtimeType}');
      return [];
    }
  } catch (e) {
    AppHelpers.debugError('Get department admins error: $e');
    return [];
  }
}

Future<List<Map<String, dynamic>>> getDepartmentAdminsByAcademicYear(
  String instituteId, 
  String academicYearId
) async {
  try {
    // First try to get admins with academic_year_id filter
    final response = await _client
        .from(AppConstants.profilesTable)
        .select('''
          id,
          name,
          email,
          phone,
          department_id,
          academic_year_id,
          account_status,
          temp_password_used,
          created_at
        ''')
        .eq('institute_id', instituteId)
        .eq('role', AppConstants.adminRole)
        .eq('academic_year_id', academicYearId)
        .order('created_at');

    if (response is List && response.isNotEmpty) {
      final List<Map<String, dynamic>> result = [];
      for (final admin in response) {
        final Map<String, dynamic> adminData = Map.from(admin);
        if (admin['department_id'] != null) {
          try {
            final deptResponse = await _client
                .from(AppConstants.departmentsTable)
                .select('name')
                .eq('id', admin['department_id'])
                .single();
            adminData['department_name'] = deptResponse['name'];
          } catch (e) {
            adminData['department_name'] = 'Unknown Department';
          }
        }
        result.add(adminData);
      }
      return result;
    } else {
      // ✅ Fallback: if no admins found with academic year filter, return all admins
      print('No admins found for academic year $academicYearId, getting all admins');
      return await getDepartmentAdmins(instituteId);
    }
  } catch (e) {
    AppHelpers.debugError('Get department admins by academic year error: $e');
    // ✅ Fallback to getting all admins
    return await getDepartmentAdmins(instituteId);
  }
}


  // ================== USERS ==================

  /// Get users with optional filters
  Future<List<UserModel>> getUsers({
    String? instituteId,
    String? departmentId,
    String? role,
    String? academicYearId,
  }) async {
    try {
      var query = _client.from(AppConstants.profilesTable).select();
      
      if (instituteId != null) {
        query = query.eq('institute_id', instituteId);
      }
      if (departmentId != null) {
        query = query.eq('department_id', departmentId);
      }
      if (role != null) {
        query = query.eq('role', role);
      }
      if (academicYearId != null) {
        query = query.eq('academic_year_id', academicYearId);
      }

      final response = await query.order('created_at', ascending: false);
      return (response as List)
          .map((json) => UserModel.fromJson(json))
          .toList();
    } catch (e) {
      AppHelpers.debugError('Get users error: $e');
      rethrow;
    }
  }

  /// Get user sessions
  Future<List<SessionModel>> getUserSessions(String userId) async {
    try {
      final response = await _client
          .from(AppConstants.sessionParticipantsTable)
          .select('''
            sessions!session_id(*)
          ''')
          .eq('user_id', userId);

      List<SessionModel> sessions = [];
      for (var item in response as List) {
        if (item['sessions'] != null) {
          sessions.add(SessionModel.fromJson(item['sessions']));
        }
      }

      return sessions;
    } catch (e) {
      AppHelpers.debugError('Get user sessions error: $e');
      rethrow;
    }
  }

  Future<SessionModel?> getSessionById(String sessionId) async {
    try {
      final response = await _client
          .from(AppConstants.sessionsTable)
          .select()
          .eq('id', sessionId)
          .single();

      return SessionModel.fromJson(response);
    } catch (e) {
      AppHelpers.debugError('Get session by ID error: $e');
      return null;
    }
  }

  /// Get department by ID
  Future<DepartmentModel?> getDepartmentById(String departmentId) async {
    try {
      final response = await _client
          .from(AppConstants.departmentsTable)
          .select()
          .eq('id', departmentId)
          .single();

      return DepartmentModel.fromJson(response);
    } catch (e) {
      AppHelpers.debugError('Get department by ID error: $e');
      return null;
    }
  }

  Future<String> createSessionWithParticipants({
  required String name,
  String? description,
  required DateTime startDateTime,
  required DateTime endDateTime,
  required String academicYear,
  String? semester,
  required String departmentId,
  required String createdBy,
  bool gpsValidationEnabled = true,
  List<String>? participantUserIds,
}) async {
  try {
    // Create session
    final sessionResponse = await _client.from(AppConstants.sessionsTable).insert({
      'name': name,
      'description': description,
      'start_datetime': startDateTime.toIso8601String(),
      'end_datetime': endDateTime.toIso8601String(),
      'session_date': DateTime(startDateTime.year, startDateTime.month, startDateTime.day).toIso8601String(),
      'academic_year': academicYear,
      'semester': semester,
      'department_id': departmentId,
      'created_by': createdBy,
      'gps_validation_enabled': gpsValidationEnabled,
      'is_active': true,
    }).select('id').single();
    
    final sessionId = sessionResponse['id'] as String;
    
    // Add participants if provided
    if (participantUserIds != null && participantUserIds.isNotEmpty) {
      final participantRecords = participantUserIds.map((userId) => {
        'session_id': sessionId,
        'user_id': userId,
      }).toList();
      
      await _client.from(AppConstants.sessionParticipantsTable).insert(participantRecords);
    }
    
    return sessionId;
  } catch (e) {
    AppHelpers.debugError('Create session with participants error: $e');
    rethrow;
  }
}

Future<ParticipantValidationResult> validateParticipants({
  required List<String> userIds,
  required String instituteId,
  required String departmentId,
  String? academicYearId,
}) async {
  try {
    // Get existing users from master list
    var query = _client
        .from(AppConstants.profilesTable)
        .select('user_id')
        .eq('institute_id', instituteId)
        .eq('department_id', departmentId)
        .eq('role', AppConstants.userRole);

    if (academicYearId != null) {
      query = query.eq('academic_year_id', academicYearId);
    }
    
    final existingUsers = await query;
    final masterList = existingUsers.map((user) => user['user_id'] as String).toSet();
    
    final validUsers = <String>[];
    final invalidUsers = <String>[];
    
    for (final userId in userIds) {
      if (masterList.contains(userId)) {
        validUsers.add(userId);
      } else {
        invalidUsers.add(userId);
      }
    }
    
    return ParticipantValidationResult(
      validUsers: validUsers,
      invalidUsers: invalidUsers,
    );
  } catch (e) {
    AppHelpers.debugError('Validate participants error: $e');
    rethrow;
  }
}

  // ================== SESSIONS ==================

  /// Get sessions with optional filters
  Future<List<SessionModel>> getSessions({
    String? departmentId,
    String? academicYearId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _client.from(AppConstants.sessionsTable).select();
      
      if (departmentId != null) {
        query = query.eq('department_id', departmentId);
      }
      
      if (academicYearId != null) {
        query = query.eq('academic_year_id', academicYearId);
      }

      if (startDate != null) {
        query = query.gte('session_date', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('session_date', endDate.toIso8601String());
      }

      final response = await query.order('start_datetime', ascending: false);

      return (response as List)
          .map((json) => SessionModel.fromJson(json))
          .toList();
    } catch (e) {
      AppHelpers.debugError('Get sessions error: $e');
      rethrow;
    }
  }

  /// Create session
  Future<void> createSession({
    required String name,
    String? description,
    required DateTime startDateTime,
    required DateTime endDateTime,
    required String academicYearId,
    required String departmentId,
    required String createdBy,
    bool gpsValidationEnabled = true,
  }) async {
    try {
      await _client.from(AppConstants.sessionsTable).insert({
        'name': name,
        'description': description,
        'start_datetime': startDateTime.toIso8601String(),
        'end_datetime': endDateTime.toIso8601String(),
        'session_date': DateTime(
          startDateTime.year,
          startDateTime.month,
          startDateTime.day,
        ).toIso8601String(),
        'academic_year_id': academicYearId,
        'department_id': departmentId,
        'created_by': createdBy,
        'gps_validation_enabled': gpsValidationEnabled,
        'is_active': true,
      });
    } catch (e) {
      AppHelpers.debugError('Create session error: $e');
      rethrow;
    }
  }

  // ================== ATTENDANCE ==================

  /// Mark attendance
  Future<void> markAttendance({
    required String sessionId,
    required String userId,
    required String markedBy,
    required String status,
    bool markedByUser = false,
    bool markedByAdmin = false,
    double? gpsLatitude,
    double? gpsLongitude,
    int? distanceFromInstitute,
  }) async {
    try {
      await _client.from(AppConstants.attendanceTable).upsert({
        'session_id': sessionId,
        'user_id': userId,
        'marked_by': markedBy,
        'marked_by_user': markedByUser,
        'marked_by_admin': markedByAdmin,
        'status': status,
        'gps_latitude': gpsLatitude,
        'gps_longitude': gpsLongitude,
        'distance_from_institute': distanceFromInstitute,
      });
    } catch (e) {
      AppHelpers.debugError('Mark attendance error: $e');
      rethrow;
    }
  }

  /// Get session attendance with user details
  Future<List<Map<String, dynamic>>> getSessionAttendance(String sessionId) async {
    try {
      final response = await _client
          .from(AppConstants.attendanceTable)
          .select('''
            *,
            profiles!user_id(name, user_id, email)
          ''')
          .eq('session_id', sessionId);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      AppHelpers.debugError('Get session attendance error: $e');
      rethrow;
    }
  }

  /// Get attendance records
  Future<List<AttendanceModel>> getAttendanceRecords(String sessionId) async {
    try {
      final response = await _client
          .from(AppConstants.attendanceTable)
          .select()
          .eq('session_id', sessionId);

      return (response as List)
          .map((json) => AttendanceModel.fromJson(json))
          .toList();
    } catch (e) {
      AppHelpers.debugError('Get attendance records error: $e');
      rethrow;
    }
  }

  // ================== ACADEMIC YEARS ==================

  /// Get academic years
  
  Future<void> setCurrentAcademicYear({
    required String instituteId,
    required String yearId,
  }) async {
    try {
      // Use a transaction-like approach to ensure atomicity
      
      // First, remove current flag from all years for this institute
      await _client
          .from(AppConstants.academicYearsTable)
          .update({'is_current': false, 'updated_at': DateTime.now().toIso8601String()})
          .eq('institute_id', instituteId);

      // Then set the selected year as current
      await _client
          .from(AppConstants.academicYearsTable)
          .update({'is_current': true, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', yearId)
          .eq('institute_id', instituteId); // Double check institute ownership

      AppHelpers.debugLog('Successfully set academic year $yearId as current for institute $instituteId');
    } catch (e) {
      AppHelpers.debugError('Set current academic year error: $e');
      rethrow;
    }
  }

  Future<void> updateAcademicYear({
  required String yearId,
  required String yearLabel,
  required int startYear,
  required int endYear,
  required DateTime startDate,
  required DateTime endDate,
  bool? isCurrent,
}) async {
  try {
    final updates = {
      'year_label': yearLabel,
      'start_year': startYear,
      'end_year': endYear,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (isCurrent != null) {
      updates['is_current'] = isCurrent;
    }

    await _client
        .from(AppConstants.academicYearsTable)
        .update(updates)
        .eq('id', yearId);
  } catch (e) {
    AppHelpers.debugError('Update academic year error: $e');
    rethrow;
  }
}

/// Delete academic year (with safety checks)
Future<void> deleteAcademicYear(String yearId) async {
  try {
    // Check if this year has any sessions
    final sessionsCount = await _client
        .from(AppConstants.sessionsTable)
        .select()
        .eq('academic_year_id', yearId);

    if ((sessionsCount as List).isNotEmpty) {
      throw Exception('Cannot delete academic year that has existing sessions');
    }

    // Check if this year has any admins assigned
    final adminsCount = await _client
        .from(AppConstants.profilesTable)
        .select()
        .eq('academic_year_id', yearId);

    if ((adminsCount as List).isNotEmpty) {
      throw Exception('Cannot delete academic year that has assigned admins');
    }

    await _client
        .from(AppConstants.academicYearsTable)
        .delete()
        .eq('id', yearId);
  } catch (e) {
    AppHelpers.debugError('Delete academic year error: $e');
    rethrow;
  }
}
  Future<List<AcademicYearModel>> getAcademicYears(String instituteId) async {
    try {
      final response = await _client
          .from(AppConstants.academicYearsTable)
          .select()
          .eq('institute_id', instituteId)
          .order('start_year', ascending: false);

      return (response as List)
          .map((json) => AcademicYearModel.fromJson(json))
          .toList();
    } catch (e) {
      AppHelpers.debugError('Get academic years error: $e');
      rethrow;
    }
  }

  /// Get current academic year
  Future<AcademicYearModel?> getCurrentAcademicYear(String instituteId) async {
    try {
      final response = await _client
          .from(AppConstants.academicYearsTable)
          .select()
          .eq('institute_id', instituteId)
          .eq('is_current', true)
          .single();

      return AcademicYearModel.fromJson(response);
    } catch (e) {
      AppHelpers.debugError('Get current academic year error: $e');
      return null;
    }
  }

  /// Create academic year
  Future<void> createAcademicYear({
    required String yearLabel,
    required int startYear,
    required int endYear,
    required DateTime startDate,
    required DateTime endDate,
    required String instituteId,
    bool isCurrent = false,
  }) async {
    try {
      // If setting as current, remove current flag from others
      if (isCurrent) {
        await _client
            .from(AppConstants.academicYearsTable)
            .update({'is_current': false})
            .eq('institute_id', instituteId);
      }

      await _client.from(AppConstants.academicYearsTable).insert({
        'year_label': yearLabel,
        'start_year': startYear,
        'end_year': endYear,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'institute_id': instituteId,
        'is_current': isCurrent,
      });
    } catch (e) {
      AppHelpers.debugError('Create academic year error: $e');
      rethrow;
    }
  }

  // ================== ANALYTICS & COUNTS ==================

  /// Get user count by institute
  Future<int> getUserCountByInstitute(String instituteId) async {
    try {
      final response = await _client
          .from(AppConstants.profilesTable)
          .select()
          .eq('institute_id', instituteId)
          .eq('role', AppConstants.userRole);

      return (response as List).length;
    } catch (e) {
      AppHelpers.debugError('Get user count error: $e');
      return 0;
    }
  }

  /// Get department count by institute
  Future<int> getDepartmentCountByInstitute(String instituteId) async {
    try {
      final response = await _client
          .from(AppConstants.departmentsTable)
          .select()
          .eq('institute_id', instituteId);

      return (response as List).length;
    } catch (e) {
      AppHelpers.debugError('Get department count error: $e');
      return 0;
    }
  }

  Future<int> getSessionCountByDepartmentAndYear(String departmentId, String academicYearId) async {
    try {
      final response = await _client
          .from(AppConstants.sessionsTable)
          .select()
          .eq('department_id', departmentId)
          .eq('academic_year_id', academicYearId);
      return (response as List).length;
    } catch (e) {
      AppHelpers.debugError('Get session count by department and year error: $e');
      return 0;
    }
}

  /// Get session count by department
  Future<int> getSessionCountByDepartment(String departmentId) async {
    try {
      final response = await _client
          .from(AppConstants.sessionsTable)
          .select()
          .eq('department_id', departmentId);
      return (response as List).length;
    } catch (e) {
      AppHelpers.debugError('Get session count error: $e');
      return 0;
    }
  }

  Future<void> deleteDepartment(String id) async {
  try {
    await _client
        .from(AppConstants.departmentsTable)
        .delete()
        .eq('id', id);
  } catch (e) {
    AppHelpers.debugError('Delete department error: $e');
    rethrow;
  }
}

/// Delete admin (removes admin role, keeps user account)
Future<void> deleteAdmin(String adminId) async {
  try {
    await _client
        .from(AppConstants.profilesTable)
        .delete()
        .eq('id', adminId);
  } catch (e) {
    AppHelpers.debugError('Delete admin error: $e');
    rethrow;
  }
}

/// Update institute with GPS coordinates
Future<void> updateInstituteWithGPS({
  required String id,
  required String name,
  String? address,
  String? phone,
  required int allowedRadius,
  double? gpsLatitude,
  double? gpsLongitude,
}) async {
  try {
    await _client
        .from(AppConstants.institutesTable)
        .update({
          'name': name,
          'address': address,
          'phone': phone,
          'allowed_radius': allowedRadius,
          'gps_latitude': gpsLatitude,
          'gps_longitude': gpsLongitude,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  } catch (e) {
    AppHelpers.debugError('Update institute with GPS error: $e');
    rethrow;
  }
}

  // ================== BULK OPERATIONS ==================

  /// Bulk create users
  Future<void> bulkCreateUsers(List<Map<String, dynamic>> users) async {
    try {
      await _client.from(AppConstants.profilesTable).insert(users);
    } catch (e) {
      AppHelpers.debugError('Bulk create users error: $e');
      rethrow;
    }
  }

  /// Delete multiple records
  Future<void> deleteRecords(String table, List<String> ids) async {
    try {
      await _client.from(table).delete().inFilter('id', ids);
    } catch (e) {
      AppHelpers.debugError('Delete records error: $e');
      rethrow;
    }
  }
}

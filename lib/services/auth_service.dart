import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:attendance_pro_app/models/user_model.dart';
import 'package:attendance_pro_app/constants/app_constants.dart';
import 'package:attendance_pro_app/utils/helpers.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;
  
  // Fixed: Use getter instead of property
  SupabaseClient get client => _client;

  /// Sign up a new user with email and password
  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    String? phone,
    String? role,
    String? instituteId,
    String? departmentId,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Sign up failed');
      }

      // Create profile after successful auth signup
      await _createUserProfile(
        userId: response.user!.id,
        email: email,
        name: name,
        phone: phone,
        role: role ?? AppConstants.userRole,
        instituteId: instituteId,
        departmentId: departmentId,
      );
    } catch (e) {
      AppHelpers.debugError('Auth signup error: $e');
      rethrow;
    }
  }

  /// Sign in existing user
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Sign in failed');
      }
    } catch (e) {
      AppHelpers.debugError('Auth signin error: $e');
      rethrow;
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      AppHelpers.debugError('Auth signout error: $e');
      rethrow;
    }
  }

  /// Get current authenticated user
  User? get currentUser => _client.auth.currentUser;

  /// Check if user is authenticated
  bool get isAuthenticated => currentUser != null;

  /// Get current user profile with full details
  Future<UserModel?> getCurrentUserProfile() async {
    try {
      print('🔄 Getting current user profile...');
      
      final user = currentUser;
      if (user == null) {
        print('❌ No current user found');
        return null;
      }
      print('✅ Current user exists: ${user.email}');
      print('Fetching profile for ID: ${user.id}');

      final response = await _client
          .from(AppConstants.profilesTable)
          .select()
          .eq('id', user.id)
          .single();

      print('✅ Profile fetched successfully');
      return UserModel.fromJson(response);
      
    } catch (e) {
      print('❌ Get user profile error: $e');
      print('❌ Error type: ${e.runtimeType}');
      
      AppHelpers.debugError('Get user profile error: $e');
      rethrow;
    }
  }

  /// Update user password
  Future<void> updatePassword(String newPassword) async {
    try {
      final response = await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      if (response.user == null) {
        throw Exception('Password update failed');
      }

      // Mark temp password as used
      await _client
          .from(AppConstants.profilesTable)
          .update({'temp_password_used': false})
          .eq('id', currentUser!.id);
    } catch (e) {
      AppHelpers.debugError('Update password error: $e');
      rethrow;
    }
  }

  /// Change password with current password verification
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = currentUser;
      if (user == null) {
        throw Exception('No authenticated user');
      }

      // Re-authenticate with current password
      await signIn(email: user.email!, password: currentPassword);
      
      // Update to new password
      await updatePassword(newPassword);
    } catch (e) {
      AppHelpers.debugError('Change password error: $e');
      rethrow;
    }
  }

  /// Register institute admin (first user registration)
  Future<void> registerInstituteAdmin({
    required String email,
    required String password,
    required String name,
    String? phone,
    required String instituteName,
    String? instituteAddress,
    String? institutePhone,
    double? gpsLatitude,
    double? gpsLongitude,
    int allowedRadius = 100,
  }) async {
    try {
      // 1. Create the auth user first
      final authResponse = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'phone': phone,
          'role': AppConstants.instituteAdminRole,
        },
      );

      if (authResponse.user == null) {
        throw Exception('Failed to create user account');
      }

      final userId = authResponse.user!.id;

      // 2. Create institute WITHOUT created_by to avoid FK issues
      final instituteResponse = await _client
          .from(AppConstants.institutesTable)
          .insert({
            'name': instituteName,
            'address': instituteAddress,
            'phone': institutePhone,
            'gps_latitude': gpsLatitude,
            'gps_longitude': gpsLongitude,
            'allowed_radius': allowedRadius,
            'created_by': null, // Temporarily null
          })
          .select('id')
          .single();

      final instituteId = instituteResponse['id'] as String;
      AppHelpers.debugLog('Created institute with ID: $instituteId');

      // 3. Create admin profile with the institute_id linkage
      await _client.from(AppConstants.profilesTable).insert({
        'id': userId,
        'user_id': 'INST_ADMIN_${DateTime.now().millisecondsSinceEpoch}',
        'name': name,
        'email': email,
        'phone': phone,
        'role': AppConstants.instituteAdminRole,
        'institute_id': instituteId,
        'account_status': 'active',
        'temp_password_used': false,
      });

      AppHelpers.debugLog('Created admin profile with institute_id: $instituteId');

      // 4. Update institute with created_by now that profile exists
      await _client
          .from(AppConstants.institutesTable)
          .update({'created_by': userId})
          .eq('id', instituteId);

      AppHelpers.debugLog('Institute admin registration completed successfully');
    } catch (e) {
      AppHelpers.debugError('Register institute admin error: $e');
      rethrow;
    }
  }

  /// Create institute admin for existing institute
  Future<void> createInstituteAdmin({
    required String email,
    required String password,
    required String name,
    String? phone,
    required String instituteId,
  }) async {
    try {
      // 1. Create the auth user
      final authResponse = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'phone': phone,
          'role': AppConstants.instituteAdminRole,
        },
      );

      if (authResponse.user == null) {
        throw Exception('Failed to create user account');
      }

      final userId = authResponse.user!.id;

      // 2. Create profile linked to institute
      await _client.from(AppConstants.profilesTable).insert({
        'id': userId,
        'user_id': 'INST_ADMIN_${DateTime.now().millisecondsSinceEpoch}',
        'name': name,
        'email': email,
        'phone': phone,
        'role': AppConstants.instituteAdminRole,
        'institute_id': instituteId,
        'account_status': 'active',
        'temp_password_used': false,
      });
    } catch (e) {
      AppHelpers.debugError('Create institute admin error: $e');
      rethrow;
    }
  }

  /// Create user account (admin creating users)
  Future<void> createUserAccount({
    required String email,
    required String userId,
    required String name,
    required String role,
    String? phone,
    required String instituteId,
    String? departmentId,
    String? academicYearId,
  }) async {
    try {
      final currentSession = _client.auth.currentSession;
      final tempPassword = AppConstants.generateTempPassword(userId);

      final authResponse = await _client.auth.signUp(
        email: email,
        password: tempPassword,
      );

      if (authResponse.user == null) {
        throw Exception('User creation failed');
      }

      await _createUserProfile(
        userId: authResponse.user!.id,
        email: email,
        name: name,
        phone: phone,
        role: role,
        instituteId: instituteId,
        departmentId: departmentId,
        customUserId: userId,
        isAdminCreated: true,
        academicYearId: academicYearId,
      );

      if (currentSession != null && currentSession.refreshToken != null) {
        await _client.auth.setSession(currentSession.refreshToken!);
      }
    } catch (e) {
      AppHelpers.debugError('Create user account error: $e');
      rethrow;
    }
  }

  /// Reset password via email
  Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } catch (e) {
      AppHelpers.debugError('Reset password error: $e');
      rethrow;
    }
  }

  /// Listen to auth state changes
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Send invitation email with temporary password
  Future<void> sendInvitationEmail({
    required String email,
    required String temporaryPassword,
    required String userName,
    required String instituteName,
    required String role,
  }) async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('No authenticated user');

      final response = await _client.functions.invoke(
        'send-invitation-email',
        body: {
          'email': email,
          'temporaryPassword': temporaryPassword,
          'userName': userName,
          'instituteName': instituteName,
          'role': role,
          'createdBy': user.id,
        },
        headers: {
          'Authorization': 'Bearer ${_client.auth.currentSession?.accessToken}',
        },
      );

      if (response.status != 200) {
        throw Exception('Failed to send invitation email');
      }

      AppHelpers.debugLog('Invitation email sent successfully');
    } catch (e) {
      AppHelpers.debugError('Send invitation email error: $e');
      rethrow;
    }
  }

  /// Send forgot password email
  Future<void> sendForgotPasswordEmail(String email) async {
    try {
      final response = await _client.functions.invoke(
        'send-forgot-password-email',
        body: {'email': email},
      );

      if (response.status != 200) {
        throw Exception('Failed to send password reset email');
      }

      AppHelpers.debugLog('Password reset email sent successfully');
    } catch (e) {
      AppHelpers.debugError('Send forgot password email error: $e');
      rethrow;
    }
  }

  /// Reset password using token - FIXED VERSION
  Future<void> resetPasswordWithToken({
    required String token,
    required String newPassword,
  }) async {
    try {
      // Verify token and get user
      final tokenResponse = await _client
          .from('password_reset_tokens')
          .select('user_id, expires_at, used')
          .eq('token', token)
          .eq('used', false)
          .single();

      final tokenData = tokenResponse;
      final expiresAt = DateTime.parse(tokenData['expires_at']);
      
      if (DateTime.now().isAfter(expiresAt)) {
        throw Exception('Reset token has expired');
      }

      final userId = tokenData['user_id'];

      // FIXED: Use AdminUserAttributes instead of UserAttributes
      final authResponse = await _client.auth.admin.updateUserById(
        userId,
        attributes: AdminUserAttributes(
          password: newPassword, // This is the correct way
        ),
      );

      if (authResponse.user == null) {
        throw Exception('Failed to update password');
      }

      // Mark token as used
      await _client
          .from('password_reset_tokens')
          .update({'used': true})
          .eq('token', token);

      // Fixed column name: temp_password_used instead of temppasswordused
      await _client
          .from(AppConstants.profilesTable)
          .update({'temp_password_used': false})
          .eq('id', userId);

    } catch (e) {
      AppHelpers.debugError('Reset password with token error: $e');
      rethrow;
    }
  }

  /// Enhanced user creation with email invitation
  Future<void> createUserAccountWithInvitation({
    required String email,
    required String userId,
    required String name,
    required String role,
    String? phone,
    required String instituteId,
    String? departmentId,
    String? academicYearId,
  }) async {
    try {
      // Get current session for restoration
      final currentSession = _client.auth.currentSession;
      
      // Generate temp password
      final tempPassword = AppConstants.generateTempPassword(userId);
      
      // Create auth user
      final authResponse = await _client.auth.signUp(
        email: email,
        password: tempPassword,
      );

      if (authResponse.user == null) {
        throw Exception('User creation failed');
      }

      // Create profile - FIXED: Use the correct method name
      await _createUserProfile(
        userId: authResponse.user!.id,
        email: email,
        name: name,
        phone: phone,
        role: role,
        instituteId: instituteId,
        departmentId: departmentId,
        customUserId: userId,
        isAdminCreated: true,
        academicYearId: academicYearId,
      );

      // Get institute info for email
      final institute = await _client
          .from(AppConstants.institutesTable)
          .select('name')
          .eq('id', instituteId)
          .single();

      // Send invitation email
      await sendInvitationEmail(
        email: email,
        temporaryPassword: tempPassword,
        userName: name,
        instituteName: institute['name'] ?? 'Institute',
        role: role,
      );

      // Restore current session
      if (currentSession?.refreshToken != null) {
        await _client.auth.setSession(currentSession!.refreshToken!);
      }

    } catch (e) {
      AppHelpers.debugError('Create user account with invitation error: $e');
      rethrow;
    }
  }

  /// Private helper to create user profile
  Future<void> _createUserProfile({
    required String userId,
    required String email,
    required String name,
    String? phone,
    required String role,
    String? instituteId,
    String? departmentId,
    String? customUserId,
    bool isAdminCreated = false,
    String? academicYearId,
  }) async {
    bool tempPasswordUsed = true;
    if (role == AppConstants.userRole && isAdminCreated) {
      tempPasswordUsed = false; 
    }

    await _client.from(AppConstants.profilesTable).insert({
      'id': userId,
      'user_id': customUserId ?? userId,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'institute_id': instituteId,
      'department_id': departmentId,
      'academic_year_id': academicYearId, 
      'account_status': AppConstants.activeStatus,
      'temp_password_used': tempPasswordUsed,
    });
  }

  /// Update user profile
  Future<void> updateProfile({
    String? name,
    String? phone,
    String? departmentId,
  }) async {
    try {
      final user = currentUser;
      if (user == null) {
        throw Exception('No authenticated user');
      }

      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (name != null) updates['name'] = name;
      if (phone != null) updates['phone'] = phone;
      if (departmentId != null) updates['department_id'] = departmentId;

      await _client
          .from(AppConstants.profilesTable)
          .update(updates)
          .eq('id', user.id);
    } catch (e) {
      AppHelpers.debugError('Update profile error: $e');
      rethrow;
    }
  }

  /// Delete user account
  Future<void> deleteAccount() async {
    try {
      final user = currentUser;
      if (user == null) {
        throw Exception('No authenticated user');
      }

      // Delete profile first
      await _client
          .from(AppConstants.profilesTable)
          .delete()
          .eq('id', user.id);

      // Sign out
      await signOut();
    } catch (e) {
      AppHelpers.debugError('Delete account error: $e');
      rethrow;
    }
  }
}

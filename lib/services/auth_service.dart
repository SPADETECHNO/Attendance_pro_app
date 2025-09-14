import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:attendance_pro_app/models/user_model.dart';
import 'package:attendance_pro_app/constants/app_constants.dart';
import 'package:attendance_pro_app/utils/helpers.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

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
      
      // Don't silently return null - this hides the real problem
      AppHelpers.debugError('Get user profile error: $e');
      
      // For debugging, rethrow to see the actual error
      rethrow; // This will show you the real problem!
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
        'institute_id': instituteId, // ✅ THIS IS THE KEY FIX
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

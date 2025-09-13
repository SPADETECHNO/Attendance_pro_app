import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:attendance_pro_app/services/auth_service.dart';
import 'package:attendance_pro_app/screens/auth/login_screen.dart';
import 'package:attendance_pro_app/screens/auth/force_password_change_screen.dart';
import 'package:attendance_pro_app/screens/super_admin/super_dashboard.dart';
import 'package:attendance_pro_app/screens/institute_admin/institute_dashboard.dart';
import 'package:attendance_pro_app/screens/admin/admin_dashboard.dart';
import 'package:attendance_pro_app/screens/users/user_dashboard.dart';
import 'package:attendance_pro_app/utils/constants.dart';
import 'package:attendance_pro_app/utils/helpers.dart';
import 'package:attendance_pro_app/constants/app_constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: AppDurations.verySlow,
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));
    
    _initializeApp();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    try {
      // Start animations
      _animationController.forward();
      
      // Minimum splash duration for branding
      await Future.delayed(AppDurations.slow);
      
      final authService = context.read<AuthService>();
      final user = await authService.getCurrentUserProfile();
      
      if (!mounted) return;
      
      if (user == null) {
        // User not authenticated, go to login
        _navigateToLogin();
      } else if (user.tempPasswordUsed) {
        // User needs to change password
        _navigateToPasswordChange(user.email);
      } else {
        // User authenticated, navigate based on role
        _navigateToRoleDashboard(user.role);
      }
    } catch (e) {
      AppHelpers.debugError('Splash screen error: $e');
      if (mounted) {
        _navigateToLogin();
      }
    }
  }

  void _navigateToLogin() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
        transitionDuration: AppDurations.normal,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _navigateToPasswordChange(String email) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => 
            ForcePasswordChangeScreen(email: email),
        transitionDuration: AppDurations.normal,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _navigateToRoleDashboard(String role) {
    Widget dashboard;
    
    switch (role) {
      case AppConstants.superAdminRole:
        dashboard = const SuperDashboard();
        break;
      case AppConstants.instituteAdminRole:
        dashboard = const InstituteDashboard();
        break;
      case AppConstants.adminRole:
        dashboard = const AdminDashboard();
        break;
      case AppConstants.userRole:
        dashboard = const UserDashboard();
        break;
      default:
        dashboard = const LoginScreen();
    }
    
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => dashboard,
        transitionDuration: AppDurations.normal,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: animation.drive(
              Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                  .chain(CurveTween(curve: Curves.easeInOut)),
            ),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo Animation
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Opacity(
                      opacity: _opacityAnimation.value,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(AppSizes.radiusXl),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.event_available,
                          size: 60,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: AppSizes.xl),
              
              // App Name Animation
              AnimatedBuilder(
                animation: _opacityAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _opacityAnimation.value,
                    child: Column(
                      children: [
                        Text(
                          AppStrings.appName,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: AppSizes.sm),
                        Text(
                          AppInfo.description,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: AppColors.white.withOpacity(0.9),
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
              
              const SizedBox(height: AppSizes.xxxl),
              
              // Loading Animation
              LoadingAnimationWidget.progressiveDots(
                color: AppColors.white,
                size: 50,
              ),
              
              const SizedBox(height: AppSizes.lg),
              
              // Version Info
              AnimatedBuilder(
                animation: _opacityAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _opacityAnimation.value * 0.7,
                    child: Text(
                      'Version ${AppInfo.version}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.white.withOpacity(0.7),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

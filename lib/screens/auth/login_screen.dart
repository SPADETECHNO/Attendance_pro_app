import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attendance_pro_app/services/auth_service.dart';
import 'package:attendance_pro_app/widgets/custom_button.dart';
import 'package:attendance_pro_app/widgets/custom_text_field.dart';
import 'package:attendance_pro_app/screens/auth/register_screen.dart';
import 'package:attendance_pro_app/screens/auth/splash_screen.dart';
import 'package:attendance_pro_app/utils/constants.dart';
import 'package:attendance_pro_app/utils/helpers.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = context.read<AuthService>();
      await authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        AppHelpers.showSuccessToast(AppStrings.successLogin);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SplashScreen()),
        );
      }
    } catch (e) {
      AppHelpers.showErrorToast(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.lock_reset,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppSizes.sm),
              const Text('Forgot Password?'),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter your email address and we\'ll send you a secure link to reset your password.',
                  style: TextStyle(height: 1.4),
                ),
                const SizedBox(height: AppSizes.lg),
                CustomTextField(
                  label: 'Email Address',
                  hint: 'Enter your registered email',
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.email_outlined,
                  validator: AppHelpers.validateEmail,
                  enabled: !isSubmitting,
                ),
                const SizedBox(height: AppSizes.sm),
                Container(
                  padding: const EdgeInsets.all(AppSizes.sm),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: AppSizes.iconSm,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: AppSizes.xs),
                      Expanded(
                        child: Text(
                          'The reset link will expire in 15 minutes for security.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (formKey.currentState?.validate() ?? false) {
                        setDialogState(() => isSubmitting = true);
                        
                        try {
                          final authService = context.read<AuthService>();
                          await authService.sendForgotPasswordEmail(
                            emailController.text.trim(),
                          );
                          
                          if (context.mounted) {
                            Navigator.pop(context, true);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            AppHelpers.showErrorToast(
                              'Failed to send reset email. Please try again.',
                            );
                            setDialogState(() => isSubmitting = false);
                          }
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send Reset Link'),
            ),
          ],
        ),
      ),
    );

    emailController.dispose();

    if (result == true && mounted) {
      AppHelpers.showSuccessToast(
        'Password reset link sent! Please check your email and spam folder.',
      );
    }
  }

  void _navigateToRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: size.height * 0.08),
                
                // Logo Section
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(AppSizes.lg),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppSizes.radiusXl),
                    ),
                    child: Icon(
                      Icons.event_available,
                      size: AppSizes.iconXl + 20,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                
                const SizedBox(height: AppSizes.xl),
                
                // Welcome Text
                Text(
                  'Welcome Back!',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onBackground,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: AppSizes.sm),
                
                Text(
                  'Sign in to continue to ${AppStrings.appName}',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onBackground.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: AppSizes.xxxl),
                
                // Email Field
                CustomTextField(
                  label: AppStrings.email,
                  hint: 'Enter your ${AppStrings.email.toLowerCase()}',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.email_outlined,
                  validator: AppHelpers.validateEmail,
                ),
                
                const SizedBox(height: AppSizes.lg),
                
                // Password Field
                CustomTextField(
                  label: AppStrings.password,
                  hint: 'Enter your ${AppStrings.password.toLowerCase()}',
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  prefixIcon: Icons.lock_outline,
                  suffixIcon: _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  onSuffixIconTap: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                  validator: AppHelpers.validatePassword,
                ),
                
                const SizedBox(height: AppSizes.md),
                
                // Forgot Password Link
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading ? null : _showForgotPasswordDialog,
                    child: Text(
                      AppStrings.forgotPassword,
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: AppSizes.xl),
                
                // Login Button
                CustomButton(
                  text: AppStrings.login,
                  onPressed: _signIn,
                  isLoading: _isLoading,
                  icon: Icons.login,
                ),
                
                const SizedBox(height: AppSizes.xl),
                
                // Divider
                Row(
                  children: [
                    Expanded(
                      child: Divider(color: theme.colorScheme.outline),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
                      child: Text(
                        'OR',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(color: theme.colorScheme.outline),
                    ),
                  ],
                ),
                
                const SizedBox(height: AppSizes.xl),
                
                // Register Button
                CustomButton(
                  text: 'Create New Account',
                  onPressed: _navigateToRegister,
                  isOutlined: true,
                  icon: Icons.person_add,
                ),
                
                const SizedBox(height: AppSizes.lg),
                
                // App Info
                Center(
                  child: Column(
                    children: [
                      Text(
                        AppInfo.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSizes.xs),
                      Text(
                        'Version ${AppInfo.version}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/layout/app_page_container.dart';
import '../widgets/layout/app_scaffold.dart';
import '../widgets/ui/app_card.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (success && mounted) {
        // Navigate to dashboard route which uses StaffDrawerShell with user key
        // This ensures the AdvancedDrawer controller is properly initialized
        Navigator.of(context).pushReplacementNamed('/dashboard');
      } else if (mounted) {
        // Error message is shown via Consumer below
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppScaffold(
      extendBodyBehindAppBar: true,
      header: Row(
        children: [
          const CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme.neutral20,
            child: Icon(Icons.local_taxi_outlined, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: AppTheme.spacingM),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('NSC Transport', style: theme.textTheme.titleMedium),
              Text(
                'Transport Operations Portal',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingXXL),
          child: AppPageContainer(
            maxWidth: 440,
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
            child: AppCard(
              showShadow: true,
              borderColor: Colors.transparent,
              padding: const EdgeInsets.all(AppTheme.spacingXL),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.directions_car_filled_rounded,
                        size: 48, color: AppTheme.primaryColor),
                    const SizedBox(height: AppTheme.spacingL),
                    Text('Welcome Back', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: AppTheme.spacingXS),
                    Text(
                      'Sign in with your staff credentials to manage transport requests.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppTheme.spacingXL),
                    Consumer<AuthProvider>(
                      builder: (context, authProvider, _) {
                        final error = authProvider.errorMessage;
                        if (error == null) return const SizedBox.shrink();
                        return AppCard(
                          backgroundColor: colorScheme.error.withOpacity(.08),
                          borderColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacingM,
                            vertical: AppTheme.spacingS,
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline,
                                  color: colorScheme.error, size: 20),
                              const SizedBox(width: AppTheme.spacingS),
                              Expanded(
                                child: Text(
                                  error,
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(color: colorScheme.error),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: AppTheme.spacingL),
                    Text('Email', style: theme.textTheme.labelLarge),
                    const SizedBox(height: AppTheme.spacingS),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        hintText: 'you@example.com',
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppTheme.spacingL),
                    Text('Password', style: theme.textTheme.labelLarge),
                    const SizedBox(height: AppTheme.spacingS),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _handleLogin(),
                      decoration: InputDecoration(
                        hintText: 'Enter your password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppTheme.spacingXL),
                    Consumer<AuthProvider>(
                      builder: (context, authProvider, _) {
                        return FilledButton(
                          onPressed: authProvider.isLoading ? null : _handleLogin,
                          child: authProvider.isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2.5),
                                )
                              : const Text('Sign In'),
                        );
                      },
                    ),
                    const SizedBox(height: AppTheme.spacingL),
                    Text(
                      'Need help? Contact the transport team.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ziesocial/viewmodel/login_viewmodel.dart';
import 'package:ziesocial/views/main_navigation_shell.dart';
import 'package:ziesocial/views/register_view.dart';
import 'package:ziesocial/widget/auth_components.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _validateInputs() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    String? nextEmailError;
    String? nextPasswordError;

    if (email.isEmpty) {
      nextEmailError = 'Email wajib diisi.';
    }
    if (password.isEmpty) {
      nextPasswordError = 'Password wajib diisi.';
    }

    setState(() {
      _emailError = nextEmailError;
      _passwordError = nextPasswordError;
    });

    return nextEmailError == null && nextPasswordError == null;
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    if (!_validateInputs()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final success = await context.read<LoginViewModel>().login(
      email: email,
      password: password,
    );

    if (!mounted) return;

    if (success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainNavigationShell()),
      );
    } else {
      final errorMessage = context.read<LoginViewModel>().errorMessage;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            backgroundColor: ZieAuthColors.error,
            content: Text(errorMessage ?? 'Login gagal.'),
          ),
        );
    }
  }

  void _onForgotPassword() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Fitur lupa kata sandi belum tersedia saat ini.'),
        ),
      );
  }

  Future<void> _loginWithGoogle() async {
    FocusScope.of(context).unfocus();

    final loginVm = context.read<LoginViewModel>();
    final success = await loginVm.loginWithGoogle();

    if (!mounted) return;

    if (success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainNavigationShell()),
      );
    } else if (!loginVm.wasGoogleCancelled) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            backgroundColor: ZieAuthColors.error,
            content: Text(loginVm.errorMessage ?? 'Login dengan Google gagal.'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loginVm = context.watch<LoginViewModel>();
    final isLoading = loginVm.isLoading;
    final isGoogleLoading = loginVm.isGoogleLoading;

    return Scaffold(
      backgroundColor: ZieAuthColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 48).clamp(
                    0.0,
                    double.infinity,
                  ),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Sign In',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: ZieAuthColors.textPrimary,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Hi! Welcome back, you've been missed",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: ZieAuthColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 36),

                        AuthTextField(
                          controller: _emailController,
                          label: 'Email',
                          hintText: 'example@gmail.com',
                          prefixIcon: Icons.mail_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          enabled: !isLoading,
                          errorText: _emailError,
                          onChanged: (_) {
                            if (_emailError != null) {
                              setState(() => _emailError = null);
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        AuthTextField(
                          controller: _passwordController,
                          label: 'Password',
                          hintText: '••••••••••••',
                          prefixIcon: Icons.lock_outline_rounded,
                          isPassword: true,
                          textInputAction: TextInputAction.done,
                          enabled: !isLoading,
                          errorText: _passwordError,
                          onChanged: (_) {
                            if (_passwordError != null) {
                              setState(() => _passwordError = null);
                            }
                          },
                          onSubmitted: (_) {
                            if (!isLoading) _login();
                          },
                        ),
                        const SizedBox(height: 8),

                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: isLoading ? null : _onForgotPassword,
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              foregroundColor: ZieAuthColors.primary,
                            ),
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                                decorationColor: ZieAuthColors.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        AuthPrimaryButton(
                          label: 'Sign In',
                          onPressed: isLoading ? null : _login,
                          isLoading: isLoading && !isGoogleLoading,
                        ),
                        const SizedBox(height: 28),

                        const AuthDivider(text: 'Or sign in with'),
                        const SizedBox(height: 24),

                        AuthGoogleButton(
                          onPressed: isLoading ? null : _loginWithGoogle,
                          isLoading: isGoogleLoading,
                        ),
                        const SizedBox(height: 28),

                        Center(
                          child: TextButton(
                            onPressed: isLoading
                                ? null
                                : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const RegisterView(),
                                      ),
                                    );
                                  },
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                            ),
                            child: RichText(
                              textAlign: TextAlign.center,
                              text: const TextSpan(
                                style: TextStyle(
                                  fontSize: 14,
                                  color: ZieAuthColors.textSecondary,
                                ),
                                children: [
                                  TextSpan(text: "Don't have an account? "),
                                  TextSpan(
                                    text: 'Sign Up',
                                    style: TextStyle(
                                      color: ZieAuthColors.primary,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                      decorationColor: ZieAuthColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

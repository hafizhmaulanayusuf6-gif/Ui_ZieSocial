import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ziesocial/viewmodel/register_viewmodel.dart';
import 'package:ziesocial/widget/auth_components.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _nameError;
  String? _usernameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _validateInputs() {
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    String? nextNameError;
    String? nextUsernameError;
    String? nextEmailError;
    String? nextPasswordError;
    String? nextConfirmError;

    if (name.isEmpty) {
      nextNameError = 'Nama lengkap wajib diisi.';
    }
    if (username.isEmpty) {
      nextUsernameError = 'Username wajib diisi.';
    }
    if (email.isEmpty) {
      nextEmailError = 'Email wajib diisi.';
    }
    if (password.isEmpty) {
      nextPasswordError = 'Password wajib diisi.';
    }
    if (confirmPassword.isEmpty) {
      nextConfirmError = 'Konfirmasi password wajib diisi.';
    } else if (password != confirmPassword) {
      nextConfirmError = 'Password dan konfirmasi password tidak cocok.';
    }

    setState(() {
      _nameError = nextNameError;
      _usernameError = nextUsernameError;
      _emailError = nextEmailError;
      _passwordError = nextPasswordError;
      _confirmPasswordError = nextConfirmError;
    });

    return nextNameError == null &&
        nextUsernameError == null &&
        nextEmailError == null &&
        nextPasswordError == null &&
        nextConfirmError == null;
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();
    if (!_validateInputs()) return;

    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final success = await context.read<RegisterViewmodel>().register(
      name: name,
      username: username,
      email: email,
      password: password,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            backgroundColor: ZieAuthColors.success,
            content: Text('Registrasi berhasil! Silakan login.'),
          ),
        );
      Navigator.pop(context);
    } else {
      final errorMessage = context.read<RegisterViewmodel>().errorMessage;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            backgroundColor: ZieAuthColors.error,
            content: Text(errorMessage ?? 'Registrasi gagal.'),
          ),
        );
    }
  }

  // UI-only placeholder: Google OAuth / Firebase Auth belum diaktifkan
  void _onGoogleSignUpPressed() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Daftar dengan Google belum tersedia pada versi ini.'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<RegisterViewmodel>().isLoading;

    return Scaffold(
      backgroundColor: ZieAuthColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 36).clamp(
                    0.0,
                    double.infinity,
                  ),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            onPressed: isLoading
                                ? null
                                : () => Navigator.pop(context),
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            tooltip: 'Kembali',
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              color: ZieAuthColors.textPrimary,
                              size: 22,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        const Text(
                          'Create Account',
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
                          'Fill your information below or register\nwith your social account.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: ZieAuthColors.textSecondary,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 28),

                        AuthTextField(
                          controller: _nameController,
                          label: 'Name',
                          hintText: 'John Doe',
                          prefixIcon: Icons.person_outline_rounded,
                          textInputAction: TextInputAction.next,
                          enabled: !isLoading,
                          errorText: _nameError,
                          onChanged: (_) {
                            if (_nameError != null) {
                              setState(() => _nameError = null);
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        AuthTextField(
                          controller: _usernameController,
                          label: 'Username',
                          hintText: 'johndoe',
                          prefixIcon: Icons.alternate_email_rounded,
                          textInputAction: TextInputAction.next,
                          enabled: !isLoading,
                          errorText: _usernameError,
                          onChanged: (_) {
                            if (_usernameError != null) {
                              setState(() => _usernameError = null);
                            }
                          },
                        ),
                        const SizedBox(height: 16),

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
                          textInputAction: TextInputAction.next,
                          enabled: !isLoading,
                          errorText: _passwordError,
                          onChanged: (_) {
                            if (_passwordError != null) {
                              setState(() => _passwordError = null);
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        AuthTextField(
                          controller: _confirmPasswordController,
                          label: 'Confirm Password',
                          hintText: '••••••••••••',
                          prefixIcon: Icons.lock_outline_rounded,
                          isPassword: true,
                          textInputAction: TextInputAction.done,
                          enabled: !isLoading,
                          errorText: _confirmPasswordError,
                          onChanged: (_) {
                            if (_confirmPasswordError != null) {
                              setState(() => _confirmPasswordError = null);
                            }
                          },
                          onSubmitted: (_) {
                            if (!isLoading) _register();
                          },
                        ),
                        const SizedBox(height: 24),

                        AuthPrimaryButton(
                          label: 'Sign Up',
                          onPressed: _register,
                          isLoading: isLoading,
                        ),
                        const SizedBox(height: 24),

                        const AuthDivider(text: 'Or sign up with'),
                        const SizedBox(height: 20),

                        AuthGoogleButton(
                          onPressed: isLoading ? null : _onGoogleSignUpPressed,
                        ),
                        const SizedBox(height: 24),

                        Center(
                          child: TextButton(
                            onPressed: isLoading
                                ? null
                                : () => Navigator.pop(context),
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
                                  TextSpan(text: 'Already have an account? '),
                                  TextSpan(
                                    text: 'Sign In',
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

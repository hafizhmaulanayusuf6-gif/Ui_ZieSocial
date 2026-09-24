import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ziesocial/viewmodel/register_viewmodel.dart'; // Sesuaikan path-nya

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  // 1. Buat Controller untuk setiap input teks
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // 2. Buat fungsi eksekusi Register
  Future<void> _register() async {
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // Validasi kosong
    if (name.isEmpty || username.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Semua field wajib diisi.')),
      );
      return;
    }

    // Validasi kecocokan password
    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password dan Confirm Password tidak cocok.')),
      );
      return;
    }

    // Panggil fungsi register di ViewModel
    final success = await context.read<RegisterViewmodel>().register(
          name: name,
          username: username,
          email: email,
          password: password,
        );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registrasi berhasil! Silakan login.')),
      );
      Navigator.pop(context); // Kembali ke halaman Login
    } else {
      final errorMessage = context.read<RegisterViewmodel>().errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage ?? 'Registrasi gagal.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Pantau status loading
    final isLoading = context.watch<RegisterViewmodel>().isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Color(0xFF4B4BD8), size: 20),
              ),
              const SizedBox(height: 55),
              // ... (Bagian Text Header dan Upload Photo biarkan sama seperti sebelumnya) ...
              
              _buildLabel('Full Name'),
              const SizedBox(height: 5),
              _buildTextField(
                controller: _nameController, // Masukkan controller
                hintText: 'Full Name',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 10),

              _buildLabel('Username'),
              const SizedBox(height: 5),
              _buildTextField(
                controller: _usernameController,
                hintText: 'Username',
                icon: Icons.alternate_email,
              ),
              const SizedBox(height: 10),

              _buildLabel('Email Address'),
              const SizedBox(height: 5),
              _buildTextField(
                controller: _emailController,
                hintText: 'Email Address',
                icon: Icons.email_outlined,
              ),
              const SizedBox(height: 10),

              _buildLabel('Password'),
              const SizedBox(height: 5),
              _buildTextField(
                controller: _passwordController,
                hintText: 'Password',
                icon: Icons.lock_outline,
                obscureText: true,
                showPasswordIcon: true,
              ),
              const SizedBox(height: 10),

              _buildLabel('Confirm Password'),
              const SizedBox(height: 5),
              _buildTextField(
                controller: _confirmPasswordController,
                hintText: 'Confirm Password',
                icon: Icons.lock_outline,
                obscureText: true,
                showPasswordIcon: true,
              ),
              const SizedBox(height: 15),

              SizedBox(
                width: double.infinity,
                height: 38,
                child: ElevatedButton(
                  // Matikan tombol saat loading
                  onPressed: isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4B4BD8),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              // ... (Bagian bawah / Tombol Login biarkan sama seperti sebelumnya) ...
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
    );
  }

  // 3. Tambahkan parameter TextEditingController di sini
  static Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool obscureText = false,
    bool showPasswordIcon = false,
  }) {
    return TextField(
      controller: controller, // Hubungkan controller
      obscureText: obscureText,
      style: const TextStyle(fontSize: 10),
      decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(fontSize: 10, color: Colors.grey.shade500),
          prefixIcon: Icon(icon, size: 17, color: Colors.grey.shade600),
          suffixIcon: showPasswordIcon
              ? Icon(Icons.visibility_off_outlined, size: 17, color: Colors.grey.shade500)
              : null,
          filled: true,
          fillColor: const Color(0xFFF4F4F6),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFF4B4BD8)),
          )),
    );
  }
}
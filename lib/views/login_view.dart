import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; //[cite: 1]
import 'package:ziesocial/viewmodel/login_viewmodel.dart';
import 'package:ziesocial/views/register_view.dart';
import 'home_view.dart';
// Sesuaikan import di bawah ini sesuai lokasi LoginViewModel di project Anda
// import 'package:ziesocial/viewmodel/login_viewmodel.dart'; 

class LoginView extends StatefulWidget { //[cite: 1]
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState(); //[cite: 1]
}

class _LoginViewState extends State<LoginView> {
  final _emailController = TextEditingController(); //[cite: 1]
  final _passwordController = TextEditingController(); //[cite: 1]

  @override
  void dispose() {
    _emailController.dispose(); //[cite: 1]
    _passwordController.dispose(); //[cite: 1]
    super.dispose(); //[cite: 1]
  }

  Future<void> _login() async { //[cite: 1]
    final email = _emailController.text.trim(); //[cite: 1]
    final password = _passwordController.text; //[cite: 1]

    if (email.isEmpty || password.isEmpty) { //[cite: 1]
      ScaffoldMessenger.of(context).showSnackBar( //[cite: 1]
        const SnackBar(
          content: Text('Email dan password wajib diisi.'), //[cite: 1]
        ),
      );
      return; //[cite: 1]
    }

    // Memanggil LoginViewModel via Provider[cite: 1]
    final success = await context.read<LoginViewModel>().login(
          email: email,
          password: password,
        ); //[cite: 1]

    if (!mounted) return; //[cite: 1]

    if (success) { //[cite: 1]
      Navigator.pushReplacement( //[cite: 1]
        context,
        MaterialPageRoute(
          builder: (context) => const HomeView(), //[cite: 1]
        ),
      );
    } else {
      final errorMessage = context.read<LoginViewModel>().errorMessage; //[cite: 1]
      ScaffoldMessenger.of(context).showSnackBar( //[cite: 1]
        SnackBar(
          content: Text(errorMessage ?? 'Login gagal.'), //[cite: 1]
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Memantau status loading dari LoginViewModel[cite: 1]
    final isLoading = context.watch<LoginViewModel>().isLoading; //[cite: 1]

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(
                maxWidth: 400,
              ),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      'ZieSocial',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF4B4BD8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Welcome back. Please enter your details.',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),

                  const Text(
                    'Email',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),

                  TextField(
                    controller: _emailController, // Menambahkan controller[cite: 1]
                    keyboardType: TextInputType.emailAddress, // Menambahkan tipe input[cite: 1]
                    decoration: InputDecoration(
                      hintText: 'Enter Your Email',
                      hintStyle: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade400,
                      ),
                      prefixIcon: Icon(
                        Icons.email_outlined,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF4F4F6),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(
                          color: Colors.grey.shade300,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(
                          color: Colors.grey.shade300,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: Color(0xFF4B4BD8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text(
                    'Password',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),

                  TextField(
                    controller: _passwordController, // Menambahkan controller[cite: 1]
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: '••••••••',
                      hintStyle: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade400,
                      ),
                      prefixIcon: Icon(
                        Icons.lock_outline, // Mengganti ikon agar lebih sesuai
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF4F4F6),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(
                          color: Colors.grey.shade300,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(
                          color: Colors.grey.shade300,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(
                          color: Color(0xFF4B4BD8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Forgot Password?',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF4B4BD8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 38,
                    child: ElevatedButton(
                      // Memanggil fungsi _login dan menampilkan indikator saat loading[cite: 1]
                      onPressed: isLoading ? null : _login, 
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
                              'Login',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  Divider(
                    color: Colors.grey.shade200,
                    thickness: 1,
                  ),
                  const SizedBox(height: 14),

                  Center(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RegisterView(),
                          ),
                        );
                      },
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                          children: const [
                            TextSpan(
                              text: "Don't have an account? ",
                            ),
                            TextSpan(
                              text: 'Create an account',
                              style: TextStyle(
                                color: Color(0xFF4B4BD8),
                                fontWeight: FontWeight.w600,
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
      ),
    );
  }
}
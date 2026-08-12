import 'package:flutter/material.dart';

class RegisterView extends StatelessWidget {
  const RegisterView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(
                  Icons.arrow_back,
                  color: Color(0xFF4B4BD8),
                  size: 20,
                ),
              ),
              const SizedBox(height: 55),

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
                  "Join the community. Let's get started.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Center(
                child: Column(
                  children: [
                    Container(
                      width: 66,
                      height: 66,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8E8EA),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add_a_photo_outlined,
                        color: Colors.grey.shade600,
                        size: 25,
                      ),
                    ),
                    const SizedBox(height: 7),

                    Text(
                      'Upload Photo',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              _buildLabel('Full Name'),

              const SizedBox(height: 5),
              _buildTextField(
                hintText: 'Full Name',
                icon: Icons.person_outline,
              ),

              const SizedBox(height: 10),

              // Username
              _buildLabel('Username'),

              const SizedBox(height: 5),

              _buildTextField(
                hintText: 'Username',
                icon: Icons.alternate_email,
              ),

              const SizedBox(height: 10),

              // Email
              _buildLabel('Email Address'),

              const SizedBox(height: 5),

              _buildTextField(
                hintText: 'Email Address',
                icon: Icons.email_outlined,
              ),

              const SizedBox(height: 10),

              // Password
              _buildLabel('Password'),

              const SizedBox(height: 5),

              _buildTextField(
                hintText: 'Password',
                icon: Icons.lock_outline,
                obscureText: true,
                showPasswordIcon: true,
              ),

              const SizedBox(height: 10),

              // Confirm Password
              _buildLabel('Confirm Password'),

              const SizedBox(height: 5),

              _buildTextField(
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
                  onPressed: () {}, 
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4B4BD8),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 17),

              Center(
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600
                      ),
                      children: const[
                        TextSpan(
                          text: 'Already have an account? ',
                        ),
                        TextSpan(
                          text: 'Login',
                          style: TextStyle(
                            color: Color(0xFF4B4BD8),
                            fontWeight: FontWeight.w600,
                          )
                        )
                      ]
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 15),
            ],
          ),
        )
      ),
    );
  }
  static Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  static Widget _buildTextField({
    required String hintText,
    required IconData icon,
    bool obscureText = false,
    bool showPasswordIcon = false,
  }) {
    return TextField(
      obscureText: obscureText,
      style: const TextStyle(
        fontSize: 10
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          fontSize: 10,
          color: Colors.grey.shade500,
        ),
        prefixIcon: Icon(
          icon,
          size: 17,
          color: Colors.grey.shade600,
        ),
        
        suffixIcon: showPasswordIcon
            ? Icon(
                Icons.visibility_off_outlined,
                size: 17,
                color: Colors.grey.shade500,
              )
            : null,

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
            color: Colors.grey.shade300
          ),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(
            color: Color(0xFF4B4BD8),
          )
        )
      ),
    );
  }
}
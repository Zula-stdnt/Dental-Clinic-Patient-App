import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'signup_page.dart';
import 'main_screen.dart';
import 'forgot_password.dart';
import 'captcha_widget.dart';
import 'config.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _captchaController = TextEditingController();
  String _currentCaptchaHash = '';

  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _login() async {
    if (_captchaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Please complete the CAPTCHA verification."),
          backgroundColor: Colors.red.shade600,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/login.php');
      final response = await http.post(
        url,
        body: {
          'email': _emailController.text,
          'password': _passwordController.text,
          'captcha_answer': _captchaController.text,
          'captcha_hash': _currentCaptchaHash,
        },
      );

      if (!mounted) return;
      final data = json.decode(response.body);

      // NEW: Instantly logs in on success!
      if (data['status'] == 'success') {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('userId', data['user']['id'].toString());

        String fName = data['user']['first_name'] ?? '';
        String mName = data['user']['middle_name'] ?? '';
        String lName = data['user']['last_name'] ?? '';

        await prefs.setString('firstName', fName);
        await prefs.setString('middleName', mName);
        await prefs.setString('lastName', lName);
        await prefs.setString('userName', "$fName $lName".trim());
        await prefs.setString('userEmail', data['user']['email'] ?? '');
        await prefs.setString('userPhone', data['user']['phone_number'] ?? '');
        await prefs.setString('userDob', data['user']['dob'] ?? '');

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message']),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Connection Error. Please check your network."),
          backgroundColor: Colors.red.shade600,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon,
    bool isPassword,
  ) {
    return TextField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : false,
      keyboardType: isPassword
          ? TextInputType.text
          : TextInputType.emailAddress,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.grey.shade500,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 30.0,
              vertical: 20.0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ==========================================
                // NEW: Custom Logo Image (Now Circular)
                // ==========================================
                Center(
                  child: ClipOval(
                    child: Image.asset(
                      'assets/logo.jpg',
                      height: 110,
                      width: 110, // Match height for a perfect circle
                      fit: BoxFit.cover, // Fill the circle completely
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ==========================================
                // NEW: Official Clinic Title
                // ==========================================
                Text(
                  "Agusan Local Dental Clinic",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26, // Slightly reduced to ensure a clean wrap
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                    letterSpacing: -0.5,
                    height: 1.2, // Adds a nice gap if it wraps to two lines
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Online Appointment Scheduling",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 48),

                _buildTextField(
                  _emailController,
                  "Email Address",
                  Icons.email_outlined,
                  false,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  _passwordController,
                  "Password",
                  Icons.lock_outline,
                  true,
                ),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ForgotPasswordPage(),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue.shade800,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 0,
                        vertical: 16,
                      ),
                    ),
                    child: const Text("Forgot password?"),
                  ),
                ),

                const SizedBox(height: 8),
                CaptchaWidget(
                  answerController: _captchaController,
                  onHashReceived: (hash) => _currentCaptchaHash = hash,
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text("Log In"),
                ),

                const SizedBox(height: 32),

                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        "New to the clinic?",
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                  ],
                ),

                const SizedBox(height: 24),

                OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SignupPage(),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue.shade800,
                    side: BorderSide(color: Colors.blue.shade800, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    "Create an Account",
                    style: TextStyle(fontWeight: FontWeight.w600),
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'captcha_widget.dart';
import 'otp_verification_page.dart';
import 'config.dart'; // NEW IMPORT

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _captchaController = TextEditingController();
  final _securityAnswerController = TextEditingController();

  String? _selectedSecurityQuestion;
  final List<String> _securityQuestions = [
    "What is the name of your first pet?",
    "What is your favorite food?",
    "What city were you born in?",
    "What is your mother's maiden name?",
  ];

  String _currentCaptchaHash = '';
  String _dobString = "Date of Birth";
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  bool _isPasswordStrong = false;
  bool _hasStartedTypingPassword = false;

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  // ==========================================
  // NEW: DRAFT SAVING MECHANICS
  // ==========================================
  Future<void> _loadDraft() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? draftJson = prefs.getString('signupDraft');
    if (draftJson != null) {
      Map<String, dynamic> draft = json.decode(draftJson);
      setState(() {
        _firstNameController.text = draft['first_name'] ?? '';
        _middleNameController.text = draft['middle_name'] ?? '';
        _lastNameController.text = draft['last_name'] ?? '';
        _emailController.text = draft['email'] ?? '';
        _phoneController.text = draft['phone_number'] ?? '';
        _dobString = draft['dob'] ?? "Date of Birth";
        _selectedSecurityQuestion = draft['security_question'];
        _securityAnswerController.text = draft['security_answer'] ?? '';
      });
    }
  }

  Future<void> _saveDraft() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> draft = {
      'first_name': _firstNameController.text,
      'middle_name': _middleNameController.text,
      'last_name': _lastNameController.text,
      'email': _emailController.text,
      'phone_number': _phoneController.text,
      'dob': _dobString,
      'security_question': _selectedSecurityQuestion,
      'security_answer': _securityAnswerController.text,
    };
    await prefs.setString('signupDraft', json.encode(draft));
  }

  void _checkPasswordStrength(String value) {
    setState(() {
      _hasStartedTypingPassword = value.isNotEmpty;
      String pattern = r'^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[\W_]).{8,}$';
      RegExp regex = RegExp(pattern);
      _isPasswordStrong = regex.hasMatch(value);
    });
  }

  Future<void> _submitSignup() async {
    if (_firstNameController.text.isEmpty ||
        _lastNameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Please fill all required fields"),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_phoneController.text.length != 13 ||
        !_phoneController.text.startsWith('+63')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Please enter a valid 11-digit phone number."),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_selectedSecurityQuestion == null ||
        _securityAnswerController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Please select and answer a security question."),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!_isPasswordStrong) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Please provide a strong password."),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Passwords do not match!"),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_captchaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Please complete the CAPTCHA verification."),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    await _saveDraft(); // Final save before network request

    // Prepare all data to send to OTP screen
    Map<String, String> registrationData = {
      'first_name': _firstNameController.text,
      'middle_name': _middleNameController.text,
      'last_name': _lastNameController.text,
      'email': _emailController.text,
      'phone_number': _phoneController.text,
      'dob': _dobString == "Date of Birth" ? "" : _dobString,
      'password': _passwordController.text,
      'security_question': _selectedSecurityQuestion ?? '',
      'security_answer': _securityAnswerController.text,
    };

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/signup.php');
      final response = await http.post(
        url,
        body: {
          'email': _emailController.text,
          'phone_number': _phoneController.text,
          'password': _passwordController.text,
          'captcha_answer': _captchaController.text,
          'captcha_hash': _currentCaptchaHash,
        },
      );

      final data = json.decode(response.body);

      if (!mounted) return;

      if (data['status'] == 'require_otp') {
        // Navigate to Dual-Purpose OTP Screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtpVerificationPage(
              identifier: data['email'],
              maskedPhoneNumber: data['phone_number'],
              isSignupFlow: true,
              signupData: registrationData,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message']),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Connection Error. Please check your network."),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool isPassword = false,
    bool isConfirmPassword = false,
    TextInputType type = TextInputType.text,
    Function(String)? onChanged,
    List<TextInputFormatter>? formatters,
  }) {
    bool isObscure = isPassword
        ? _obscurePassword
        : (isConfirmPassword ? _obscureConfirmPassword : false);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: controller,
        obscureText: isObscure,
        keyboardType: type,
        onChanged: (val) {
          if (onChanged != null) onChanged(val);
          _saveDraft(); // Save draft on every keystroke
        },
        inputFormatters: formatters,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon),
          suffixIcon: (isPassword || isConfirmPassword)
              ? IconButton(
                  icon: Icon(
                    isObscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey.shade500,
                  ),
                  onPressed: () {
                    setState(() {
                      if (isPassword) _obscurePassword = !_obscurePassword;
                      if (isConfirmPassword)
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                )
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.blue.shade900),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Create an Account",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Please fill in your details to continue.",
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 32),

              _buildTextField(
                _lastNameController,
                "Last Name",
                Icons.person_outline,
              ),
              _buildTextField(
                _firstNameController,
                "First Name",
                Icons.person_outline,
              ),
              _buildTextField(
                _middleNameController,
                "Middle Initial (Optional)",
                Icons.person_outline,
              ),
              _buildTextField(
                _emailController,
                "Email (ex: juan@gmail.com)",
                Icons.email_outlined,
                type: TextInputType.emailAddress,
              ),

              _buildTextField(
                _phoneController,
                "Phone Number (ex: +63...)",
                Icons.phone_outlined,
                type: TextInputType.phone,
                formatters: [LengthLimitingTextInputFormatter(13)],
                onChanged: (value) {
                  if (value.startsWith('0')) {
                    _phoneController.text = '+63${value.substring(1)}';
                    _phoneController.selection = TextSelection.fromPosition(
                      TextPosition(offset: _phoneController.text.length),
                    );
                  }
                },
              ),

              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: GestureDetector(
                  onTap: () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime(2000),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(
                        () => _dobString = "${picked.toLocal()}".split(' ')[0],
                      );
                      _saveDraft();
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.calendar_today_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Text(
                      _dobString,
                      style: TextStyle(
                        color: _dobString == "Date of Birth"
                            ? Colors.grey.shade400
                            : Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              Text(
                "Account Recovery",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
              const SizedBox(height: 16),

              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.security_outlined),
                    hintText: "Select a Security Question",
                  ),
                  value: _selectedSecurityQuestion,
                  isExpanded: true,
                  icon: Icon(Icons.expand_more, color: Colors.grey.shade500),
                  items: _securityQuestions.map((String question) {
                    return DropdownMenuItem<String>(
                      value: question,
                      child: Text(
                        question,
                        style: const TextStyle(fontSize: 14),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() => _selectedSecurityQuestion = newValue);
                    _saveDraft();
                  },
                ),
              ),

              _buildTextField(
                _securityAnswerController,
                "Your Answer",
                Icons.question_answer_outlined,
              ),

              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 24),

              _buildTextField(
                _passwordController,
                "Password",
                Icons.lock_outline,
                isPassword: true,
                onChanged: _checkPasswordStrength,
              ),

              if (_hasStartedTypingPassword)
                Padding(
                  padding: const EdgeInsets.only(
                    left: 12,
                    right: 12,
                    bottom: 16,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _isPasswordStrong
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
                        color: _isPasswordStrong
                            ? Colors.green.shade600
                            : Colors.red.shade600,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isPasswordStrong
                              ? "Strong Password."
                              : "Password must include uppercase letters, lowercase letters, numbers, and special characters (Min 8 chars).",
                          style: TextStyle(
                            color: _isPasswordStrong
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              _buildTextField(
                _confirmPasswordController,
                "Confirm Password",
                Icons.lock_outline,
                isConfirmPassword: true,
              ),

              const SizedBox(height: 16),
              CaptchaWidget(
                answerController: _captchaController,
                onHashReceived: (hash) => _currentCaptchaHash = hash,
              ),

              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _isLoading ? null : _submitSignup,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text("Create Account"),
              ),

              const SizedBox(height: 16),

              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade600,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Already have an account? "),
                    Text(
                      "Log In",
                      style: TextStyle(
                        color: Colors.blue.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

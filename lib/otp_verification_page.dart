import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'main_screen.dart';
import 'config.dart';

class OtpVerificationPage extends StatefulWidget {
  final String identifier;
  final String maskedPhoneNumber;
  final bool isSignupFlow;
  final bool isSecurityFlow;
  final bool isProfileFlow;
  final Map<String, String>? signupData;
  final Map<String, String>? securityData;
  final Map<String, String>? profileData;

  const OtpVerificationPage({
    super.key,
    required this.identifier,
    required this.maskedPhoneNumber,
    this.isSignupFlow = false,
    this.isSecurityFlow = false,
    this.isProfileFlow = false,
    this.signupData,
    this.securityData,
    this.profileData,
  });

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  // We only need ONE controller now!
  final _otpController = TextEditingController();

  bool _isLoading = false;
  bool _isResending = false;
  int _resendCountdown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() => _resendCountdown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _verifyOtp() async {
    // 1. Single Validation Check
    if (_otpController.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Please enter the 6-digit verification code."),
          backgroundColor: Colors.red.shade600,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 2. Dynamic Endpoint Routing
      String endpoint = '${ApiConfig.baseUrl}/verify_otp.php';
      if (widget.isSignupFlow) {
        endpoint = '${ApiConfig.baseUrl}/verify_signup_otp.php';
      } else if (widget.isSecurityFlow && widget.securityData != null) {
        endpoint = widget.securityData!['action'] == 'password'
            ? '${ApiConfig.baseUrl}/change_password.php'
            : '${ApiConfig.baseUrl}/update_security_question.php';
      } else if (widget.isProfileFlow) {
        endpoint = '${ApiConfig.baseUrl}/update_profile.php';
      }

      // 3. Dynamic Payload Construction
      Map<String, String> payload = {};

      if (widget.isSignupFlow && widget.signupData != null) {
        payload.addAll(widget.signupData!);
      } else if (widget.isSecurityFlow && widget.securityData != null) {
        payload.addAll(widget.securityData!);
      } else if (widget.isProfileFlow && widget.profileData != null) {
        payload.addAll(widget.profileData!);
      } else {
        payload['patient_id'] = widget.identifier;
      }

      // EVERY flow now sends the exact same parameter: 'otp_code'
      payload['otp_code'] = _otpController.text;

      final url = Uri.parse(endpoint);
      final response = await http.post(url, body: payload);
      final data = json.decode(response.body);

      if (!mounted) return;

      if (data['status'] == 'success') {
        SharedPreferences prefs = await SharedPreferences.getInstance();

        if (widget.isSignupFlow) {
          await prefs.remove('signupDraft');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                "Account Created Successfully! Please log in.",
              ),
              backgroundColor: Colors.green.shade600,
            ),
          );
          int count = 0;
          Navigator.popUntil(context, (route) => count++ == 2);
        } else if (widget.isSecurityFlow) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message']),
              backgroundColor: Colors.green.shade600,
            ),
          );
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const MainScreen()),
            (route) => false,
          );
        } else if (widget.isProfileFlow && widget.profileData != null) {
          await prefs.setString(
            'firstName',
            widget.profileData!['first_name']!,
          );
          await prefs.setString(
            'middleName',
            widget.profileData!['middle_name']!,
          );
          await prefs.setString('lastName', widget.profileData!['last_name']!);
          await prefs.setString(
            'userName',
            "${widget.profileData!['first_name']} ${widget.profileData!['last_name']}",
          );
          await prefs.setString('userEmail', widget.profileData!['email']!);
          await prefs.setString(
            'userPhone',
            widget.profileData!['phone_number']!,
          );
          await prefs.setString('userDob', widget.profileData!['dob']!);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Profile Securely Updated!"),
              backgroundColor: Colors.green.shade600,
            ),
          );
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const MainScreen()),
            (route) => false,
          );
        } else {
          await prefs.setBool('isLoggedIn', true);
          await prefs.setString('userId', data['user']['id'].toString());
          await prefs.setString('firstName', data['user']['first_name'] ?? '');
          await prefs.setString(
            'middleName',
            data['user']['middle_name'] ?? '',
          );
          await prefs.setString('lastName', data['user']['last_name'] ?? '');
          await prefs.setString(
            'userName',
            "${data['user']['first_name']} ${data['user']['last_name']}".trim(),
          );
          await prefs.setString('userEmail', data['user']['email'] ?? '');
          await prefs.setString(
            'userPhone',
            data['user']['phone_number'] ?? '',
          );
          await prefs.setString('userDob', data['user']['dob'] ?? '');

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const MainScreen()),
            (route) => false,
          );
        }
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
          content: const Text("Connection Error. Please try again."),
          backgroundColor: Colors.red.shade600,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOtp() async {
    setState(() => _isResending = true);
    try {
      final isSecurity = widget.isSecurityFlow || widget.isProfileFlow;
      String endpoint = isSecurity
          ? '${ApiConfig.baseUrl}/request_security_otp.php'
          : '${ApiConfig.baseUrl}/resend_otp.php';

      Map<String, String> payload = widget.isSignupFlow
          ? {
              'email': widget.identifier,
              'phone_number': widget.signupData?['phone_number'] ?? '',
              'is_signup': 'true',
            }
          : {'patient_id': widget.identifier};

      final response = await http.post(Uri.parse(endpoint), body: payload);
      final data = json.decode(response.body);

      if (!mounted) return;

      if (data['status'] == 'success') {
        _startResendTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? "New code sent!"),
            backgroundColor: Colors.green.shade600,
          ),
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
          content: const Text("Connection Error. Failed to resend."),
          backgroundColor: Colors.red.shade600,
        ),
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Widget _buildOtpInput(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      style: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        letterSpacing: 12,
        color: Colors.blue.shade900,
      ),
      decoration: InputDecoration(
        hintText: "000000",
        hintStyle: TextStyle(color: Colors.grey.shade300, letterSpacing: 12),
        contentPadding: const EdgeInsets.symmetric(vertical: 20),
        labelText: hint,
        floatingLabelAlignment: FloatingLabelAlignment.center,
        labelStyle: TextStyle(
          color: Colors.grey.shade700.withOpacity(0.6),
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelBehavior: FloatingLabelBehavior.always,
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
          padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.security,
                  size: 60,
                  color: Colors.blue.shade800,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "Verify Your Identity",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),

              // Unified instructional text!
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                  children: [
                    const TextSpan(
                      text:
                          "Please enter the 6-digit code sent to your email or your phone ending in ",
                    ),
                    TextSpan(
                      text: widget.maskedPhoneNumber,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    const TextSpan(text: "."),
                  ],
                ),
              ),
              const SizedBox(height: 48),

              // Only ONE input box rendered now!
              _buildOtpInput(_otpController, "Verification Code"),

              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _verifyOtp,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        widget.isSignupFlow
                            ? "Verify & Create Account"
                            : widget.isSecurityFlow
                            ? "Verify & Save Changes"
                            : widget.isProfileFlow
                            ? "Verify & Update Profile"
                            : "Verify OTP",
                      ),
              ),
              const SizedBox(height: 24),
              Center(
                child: _resendCountdown > 0
                    ? Text(
                        "Resend code in $_resendCountdown seconds",
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 13,
                        ),
                      )
                    : TextButton(
                        onPressed: _isResending ? null : _resendOtp,
                        child: _isResending
                            ? SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.blue.shade800,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                "Resend Code",
                                style: TextStyle(
                                  color: Colors.blue.shade800,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

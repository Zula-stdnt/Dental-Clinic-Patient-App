import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

class ChangeSecurityQuestionPage extends StatefulWidget {
  const ChangeSecurityQuestionPage({super.key});

  @override
  State<ChangeSecurityQuestionPage> createState() =>
      _ChangeSecurityQuestionPageState();
}

class _ChangeSecurityQuestionPageState
    extends State<ChangeSecurityQuestionPage> {
  final _passwordController = TextEditingController();
  final _oldAnswerController = TextEditingController();
  final _newAnswerController = TextEditingController();

  String? _currentQuestion = "Loading...";
  String? _selectedNewQuestion;
  bool _isLoading = false;
  bool _obscurePassword = true;

  final List<String> _securityQuestions = [
    "What is the name of your first pet?",
    "What is your favorite food?",
    "What city were you born in?",
    "What is your mother's maiden name?",
  ];

  @override
  void initState() {
    super.initState();
    _fetchCurrentQuestion();
  }

  Future<void> _fetchCurrentQuestion() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('userId');

    try {
      // Added a 10-second timeout to prevent infinite loading
      final response = await http
          .get(
            Uri.parse(
              '${ApiConfig.baseUrl}/get_security_question.php?patient_id=$userId',
            ),
          )
          .timeout(const Duration(seconds: 10));

      final data = json.decode(response.body);

      if (mounted) {
        if (data['status'] == 'success') {
          setState(() => _currentQuestion = data['security_question']);
        } else {
          // NEW: Handle server rejections
          setState(() => _currentQuestion = "Error: ${data['message']}");
        }
      }
    } catch (e) {
      if (mounted) {
        // NEW: Handle network drops/timeouts
        setState(() => _currentQuestion = "Server busy or offline.");
      }
    }
  }

  Future<void> _updateSecurityQuestion() async {
    if (_passwordController.text.isEmpty ||
        _oldAnswerController.text.isEmpty ||
        _selectedNewQuestion == null ||
        _newAnswerController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Please fill all fields."),
          backgroundColor: Colors.red.shade600,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('userId');

    try {
      // Direct API Call without OTP!
      final url = Uri.parse(
        '${ApiConfig.baseUrl}/update_security_question.php',
      );
      final response = await http.post(
        url,
        body: {
          'patient_id': userId ?? '',
          'password': _passwordController.text,
          'old_answer': _oldAnswerController.text,
          'new_question': _selectedNewQuestion ?? '',
          'new_answer': _newAnswerController.text,
        },
      );
      final data = json.decode(response.body);

      if (!mounted) return;

      if (data['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message']),
            backgroundColor: Colors.green.shade600,
          ),
        );
        Navigator.pop(context); // Go back safely
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
          content: const Text("Connection Error."),
          backgroundColor: Colors.red.shade600,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Security Question",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      backgroundColor: Colors.grey.shade50,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Current Question",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentQuestion ?? "Loading...",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                hintText: "Current Password",
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey.shade500,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _oldAnswerController,
              decoration: const InputDecoration(
                hintText: "Answer to Current Question",
                prefixIcon: Icon(Icons.history),
              ),
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 32),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                hintText: "Select New Security Question",
                prefixIcon: Icon(Icons.security),
              ),
              value: _selectedNewQuestion,
              isExpanded: true,
              icon: Icon(Icons.expand_more, color: Colors.grey.shade500),
              items: _securityQuestions.map((String question) {
                return DropdownMenuItem<String>(
                  value: question,
                  child: Text(
                    question,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() => _selectedNewQuestion = newValue);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newAnswerController,
              decoration: const InputDecoration(
                hintText: "New Answer",
                prefixIcon: Icon(Icons.check_circle_outline),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updateSecurityQuestion,
                child: _isLoading
                    ? const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      )
                    : const Text("Update Security Details"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

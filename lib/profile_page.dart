import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login_page.dart';
import 'change_password.dart';
import 'contact_clinic_page.dart';
import 'change_security_question.dart';
import 'otp_verification_page.dart';
import 'config.dart'; // NEW IMPORT

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isEditing = false;
  bool _isLoading = false;

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _middleNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  String _dobString = "Select Date";

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _firstNameController.text = prefs.getString('firstName') ?? "";
      _middleNameController.text = prefs.getString('middleName') ?? "";
      _lastNameController.text = prefs.getString('lastName') ?? "";
      _emailController.text = prefs.getString('userEmail') ?? "";
      _phoneController.text = prefs.getString('userPhone') ?? "";
      _dobString = prefs.getString('userDob') ?? "Select Date";
      if (_dobString.isEmpty) _dobString = "Select Date";
    });
  }

  Future<void> _saveProfile() async {
    if (_phoneController.text.length != 13 ||
        !_phoneController.text.startsWith('+63')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Please enter a valid 11-digit phone number."),
          backgroundColor: Colors.red.shade600,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('userId');
    String currentEmail = prefs.getString('userEmail') ?? "";
    String currentPhone = prefs.getString('userPhone') ?? "";

    // Security Check: Did they change sensitive fields?
    bool requiresOtp =
        (_emailController.text != currentEmail) ||
        (_phoneController.text != currentPhone);

    Map<String, String> newProfileData = {
      'patient_id': userId ?? '',
      'first_name': _firstNameController.text,
      'middle_name': _middleNameController.text,
      'last_name': _lastNameController.text,
      'email': _emailController.text,
      'phone_number': _phoneController.text,
      'dob': _dobString == "Select Date" ? "" : _dobString,
    };

    if (requiresOtp) {
      try {
        // Trigger the exact same Dual-OTP script used for passwords
        final url = Uri.parse(
          '${ApiConfig.baseUrl}/request_security_otp.php',
        );
        final response = await http.post(
          url,
          body: {'patient_id': userId ?? ''},
        );
        final data = json.decode(response.body);

        if (!mounted) return;

        if (data['status'] == 'success') {
          // Push to OTP Screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OtpVerificationPage(
                identifier: userId ?? '',
                maskedPhoneNumber: data['masked_phone'].toString(),
                isProfileFlow: true, // NEW FLAG
                profileData: newProfileData, // PASS THE DATA
              ),
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
            content: const Text("Connection Error. Cannot request OTP."),
            backgroundColor: Colors.red.shade600,
          ),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
      return; // Stop here, OTP screen handles the rest!
    }

    // NORMAL UPDATE FLOW (No sensitive data changed)
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/update_profile.php');
      final response = await http.post(url, body: newProfileData);
      final data = json.decode(response.body);

      if (data['status'] == 'success') {
        await prefs.setString('firstName', _firstNameController.text);
        await prefs.setString('middleName', _middleNameController.text);
        await prefs.setString('lastName', _lastNameController.text);
        await prefs.setString(
          'userName',
          "${_firstNameController.text} ${_lastNameController.text}",
        );
        await prefs.setString('userEmail', _emailController.text);
        await prefs.setString('userPhone', _phoneController.text);
        await prefs.setString('userDob', _dobString);

        setState(() => _isEditing = false);

        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Profile Updated Successfully!"),
              backgroundColor: Colors.green.shade600,
            ),
          );
      } else {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message']),
              backgroundColor: Colors.red.shade600,
            ),
          );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Connection Error"),
            backgroundColor: Colors.red.shade600,
          ),
        );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Column(
            children: [
              Icon(Icons.logout, color: Colors.red.shade600, size: 48),
              const SizedBox(height: 16),
              Text(
                "Log Out",
                style: TextStyle(
                  color: Colors.blue.shade900,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: const Text(
            "Are you sure you want to log out?",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actionsPadding: const EdgeInsets.only(
            bottom: 20,
            left: 20,
            right: 20,
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _logout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                elevation: 0,
              ),
              child: const Text("Logout"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfileField(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType type = TextInputType.text,
    Function(String)? onChanged,
    List<TextInputFormatter>? formatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.blue.shade900,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextField(
            controller: controller,
            enabled: _isEditing,
            keyboardType: type,
            onChanged: onChanged,
            inputFormatters: formatters,
            style: TextStyle(
              color: _isEditing ? Colors.black87 : Colors.grey.shade600,
            ),
            decoration: InputDecoration(prefixIcon: Icon(icon)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          children: [
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.blue.shade100, width: 3),
                    ),
                    child: CircleAvatar(
                      radius: 45,
                      backgroundColor: Colors.blue.shade50,
                      child: Icon(
                        Icons.person_outline,
                        size: 45,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Personal Information",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            _buildProfileField(
              "Last Name",
              _lastNameController,
              Icons.person_outline,
            ),
            _buildProfileField(
              "First Name",
              _firstNameController,
              Icons.person_outline,
            ),
            _buildProfileField(
              "Middle Name (Optional)",
              _middleNameController,
              Icons.person_outline,
            ),
            _buildProfileField(
              "Email",
              _emailController,
              Icons.email_outlined,
              type: TextInputType.emailAddress,
            ),

            _buildProfileField(
              "Phone Number",
              _phoneController,
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
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 6),
                    child: Text(
                      "Birth Date",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _isEditing
                        ? () async {
                            DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime(2000),
                              firstDate: DateTime(1900),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null)
                              setState(
                                () => _dobString = "${picked.toLocal()}".split(
                                  ' ',
                                )[0],
                              );
                          }
                        : null,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.calendar_today_outlined),
                        enabled: _isEditing,
                      ),
                      child: Text(
                        _dobString,
                        style: TextStyle(
                          fontSize: 16,
                          color: _isEditing
                              ? Colors.black87
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _isEditing = !_isEditing;
                        if (!_isEditing) _loadProfileData();
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _isEditing
                          ? Colors.grey.shade700
                          : Colors.blue.shade800,
                      side: BorderSide(
                        color: _isEditing
                            ? Colors.grey.shade400
                            : Colors.blue.shade800,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(_isEditing ? "Cancel" : "Edit Profile"),
                  ),
                ),
                if (_isEditing) const SizedBox(width: 16),
                if (_isEditing)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text("Save Changes"),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),

            ListTile(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ContactClinicPage(),
                ),
              ),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.support_agent_outlined,
                  color: Colors.green.shade700,
                ),
              ),
              title: const Text(
                "Contact Clinic",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            ),

            ListTile(
              // NEW: Simple direct routing
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChangePasswordPage(),
                ),
              ),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.lock_reset_outlined,
                  color: Colors.blue.shade800,
                ),
              ),
              title: const Text(
                "Change Password",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            ),

            ListTile(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChangeSecurityQuestionPage(),
                ),
              ),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.security_outlined,
                  color: Colors.blue.shade800,
                ),
              ),
              title: const Text(
                "Security Question",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            ),

            ListTile(
              onTap: _showLogoutConfirmation,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.logout, color: Colors.red.shade600),
              ),
              title: Text(
                "Log Out",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade600,
                ),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

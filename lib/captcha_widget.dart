import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';

class CaptchaWidget extends StatefulWidget {
  final TextEditingController answerController;
  final Function(String) onHashReceived;

  const CaptchaWidget({
    super.key,
    required this.answerController,
    required this.onHashReceived,
  });

  @override
  State<CaptchaWidget> createState() => CaptchaWidgetState();
}

class CaptchaWidgetState extends State<CaptchaWidget> {
  String _question = "Loading CAPTCHA...";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    refreshCaptcha();
  }

  Future<void> refreshCaptcha() async {
    setState(() {
      _isLoading = true;
      widget.answerController.clear();
    });
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/get_captcha.php');
      // final url = Uri.parse('${ApiConfig.baseUrl}/get_captcha.php');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _question = data['question'];
          _isLoading = false;
        });
        widget.onHashReceived(data['hash']);
      }
    } catch (e) {
      setState(() {
        _question = "Connection Error";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.5), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Security Verification",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: refreshCaptcha,
                child: const Icon(
                  Icons.refresh,
                  size: 18,
                  color: Colors.blueAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: _isLoading
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _question,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              letterSpacing: 2,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                flex: 1,
                child: TextField(
                  controller: widget.answerController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: "?",
                    filled: true,
                    fillColor: Colors.blue[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

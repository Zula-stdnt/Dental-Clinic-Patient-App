import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactClinicPage extends StatelessWidget {
  const ContactClinicPage({super.key});

  // Tap-to-dial function
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      // Failsafe if the device cannot make calls (e.g., a tablet without a SIM)
      debugPrint('Could not launch $launchUri');
    }
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    bool isActionable = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isActionable ? Colors.green.shade50 : Colors.blue.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: isActionable ? Colors.green.shade600 : Colors.blue.shade800,
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            subtitle,
            style: TextStyle(
              fontSize: 15,
              color: isActionable
                  ? Colors.green.shade700
                  : Colors.blue.shade900,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        trailing: isActionable
            ? Icon(Icons.call_made, color: Colors.green.shade600, size: 20)
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          "Contact Clinic",
          style: TextStyle(
            color: Colors.blue.shade900,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.blue.shade900),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Header Logo
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.health_and_safety_outlined,
                size: 60,
                color: Colors.blue.shade800,
              ),
            ),
            const SizedBox(height: 24),

            Text(
              "Agusan Local Dental Clinic",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "We're here to help you with your dental concerns.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 32),

            // Information Cards
            _buildInfoCard(
              icon: Icons.person_outline,
              title: "Attending Dentist",
              subtitle: "Dr. Nabalitan, Avelino Jr. M.",
            ),

            _buildInfoCard(
              icon: Icons.location_on_outlined,
              title: "Clinic Address",
              subtitle: "Zone 1, Agusan, Cagayan De Oro, Misamis Oriental",
            ),

            // Actionable Phone Card!
            _buildInfoCard(
              icon: Icons.phone_outlined,
              title: "Tap to Call",
              subtitle: "0993 241 5245",
              isActionable: true,
              onTap: () => _makePhoneCall("+639932415245"),
            ),

            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange.shade700,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "If your account has been restricted due to multiple No-Shows, please call the clinic directly to request an unban.",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

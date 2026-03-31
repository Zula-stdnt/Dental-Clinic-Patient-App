import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_page.dart';
import 'dashboard.dart';
import 'profile_page.dart';
import 'booking_page.dart';
import 'notifications_page.dart';
import 'config.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  String _userName = "Patient";
  int _activePage = 0;
  int _unreadMessagesCount = 0;
  Timer? _pollingTimer;
  Key _dashboardKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _checkUnreadNotifications();

    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkUnreadNotifications();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUserName() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('userName') ?? "Patient";
    });
  }

  Future<void> _checkUnreadNotifications() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('userId');
    if (userId == null) return;

    try {
      final url = Uri.parse(
        '${ApiConfig.baseUrl}/get_unread_count.php?patient_id=$userId',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() => _unreadMessagesCount = data['unread'] ?? 0);
        }
      }
    } catch (e) {}
  }

  void _onItemTapped(int physicalIndex) {
    if (physicalIndex == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const BookingPage()),
      ).then((didBook) {
        if (didBook == true) {
          setState(() {
            _dashboardKey = UniqueKey();
            _activePage = 1;
          });
        }
      });
    } else {
      setState(() {
        if (physicalIndex == 0) _activePage = 0;
        if (physicalIndex == 2) _activePage = 1;
        if (physicalIndex == 3) _activePage = 2;
      });
    }
  }

  int _getPhysicalIndex() {
    if (_activePage == 0) return 0;
    if (_activePage == 1) return 2;
    if (_activePage == 2) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      HomePage(userName: _userName),
      AppointmentDashboard(key: _dashboardKey),
      const ProfilePage(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD),
      appBar: AppBar(
        toolbarHeight: 48, // NEW: Thinner App Bar
        backgroundColor: Colors.white,
        elevation: 0,
        leadingWidth: 70, // NEW: Tighter Logo spacing
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 6.0, bottom: 6.0),
          child: InkWell(
            onTap: () => setState(() => _activePage = 0),
            child: Image.asset('assets/logo.jpg', fit: BoxFit.contain),
          ),
        ),
        actions: [
          IconButton(
            padding: EdgeInsets.zero, // NEW: Removed built-in icon padding
            icon: Badge(
              isLabelVisible: _unreadMessagesCount > 0,
              label: Text(_unreadMessagesCount.toString()),
              child: const Icon(
                Icons.notifications,
                color: Colors.amber,
                size: 28, // NEW: Slightly scaled down
              ),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsPage(),
                ),
              ).then((_) => _checkUnreadNotifications());
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: pages[_activePage],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _getPhysicalIndex(),
        onTap: _onItemTapped,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline, size: 30),
            label: 'Book',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Appointments',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'contact_clinic_page.dart';
import 'config.dart';

class AppointmentDashboard extends StatefulWidget {
  const AppointmentDashboard({super.key});

  @override
  State<AppointmentDashboard> createState() => _AppointmentDashboardState();
}

class _AppointmentDashboardState extends State<AppointmentDashboard> {
  String? userName;
  List appointments = [];
  bool _isLoadingList = true;
  Timer? _dashboardRefreshTimer;

  String _selectedFilter = 'All';
  String _selectedSort = 'Latest First';

  final List<String> _filterOptions = [
    'All',
    'Pending',
    'Approved',
    'Completed',
    'Declined',
    'Rescheduled',
    'Cancelled',
    'No Show',
  ];

  int _currentPage = 1;
  final int _itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchAppointments();

    _dashboardRefreshTimer = Timer.periodic(const Duration(seconds: 10), (
      timer,
    ) {
      _fetchAppointments(isBackground: true);
    });
  }

  @override
  void dispose() {
    _dashboardRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString('userName') ?? "Patient";
    });
  }

  Future<void> _fetchAppointments({bool isBackground = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    if (userId == null) return;

    try {
      final url = Uri.parse(
        '${ApiConfig.baseUrl}/get_appointments.php?patient_id=$userId',
      );
      final response = await http.get(url);

      if (response.statusCode == 200 && mounted) {
        setState(() {
          appointments = json.decode(response.body);
          if (!isBackground) _isLoadingList = false;
        });
      }
    } catch (e) {
      if (mounted && !isBackground) setState(() => _isLoadingList = false);
    }
  }

  DateTime _parseDateTime(String? dateStr, String? timeStr) {
    if (dateStr == null || timeStr == null) return DateTime(2000);
    try {
      return DateTime.parse("$dateStr $timeStr");
    } catch (e) {
      return DateTime(2000);
    }
  }

  List get _processedAppointments {
    List result = List.from(appointments);

    if (_selectedFilter != 'All') {
      result = result.where((appt) {
        String rawStatus = (appt['status'] ?? '').toString().toUpperCase();
        String filterUpper = _selectedFilter.toUpperCase().replaceAll(' ', '_');
        if (filterUpper == 'CANCELLED')
          return rawStatus == 'CANCELLED' ||
              rawStatus == 'CANCELLED_BY_PATIENT';
        return rawStatus == filterUpper;
      }).toList();
    }

    result.sort((a, b) {
      DateTime dateA = _parseDateTime(
        a['appointment_date'],
        a['appointment_time'],
      );
      DateTime dateB = _parseDateTime(
        b['appointment_date'],
        b['appointment_time'],
      );
      if (_selectedSort == 'Soonest First')
        return dateA.compareTo(dateB);
      else
        return dateB.compareTo(dateA);
    });

    return result;
  }

  int get _totalPages {
    final totalItems = _processedAppointments.length;
    return (totalItems / _itemsPerPage).ceil();
  }

  List get _paginatedAppointments {
    final allProcessed = _processedAppointments;
    if (allProcessed.isEmpty) return [];

    int startIndex = (_currentPage - 1) * _itemsPerPage;
    int endIndex = startIndex + _itemsPerPage;
    if (endIndex > allProcessed.length) endIndex = allProcessed.length;
    if (startIndex >= allProcessed.length) return [];

    return allProcessed.sublist(startIndex, endIndex);
  }

  // NEW: Confirmation Dialog before cancelling
  void _showCancelConfirmation(String appointmentId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Column(
            mainAxisSize:
                MainAxisSize.min, // Good practice to keep the column compact
            children: [
              Icon(Icons.event_busy, color: Colors.red.shade600, size: 48),
              const SizedBox(height: 16),
              Text(
                "Cancel Appointment",
                textAlign: TextAlign.center, // <-- This centers the text
                style: TextStyle(
                  color: Colors.blue.shade900,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: const Text(
            "Are you sure you want to cancel this booking? This action cannot be undone.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15),
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actionsPadding: const EdgeInsets.only(
            bottom: 20,
            left: 20,
            right: 20,
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(), // Just close dialog
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text("No, Keep it"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog first
                _cancelAppointment(appointmentId); // Then execute cancellation
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text("Yes, Cancel"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _cancelAppointment(String appointmentId) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/cancel_appointment.php');
      final response = await http.post(
        url,
        body: {'appointment_id': appointmentId},
      );
      final data = json.decode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(data['message'] ?? 'Cancelled'),
          backgroundColor: data['success'] == true
              ? Colors.green.shade600
              : Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (response.statusCode == 200) _fetchAppointments();
    } catch (e) {}
  }

  Future<void> _respondToReschedule(String appointmentId, String action) async {
    try {
      final url = Uri.parse(
        '${ApiConfig.baseUrl}/patient_respond_reschedule.php',
      );
      final response = await http.post(
        url,
        body: {'appointment_id': appointmentId, 'action': action},
      );

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Action processed'),
            backgroundColor: data['success'] == true
                ? Colors.green.shade600
                : Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (data['success'] == true) _fetchAppointments();
      }
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    final currentPageList = _paginatedAppointments;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        color: Colors.blue.shade800,
        onRefresh: () => _fetchAppointments(isBackground: false),
        // NEW: Entire page scrolls, unpinning the header!
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 10.0, bottom: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Area
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Hello, $userName! 👋",
                      style: TextStyle(
                        fontSize: 22, // Scaled down
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Your Appointments",
                          style: TextStyle(
                            color: Colors.blue.shade900,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          height: 34, // NEW: Thinner dropdown
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedSort,
                              icon: Icon(
                                Icons.sort,
                                size: 14,
                                color: Colors.blue.shade800,
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade900,
                                fontWeight: FontWeight.w600,
                              ),
                              items: ['Latest First', 'Soonest First'].map((
                                String sortType,
                              ) {
                                return DropdownMenuItem<String>(
                                  value: sortType,
                                  child: Text(sortType),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null)
                                  setState(() {
                                    _selectedSort = newValue;
                                    _currentPage = 1;
                                  });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: _filterOptions.map((String filter) {
                    final isSelected = _selectedFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: ChoiceChip(
                        label: Text(
                          filter,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : Colors.blue.shade900,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            fontSize: 12, // Scaled down
                          ),
                        ),
                        selected: isSelected,
                        showCheckmark: false,
                        selectedColor: Colors.blue.shade800,
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isSelected
                                ? Colors.blue.shade800
                                : Colors.blue.shade100,
                          ),
                        ),
                        onSelected: (bool selected) {
                          if (selected)
                            setState(() {
                              _selectedFilter = filter;
                              _currentPage = 1;
                            });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // Content Area
              if (_isLoadingList)
                Padding(
                  padding: const EdgeInsets.only(top: 40.0),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Colors.blue.shade800,
                    ),
                  ),
                )
              else if (_processedAppointments.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40.0),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 48,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _selectedFilter == 'All'
                              ? "No appointments found."
                              : "No $_selectedFilter appointments.",
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                // NEW: Embedded ListView that grows with the content
                ListView.builder(
                  shrinkWrap: true,
                  physics:
                      const NeverScrollableScrollPhysics(), // Let the parent handle scrolling
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  itemCount: currentPageList.length,
                  itemBuilder: (context, index) {
                    final appt = currentPageList[index];
                    final rawStatus = (appt['status'] ?? 'pending')
                        .toString()
                        .toUpperCase();
                    String displayStatus = rawStatus.replaceAll('_', ' ');

                    if (rawStatus == 'CANCELLED_BY_PATIENT')
                      displayStatus = 'CANCELLED';

                    Color statusBgColor = Colors.orange;
                    Color? cardBgColor;
                    Color? iconColor = Colors.blue.shade600;
                    Border? cardBorder = Border.all(
                      color: Colors.grey.shade200,
                    );

                    if (rawStatus == 'APPROVED')
                      statusBgColor = Colors.green.shade400;
                    else if (rawStatus == 'DECLINED')
                      statusBgColor = Colors.red;
                    else if (rawStatus == 'CANCELLED_BY_PATIENT' ||
                        rawStatus == 'CANCELLED')
                      statusBgColor = Colors.grey.shade600;
                    else if (rawStatus == 'RESCHEDULED')
                      statusBgColor = Colors.blue.shade600;
                    else if (rawStatus == 'NO_SHOW') {
                      statusBgColor = Colors.purple.shade700;
                      cardBgColor = Colors.purple.shade50;
                      cardBorder = Border.all(color: Colors.purple.shade200);
                      iconColor = Colors.purple.shade700;
                    } else if (rawStatus == 'COMPLETED')
                      statusBgColor = Colors.green.shade700;

                    bool within24Hours = false;
                    DateTime? scheduled;
                    try {
                      scheduled = DateTime.parse(
                        "${appt['appointment_date']} ${appt['appointment_time']}",
                      );
                      final diff = scheduled.difference(DateTime.now());
                      within24Hours = diff.inHours > 0 && diff.inHours < 24;
                    } catch (_) {}

                    final isRescheduled = rawStatus == 'RESCHEDULED';
                    final isNoShow = rawStatus == 'NO_SHOW';
                    final canCancel =
                        (rawStatus == 'PENDING' || rawStatus == 'APPROVED') &&
                        !within24Hours;

                    return Container(
                      margin: const EdgeInsets.only(
                        bottom: 12,
                      ), // Tighter card spacing
                      decoration: BoxDecoration(
                        color: cardBgColor ?? Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: cardBorder,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(
                          16,
                        ), // Tighter inner padding
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: cardBgColor != null
                                        ? Colors.red.shade100
                                        : Colors.blue.shade50,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.medical_information_outlined,
                                    color: iconColor,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        appt['service'] ?? 'Dental Service',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Colors.blue.shade900,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "${appt['appointment_date']} • ${appt['appointment_time']}",
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Wrap the badge in a SizedBox to force a consistent width
                                SizedBox(
                                  width:
                                      80, // Set a fixed width that fits your longest word (RESCHEDULED)
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical:
                                          6, // Slightly increased for better vertical centering
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusBgColor,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      displayStatus,
                                      textAlign: TextAlign
                                          .center, // Center text within the fixed width
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize:
                                            10, // Increased slightly for readability
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            if (canCancel) ...[
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: OutlinedButton.icon(
                                  onPressed: () => _showCancelConfirmation(
                                    appt['appointment_id'].toString(),
                                  ),
                                  icon: Icon(
                                    Icons.close,
                                    color: Colors.red.shade600,
                                    size: 14,
                                  ),
                                  label: Text(
                                    "Cancel Booking",
                                    style: TextStyle(
                                      color: Colors.red.shade600,
                                      fontSize: 11,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: Colors.red.shade200,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 3,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    minimumSize: Size.zero,
                                  ),
                                ),
                              ),
                            ],

                            if (rawStatus == 'APPROVED' && within24Hours) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      color: Colors.amber.shade700,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        "Cannot cancel online within 24 hours. Contact clinic.",
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.brown.shade800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            if (isRescheduled) ...[
                              const SizedBox(height: 12),
                              Divider(color: Colors.grey.shade200),
                              const SizedBox(height: 6),
                              Text(
                                "Clinic proposed a new time. Do you accept?",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade900,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _respondToReschedule(
                                        appt['appointment_id'].toString(),
                                        'declined',
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red.shade600,
                                        side: BorderSide(
                                          color: Colors.red.shade200,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                      ),
                                      child: const Text(
                                        "Decline",
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () => _respondToReschedule(
                                        appt['appointment_id'].toString(),
                                        'approved',
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green.shade600,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                      ),
                                      child: const Text(
                                        "Accept Time",
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            if (isNoShow) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.purple.shade200,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.warning_amber_rounded,
                                          color: Colors.orange.shade700,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            "This appointment was marked as No Show. Please contact the clinic.",
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.orange.shade900,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const ContactClinicPage(),
                                          ),
                                        ),
                                        icon: Icon(
                                          Icons.support_agent_outlined,
                                          color: Colors.orange.shade700,
                                          size: 16,
                                        ),
                                        label: Text(
                                          "Contact Clinic",
                                          style: TextStyle(
                                            color: Colors.orange.shade800,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(
                                            color: Colors.orange.shade300,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),

              // NEW: Highly Compacted Pagination
              if (!_isLoadingList && _totalPages > 1)
                Container(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(50, 30),
                        ),
                        onPressed: _currentPage > 1
                            ? () => setState(() => _currentPage--)
                            : null,
                        child: Text(
                          "Prev",
                          style: TextStyle(
                            fontSize: 13,
                            color: _currentPage > 1
                                ? Colors.blue.shade800
                                : Colors.grey.shade400,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(_totalPages, (index) {
                            int pageNum = index + 1;
                            bool isSelected = pageNum == _currentPage;
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _currentPage = pageNum),
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.blue.shade800
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.blue.shade800
                                        : Colors.grey.shade200,
                                  ),
                                ),
                                child: Text(
                                  '$pageNum',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.blue.shade900,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(50, 30),
                        ),
                        onPressed: _currentPage < _totalPages
                            ? () => setState(() => _currentPage++)
                            : null,
                        child: Text(
                          "Next",
                          style: TextStyle(
                            fontSize: 13,
                            color: _currentPage < _totalPages
                                ? Colors.blue.shade800
                                : Colors.grey.shade400,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

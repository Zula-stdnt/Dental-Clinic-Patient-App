import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'config.dart';

class BookingPage extends StatefulWidget {
  final String? preselectedService;

  const BookingPage({super.key, this.preselectedService});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

// 1. UPGRADED TIMERANGE CLASS
class TimeRange {
  final TimeOfDay start;
  final TimeOfDay end;
  bool isAvailable;
  String reason;
  String type; // NEW: Tracks if it's an appointment or admin_block

  TimeRange(
    this.start,
    this.end, {
    this.isAvailable = true,
    this.reason = '',
    this.type = 'appointment',
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeRange &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end;

  @override
  int get hashCode => start.hashCode ^ end.hashCode;
}

class _BookingPageState extends State<BookingPage> {
  String? selectedService;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDate;
  TimeRange? selectedTimeRange;

  bool _isLoading = false;
  bool _isLoadingTimes = false;

  Map<String, String> disabledDatesWithReasons = {};
  List<String> fullyBookedDates = [];
  List<TimeRange> bookedTimeRanges = [];
  List<TimeRange> availableTimeSlots = [];

  final Map<String, String> servicesPrices = {
    'Braces & Orthodontics': '₱35,000 - ₱50,000',
    'Dental Check-ups & Exams': '₱500 - ₱1,000',
    'Dentures (Full and Partial)': '₱5,000 - ₱15,000',
    'Root Canal Therapy': '₱3,000 - ₱7,000',
    'Tooth Cleaning': '₱800 - ₱1,500',
    'Tooth Extraction': '₱600 - ₱1,200',
    'Teeth Whitening': '₱3,000 - ₱5,000',
  };

  final Map<String, int> serviceDurations = {
    'Dental Check-ups & Exams': 30,
    'Tooth Cleaning': 60,
    'Tooth Extraction': 60,
    'Teeth Whitening': 90,
    'Root Canal Therapy': 90,
    'Dentures (Full and Partial)': 60,
    'Braces & Orthodontics': 120,
  };

  @override
  void initState() {
    super.initState();
    if (widget.preselectedService != null &&
        servicesPrices.containsKey(widget.preselectedService)) {
      selectedService = widget.preselectedService;
    }
    _fetchDisabledDates();
    _fetchFullyBookedDates();
  }

  Future<void> _fetchDisabledDates() async {
    try {
      final response = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/get_disabled_dates.php',
        ),
      );
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        Map<String, String> tempMap = {};
        for (var item in data) {
          tempMap[item['date']] = item['reason'];
        }
        setState(() => disabledDatesWithReasons = tempMap);
      }
    } catch (e) {}
  }

  Future<void> _fetchFullyBookedDates() async {
    try {
      final response = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/get_fully_booked_dates.php',
        ),
      );
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        setState(() => fullyBookedDates = data.cast<String>());
      }
    } catch (e) {}
  }

  TimeOfDay _parseTimeString(String timeStr) {
    List<String> parts = timeStr.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  int _timeToMinutes(TimeOfDay time) => time.hour * 60 + time.minute;
  TimeOfDay _minutesToTime(int minutes) =>
      TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);

  String _formatTimeForDisplay(TimeOfDay time) {
    final dt = DateTime(2000, 1, 1, time.hour, time.minute);
    return DateFormat('h:mm a').format(dt);
  }

  String _formatTimeForDb(TimeOfDay time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00";
  }

  Future<void> _fetchBookedTimes(DateTime date) async {
    setState(() {
      _isLoadingTimes = true;
      selectedTimeRange = null;
      availableTimeSlots = [];
      bookedTimeRanges = [];
    });

    String formattedDate = date.toIso8601String().split('T')[0];

    try {
      final response = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/get_booked_times.php?date=$formattedDate',
        ),
      );

      if (response.statusCode == 200) {
        var decoded = json.decode(response.body);

        if (decoded is List) {
          bookedTimeRanges = decoded
              .map(
                (item) => TimeRange(
                  _parseTimeString(item['start']),
                  _parseTimeString(item['end']),
                  isAvailable: false,
                  reason: item['reason'] ?? 'Booked',
                  type:
                      item['type'] ??
                      'appointment', // NEW: Read the type from PHP
                ),
              )
              .toList();
        }
      }
    } catch (e) {
      debugPrint("Parse error: $e");
    } finally {
      _generateDynamicTimeSlots();
      setState(() => _isLoadingTimes = false);
    }
  }

  void _generateDynamicTimeSlots() {
    if (selectedService == null || _selectedDate == null) return;
    int durationMins = serviceDurations[selectedService!] ?? 30;
    int morningStart = 8 * 60;
    int morningEnd = 12 * 60;
    int afternoonStart = 13 * 60;
    int afternoonEnd = 18 * 60;
    List<TimeRange> generatedSlots = [];

    void buildBlocks(int shiftStart, int shiftEnd) {
      int currentStart = shiftStart;
      while (currentStart + durationMins <= shiftEnd) {
        int currentEnd = currentStart + durationMins;
        TimeRange potentialSlot = TimeRange(
          _minutesToTime(currentStart),
          _minutesToTime(currentEnd),
        );

        bool isOverlapping = false;
        String overlapReason = 'Booked';
        String overlapType = 'appointment';

        for (var booked in bookedTimeRanges) {
          if (currentStart < _timeToMinutes(booked.end) &&
              currentEnd > _timeToMinutes(booked.start)) {
            isOverlapping = true;
            overlapReason = booked.reason;
            overlapType = booked.type;
            break;
          }
        }

        if (isOverlapping) {
          potentialSlot.isAvailable = false;
          potentialSlot.reason = overlapReason;
          potentialSlot.type = overlapType;
        }

        // ==========================================
        // CRITICAL FIX: These two lines prevent the infinite loop!
        // ==========================================
        generatedSlots.add(potentialSlot);
        currentStart += durationMins;
      }
    }

    buildBlocks(morningStart, morningEnd);
    buildBlocks(afternoonStart, afternoonEnd);

    setState(() {
      availableTimeSlots = generatedSlots;
      selectedTimeRange = null; // Prevent assertion errors on service change
    });
  }

  void _onServiceChanged(String? newService) {
    setState(() {
      selectedService = newService;
      if (_selectedDate != null) _generateDynamicTimeSlots();
    });
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    String formattedDay = selectedDay.toIso8601String().split('T')[0];
    if (selectedDay.weekday == DateTime.sunday) {
      _showUnavailableDialog(
        "Clinic Closed",
        "We are closed on Sundays.",
        Icons.event_busy,
        Colors.grey,
      );
      return;
    }
    if (disabledDatesWithReasons.containsKey(formattedDay)) {
      _showUnavailableDialog(
        "Date Unavailable",
        "Blocked: ${disabledDatesWithReasons[formattedDay]!}",
        Icons.block,
        Colors.redAccent,
      );
      return;
    }
    if (fullyBookedDates.contains(formattedDay)) {
      _showUnavailableDialog(
        "Fully Booked",
        "All slots are taken.",
        Icons.group_off,
        Colors.orange,
      );
      return;
    }
    setState(() {
      _selectedDate = selectedDay;
      _focusedDay = focusedDay;
    });
    _fetchBookedTimes(selectedDay);
  }

  void _showUnavailableDialog(
    String title,
    String message,
    IconData icon,
    Color color,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          children: [
            Icon(icon, color: color, size: 50),
            const SizedBox(height: 10),
            Text(title),
          ],
        ),
        content: Text(message, textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Understood"),
          ),
        ],
      ),
    );
  }

  Future<void> _bookAppointment() async {
    if (selectedService == null ||
        _selectedDate == null ||
        selectedTimeRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Please complete all fields"),
          backgroundColor: Colors.red.shade600,
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    try {
      final response = await http.post(
        Uri.parse(
          '${ApiConfig.baseUrl}/create_appointment.php',
        ),
        body: {
          'patient_id': userId,
          'service': selectedService,
          'date': _selectedDate!.toIso8601String().split('T')[0],
          'time': _formatTimeForDb(selectedTimeRange!.start),
          'end_time': _formatTimeForDb(selectedTimeRange!.end),
        },
      );
      final data = json.decode(response.body);
      if (data['status'] == 'success') {
        _showSuccessDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? "Booking failed"),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Error connecting"),
          backgroundColor: Colors.red.shade600,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Column(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 60),
            SizedBox(height: 15),
            Text("Booking Successful!", textAlign: TextAlign.center),
          ],
        ),
        content: const Text(
          "Your request has been sent.",
          textAlign: TextAlign.center,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
              ),
              child: const Text("Go to Dashboard"),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check if there are ANY selectable slots left to determine the hint text
    bool hasAvailableSlots = availableTimeSlots.any((slot) => slot.isAvailable);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Book Appointment",
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
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Select details for your visit",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade900,
              ),
            ),
            const SizedBox(height: 24),

            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                hintText: "Select Dental Service",
                prefixIcon: Icon(Icons.medical_services_outlined),
              ),
              isExpanded: true,
              value: selectedService,
              icon: Icon(Icons.expand_more, color: Colors.grey.shade500),
              items: servicesPrices.keys.map((String service) {
                return DropdownMenuItem<String>(
                  value: service,
                  child: Text(
                    "$service (${servicesPrices[service]})",
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: _onServiceChanged,
            ),
            const SizedBox(height: 24),

            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: TableCalendar(
                firstDay: DateTime.now(),
                lastDay: DateTime.now().add(const Duration(days: 365)),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDate, day),
                onDaySelected: _onDaySelected,
                availableCalendarFormats: const {CalendarFormat.month: 'Month'},
                headerStyle: const HeaderStyle(
                  titleCentered: true,
                  formatButtonVisible: false,
                ),
                calendarStyle: CalendarStyle(
                  selectedDecoration: BoxDecoration(
                    color: Colors.blue.shade800,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: Colors.blue.shade200,
                    shape: BoxShape.circle,
                  ),
                ),
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, focusedDay) {
                    String formattedDay = day.toIso8601String().split('T')[0];
                    if (day.weekday == DateTime.sunday)
                      return Center(
                        child: Text(
                          '${day.day}',
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                      );
                    if (disabledDatesWithReasons.containsKey(formattedDay))
                      return Center(
                        child: Text(
                          '${day.day}',
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    if (fullyBookedDates.contains(formattedDay))
                      return Center(
                        child: Text(
                          '${day.day}',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    return null;
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            DropdownButtonFormField<TimeRange>(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.access_time_outlined),
              ),
              isExpanded: true,
              // 4. Dynamic Hint based on availability
              hint: _isLoadingTimes
                  ? const Text("Loading available times...")
                  : (!hasAvailableSlots && _selectedDate != null)
                  ? const Text(
                      "Fully booked/blocked this day",
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : const Text("Select Time Slot Range"),
              value: selectedTimeRange,
              icon: Icon(Icons.expand_more, color: Colors.grey.shade500),
              items:
                  (_selectedDate == null ||
                      selectedService == null ||
                      _isLoadingTimes ||
                      availableTimeSlots.isEmpty)
                  ? null
                  : availableTimeSlots.map((TimeRange range) {
                      String displayStr =
                          "${_formatTimeForDisplay(range.start)} – ${_formatTimeForDisplay(range.end)}";

                      Color textColor =
                          Colors.black87; // Default available color

                      // Append reason and calculate color if blocked
                      if (!range.isAvailable) {
                        displayStr += " (${range.reason})";

                        // NEW: Red for admin blocks, Grey for patient bookings
                        if (range.type == 'admin_block') {
                          textColor = Colors.red.shade600;
                        } else {
                          textColor = Colors.grey.shade400;
                        }
                      }

                      return DropdownMenuItem<TimeRange>(
                        value: range,
                        enabled: range.isAvailable,
                        child: Text(
                          displayStr,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: textColor, // NEW: Applies the dynamic color
                          ),
                        ),
                      );
                    }).toList(),
              onChanged: (val) => setState(() => selectedTimeRange = val),
            ),
            const SizedBox(height: 16),

            if (selectedService != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade700,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Estimated duration for $selectedService is ${serviceDurations[selectedService]} minutes. Costs will be finalized during the consultation.",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade900,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _bookAppointment,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text("CONFIRM BOOKING"),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

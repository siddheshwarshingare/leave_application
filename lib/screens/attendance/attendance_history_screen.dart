import 'package:flutter/material.dart';

import 'widgets/attendance_history_item.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  static const Color primaryBlue = Color(0xFF102A56);

  String selectedFilter = 'All';

  DateTime selectedDate = DateTime(2026, 9, 11);

  int selectedMonth = 9;
  int selectedYear = 2026;

  final List<String> filters = ['All', 'Present', 'Late', 'Absent', 'On Leave'];

  final List<String> monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  final List<int> years = [2024, 2025, 2026, 2027];

  final List<Map<String, String>> attendanceData = [
    {
      'date': '11',
      'day': 'Friday',
      'checkIn': '09:12 AM',
      'checkOut': '06:15 PM',
      'workingHours': '09h 03m',
      'status': 'Present',
    },
    {
      'date': '10',
      'day': 'Thursday',
      'checkIn': '09:05 AM',
      'checkOut': '06:28 PM',
      'workingHours': '09h 23m',
      'status': 'Present',
    },
    {
      'date': '09',
      'day': 'Wednesday',
      'checkIn': '09:42 AM',
      'checkOut': '06:10 PM',
      'workingHours': '08h 28m',
      'status': 'Late',
    },
    {
      'date': '08',
      'day': 'Tuesday',
      'checkIn': '--:--',
      'checkOut': '--:--',
      'workingHours': '--:--',
      'status': 'Absent',
    },
    {
      'date': '07',
      'day': 'Monday',
      'checkIn': '09:08 AM',
      'checkOut': '06:35 PM',
      'workingHours': '09h 27m',
      'status': 'Present',
    },
    {
      'date': '06',
      'day': 'Sunday',
      'checkIn': '--:--',
      'checkOut': '--:--',
      'workingHours': '--:--',
      'status': 'On Leave',
    },
    {
      'date': '05',
      'day': 'Saturday',
      'checkIn': '09:18 AM',
      'checkOut': '06:25 PM',
      'workingHours': '09h 07m',
      'status': 'Present',
    },
    {
      'date': '04',
      'day': 'Friday',
      'checkIn': '09:35 AM',
      'checkOut': '06:12 PM',
      'workingHours': '08h 37m',
      'status': 'Late',
    },
    {
      'date': '03',
      'day': 'Thursday',
      'checkIn': '08:58 AM',
      'checkOut': '06:15 PM',
      'workingHours': '09h 17m',
      'status': 'Present',
    },
    {
      'date': '02',
      'day': 'Wednesday',
      'checkIn': '09:04 AM',
      'checkOut': '06:20 PM',
      'workingHours': '09h 16m',
      'status': 'Present',
    },
    {
      'date': '01',
      'day': 'Tuesday',
      'checkIn': '--:--',
      'checkOut': '--:--',
      'workingHours': '--:--',
      'status': 'Absent',
    },
  ];

  List<Map<String, String>> get filteredList {
    if (selectedFilter == 'All') {
      return attendanceData;
    }

    return attendanceData
        .where((item) => item['status'] == selectedFilter)
        .toList();
  }

  String get selectedMonthName {
    return monthNames[selectedMonth - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: SafeArea(
        child: Column(
          children: [
            _header(context),

            Expanded(
              child: Column(
                children: [
                  _monthSelector(),

                  _summaryCard(),

                  _filterList(),

                  Expanded(
                    child: filteredList.isEmpty
                        ? _emptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                            itemCount: filteredList.length,
                            itemBuilder: (context, index) {
                              final item = filteredList[index];

                              return AttendanceHistoryItem(
                                date: item['date']!,
                                day: item['day']!,
                                checkIn: item['checkIn']!,
                                checkOut: item['checkOut']!,
                                workingHours: item['workingHours']!,
                                status: item['status']!,
                              );
                            },
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

  // ============================================================
  // HEADER
  // ============================================================

  Widget _header(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 14, 10, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF102A56), Color(0xFF173867)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(22),
          bottomRight: Radius.circular(22),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),

          const Expanded(
            child: Column(
              children: [
                Text(
                  'Attendance History',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'View your complete attendance',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),

          // Working calendar button
          IconButton(
            onPressed: () {
              _openCalendar();
            },
            icon: const Icon(
              Icons.calendar_month_outlined,
              color: Colors.white,
              size: 23,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MONTH SELECTOR
  // ============================================================

  Widget _monthSelector() {
    return GestureDetector(
      onTap: () {
        _showMonthBottomSheet();
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE7ECF2)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              color: Color(0xFF245078),
              size: 20,
            ),

            const SizedBox(width: 10),

            Expanded(
              child: Text(
                '$selectedMonthName $selectedYear',
                style: const TextStyle(
                  color: Color(0xFF101828),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF52627A),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DATE PICKER
  // ============================================================

  Future<void> _openCalendar() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,

      initialDate: selectedDate,

      firstDate: DateTime(2020),

      lastDate: DateTime(2035),

      helpText: 'Select Attendance Date',

      cancelText: 'Cancel',

      confirmText: 'Select',

      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryBlue,
              onPrimary: Colors.white,
              onSurface: Color(0xFF101828),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        selectedDate = pickedDate;

        selectedMonth = pickedDate.month;

        selectedYear = pickedDate.year;
      });

      debugPrint(
        'Selected Date: ${pickedDate.day}-${pickedDate.month}-${pickedDate.year}',
      );

      // Call your API here
      //
      // getAttendance(
      //   month: selectedMonth,
      //   year: selectedYear,
      // );
    }
  }

  // ============================================================
  // MONTH BOTTOM SHEET
  // ============================================================

  void _showMonthBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        int tempMonth = selectedMonth;
        int tempYear = selectedYear;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter bottomSheetSetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 15, 20, 25),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 45,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD5DBE3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Row(
                      children: [
                        Icon(Icons.calendar_month_rounded, color: primaryBlue),
                        SizedBox(width: 8),
                        Text(
                          'Select Month',
                          style: TextStyle(
                            color: Color(0xFF101828),
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Month Dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE1E7EE)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: tempMonth,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down),
                          items: List.generate(12, (index) {
                            return DropdownMenuItem<int>(
                              value: index + 1,
                              child: Text(monthNames[index]),
                            );
                          }),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }

                            bottomSheetSetState(() {
                              tempMonth = value;
                            });
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Year Dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE1E7EE)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: tempYear,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down),
                          items: years.map((year) {
                            return DropdownMenuItem<int>(
                              value: year,
                              child: Text(year.toString()),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }

                            bottomSheetSetState(() {
                              tempYear = value;
                            });
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            selectedMonth = tempMonth;
                            selectedYear = tempYear;

                            selectedDate = DateTime(tempYear, tempMonth, 1);
                          });

                          Navigator.pop(context);

                          debugPrint(
                            'Selected Month: $selectedMonth/$selectedYear',
                          );

                          // Call your API here:
                          //
                          // getAttendance(
                          //   month: selectedMonth,
                          //   year: selectedYear,
                          // );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Apply',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // SUMMARY
  // ============================================================

  Widget _summaryCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7ECF2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _summaryItem(
              value: '18',
              title: 'Present',
              color: const Color(0xFF1FB45A),
              background: const Color(0xFFE7F8ED),
            ),
          ),
          Expanded(
            child: _summaryItem(
              value: '02',
              title: 'Absent',
              color: const Color(0xFFE24C50),
              background: const Color(0xFFFFECEE),
            ),
          ),
          Expanded(
            child: _summaryItem(
              value: '03',
              title: 'Late',
              color: const Color(0xFFD79A15),
              background: const Color(0xFFFFF5D9),
            ),
          ),
          Expanded(
            child: _summaryItem(
              value: '01',
              title: 'Leave',
              color: const Color(0xFF7661DE),
              background: const Color(0xFFF0EBFF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryItem({
    required String value,
    required String title,
    required Color color,
    required Color background,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            child: Text(
              title,
              style: const TextStyle(color: Color(0xFF52627A), fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FILTER
  // ============================================================

  Widget _filterList() {
    return SizedBox(
      height: 60,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) {
          return const SizedBox(width: 8);
        },
        itemBuilder: (context, index) {
          final filter = filters[index];

          final isSelected = selectedFilter == filter;

          return GestureDetector(
            onTap: () {
              setState(() {
                selectedFilter = filter;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? primaryBlue : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? primaryBlue : const Color(0xFFE3E8EF),
                ),
              ),
              child: Text(
                filter,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF52627A),
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _emptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_month_outlined,
            size: 60,
            color: Color(0xFFA8B5C4),
          ),
          SizedBox(height: 12),
          Text(
            'No attendance found',
            style: TextStyle(
              color: Color(0xFF52627A),
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

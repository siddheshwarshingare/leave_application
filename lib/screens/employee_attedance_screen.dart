import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// class EmployeeAttendanceScreen extends StatelessWidget {
//   const EmployeeAttendanceScreen({super.key});

//   Future<void> showPunchDetails(
//     BuildContext context,
//     String attendanceId,
//   ) async {
//     QuerySnapshot snap = await FirebaseFirestore.instance
//         .collection('attendance')
//         .doc(attendanceId)
//         .collection('punches')
//         .orderBy('time')
//         .get();

//     showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: const Text("Punch Details"),
//         content: SizedBox(
//           width: double.maxFinite,
//           child: ListView.builder(
//             shrinkWrap: true,
//             itemCount: snap.docs.length,
//             itemBuilder: (_, index) {
//               var punch = snap.docs[index];

//               DateTime time = (punch['time'] as Timestamp).toDate();

//               return ListTile(
//                 leading: Icon(
//                   punch['type'] == "IN" ? Icons.login : Icons.logout,
//                   color: punch['type'] == "IN" ? Colors.green : Colors.red,
//                 ),
//                 title: Text(punch['type']),
//                 subtitle: Text(time.toString()),
//               );
//             },
//           ),
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     String uid = FirebaseAuth.instance.currentUser!.uid;

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text(
//           "My Attendance",
//           style: TextStyle(fontWeight: FontWeight.bold),
//         ),
//         backgroundColor: Colors.blue,
//         //foregroundColor: Colors.black,
//       ),

//       body: StreamBuilder<QuerySnapshot>(
//         stream: FirebaseFirestore.instance
//             .collection('attendance')
//             .where('uid', isEqualTo: uid)
//             .orderBy('date', descending: true)
//             .snapshots(),

//         builder: (context, snapshot) {
//           if (!snapshot.hasData) {
//             return const Center(child: CircularProgressIndicator());
//           }

//           final docs = snapshot.data!.docs;

//           if (docs.isEmpty) {
//             return const Center(child: Text("No Attendance Found"));
//           }

//           return ListView.builder(
//             itemCount: docs.length,
//             itemBuilder: (context, index) {
//               var data = docs[index];

//               return Card(
//                 elevation: 6,
//                 margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(18),
//                 ),
//                 child: Container(
//                   padding: const EdgeInsets.all(16),
//                   decoration: BoxDecoration(
//                     borderRadius: BorderRadius.circular(18),
//                     gradient: LinearGradient(
//                       colors: [Colors.blue.shade50, Colors.white],
//                     ),
//                   ),
//                   child: Row(
//                     children: [
//                       Container(
//                         padding: const EdgeInsets.all(14),
//                         decoration: BoxDecoration(
//                           color: Colors.blue.shade100,
//                           borderRadius: BorderRadius.circular(14),
//                         ),
//                         child: const Icon(
//                           Icons.calendar_month,
//                           color: Colors.blue,
//                           size: 30,
//                         ),
//                       ),

//                       const SizedBox(width: 15),

//                       Expanded(
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               data['date'],
//                               style: const TextStyle(
//                                 fontSize: 17,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),

//                             const SizedBox(height: 8),

//                             Row(
//                               children: [
//                                 const Icon(
//                                   Icons.access_time,
//                                   size: 18,
//                                   color: Colors.green,
//                                 ),

//                                 const SizedBox(width: 5),

//                                 Text(
//                                   data['workingHours'],
//                                   style: const TextStyle(
//                                     fontSize: 15,
//                                     fontWeight: FontWeight.w600,
//                                     color: Colors.green,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ],
//                         ),
//                       ),

//                       InkWell(
//                         onTap: () {
//                           showPunchDetails(context, data.id);
//                         },
//                         borderRadius: BorderRadius.circular(12),
//                         child: Container(
//                           padding: const EdgeInsets.all(10),
//                           decoration: BoxDecoration(
//                             color: Colors.blue.shade50,
//                             borderRadius: BorderRadius.circular(12),
//                           ),
//                           child: const Icon(
//                             Icons.visibility,
//                             color: Colors.blue,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }
// }
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EmployeeAttendanceScreen extends StatefulWidget {
  const EmployeeAttendanceScreen({super.key});

  @override
  State<EmployeeAttendanceScreen> createState() =>
      _EmployeeAttendanceScreenState();
}

class _EmployeeAttendanceScreenState extends State<EmployeeAttendanceScreen> {
  DateTime selectedDate = DateTime.now();

  bool isLoading = true;

  String? attendanceId;

  List<_Punch> punches = [];

  Duration workingTime = Duration.zero;
  Duration breakTime = Duration.zero;

  // ----------------------------------------------------------
  // LOAD ATTENDANCE FOR SELECTED DAY
  // ----------------------------------------------------------
  Widget _buildDateSelector() {
    final isToday = DateUtils.isSameDay(selectedDate, DateTime.now());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          _dateArrow(icon: Icons.chevron_left_rounded, onTap: _previousDay),

          Expanded(
            child: InkWell(
              onTap: selectDate,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 15,
                          color: Color(0xFF6D28D9),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isToday ? "Today" : _dayName(selectedDate),
                          style: const TextStyle(
                            color: Color(0xFF6D28D9),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 5),

                    Text(
                      _displayDate(selectedDate),
                      style: const TextStyle(
                        color: Color(0xFF17133A),
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          _dateArrow(icon: Icons.chevron_right_rounded, onTap: _nextDay),
        ],
      ),
    );
  }

  Widget _dateArrow({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: const Color(0xFFF3EEFF),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: const SizedBox(
          width: 46,
          height: 46,
          child: Icon(Icons.chevron_left_rounded, color: Color(0xFF6D28D9)),
        ),
      ),
    );
  }

  Widget _buildModernSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.04),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withOpacity(.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 21),
                ),

                const Spacer(),

                Icon(Icons.more_horiz_rounded, color: Colors.grey.shade400),
              ],
            ),

            const SizedBox(height: 16),

            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 5),

            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernPunchTile(_Punch punch, {required bool isLast}) {
    IconData icon;
    Color color;
    Color lightColor;
    String title;
    String subtitle;

    switch (punch.type) {
      case "IN":
        icon = Icons.login_rounded;
        color = const Color(0xFF2563EB);
        lightColor = const Color(0xFFEFF6FF);
        title = "Clock In";
        subtitle = "Started working";
        break;

      case "OUT":
        icon = Icons.logout_rounded;
        color = const Color(0xFFE11D48);
        lightColor = const Color(0xFFFFF1F2);
        title = "Clock Out";
        subtitle = "Finished working";
        break;

      case "BREAK_IN":
        icon = Icons.coffee_rounded;
        color = const Color(0xFFEA580C);
        lightColor = const Color(0xFFFFF7ED);
        title = "Break Started";
        subtitle = "Employee went on break";
        break;

      case "BREAK_OUT":
        icon = Icons.play_arrow_rounded;
        color = const Color(0xFF059669);
        lightColor = const Color(0xFFECFDF5);
        title = "Break Ended";
        subtitle = "Work resumed";
        break;

      default:
        icon = Icons.access_time_rounded;
        color = const Color(0xFF6B7280);
        lightColor = const Color(0xFFF3F4F6);
        title = punch.type;
        subtitle = "Attendance activity";
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 52,
          child: Column(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: lightColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 21),
              ),

              if (!isLast)
                Container(
                  width: 2,
                  height: 55,
                  margin: const EdgeInsets.only(top: 5),
                  color: Colors.grey.shade200,
                ),
            ],
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF17133A),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFF8A8FA3),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatTime(punch.time),
                      style: TextStyle(
                        color: color,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      "${punch.time.day} ${_monthName(punch.time.month)}",
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _monthName(int month) {
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];

    return months[month - 1];
  }

  Widget _buildAttendanceEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.035),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 75,
            height: 75,
            decoration: const BoxDecoration(
              color: Color(0xFFF3EEFF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_busy_rounded,
              size: 34,
              color: Color(0xFF6D28D9),
            ),
          ),

          const SizedBox(height: 18),

          const Text(
            "No Attendance",
            style: TextStyle(
              color: Color(0xFF17133A),
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            "There are no attendance records\n"
            "for ${_displayDate(selectedDate)}",
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF8A8FA3),
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> loadAttendance() async {
    setState(() {
      isLoading = true;
      punches = [];
      attendanceId = null;
      workingTime = Duration.zero;
      breakTime = Duration.zero;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (!mounted) return;

        setState(() {
          isLoading = false;
        });

        return;
      }

      final date = _formatDate(selectedDate);

      final snapshot = await FirebaseFirestore.instance
          .collection("attendance")
          .where("uid", isEqualTo: user.uid)
          .where("date", isEqualTo: date)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        if (!mounted) return;

        setState(() {
          isLoading = false;
          punches = [];
          attendanceId = null;
          workingTime = Duration.zero;
          breakTime = Duration.zero;
        });

        return;
      }

      final attendanceDoc = snapshot.docs.first;

      final punchesSnapshot = await FirebaseFirestore.instance
          .collection("attendance")
          .doc(attendanceDoc.id)
          .collection("punches")
          .orderBy("time")
          .get();

      final List<_Punch> loadedPunches = [];

      for (final doc in punchesSnapshot.docs) {
        final data = doc.data();

        final type = data["type"]?.toString() ?? "";

        final timestamp = data["time"];

        if (timestamp is! Timestamp) {
          continue;
        }

        loadedPunches.add(_Punch(type: type, time: timestamp.toDate()));
      }

      final calculatedWorkingTime = _calculateWorkingTime(loadedPunches);

      final calculatedBreakTime = _calculateBreakTime(loadedPunches);

      if (!mounted) return;

      setState(() {
        attendanceId = attendanceDoc.id;
        punches = loadedPunches;

        workingTime = calculatedWorkingTime;
        breakTime = calculatedBreakTime;

        isLoading = false;
      });
    } catch (e) {
      debugPrint("Attendance loading error: $e");

      if (!mounted) return;

      setState(() {
        isLoading = false;
        punches = [];
        attendanceId = null;
        workingTime = Duration.zero;
        breakTime = Duration.zero;
      });
    }
  }

  // ----------------------------------------------------------
  // FORMAT DATE
  // ----------------------------------------------------------

  String _formatDate(DateTime date) {
    return "${date.year}-"
        "${date.month.toString().padLeft(2, '0')}-"
        "${date.day.toString().padLeft(2, '0')}";
  }

  // ----------------------------------------------------------
  // DISPLAY DATE
  // ----------------------------------------------------------

  String _displayDate(DateTime date) {
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];

    return "${date.day.toString().padLeft(2, '0')} "
        "${months[date.month - 1]} "
        "${date.year}";
  }

  // ----------------------------------------------------------
  // DAY NAME
  // ----------------------------------------------------------

  String _dayName(DateTime date) {
    const days = [
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday",
      "Saturday",
      "Sunday",
    ];

    return days[date.weekday - 1];
  }

  // ----------------------------------------------------------
  // WORKING TIME CALCULATION
  // ----------------------------------------------------------

  Duration _calculateWorkingTime(List<_Punch> punches) {
    Duration total = Duration.zero;

    DateTime? inTime;

    for (final punch in punches) {
      if (punch.type == "IN") {
        inTime = punch.time;
      }

      if (punch.type == "OUT" && inTime != null) {
        total += punch.time.difference(inTime);

        inTime = null;
      }
    }

    // If employee is currently clocked in,
    // calculate until current time.
    if (inTime != null) {
      total += DateTime.now().difference(inTime);
    }

    return total;
  }

  // ----------------------------------------------------------
  // BREAK TIME CALCULATION
  // ----------------------------------------------------------

  Duration _calculateBreakTime(List<_Punch> punches) {
    Duration total = Duration.zero;

    DateTime? breakStart;

    for (final punch in punches) {
      if (punch.type == "BREAK_IN") {
        breakStart = punch.time;
      }

      if (punch.type == "BREAK_OUT" && breakStart != null) {
        total += punch.time.difference(breakStart);

        breakStart = null;
      }
    }

    // If currently on break,
    // calculate until current time.
    if (breakStart != null) {
      total += DateTime.now().difference(breakStart);
    }

    return total;
  }

  // ----------------------------------------------------------
  // FORMAT DURATION
  // ----------------------------------------------------------

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;

    final minutes = duration.inMinutes % 60;

    return "${hours.toString().padLeft(2, '0')}h "
        "${minutes.toString().padLeft(2, '0')}m";
  }

  // ----------------------------------------------------------
  // PREVIOUS DAY
  // ----------------------------------------------------------

  void _previousDay() {
    setState(() {
      selectedDate = selectedDate.subtract(const Duration(days: 1));
    });

    loadAttendance();
  }

  // ----------------------------------------------------------
  // NEXT DAY
  // ----------------------------------------------------------

  void _nextDay() {
    final today = DateTime.now();

    final currentDay = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );

    final todayOnly = DateTime(today.year, today.month, today.day);

    // Don't allow future dates.
    if (currentDay.isAtSameMomentAs(todayOnly)) {
      return;
    }

    setState(() {
      selectedDate = selectedDate.add(const Duration(days: 1));
    });

    loadAttendance();
  }

  // ----------------------------------------------------------
  // DATE PICKER
  // ----------------------------------------------------------

  Future<void> selectDate() async {
    final today = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(today.year, today.month, today.day),
    );

    if (picked == null) return;

    setState(() {
      selectedDate = picked;
    });

    loadAttendance();
  }

  // ----------------------------------------------------------
  // PUNCH DETAILS POPUP
  // ----------------------------------------------------------

  Future<void> showPunchDetails() async {
    if (punches.isEmpty) return;

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "Punch Details",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: punches.length,
                    itemBuilder: (_, index) {
                      final punch = punches[index];

                      return _buildPunchTile(
                        punch,
                        showDivider: index != punches.length - 1,
                      );
                    },
                  ),
                ),

                const Divider(),

                _summaryRow(
                  "Working Time",
                  _formatDuration(workingTime),
                  Icons.access_time,
                  Colors.green,
                ),

                const SizedBox(height: 8),

                _summaryRow(
                  "Break Time",
                  _formatDuration(breakTime),
                  Icons.free_breakfast,
                  Colors.orange,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  // ----------------------------------------------------------
  // PUNCH TILE
  // ----------------------------------------------------------

  Widget _buildPunchTile(_Punch punch, {bool showDivider = true}) {
    IconData icon;
    Color color;
    String title;

    switch (punch.type) {
      case "IN":
        icon = Icons.login;
        color = Colors.green;
        title = "Clock In";
        break;

      case "OUT":
        icon = Icons.logout;
        color = Colors.red;
        title = "Clock Out";
        break;

      case "BREAK_IN":
        icon = Icons.free_breakfast;
        color = Colors.orange;
        title = "Break In";
        break;

      case "BREAK_OUT":
        icon = Icons.play_arrow;
        color = Colors.blue;
        title = "Break Out";
        break;

      default:
        icon = Icons.access_time;
        color = Colors.grey;
        title = punch.type;
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // ICON
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 23),
              ),

              const SizedBox(width: 14),

              // TITLE + TIME
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF172033),
                      ),
                    ),

                    const SizedBox(height: 5),

                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 13,
                          color: Colors.grey.shade500,
                        ),

                        const SizedBox(width: 5),

                        Text(
                          _formatTime(punch.time),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // RIGHT SIDE
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),

        if (showDivider) const Divider(height: 1),
      ],
    );
  }

  // ----------------------------------------------------------
  // FORMAT TIME
  // ----------------------------------------------------------

  String _formatTime(DateTime time) {
    final hour = time.hour == 0
        ? 12
        : time.hour > 12
        ? time.hour - 12
        : time.hour;

    final minute = time.minute.toString().padLeft(2, '0');

    final period = time.hour >= 12 ? "PM" : "AM";

    return "$hour:$minute $period";
  }

  // ----------------------------------------------------------
  // SUMMARY ROW
  // ----------------------------------------------------------

  Widget _summaryRow(String title, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),

        const SizedBox(width: 8),

        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),

        Text(
          value,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // ----------------------------------------------------------
  // INITIAL LOAD
  // ----------------------------------------------------------

  @override
  void initState() {
    super.initState();

    loadAttendance();
  }

  // ----------------------------------------------------------
  // BUILD
  // ----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),

      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FC),
        elevation: 0,
        centerTitle: false,
        titleSpacing: 20,

        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "My Attendance",
              style: TextStyle(
                color: Color(0xFF17133A),
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 2),
            Text(
              "Track your daily work activity",
              style: TextStyle(
                color: Color(0xFF8A8FA3),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),

        actions: [
          Container(
            margin: const EdgeInsets.only(right: 18),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 10),
              ],
            ),
            child: IconButton(
              onPressed: loadAttendance,
              icon: const Icon(
                Icons.refresh_rounded,
                color: Color(0xFF6D28D9),
                size: 21,
              ),
            ),
          ),
        ],
      ),

      body: RefreshIndicator(
        color: const Color(0xFF6D28D9),
        onRefresh: loadAttendance,

        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),

          padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),

          children: [
            // =====================================================
            // DATE
            // =====================================================
            _buildDateSelector(),

            const SizedBox(height: 18),

            // =====================================================
            // DATE LABEL
            // =====================================================
            Row(
              children: [
                const Icon(
                  Icons.today_rounded,
                  color: Color(0xFF6D28D9),
                  size: 18,
                ),

                const SizedBox(width: 7),

                Text(
                  _dayName(selectedDate),
                  style: const TextStyle(
                    color: Color(0xFF17133A),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const Spacer(),

                if (DateUtils.isSameDay(selectedDate, DateTime.now()))
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE9FE),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      "TODAY",
                      style: TextStyle(
                        color: Color(0xFF6D28D9),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 15),

            // =====================================================
            // LOADING
            // =====================================================
            if (isLoading)
              const SizedBox(
                height: 400,
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF6D28D9)),
                ),
              )
            // =====================================================
            // EMPTY
            // =====================================================
            else if (punches.isEmpty)
              _buildAttendanceEmptyState()
            // =====================================================
            // DATA
            // =====================================================
            else ...[
              // =================================================
              // SUMMARY
              // =================================================
              Row(
                children: [
                  _buildModernSummaryCard(
                    title: "Working Time",
                    value: _formatDuration(workingTime),
                    icon: Icons.access_time_filled_rounded,
                    color: const Color(0xFF059669),
                  ),

                  const SizedBox(width: 12),

                  _buildModernSummaryCard(
                    title: "Break Time",
                    value: _formatDuration(breakTime),
                    icon: Icons.coffee_rounded,
                    color: const Color(0xFFEA580C),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              // =================================================
              // PUNCH HEADER
              // =================================================
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Activity",
                          style: TextStyle(
                            color: Color(0xFF17133A),
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),

                        SizedBox(height: 3),

                        Text(
                          "Today's attendance timeline",
                          style: TextStyle(
                            color: Color(0xFF8A8FA3),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),

                  InkWell(
                    onTap: showPunchDetails,
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0E9FF),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.visibility_rounded,
                            color: Color(0xFF6D28D9),
                            size: 16,
                          ),

                          SizedBox(width: 5),

                          Text(
                            "View All",
                            style: TextStyle(
                              color: Color(0xFF6D28D9),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // =================================================
              // TIMELINE
              // =================================================
              Container(
                padding: const EdgeInsets.fromLTRB(10, 18, 10, 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.035),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < punches.length; i++)
                      _buildModernPunchTile(
                        punches[i],
                        isLast: i == punches.length - 1,
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // =================================================
              // DAILY SUMMARY
              // =================================================
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6D28D9).withOpacity(.20),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.15),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.analytics_rounded,
                        color: Colors.white,
                        size: 25,
                      ),
                    ),

                    const SizedBox(width: 13),

                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Daily Summary",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),

                          SizedBox(height: 4),

                          Text(
                            "Your attendance for this day",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatDuration(workingTime),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),

                        const SizedBox(height: 3),

                        const Text(
                          "worked",
                          style: TextStyle(color: Colors.white70, fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------
// SUMMARY CARD
// ----------------------------------------------------------

Widget _summaryCard({
  required String title,
  required String value,
  required IconData icon,
  required Color color,
}) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: color.withOpacity(0.15)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),

        const SizedBox(height: 12),

        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: 4),

        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

// ============================================================
// PUNCH MODEL
// ============================================================

class _Punch {
  final String type;
  final DateTime time;

  _Punch({required this.type, required this.time});
}

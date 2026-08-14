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
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(_formatTime(punch.time)),
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
      appBar: AppBar(
        title: const Text(
          "My Attendance",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      body: RefreshIndicator(
        onRefresh: loadAttendance,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ------------------------------------------------
            // DATE FILTER
            // ------------------------------------------------
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                children: [
                  // PREVIOUS
                  IconButton(
                    onPressed: _previousDay,
                    icon: const Icon(Icons.chevron_left),
                    color: Colors.blue,
                  ),

                  Expanded(
                    child: InkWell(
                      onTap: selectDate,
                      borderRadius: BorderRadius.circular(12),
                      child: Column(
                        children: [
                          Text(
                            _dayName(selectedDate),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          const SizedBox(height: 3),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.calendar_month,
                                size: 20,
                                color: Colors.blue,
                              ),

                              const SizedBox(width: 6),

                              Text(
                                _displayDate(selectedDate),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // NEXT
                  IconButton(
                    onPressed: _nextDay,
                    icon: const Icon(Icons.chevron_right),
                    color: Colors.blue,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ------------------------------------------------
            // LOADING
            // ------------------------------------------------
            if (isLoading)
              const SizedBox(
                height: 250,
                child: Center(child: CircularProgressIndicator()),
              )
            // ------------------------------------------------
            // NO ATTENDANCE
            // ------------------------------------------------
            else if (punches.isEmpty)
              Container(
                padding: const EdgeInsets.all(35),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.event_busy,
                      size: 55,
                      color: Colors.grey.shade400,
                    ),

                    const SizedBox(height: 15),

                    const Text(
                      "No Attendance Found",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      "No attendance record for\n"
                      "${_displayDate(selectedDate)}",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              )
            // ------------------------------------------------
            // ATTENDANCE DATA
            // ------------------------------------------------
            else ...[
              // ----------------------------------------------
              // SUMMARY CARDS
              // ----------------------------------------------
              Row(
                children: [
                  Expanded(
                    child: _summaryCard(
                      title: "Working Time",
                      value: _formatDuration(workingTime),
                      icon: Icons.access_time,
                      color: Colors.green,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: _summaryCard(
                      title: "Break Time",
                      value: _formatDuration(breakTime),
                      icon: Icons.free_breakfast,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // ----------------------------------------------
              // PUNCH HISTORY HEADER
              // ----------------------------------------------
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Punch History",
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  InkWell(
                    onTap: showPunchDetails,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.visibility, size: 18, color: Colors.blue),
                          SizedBox(width: 5),
                          Text(
                            "View All",
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ----------------------------------------------
              // PUNCH LIST
              // ----------------------------------------------
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < punches.length; i++)
                      _buildPunchTile(
                        punches[i],
                        showDivider: i != punches.length - 1,
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
}

// ============================================================
// PUNCH MODEL
// ============================================================

class _Punch {
  final String type;
  final DateTime time;

  _Punch({required this.type, required this.time});
}

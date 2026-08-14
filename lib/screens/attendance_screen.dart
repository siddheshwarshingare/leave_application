import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:leave_application/screens/employee_attedance_screen.dart';
import 'package:leave_application/services/attendance_service.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _Punch {
  final String type;
  final DateTime time;

  _Punch({required this.type, required this.time});
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  List<_Punch> _todayPunches = [];
  Timer? timer;
  bool isOnBreak = false;
  bool isProcessing = false;
  bool isClockedIn = false;
  DateTime? clockInTime;
  Duration elapsed = Duration.zero;
  String workingHours = "0h 0m";
  List<Map<String, dynamic>> history = [];
  bool isLoadingHistory = true;
  final List<Map<String, dynamic>> tempHistory = [];

  @override
  void initState() {
    super.initState();
    loadAttendance();
    loadTodayHistory();
  }

  void _calculateCurrentStatus(List<_Punch> punches) {
    bool clockedIn = false;
    bool onBreak = false;

    for (final punch in punches) {
      switch (punch.type) {
        case "IN":
          clockedIn = true;
          onBreak = false;
          break;

        case "BREAK_IN":
          if (clockedIn) {
            onBreak = true;
          }
          break;

        case "BREAK_OUT":
          if (clockedIn) {
            onBreak = false;
          }
          break;

        case "OUT":
          clockedIn = false;
          onBreak = false;
          break;
      }
    }

    isClockedIn = clockedIn;
    isOnBreak = onBreak;
  }

  Duration _calculateWorkingTime(List<_Punch> punches, {DateTime? now}) {
    final currentTime = now ?? DateTime.now();

    Duration total = Duration.zero;

    DateTime? workStart;
    DateTime? breakStart;

    Duration breakDuration = Duration.zero;

    for (final punch in punches) {
      final time = punch.time;

      switch (punch.type) {
        // ------------------------------------------------------
        // CLOCK IN
        // ------------------------------------------------------

        case "IN":
          if (workStart == null) {
            workStart = time;
            breakDuration = Duration.zero;
            breakStart = null;
          }
          break;

        // ------------------------------------------------------
        // BREAK IN
        // ------------------------------------------------------

        case "BREAK_IN":
          if (workStart != null && breakStart == null) {
            breakStart = time;
          }
          break;

        // ------------------------------------------------------
        // BREAK OUT
        // ------------------------------------------------------

        case "BREAK_OUT":
          if (workStart != null && breakStart != null) {
            if (time.isAfter(breakStart!)) {
              breakDuration += time.difference(breakStart!);
            }

            breakStart = null;
          }
          break;

        // ------------------------------------------------------
        // CLOCK OUT
        // ------------------------------------------------------

        case "OUT":
          if (workStart != null) {
            Duration currentBreak = breakDuration;

            if (breakStart != null) {
              if (time.isAfter(breakStart!)) {
                currentBreak += time.difference(breakStart!);
              }
            }

            Duration sessionDuration =
                time.difference(workStart) - currentBreak;

            if (sessionDuration.isNegative) {
              sessionDuration = Duration.zero;
            }

            total += sessionDuration;

            workStart = null;
            breakStart = null;
            breakDuration = Duration.zero;
          }

          break;
      }
    }

    // ----------------------------------------------------------
    // CURRENT OPEN SESSION
    // ----------------------------------------------------------

    if (workStart != null) {
      Duration currentBreak = breakDuration;

      if (breakStart != null) {
        currentBreak += currentTime.difference(breakStart!);
      }

      Duration liveDuration = currentTime.difference(workStart) - currentBreak;

      if (liveDuration.isNegative) {
        liveDuration = Duration.zero;
      }

      total += liveDuration;
    }

    return total;
  }

  Future<void> loadTodayHistory() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      // ----------------------------------------------------------
      // USER NOT LOGGED IN
      // ----------------------------------------------------------
      if (user == null) {
        if (!mounted) return;

        setState(() {
          history = [];
          _todayPunches = [];
          elapsed = Duration.zero;
          workingHours = "0h 0m";
          isClockedIn = false;
          isOnBreak = false;
          isLoadingHistory = false;
        });

        timer?.cancel();
        return;
      }

      final now = DateTime.now();

      final date =
          "${now.year}-"
          "${now.month.toString().padLeft(2, '0')}-"
          "${now.day.toString().padLeft(2, '0')}";

      // ----------------------------------------------------------
      // GET TODAY ATTENDANCE DOCUMENT
      // ----------------------------------------------------------
      final snapshot = await FirebaseFirestore.instance
          .collection("attendance")
          .where("uid", isEqualTo: user.uid)
          .where("date", isEqualTo: date)
          .limit(1)
          .get();

      // ----------------------------------------------------------
      // NO ATTENDANCE RECORD FOR TODAY
      // ----------------------------------------------------------
      if (snapshot.docs.isEmpty) {
        if (!mounted) return;

        setState(() {
          history = [];
          _todayPunches = [];
          elapsed = Duration.zero;
          workingHours = "0h 0m";
          isClockedIn = false;
          isOnBreak = false;
          isLoadingHistory = false;
        });

        timer?.cancel();
        return;
      }

      final attendanceDoc = snapshot.docs.first;

      // ----------------------------------------------------------
      // GET TODAY'S PUNCHES
      // ----------------------------------------------------------
      final punchesSnapshot = await FirebaseFirestore.instance
          .collection("attendance")
          .doc(attendanceDoc.id)
          .collection("punches")
          .orderBy("time")
          .get();

      final List<_Punch> punches = [];
      final List<Map<String, dynamic>> tempHistory = [];

      // ----------------------------------------------------------
      // CONVERT FIREBASE PUNCHES
      // ----------------------------------------------------------
      for (final doc in punchesSnapshot.docs) {
        final data = doc.data();

        final type = data["type"]?.toString() ?? "";

        final timestamp = data["time"];

        if (timestamp is! Timestamp) {
          continue;
        }

        final time = timestamp.toDate();

        punches.add(_Punch(type: type, time: time));

        tempHistory.add({"type": type, "time": time});
      }

      // ----------------------------------------------------------
      // CALCULATE WORKING TIME
      // ----------------------------------------------------------
      final calculatedTime = _calculateWorkingTime(
        punches,
        now: DateTime.now(),
      );

      // ----------------------------------------------------------
      // CALCULATE CURRENT STATUS
      // ----------------------------------------------------------
      _calculateCurrentStatus(punches);

      // ----------------------------------------------------------
      // UPDATE UI
      // ----------------------------------------------------------
      if (!mounted) return;

      setState(() {
        history = tempHistory;

        // IMPORTANT:
        // Save today's punches here.
        // startTimer() and _hasOpenWorkSession()
        // depend on this list.
        _todayPunches = punches;

        elapsed = calculatedTime;

        workingHours =
            "${calculatedTime.inHours}h "
            "${calculatedTime.inMinutes % 60}m";

        isLoadingHistory = false;
      });

      // ----------------------------------------------------------
      // START / STOP LIVE TIMER
      // ----------------------------------------------------------
      if (_hasOpenWorkSession()) {
        startTimer();
      } else {
        timer?.cancel();
      }
    } catch (e) {
      debugPrint("Attendance loading error: $e");

      if (!mounted) return;

      setState(() {
        history = [];
        _todayPunches = [];
        elapsed = Duration.zero;
        workingHours = "0h 0m";
        isClockedIn = false;
        isOnBreak = false;
        isLoadingHistory = false;
      });

      timer?.cancel();
    }
  }

  Future<void> loadAttendance() async {
    final data = await AttendanceService.getTodayAttendance();

    if (data != null) {
      setState(() {
        isClockedIn = data['isClockedIn'] ?? false;

        workingHours = data['workingHours'] ?? "0h 0m";
      });
    }
  }

  Future<void> _refreshLiveWorkingTime() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final now = DateTime.now();

    final date =
        "${now.year}-"
        "${now.month.toString().padLeft(2, '0')}-"
        "${now.day.toString().padLeft(2, '0')}";

    final snapshot = await FirebaseFirestore.instance
        .collection("attendance")
        .where("uid", isEqualTo: user.uid)
        .where("date", isEqualTo: date)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return;

    final attendanceDoc = snapshot.docs.first;

    final punchesSnapshot = await FirebaseFirestore.instance
        .collection("attendance")
        .doc(attendanceDoc.id)
        .collection("punches")
        .orderBy("time")
        .get();

    final List<_Punch> punches = [];

    for (final doc in punchesSnapshot.docs) {
      final data = doc.data();

      final timestamp = data["time"];

      if (timestamp is Timestamp) {
        punches.add(
          _Punch(
            type: data["type"]?.toString() ?? "",
            time: timestamp.toDate(),
          ),
        );
      }
    }

    final duration = _calculateWorkingTime(punches, now: now);

    _calculateCurrentStatus(punches);

    if (!mounted) return;

    setState(() {
      elapsed = duration;

      workingHours =
          "${duration.inHours}h "
          "${duration.inMinutes % 60}m";
    });
  }

  bool _hasOpenWorkSession() {
    bool working = false;

    for (final punch in _todayPunches) {
      if (punch.type == "IN") {
        working = true;
      } else if (punch.type == "OUT") {
        working = false;
      }
    }

    return working;
  }

  void startTimer() {
    timer?.cancel();

    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_hasOpenWorkSession()) {
        timer?.cancel();
        return;
      }

      final duration = _calculateWorkingTime(
        _todayPunches,
        now: DateTime.now(),
      );

      if (!mounted) return;

      setState(() {
        elapsed = duration;

        workingHours =
            "${duration.inHours}h "
            "${duration.inMinutes % 60}m";
      });
    });
  }

  String formatDuration(Duration duration) {
    return "${duration.inHours.toString().padLeft(2, '0')}:"
        "${(duration.inMinutes % 60).toString().padLeft(2, '0')}:"
        "${(duration.inSeconds % 60).toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> handlePunchIn() async {
    if (isProcessing) return;

    try {
      setState(() {
        isProcessing = true;
      });

      final allowed = await AttendanceService.canMarkAttendance();

      if (!allowed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You are outside office location")),
        );

        return;
      }

      await AttendanceService.punchIn();

      await loadTodayHistory();

      startTimer();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Clock In Successful")));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() {
          isProcessing = false;
        });
      }
    }
  }

  Future<void> handlePunchOut() async {
    if (isProcessing) return;

    if (isOnBreak) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please end your break before Clock Out")),
      );

      return;
    }

    try {
      setState(() {
        isProcessing = true;
      });

      final allowed = await AttendanceService.canMarkAttendance();

      if (!allowed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You are outside office location")),
        );

        return;
      }

      await AttendanceService.punchOut();

      timer?.cancel();

      await loadTodayHistory();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Clock Out Successful")));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() {
          isProcessing = false;
        });
      }
    }
  }

  Future<void> handleBreakOut() async {
    if (isProcessing) return;

    if (!isOnBreak) return;

    try {
      setState(() {
        isProcessing = true;
      });

      final allowed = await AttendanceService.canMarkAttendance();

      if (!allowed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You are outside office location")),
        );

        return;
      }

      await AttendanceService.breakOut();

      await loadTodayHistory();

      startTimer();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Break Ended")));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() {
          isProcessing = false;
        });
      }
    }
  }

  Future<void> handleBreakIn() async {
    if (isProcessing) return;

    if (!isClockedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You must Clock In before taking a break"),
        ),
      );

      return;
    }

    if (isOnBreak) return;

    try {
      setState(() {
        isProcessing = true;
      });

      final allowed = await AttendanceService.canMarkAttendance();

      if (!allowed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You are outside office location")),
        );

        return;
      }

      await AttendanceService.breakIn();

      await loadTodayHistory();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Break Started")));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() {
          isProcessing = false;
        });
      }
    }
  }

  Widget _buildHistoryItem({
    required String eventType,
    required String eventTime,
  }) {
    Color backgroundColor;
    Color iconColor;
    IconData icon;
    String title;
    String subtitle;

    switch (eventType.toLowerCase()) {
      case "clock_in":
        backgroundColor = const Color(0xFFE0E7FF);
        iconColor = const Color(0xFF4F46E5);
        icon = Icons.login_rounded;
        title = "Clock In";
        subtitle = "Work started";
        break;

      case "clock_out":
        backgroundColor = const Color(0xFFFEE2E2);
        iconColor = const Color(0xFFDC2626);
        icon = Icons.logout_rounded;
        title = "Clock Out";
        subtitle = "Work finished";
        break;

      case "break_in":
        backgroundColor = const Color(0xFFFFEDD5);
        iconColor = const Color(0xFFEA580C);
        icon = Icons.free_breakfast_rounded;
        title = "Break In";
        subtitle = "Break started";
        break;

      case "break_out":
        backgroundColor = const Color(0xFFD1FAE5);
        iconColor = const Color(0xFF059669);
        icon = Icons.play_arrow_rounded;
        title = "Break Out";
        subtitle = "Work resumed";
        break;

      default:
        backgroundColor = const Color(0xFFF3F4F6);
        iconColor = const Color(0xFF6B7280);
        icon = Icons.access_time_rounded;
        title = eventType;
        subtitle = "Attendance activity";
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
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
              color: backgroundColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),

          const SizedBox(width: 14),

          // TITLE
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF1F2937),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // TIME
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                eventTime,
                style: TextStyle(
                  color: iconColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 3),

              const Text(
                "Today",
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColumn(String title, String value) {
    return Column(
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withOpacity(.70), fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildActionCircle({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        height: 125,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: colors.first.withOpacity(.20),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.20),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: Colors.white, size: 23),
            ),

            const Spacer(),

            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 3),

            Text(
              subtitle,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          SizedBox(
            height: 240,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // HEADER
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(
                    top: 40,
                    left: 20,
                    right: 20,
                    bottom: 80,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        // Color.fromARGB(255, 238, 83, 60),
                        // Color.fromARGB(255, 230, 61, 39),
                        Color(0xFF2563EB),
                        Color(0xFF60A5FA),
                      ],
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(35),
                      bottomRight: Radius.circular(35),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // PROFILE
                      Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: const CircleAvatar(
                          backgroundColor: Colors.white,
                          child: Icon(
                            Icons.person,
                            size: 32,
                            color: Colors.deepOrange,
                          ),
                        ),
                      ),

                      const SizedBox(width: 22),

                      // GREETING
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Hi, Raje 👋",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 22,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              "Have a productive day",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 17,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // NOTIFICATION
                      // Container(
                      //   width: 50,
                      //   height: 50,
                      //   decoration: BoxDecoration(
                      //     color: Colors.white.withOpacity(.18),
                      //     borderRadius: BorderRadius.circular(16),
                      //   ),
                      //   child: const Icon(
                      //     Icons.notifications_none_rounded,
                      //     color: Colors.white,
                      //     size: 27,
                      //   ),
                      // ),
                    ],
                  ),
                ),

                // ATTENDANCE CARD
                Positioned(
                  top: 130,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          //Color.fromARGB(255, 175, 199, 227),
                          // Color.fromARGB(255, 181, 212, 247),
                          //   Color.fromARGB(255, 219, 107, 120),
                          //  Color.fromARGB(255, 212, 120, 134),
                          Color.fromARGB(255, 216, 92, 73),
                          Color.fromARGB(255, 211, 75, 57),
                          // Color(0xFF2563EB),
                          //  Color(0xFF60A5FA),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xffFF7043).withOpacity(.30),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // STATUS
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(40),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 4,
                                    backgroundColor: isClockedIn
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isClockedIn ? "Present" : "Absent",
                                    style: TextStyle(
                                      color: isClockedIn
                                          ? Colors.green
                                          : Colors.red,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // TIME + GOAL
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(17),
                                    ),
                                    child: const Icon(
                                      Icons.access_time,
                                      color: Color(0xff6A38F5),
                                      size: 27,
                                    ),
                                  ),

                                  const SizedBox(width: 12),

                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        formatDuration(elapsed),
                                        style: const TextStyle(
                                          fontSize: 21,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),

                                      const SizedBox(height: 4),

                                      Text(
                                        "Today's Work Time",
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(.70),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // GOAL
                            SizedBox(
                              width: 48,
                              height: 48,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: CircularProgressIndicator(
                                      value: elapsed.inHours / 8 > 1
                                          ? 1
                                          : elapsed.inHours / 8,
                                      strokeWidth: 6,
                                      backgroundColor: Colors.white24,
                                      valueColor: const AlwaysStoppedAnimation(
                                        Colors.white,
                                      ),
                                    ),
                                  ),

                                  const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        "Goal",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                        ),
                                      ),
                                      Text(
                                        "8h",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // DETAILS
                        Row(
                          children: [
                            Expanded(
                              child: _buildColumn("Worked Hrs", workingHours),
                            ),

                            Container(
                              width: 1,
                              height: 40,
                              color: Colors.white24,
                            ),

                            Expanded(
                              child: _buildColumn(
                                "Status",
                                isClockedIn ? "Working" : "Not Started",
                              ),
                            ),

                            Container(
                              width: 1,
                              height: 40,
                              color: Colors.white24,
                            ),

                            Expanded(child: _buildColumn("Break", "00:00")),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 100),

          // ACTION BUTTONS + HISTORY
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        // CLOCK IN / OUT
                        Expanded(
                          child: _buildActionCircle(
                            title: isClockedIn ? "Clock Out" : "Clock In",
                            subtitle: isClockedIn
                                ? "Finish Work"
                                : "Start Work",
                            icon: isClockedIn
                                ? Icons.logout_rounded
                                : Icons.login_rounded,
                            colors: isClockedIn
                                ? const [
                                    Color(0xFF2563EB),
                                    Color(0xFF60A5FA),
                                  ] // Clock Out
                                : const [Color(0xFFEF4444), Color(0xFFFCA5A5)],
                            onTap: () {
                              if (isClockedIn) {
                                handlePunchOut();
                              } else {
                                handlePunchIn();
                              }
                            },
                          ),
                        ),

                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(.08),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              "OR",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Opacity(
                            opacity: isClockedIn ? 1 : .45,
                            child: IgnorePointer(
                              ignoring: !isClockedIn,
                              child: _buildActionCircle(
                                title: isOnBreak ? "Break Out" : "Break In",

                                subtitle: isOnBreak
                                    ? "Resume Work"
                                    : "Take Break",

                                icon: isOnBreak
                                    ? Icons.play_arrow_rounded
                                    : Icons.free_breakfast_rounded,

                                colors: isOnBreak
                                    ? const [
                                        Color(0xFFF59E0B),
                                        Color(0xFFFCD34D),
                                      ]
                                    : const [
                                        Color(0xFF10B981),
                                        Color(0xFF6EE7B7),
                                      ],

                                onTap: () {
                                  if (isOnBreak) {
                                    handleBreakOut();
                                  } else {
                                    handleBreakIn();
                                  }
                                },
                              ),
                            ),
                          ),
                        ),

                        // BREAK
                        // Expanded(
                        //   child: Opacity(
                        //     opacity: isClockedIn ? 1 : .45,
                        //     child: IgnorePointer(
                        //       ignoring: !isClockedIn,
                        //       child: _buildActionCircle(
                        //         title: "Break In",
                        //         subtitle: "Take Break",
                        //         icon: Icons.free_breakfast_rounded,
                        //         colors: const [
                        //           Color.fromARGB(255, 224, 124, 9),
                        //           Color(0xFFFDBA74),
                        //         ],
                        //         onTap: () {
                        //           // Break functionality here
                        //         },
                        //       ),
                        //     ),
                        //   ),
                        // ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  const Divider(),

                  // HISTORY HEADER
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        const Text(
                          "Today's History",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const Spacer(),

                        InkWell(
                          borderRadius: BorderRadius.circular(30),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const EmployeeAttendanceScreen(),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4A90E2).withOpacity(.08),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.history,
                                  size: 18,
                                  color: Color(0xFF4A90E2),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  "View All",
                                  style: TextStyle(
                                    color: Color(0xFF4A90E2),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  const SizedBox(height: 10),

                  // TODAY'S FIREBASE HISTORY
                  // TODAY'S HISTORY
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: isLoadingHistory
                        ? const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF4F46E5),
                              ),
                            ),
                          )
                        : history.isEmpty
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE0E7FF),
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: const Icon(
                                    Icons.access_time_rounded,
                                    color: Color(0xFF4F46E5),
                                  ),
                                ),

                                const SizedBox(width: 14),

                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "No attendance records",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),

                                    const SizedBox(height: 4),

                                    Text(
                                      "No punch activity recorded today",
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          )
                        : Column(
                            children: history.map((item) {
                              final String type =
                                  item["type"]?.toString() ?? "";

                              final DateTime time = item["time"] as DateTime;

                              final bool isIn = type == "IN";

                              final String formattedTime =
                                  TimeOfDay.fromDateTime(time).format(context);

                              return Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(15),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: isIn
                                            ? const Color(0xFFE0F2FE)
                                            : const Color(0xFFFFE4E6),
                                        borderRadius: BorderRadius.circular(13),
                                      ),
                                      child: Icon(
                                        isIn
                                            ? Icons.login_rounded
                                            : Icons.logout_rounded,
                                        color: isIn
                                            ? const Color(0xFF0284C7)
                                            : const Color(0xFFE11D48),
                                      ),
                                    ),

                                    const SizedBox(width: 14),

                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isIn ? "Clock In" : "Clock Out",
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),

                                          const SizedBox(height: 4),

                                          Text(
                                            isIn
                                                ? "Started working"
                                                : "Finished working",
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    Text(
                                      formattedTime,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF374151),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

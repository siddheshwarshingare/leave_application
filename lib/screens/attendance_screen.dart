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
  String name = "";
  @override
  void initState() {
    super.initState();
    //  loadAttendance();
    loadTodayHistory();
    getUserData();
  }

  getUserData() async {
    String uid = FirebaseAuth.instance.currentUser!.uid;

    DocumentSnapshot user = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    setState(() {
      name = user['name'];
      // role = user['role'];
      // email = user['email'];
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) {
      return "Good morning";
    } else if (hour < 17) {
      return "Good afternoon";
    } else if (hour < 21) {
      return "Good evening";
    } else {
      return "Good night";
    }
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
      // if (snapshot.docs.isEmpty) {
      //   if (!mounted) return;

      //   setState(() {
      //     history = [];
      //     _todayPunches = [];
      //     elapsed = Duration.zero;
      //     workingHours = "0h 0m";
      //     isClockedIn = false;
      //     isOnBreak = false;
      //     isLoadingHistory = false;
      //   });

      //   timer?.cancel();
      //   return;
      // }
      final attendanceDocId = "${user.uid}_$date";

      final attendanceRef = FirebaseFirestore.instance
          .collection("attendance")
          .doc(attendanceDocId);

      final attendanceDoc = await attendanceRef.get();

      if (!attendanceDoc.exists) {
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
      // final attendanceDoc = snapshot.docs.first;

      // ----------------------------------------------------------
      // GET TODAY'S PUNCHES
      // ----------------------------------------------------------
      // final punchesSnapshot = await FirebaseFirestore.instance
      //     .collection("attendance")
      //     .doc(attendanceDoc.id)
      //     .collection("punches")
      //     .orderBy("time")
      //     .get();
      final punchesSnapshot = await attendanceRef
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

      //  startTimer();

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

      //  startTimer();

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

  Widget _attendanceAction({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool disabled = false,
    bool showLoading = false,
  }) {
    return Opacity(
      opacity: disabled ? .45 : 1,

      child: IgnorePointer(
        ignoring: disabled,

        child: InkWell(
          borderRadius: BorderRadius.circular(20),

          onTap: isProcessing ? null : onTap,

          child: Container(
            height: 105,

            padding: const EdgeInsets.all(15),

            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),

              border: Border.all(color: const Color(0xFFE2E8F0)),

              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.035),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),

            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,

                  decoration: BoxDecoration(
                    color: color.withOpacity(.10),
                    borderRadius: BorderRadius.circular(15),
                  ),

                  child: showLoading
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                        )
                      : Icon(icon, color: color, size: 24),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    mainAxisAlignment: MainAxisAlignment.center,

                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),

                Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color),
              ],
            ),
          ),
        ),
      ),
    );
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

  Widget _buildAttendanceInfo({
    required String value,
    required String title,
    required IconData icon,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 17),

            const SizedBox(width: 5),

            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 4),

        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildModernActionButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color firstColor,
    required Color secondColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(25),

      child: Container(
        height: 135,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),

          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [firstColor, secondColor],
          ),

          boxShadow: [
            BoxShadow(
              color: secondColor.withOpacity(.20),
              blurRadius: 15,
              offset: const Offset(0, 7),
            ),
          ],
        ),

        child: Stack(
          children: [
            // Decorative circle
            Positioned(
              right: -25,
              bottom: -35,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.10),
                  shape: BoxShape.circle,
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.20),
                      borderRadius: BorderRadius.circular(15),
                    ),

                    child: Icon(icon, color: Colors.white, size: 27),
                  ),

                  const Spacer(),

                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(.80),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Arrow
            const Positioned(
              right: 15,
              bottom: 20,
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white,
                size: 17,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyHistory() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.035),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),

      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFF0E9FF),
              borderRadius: BorderRadius.circular(16),
            ),

            child: const Icon(
              Icons.access_time_rounded,
              color: Color(0xFF6D28D9),
              size: 28,
            ),
          ),

          const SizedBox(width: 15),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "No attendance records",
                  style: TextStyle(
                    color: Color(0xFF17133A),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                SizedBox(height: 5),

                Text(
                  "No punch activity recorded today",
                  style: TextStyle(color: Color(0xFF8A8FA3), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _modernInfo(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 16),

        const SizedBox(height: 5),

        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,

          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 2),

        Text(
          title,
          style: const TextStyle(color: Colors.white60, fontSize: 10),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 19, color: const Color(0xFF4F46E5)),

        const SizedBox(width: 7),

        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _modernHistoryItem(String type, String time) {
    IconData icon;
    Color color;
    Color background;
    String title;
    String subtitle;

    switch (type) {
      case "IN":
        icon = Icons.login_rounded;
        color = const Color(0xFF10B981);
        background = const Color(0xFFECFDF5);
        title = "Clock In";
        subtitle = "Started working";
        break;

      case "OUT":
        icon = Icons.logout_rounded;
        color = const Color(0xFFEF4444);
        background = const Color(0xFFFEF2F2);
        title = "Clock Out";
        subtitle = "Finished working";
        break;

      case "BREAK_IN":
        icon = Icons.coffee_rounded;
        color = const Color(0xFFF59E0B);
        background = const Color(0xFFFFFBEB);
        title = "Break Started";
        subtitle = "You are currently on break";
        break;

      case "BREAK_OUT":
        icon = Icons.play_arrow_rounded;
        color = const Color(0xFF3B82F6);
        background = const Color(0xFFEFF6FF);
        title = "Break Ended";
        subtitle = "Work resumed";
        break;

      default:
        icon = Icons.access_time_rounded;
        color = const Color(0xFF64748B);
        background = const Color(0xFFF1F5F9);
        title = type;
        subtitle = "Attendance activity";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),

      padding: const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),

        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),

      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,

            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(14),
            ),

            child: Icon(icon, color: color, size: 22),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
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
                time,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 4),

              const Text(
                "Today",
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernEmptyHistory() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(22),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),

        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),

      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,

            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(18),
            ),

            child: const Icon(
              Icons.access_time_rounded,
              color: Color(0xFF4F46E5),
              size: 28,
            ),
          ),

          const SizedBox(height: 12),

          const Text(
            "No activity yet",
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 5),

          const Text(
            "Your attendance activity will appear here.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _formatToday() {
    final now = DateTime.now();

    const months = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December",
    ];

    return "${months[now.month - 1]} ${now.day}, ${now.year}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),

          padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              // ============================================================
              // HEADER
              // ============================================================
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,

                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E7FF),
                      borderRadius: BorderRadius.circular(16),
                    ),

                    child: const Icon(
                      Icons.person_rounded,
                      color: Color(0xFF4F46E5),
                      size: 28,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Text(
                        //   "Good morning, Raje 👋",
                        //   style: TextStyle(
                        //     fontSize: 19,
                        //     fontWeight: FontWeight.w800,
                        //     color: Color(0xFF0F172A),
                        //   ),
                        // ),
                        Text(
                          "${_getGreeting()} ${name.isEmpty ? "Employee" : name} ,👋",
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        // Text(
                        //   name.isEmpty ? "Employee" : name,
                        //   maxLines: 1,
                        //   overflow: TextOverflow.ellipsis,
                        //   style: const TextStyle(
                        //     color: Colors.white,
                        //     fontSize: 23,
                        //     fontWeight: FontWeight.w800,
                        //   ),
                        // ),
                        SizedBox(height: 4),

                        Text(
                          "Manage your attendance",
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    width: 44,
                    height: 44,

                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),

                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),

                    child: const Icon(
                      Icons.notifications_none_rounded,
                      color: Color(0xFF334155),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              // ============================================================
              // TODAY DATE
              // ============================================================
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 16,
                    color: Color(0xFF6366F1),
                  ),

                  const SizedBox(width: 7),

                  Text(
                    _formatToday(),
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ============================================================
              // MAIN ATTENDANCE CARD
              // ============================================================
              Container(
                width: double.infinity,

                padding: const EdgeInsets.all(20),

                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5),
                  borderRadius: BorderRadius.circular(28),

                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4F46E5).withOpacity(.20),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
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
                            horizontal: 12,
                            vertical: 7,
                          ),

                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.15),
                            borderRadius: BorderRadius.circular(30),
                          ),

                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,

                                decoration: BoxDecoration(
                                  color: isClockedIn
                                      ? const Color(0xFF34D399)
                                      : const Color(0xFFF87171),
                                  shape: BoxShape.circle,
                                ),
                              ),

                              const SizedBox(width: 7),

                              Text(
                                isClockedIn
                                    ? (isOnBreak ? "On Break" : "Working")
                                    : "Not Clocked In",

                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Spacer(),

                        const Icon(
                          Icons.more_horiz_rounded,
                          color: Colors.white70,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // WORK TIME
                    const Text(
                      "TODAY'S WORK TIME",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),

                    const SizedBox(height: 7),

                    Text(
                      formatDuration(elapsed),

                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),

                    const SizedBox(height: 18),

                    // PROGRESS
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),

                      child: LinearProgressIndicator(
                        minHeight: 7,

                        value: (elapsed.inMinutes / (8 * 60)).clamp(0.0, 1.0),

                        backgroundColor: Colors.white.withOpacity(.15),

                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF34D399),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,

                      children: [
                        const Text(
                          "Daily target",
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),

                        const Text(
                          "8h 00m",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    // INFO
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),

                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.10),
                        borderRadius: BorderRadius.circular(18),
                      ),

                      child: Row(
                        children: [
                          Expanded(
                            child: _modernInfo(
                              "Worked",
                              workingHours,
                              Icons.access_time_rounded,
                            ),
                          ),

                          Container(
                            width: 1,
                            height: 32,
                            color: Colors.white24,
                          ),

                          Expanded(
                            child: _modernInfo(
                              "Status",
                              isClockedIn
                                  ? (isOnBreak ? "Break" : "Working")
                                  : "Not Started",
                              Icons.work_outline_rounded,
                            ),
                          ),

                          Container(
                            width: 1,
                            height: 32,
                            color: Colors.white24,
                          ),

                          Expanded(
                            child: _modernInfo(
                              "Goal",
                              "8 Hours",
                              Icons.flag_outlined,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ============================================================
              // ACTION BUTTONS
              // ============================================================
              Row(
                children: [
                  Expanded(
                    child: _attendanceAction(
                      title: isClockedIn ? "Clock Out" : "Clock In",

                      subtitle: isProcessing
                          ? "Please wait..."
                          : isClockedIn
                          ? "Finish your work"
                          : "Start your work",

                      icon: isClockedIn
                          ? Icons.logout_rounded
                          : Icons.login_rounded,

                      color: isClockedIn
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF10B981),
                      showLoading: isProcessing,
                      onTap: isClockedIn ? handlePunchOut : handlePunchIn,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: _attendanceAction(
                      title: isOnBreak ? "End Break" : "Take Break",

                      subtitle: isOnBreak ? "Resume working" : "Take some rest",

                      icon: isOnBreak
                          ? Icons.play_arrow_rounded
                          : Icons.coffee_rounded,

                      color: const Color(0xFFF59E0B),

                      disabled: !isClockedIn,

                      onTap: isOnBreak ? handleBreakOut : handleBreakIn,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ============================================================
              // LOCATION CARD
              // ============================================================
              _sectionTitle("Work Location", Icons.location_on_outlined),

              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.all(16),

                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),

                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),

                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,

                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(15),
                      ),

                      child: const Icon(
                        Icons.location_on_rounded,
                        color: Color(0xFF10B981),
                      ),
                    ),

                    const SizedBox(width: 13),

                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          Text(
                            "Office Location",
                            style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),

                          SizedBox(height: 4),

                          Text(
                            "Your current location is verified",
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),

                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(20),
                      ),

                      child: const Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: Color(0xFF10B981),
                          ),

                          SizedBox(width: 4),

                          Text(
                            "Verified",
                            style: TextStyle(
                              color: Color(0xFF059669),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ============================================================
              // HISTORY HEADER
              // ============================================================
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Today's Activity",
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),

                  InkWell(
                    borderRadius: BorderRadius.circular(20),

                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EmployeeAttendanceScreen(),
                        ),
                      );
                    },

                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),

                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(20),
                      ),

                      child: const Row(
                        children: [
                          Text(
                            "View All",
                            style: TextStyle(
                              color: Color(0xFF4F46E5),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),

                          SizedBox(width: 5),

                          Icon(
                            Icons.arrow_forward_rounded,
                            color: Color(0xFF4F46E5),
                            size: 15,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ============================================================
              // HISTORY
              // ============================================================
              if (isLoadingHistory)
                const Padding(
                  padding: EdgeInsets.all(30),

                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
                  ),
                )
              else if (history.isEmpty)
                _buildModernEmptyHistory()
              else
                Column(
                  children: history.map((item) {
                    final String type = item["type"]?.toString() ?? "";

                    final DateTime time = item["time"] as DateTime;

                    final formattedTime = TimeOfDay.fromDateTime(
                      time,
                    ).format(context);

                    return _modernHistoryItem(type, formattedTime);
                  }).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

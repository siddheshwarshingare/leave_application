import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:leave_application/screens/attendance_screen.dart';
import 'package:leave_application/screens/employee_attedance_screen.dart';
import 'package:leave_application/screens/leave_history_screen.dart';
import 'package:leave_application/screens/leave_screen.dart';
import 'package:leave_application/screens/notification.dart';
import 'package:leave_application/screens/profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String name = "";
  String role = "";
  String email = "";
  double totalLeave = 0;
  double usedLeave = 0;
  double clLeave = 3;
  double slLeave = 10;
  double remainingLeave = 0;

  @override
  void initState() {
    super.initState();
    getUserData();
    getLeaveData();
    markAllRead();
  }

  Widget _holidayList() {
    final List<Map<String, String>> holidays = [
      {'date': '01-Jan-2026', 'day': 'Thu', 'holiday': 'New Year'},
      {'date': '26-Jan-2026', 'day': 'Mon', 'holiday': 'Republic Day'},
      {'date': '19-Mar-2026', 'day': 'Thu', 'holiday': 'Gudi Padwa'},
      {
        'date': '01-May-2026',
        'day': 'Fri',
        'holiday': 'Labour Day / Maharashtra Day',
      },
      {'date': '15-Aug-2026', 'day': 'Sat', 'holiday': 'Independence Day'},
      {'date': '28-Aug-2026', 'day': 'Fri', 'holiday': 'Rakshabandhan'},
      {'date': '14-Sep-2026', 'day': 'Mon', 'holiday': 'Ganesh Chaturthi'},
      {'date': '20-Oct-2026', 'day': 'Tue', 'holiday': 'Dussehra'},
      {'date': '08-Nov-2026', 'day': 'Sun', 'holiday': 'Diwali – Laxmi Poojan'},
      {'date': '10-Nov-2026', 'day': 'Tue', 'holiday': 'Diwali – Padwa'},
      {'date': '25-Dec-2026', 'day': 'Fri', 'holiday': 'Christmas'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Holidays",
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: Color(0xFF172033),
          ),
        ),

        const SizedBox(height: 4),

        const Text(
          "Upcoming holidays",
          style: TextStyle(fontSize: 12, color: Color(0xFF8A93A5)),
        ),

        const SizedBox(height: 14),

        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE9ECF2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.035),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: holidays.length,
            separatorBuilder: (context, index) {
              return const Divider(height: 1, color: Color(0xFFE9ECF2));
            },
            itemBuilder: (context, index) {
              final holiday = holidays[index];

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    // DATE BOX
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0E9FF),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            holiday['date']!.substring(0, 2),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF7034E6),
                            ),
                          ),
                          Text(
                            holiday['date']!.substring(3, 6),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF8B5CF6),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 13),

                    // HOLIDAY NAME
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            holiday['holiday']!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF172033),
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            "${holiday['day']} • ${holiday['date']}",
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF8A93A5),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // HOLIDAY ICON
                    Container(
                      height: 34,
                      width: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.celebration_rounded,
                        size: 18,
                        color: Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> showPunchDetails(
    BuildContext context,
    String attendanceId,
  ) async {
    QuerySnapshot snap = await FirebaseFirestore.instance
        .collection('attendance')
        .doc(attendanceId)
        .collection('punches')
        .orderBy('time')
        .get();

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Attendance Details"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: snap.docs.length,
              itemBuilder: (_, index) {
                var punch = snap.docs[index];

                DateTime time = (punch['time'] as Timestamp).toDate();

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: punch['type'] == "IN"
                        ? Colors.green
                        : Colors.red,
                    child: Icon(
                      punch['type'] == "IN" ? Icons.login : Icons.logout,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(punch['type'] == "IN" ? "Punch In" : "Punch Out"),
                  subtitle: Text(time.toString()),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> getLeaveData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) return;

      final String uid = user.uid;

      // ============================================================
      // 1. GET CURRENT LEAVE BALANCE FROM FIRESTORE
      // ============================================================

      final DocumentSnapshot leaveDoc = await FirebaseFirestore.instance
          .collection('toatl_leave')
          .doc(uid)
          .get();

      if (!leaveDoc.exists) {
        print("Leave document not found");
        return;
      }

      final data = leaveDoc.data() as Map<String, dynamic>;

      // Firestore stores these as Strings:
      // Cl = "1"
      // Sl = "6.5"

      final double cl = double.tryParse(data['Cl']?.toString() ?? '0') ?? 0.0;

      final double sl = double.tryParse(data['Sl']?.toString() ?? '0') ?? 0.0;

      // Current remaining balance
      final double total = cl + sl;

      // ============================================================
      // 2. GET APPROVED LEAVES
      // ============================================================

      final QuerySnapshot snap = await FirebaseFirestore.instance
          .collection('leave_requests')
          .where('uid', isEqualTo: uid)
          .where('status', isEqualTo: 'Approved')
          .get();

      double used = 0.0;

      for (final doc in snap.docs) {
        final value = doc['days'];

        if (value is num) {
          used += value.toDouble();
        } else {
          used += double.tryParse(value.toString()) ?? 0.0;
        }
      }

      // ============================================================
      // 3. UPDATE UI
      // ============================================================

      if (!mounted) return;

      setState(() {
        clLeave = cl;
        slLeave = sl;

        totalLeave = total;

        usedLeave = used;

        // IMPORTANT:
        // If Cl + Sl represents CURRENT remaining balance,
        // don't subtract used again.
        remainingLeave = total;
      });

      print("CL = $cl");
      print("SL = $sl");
      print("Current Balance = $total");
      print("Approved Used = $used");
      print("Remaining = $total");
    } catch (e) {
      print("ERROR: $e");
    }
  }

  Widget actionCard({
    required IconData icon,
    required String title,
    required Color iconColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          height: 115,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),

              const Spacer(),

              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> markAllRead() async {
    String uid = FirebaseAuth.instance.currentUser!.uid;

    QuerySnapshot snap = await FirebaseFirestore.instance
        .collection('notifications')
        .where('uid', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in snap.docs) {
      await doc.reference.update({"isRead": true});
    }
  }

  getUserData() async {
    String uid = FirebaseAuth.instance.currentUser!.uid;

    DocumentSnapshot user = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    setState(() {
      name = user['name'];
      role = user['role'];
      email = user['email'];
    });
  }

  logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.clear();

    await FirebaseAuth.instance.signOut();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Widget quickActionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: colors.first.withOpacity(0.18),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Container(
            height: 155,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: const Color(0xff374151), size: 23),
                ),

                const Spacer(),

                // Title
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xff1F2937),
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 3),

                // Subtitle
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xff4B5563),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const Spacer(),

                // Arrow
                Align(
                  alignment: Alignment.bottomRight,
                  child: Container(
                    height: 30,
                    width: 30,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Color(0xff374151),
                      size: 17,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget leaveCard({
    required String title,
    required String value,
    required Color startColor,
    required Color endColor,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        height: 110,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [startColor, endColor],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: startColor.withOpacity(0.20),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 29,
              height: 29,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.45),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xff374151), size: 18),
            ),

            const Spacer(),

            // Value
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                color: Color(0xff1F2937),
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 2),

            // Title
            Text(
              title,
              style: const TextStyle(
                color: Color(0xff4B5563),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modernLeaveCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        height: 125,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE9ECF2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.035),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 36,
              width: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(.10),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: color, size: 19),
            ),

            const Spacer(),

            Text(
              value,
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),

            const SizedBox(height: 2),

            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modernActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Ink(
          height: 145,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE9ECF2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.035),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 23),
              ),

              const Spacer(),

              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF172033),
                ),
              ),

              const SizedBox(height: 4),

              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF8A93A5),
                  fontWeight: FontWeight.w500,
                ),
              ),

              const Spacer(),

              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  height: 28,
                  width: 28,
                  decoration: BoxDecoration(
                    color: color.withOpacity(.08),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _logoutDialog(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.12),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 58,
              width: 58,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: Color(0xFFDC2626),
                size: 27,
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              "Logout?",
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: Color(0xFF172033),
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              "Are you sure you want to logout from your account?",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Color(0xFF6B7280),
              ),
            ),

            const SizedBox(height: 22),

            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context, false);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF374151),
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context, true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      child: const Text(
                        "Logout",
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFFF8FAFC),
      width: MediaQuery.of(context).size.width * 0.80,

      child: SafeArea(
        child: Column(
          children: [
            // ======================================================
            // USER PROFILE HEADER
            // ======================================================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF7034E6), Color(0xFF8B4DE8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // PROFILE AVATAR
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(.12),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          color: Color(0xFF7C3AED),
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // NAME
                  Text(
                    name.isEmpty ? 'Employee' : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 5),

                  // ROLE
                  Text(
                    role.isEmpty ? 'Employee' : role,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // EMAIL
                  Row(
                    children: [
                      const Icon(
                        Icons.email_outlined,
                        color: Colors.white70,
                        size: 15,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          email.isEmpty ? 'No email' : email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ======================================================
            // DASHBOARD
            // ======================================================
            _drawerItem(
              context,
              icon: Icons.dashboard_outlined,
              title: 'Dashboard',
              onTap: () {
                Navigator.pop(context);
              },
            ),

            // ======================================================
            // PROFILE
            // ======================================================
            _drawerItem(
              context,
              icon: Icons.person_outline_rounded,
              title: 'My Profile',
              onTap: () {
                Navigator.pop(context);

                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
            ),

            // ======================================================
            // ATTENDANCE
            // ======================================================
            _drawerItem(
              context,
              icon: Icons.access_time_outlined,
              title: 'Attendance',
              onTap: () {
                Navigator.pop(context);

                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AttendanceScreen()),
                );
              },
            ),

            // ======================================================
            // MY ATTENDANCE
            // ======================================================
            _drawerItem(
              context,
              icon: Icons.history_rounded,
              title: 'My Attendance',
              onTap: () {
                Navigator.pop(context);

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const EmployeeAttendanceScreen(),
                  ),
                );
              },
            ),

            // ======================================================
            // APPLY LEAVE
            // ======================================================
            _drawerItem(
              context,
              icon: Icons.edit_calendar_outlined,
              title: 'Apply Leave',
              onTap: () {
                Navigator.pop(context);

                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ApplyLeaveScreen()),
                );
              },
            ),

            // ======================================================
            // LEAVE HISTORY
            // ======================================================
            _drawerItem(
              context,
              icon: Icons.event_available_outlined,
              title: 'My Leaves',
              onTap: () {
                Navigator.pop(context);

                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LeaveHistoryScreen()),
                );
              },
            ),

            // ======================================================
            // NOTIFICATIONS
            // ======================================================
            _drawerItem(
              context,
              icon: Icons.notifications_none_rounded,
              title: 'Notifications',
              onTap: () async {
                Navigator.pop(context);

                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationScreen()),
                );

                if (mounted) {
                  setState(() {});
                }
              },
            ),

            const Spacer(),

            // ======================================================
            // DIVIDER
            // ======================================================
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(height: 1, color: Color(0xFFE5E7EB)),
            ),

            const SizedBox(height: 6),

            // ======================================================
            // LOGOUT
            // ======================================================
            _drawerItem(
              context,
              icon: Icons.logout_rounded,
              title: 'Logout',
              color: const Color(0xFFDC2626),
              onTap: () async {
                Navigator.pop(context);

                bool? shouldLogout = await showDialog<bool>(
                  context: context,
                  barrierDismissible: true,
                  builder: (context) {
                    return _logoutDialog(context);
                  },
                );

                if (shouldLogout == true) {
                  await logout();
                }
              },
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color color = const Color(0xFF334155),
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(icon, size: 21, color: color),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        trailing: title == 'Dashboard'
            ? const Icon(
                Icons.chevron_right_rounded,
                size: 19,
                color: Color(0xFF94A3B8),
              )
            : null,
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();

      if (!context.mounted) return;

      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logout failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  // ================================================================
  // REFERENCE UI COLORS
  // ================================================================

  static const Color _navy = Color(0xFF102A56);
  static const Color _navyDark = Color(0xFF0B2348);
  static const Color _orange = Color(0xFFFF6B1A);
  static const Color _green = Color(0xFF18A96B);
  static const Color _blue = Color(0xFF2674D9);
  static const Color _purple = Color(0xFF7546D8);
  static const Color _textDark = Color(0xFF172033);
  static const Color _textGrey = Color(0xFF7B8494);
  static const Color _background = Color(0xFFF8F9FC);

  // ================================================================
  // ENQUAD LOGO
  // ================================================================

  Widget _enquadLogo() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 30,
          width: 30,
          decoration: BoxDecoration(
            color: _orange,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.hexagon_rounded,
            color: Colors.white,
            size: 21,
          ),
        ),

        const SizedBox(width: 8),

        const Text(
          "Enquad",
          style: TextStyle(
            color: _textDark,
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: -.3,
          ),
        ),
      ],
    );
  }

  // ================================================================
  // PROFILE AVATAR
  // ================================================================

  Widget _profileAvatar({double size = 44}) {
    final initial = name.isNotEmpty ? name.trim()[0].toUpperCase() : "U";

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        );
      },
      child: Container(
        height: size,
        width: size,
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: CircleAvatar(
          backgroundColor: const Color(0xFFE9EEF7),
          child: Text(
            initial,
            style: TextStyle(
              color: _navy,
              fontSize: size * .40,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  // ================================================================
  // WELCOME CARD
  // ================================================================

  Widget _welcomeCard() {
    return Container(
      width: double.infinity,
      height: 158,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF102A56), Color(0xFF173867)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.12),
            blurRadius: 15,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            right: 130,
            top: -25,
            child: Container(
              height: 70,
              width: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _orange.withOpacity(.55), width: 1),
              ),
            ),
          ),

          Positioned(
            right: 70,
            bottom: -35,
            child: Container(
              height: 80,
              width: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _orange.withOpacity(.45), width: 1),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Welcome back, 👋",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        name.isEmpty ? "Employee" : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 7),

                      const Text(
                        "Have a great day at work!",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // Large profile circle
                Container(
                  height: 91,
                  width: 91,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(.15),
                    border: Border.all(
                      color: Colors.white.withOpacity(.8),
                      width: 2,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _orange,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : "M",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // SECTION HEADER
  // ================================================================

  Widget _sectionHeader({
    required String title,
    required String subtitle,
    VoidCallback? onViewAll,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  color: _textDark,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .2,
                ),
              ),

              const SizedBox(height: 3),

              Text(
                subtitle,
                style: const TextStyle(
                  color: _textGrey,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        if (onViewAll != null)
          GestureDetector(
            onTap: onViewAll,
            child: const Row(
              children: [
                Text(
                  "View All",
                  style: TextStyle(
                    color: _orange,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded, color: _orange, size: 15),
              ],
            ),
          ),
      ],
    );
  }

  // ================================================================
  // LEAVE CARD
  // ================================================================

  Widget _referenceLeaveCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        height: 143,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFFE9ECF2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.035),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 38,
              width: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 21),
            ),

            const Spacer(),

            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 1),

            Text(
              title,
              style: const TextStyle(
                color: _textDark,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 1),

            Text(
              subtitle,
              style: const TextStyle(
                color: _textGrey,
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // QUICK ACTION CARD
  // ================================================================

  Widget _referenceActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Ink(
            height: 67,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: const Color(0xFFE9ECF2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.025),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(13),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                Container(
                  height: 38,
                  width: 38,
                  decoration: BoxDecoration(
                    color: color.withOpacity(.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 21),
                ),

                const SizedBox(width: 9),

                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _textDark,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _textGrey,
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  margin: const EdgeInsets.only(right: 8),
                  height: 27,
                  width: 27,
                  decoration: BoxDecoration(
                    color: color.withOpacity(.09),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: color,
                    size: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================================================================
  // UPCOMING HOLIDAYS
  // ================================================================

  Widget _holidaysSection() {
    final holidays = [
      ["15", "AUG", "Independence Day", "Friday"],
      ["05", "SEP", "Teacher's Day", "Friday"],
      ["02", "OCT", "Gandhi Jayanti", "Thursday"],
      ["31", "OCT", "Diwali", "Friday"],
      ["25", "DEC", "Christmas Day", "Thursday"],
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9ECF2)),
      ),
      child: Column(
        children: List.generate(holidays.length, (index) {
          final holiday = holidays[index];

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3EC),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            holiday[0],
                            style: const TextStyle(
                              color: _orange,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),

                          Text(
                            holiday[1],
                            style: const TextStyle(
                              color: _orange,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            holiday[2],
                            style: const TextStyle(
                              color: _textDark,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),

                          const SizedBox(height: 2),

                          Text(
                            holiday[3],
                            style: const TextStyle(
                              color: _textGrey,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Icon(
                      Icons.calendar_month_outlined,
                      color: _orange,
                      size: 18,
                    ),
                  ],
                ),
              ),

              if (index != holidays.length - 1)
                const Divider(
                  height: 1,
                  indent: 10,
                  endIndent: 10,
                  color: Color(0xFFF0F1F4),
                ),
            ],
          );
        }),
      ),
    );
  }

  // ================================================================
  // BOTTOM NAVIGATION
  // ================================================================

  Widget _bottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.08),
            blurRadius: 18,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(
            children: [
              _bottomNavItem(
                icon: Icons.home_rounded,
                label: "Home",
                selected: true,
                onTap: () {},
              ),

              _bottomNavItem(
                icon: Icons.description_outlined,
                label: "Leaves",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LeaveHistoryScreen(),
                    ),
                  );
                },
              ),

              _bottomNavItem(
                icon: Icons.access_time_outlined,
                label: "Attendance",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EmployeeAttendanceScreen(),
                    ),
                  );
                },
              ),

              _bottomNavItem(
                icon: Icons.person_outline_rounded,
                label: "Profile",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomNavItem({
    required IconData icon,
    required String label,
    bool selected = false,
    required VoidCallback onTap,
  }) {
    final color = selected ? _orange : const Color(0xFF687284);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: color),

            const SizedBox(height: 4),

            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),

            const SizedBox(height: 3),

            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 2,
              width: selected ? 35 : 0,
              decoration: BoxDecoration(
                color: _orange,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),

          title: const Text(
            'Logout',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF172033),
            ),
          ),

          content: const Text(
            'Are you sure you want to logout?',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ),

            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);

                await _logout(context);
              },
              child: const Text(
                'Logout',
                style: TextStyle(
                  color: Color(0xFFDC2626),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,

      // ============================================================
      // DRAWER
      // ============================================================
      drawer: _buildDrawer(context),

      // ============================================================
      // TOP BAR
      // ============================================================
      appBar: AppBar(
        backgroundColor: _background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,

        leadingWidth: 55,

        leading: Builder(
          builder: (context) {
            return IconButton(
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
              icon: const Icon(Icons.menu_rounded, color: _textDark, size: 25),
            );
          },
        ),

        title: _enquadLogo(),

        centerTitle: false,

        actions: [
          // Notification
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationScreen(),
                    ),
                  );

                  if (mounted) {
                    setState(() {});
                  }
                },
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: _textDark,
                  size: 25,
                ),
              ),

              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('notifications')
                    .where(
                      'uid',
                      isEqualTo: FirebaseAuth.instance.currentUser!.uid,
                    )
                    .where('isRead', isEqualTo: false)
                    .snapshots(),

                builder: (context, snapshot) {
                  final count = snapshot.data?.docs.length ?? 0;

                  if (count == 0) {
                    return const SizedBox();
                  }

                  return Positioned(
                    right: 5,
                    top: 3,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 17,
                        minHeight: 17,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          count > 99 ? "99+" : "$count",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(width: 4),

          _profileAvatar(size: 40),

          const SizedBox(width: 12),
        ],
      ),

      // ============================================================
      // BOTTOM NAVIGATION
      // ============================================================
      bottomNavigationBar: _bottomNavigationBar(),

      // ============================================================
      // BODY
      // ============================================================
      body: SafeArea(
        child: RefreshIndicator(
          color: _orange,

          onRefresh: () async {
            await getUserData();
            await getLeaveData();
          },

          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),

            padding: const EdgeInsets.fromLTRB(16, 8, 16, 25),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ==================================================
                // WELCOME
                // ==================================================
                _welcomeCard(),

                const SizedBox(height: 23),

                // ==================================================
                // LEAVE BALANCE
                // ==================================================
                _sectionHeader(
                  title: "Leave Balance",
                  subtitle: "Your current leave overview",
                  onViewAll: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LeaveHistoryScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 13),

                Row(
                  children: [
                    _referenceLeaveCard(
                      title: "CL Leave",
                      value: clLeave.toString(),
                      subtitle: "Casual Leave",
                      color: _green,
                      icon: Icons.event_available_rounded,
                    ),

                    const SizedBox(width: 9),

                    _referenceLeaveCard(
                      title: "SL Leave",
                      value: slLeave.toString(),
                      subtitle: "Sick Leave",
                      color: _blue,
                      icon: Icons.medical_services_rounded,
                    ),

                    const SizedBox(width: 9),

                    _referenceLeaveCard(
                      title: "Remaining",
                      value: remainingLeave.toString(),
                      subtitle: "Leaves Left",
                      color: _purple,
                      icon: Icons.star_rounded,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ==================================================
                // QUICK ACTIONS
                // ==================================================
                _sectionHeader(
                  title: "Quick Actions",
                  subtitle: "Manage your attendance and leaves",
                ),

                const SizedBox(height: 13),

                Row(
                  children: [
                    _referenceActionCard(
                      title: "Apply Leave",
                      subtitle: "Submit a new request",
                      icon: Icons.edit_calendar_rounded,
                      color: _green,

                      // KEEPING YOUR EXISTING LOGIC
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ApplyLeaveScreen(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(width: 10),

                    _referenceActionCard(
                      title: "My Leaves",
                      subtitle: "Track leave status",
                      icon: Icons.description_rounded,
                      color: _blue,

                      // KEEPING YOUR EXISTING LOGIC
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LeaveHistoryScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Row(
                  children: [
                    _referenceActionCard(
                      title: "Attendance",
                      subtitle: "Punch In / Out",
                      icon: Icons.access_time_filled_rounded,
                      color: _purple,

                      // KEEPING YOUR EXISTING LOGIC
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    "Attendance feature is coming soon.",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            behavior: SnackBarBehavior.floating,
                            margin: const EdgeInsets.all(16),
                            duration: const Duration(seconds: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(width: 10),

                    _referenceActionCard(
                      title: "My Attendance",
                      subtitle: "View attendance history",
                      icon: Icons.history_rounded,
                      color: _orange,

                      // KEEPING YOUR EXISTING LOGIC
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    "Attendance history is coming soon.",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            behavior: SnackBarBehavior.floating,
                            margin: const EdgeInsets.all(16),
                            duration: const Duration(seconds: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ==================================================
                // UPCOMING HOLIDAYS
                // ==================================================
                _sectionHeader(
                  title: "Upcoming Holidays",
                  subtitle: "",
                  onViewAll: () {
                    // UI only for now.
                    // Your existing logic is untouched.
                  },
                ),

                const SizedBox(height: 10),

                _holidaysSection(),

                const SizedBox(height: 20),

                // ==================================================
                // BOTTOM PROMO CARD
                // ==================================================
                Container(
                  width: double.infinity,
                  height: 116,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF102A56), Color(0xFF173867)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Stay organized,",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),

                            const Text(
                              "stay ahead!",
                              style: TextStyle(
                                color: _orange,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),

                            const SizedBox(height: 5),

                            const Text(
                              "Apply leaves, track attendance\n"
                              "and manage your work life.",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 9,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Container(
                        height: 68,
                        width: 68,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.calendar_month_rounded,
                          color: Colors.white,
                          size: 42,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
  // return Scaffold(
  //   //  backgroundColor: const Color(0xFFF5F5F5),
  //   appBar: AppBar(
  //     title: const Text(
  //       "Dashboard",
  //       style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
  //     ),
  //     actions: [
  //       IconButton(onPressed: logout, icon: const Icon(Icons.logout)),
  //     ],
  //     backgroundColor: Colors.blue,

  //     foregroundColor: Colors.white,
  //   ),

  //   body:
  //   Padding(
  //     padding: const EdgeInsets.all(20),

  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,

  //       children: [
  //         Row(
  //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //           children: [
  //             Text(
  //               "Welcome  $name",
  //               style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
  //             ),
  //             StreamBuilder<QuerySnapshot>(
  //               stream: FirebaseFirestore.instance
  //                   .collection('notifications')
  //                   .where(
  //                     'uid',
  //                     isEqualTo: FirebaseAuth.instance.currentUser!.uid,
  //                   )
  //                   .where('isRead', isEqualTo: false)
  //                   .snapshots(),

  //               builder: (context, snapshot) {
  //                 int count = snapshot.data?.docs.length ?? 0;

  //                 return Stack(
  //                   children: [
  //                     IconButton(
  //                       icon: const Icon(Icons.notifications),

  //                       onPressed: () async {
  //                         await Navigator.push(
  //                           context,
  //                           MaterialPageRoute(
  //                             builder: (_) => const NotificationScreen(),
  //                           ),
  //                         );

  //                         setState(() {});
  //                       },
  //                     ),

  //                     if (count > 0)
  //                       Positioned(
  //                         right: 8,
  //                         top: 8,

  //                         child: Container(
  //                           padding: const EdgeInsets.all(5),

  //                           decoration: const BoxDecoration(
  //                             color: Colors.red,
  //                             shape: BoxShape.circle,
  //                           ),

  //                           constraints: const BoxConstraints(
  //                             minWidth: 20,
  //                             minHeight: 20,
  //                           ),

  //                           child: Text(
  //                             "$count",

  //                             textAlign: TextAlign.center,

  //                             style: const TextStyle(
  //                               color: Colors.white,
  //                               fontSize: 12,
  //                               fontWeight: FontWeight.bold,
  //                             ),
  //                           ),
  //                         ),
  //                       ),
  //                   ],
  //                 );
  //               },
  //             ),
  //           ],
  //         ),

  //         const SizedBox(height: 4),

  //         Card(
  //           elevation: 8,
  //           color: const Color.fromARGB(255, 99, 204, 186),
  //           child: Padding(
  //             padding: const EdgeInsets.all(20),

  //             child: Column(
  //               crossAxisAlignment: CrossAxisAlignment.start,

  //               children: [
  //                 Text(
  //                   "Name : $name",
  //                   style: const TextStyle(
  //                     fontSize: 18,
  //                     color: Colors.white,
  //                     fontWeight: FontWeight.bold,
  //                   ),
  //                 ),

  //                 const SizedBox(height: 10),

  //                 Text(
  //                   "Email : $email",
  //                   style: const TextStyle(
  //                     fontSize: 18,
  //                     color: Colors.white,
  //                     fontWeight: FontWeight.bold,
  //                   ),
  //                 ),

  //                 const SizedBox(height: 10),

  //                 Text(
  //                   "Role : $role",
  //                   style: const TextStyle(
  //                     fontSize: 18,
  //                     color: Colors.white,
  //                     fontWeight: FontWeight.bold,
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ),

  //         const SizedBox(height: 4),
  //         Card(
  //           elevation: 4,
  //           child: Padding(
  //             padding: const EdgeInsets.all(20),
  //             child: Column(
  //               crossAxisAlignment: CrossAxisAlignment.start,
  //               children: [
  //                 Text(
  //                   "Total Leave: $totalLeave ==$clLeave CL + $slLeave SL",
  //                   style: const TextStyle(fontSize: 16),
  //                 ),
  //                 const SizedBox(height: 10),
  //                 Text(
  //                   "Used Leave: $usedLeave",
  //                   style: const TextStyle(fontSize: 16),
  //                 ),
  //                 const SizedBox(height: 10),
  //                 Text(
  //                   "Remaining Leave: $remainingLeave",
  //                   style: const TextStyle(
  //                     fontSize: 16,
  //                     fontWeight: FontWeight.bold,
  //                     color: Colors.green,
  //                   ),
  //                 ),
  //                 ElevatedButton(
  //                   onPressed: () {
  //                     getLeaveData();
  //                     getLeaveData(); // refresh
  //                   },
  //                   child: const Text(
  //                     "Refresh Leave",
  //                     style: TextStyle(
  //                       fontSize: 14,
  //                       fontWeight: FontWeight.w600,
  //                     ),
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ),
  //         const SizedBox(height: 30),

  //         Row(
  //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //           children: [
  //             ElevatedButton(
  //               onPressed: () {
  //                 Navigator.push(
  //                   context,

  //                   MaterialPageRoute(
  //                     builder: (_) => const ApplyLeaveScreen(),
  //                   ),
  //                 );
  //               },

  //               child: const Text(
  //                 "Apply Leave",
  //                 style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
  //               ),
  //             ),
  //             const SizedBox(width: 20),
  //             ElevatedButton(
  //               onPressed: () {
  //                 Navigator.push(
  //                   context,

  //                   MaterialPageRoute(
  //                     builder: (_) => const LeaveHistoryScreen(),
  //                   ),
  //                 );
  //               },

  //               child: const Text(
  //                 "My Leave Status",
  //                 style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
  //               ),
  //             ),
  //           ],
  //         ),

  //         InkWell(
  //           borderRadius: BorderRadius.circular(16),
  //           onTap: () {
  //             Navigator.push(
  //               context,
  //               MaterialPageRoute(builder: (_) => const AttendanceScreen()),
  //             );
  //           },
  //           child: Container(
  //             margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  //             padding: const EdgeInsets.all(16),
  //             decoration: BoxDecoration(
  //               borderRadius: BorderRadius.circular(16),
  //               gradient: const LinearGradient(
  //                 colors: [Color(0xff1976D2), Color(0xff42A5F5)],
  //               ),
  //               boxShadow: [
  //                 BoxShadow(
  //                   color: Colors.blue.withOpacity(0.3),
  //                   blurRadius: 10,
  //                   offset: const Offset(0, 5),
  //                 ),
  //               ],
  //             ),
  //             child: Row(
  //               children: [
  //                 Container(
  //                   padding: const EdgeInsets.all(12),
  //                   decoration: BoxDecoration(
  //                     color: Colors.white.withOpacity(0.2),
  //                     borderRadius: BorderRadius.circular(12),
  //                   ),
  //                   child: const Icon(
  //                     Icons.access_time_filled,
  //                     color: Colors.white,
  //                     size: 28,
  //                   ),
  //                 ),

  //                 const SizedBox(width: 15),

  //                 const Expanded(
  //                   child: Column(
  //                     crossAxisAlignment: CrossAxisAlignment.start,
  //                     children: [
  //                       Text(
  //                         "Attendance",
  //                         style: TextStyle(
  //                           color: Colors.white,
  //                           fontSize: 18,
  //                           fontWeight: FontWeight.bold,
  //                         ),
  //                       ),

  //                       SizedBox(height: 4),

  //                       Text(
  //                         "Punch In / Punch Out",
  //                         style: TextStyle(
  //                           color: Colors.white70,
  //                           fontSize: 13,
  //                         ),
  //                       ),
  //                     ],
  //                   ),
  //                 ),

  //                 const Icon(
  //                   Icons.arrow_forward_ios,
  //                   color: Colors.white,
  //                   size: 18,
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ),
  //         const SizedBox(height: 30),

  //         Center(
  //           child: ElevatedButton.icon(
  //             icon: const Icon(Icons.history),
  //             label: const Text("My Attendance"),
  //             onPressed: () {
  //               Navigator.push(
  //                 context,
  //                 MaterialPageRoute(
  //                   builder: (_) => const EmployeeAttendanceScreen(),
  //                 ),
  //               );
  //             },
  //           ),
  //         ),
  //       ],
  //     ),
  //   ),

  // );


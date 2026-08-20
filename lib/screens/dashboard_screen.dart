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
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FC),
        surfaceTintColor: Colors.transparent,
        elevation: 0,

        leading: Builder(
          builder: (context) {
            return IconButton(
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
              icon: const Icon(
                Icons.menu_rounded,
                size: 25,
                color: Color(0xFF1F2937),
              ),
            );
          },
        ),

        title: const Text(
          'Enquad',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
        centerTitle: true,
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async {
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
                  child: Container(
                    height: 54,
                    width: 54,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(.05),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.notifications_none_rounded,
                      color: Color(0xFF374151),
                      size: 23,
                    ),
                  ),
                ),
              ),

              // NOTIFICATION COUNT
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
                    right: -3,
                    top: -4,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          count > 99 ? "99+" : "$count",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
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
        ],
      ),
      backgroundColor: const Color(0xFFF7F8FC),
      drawer: _buildDrawer(context),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await getUserData();
            await getLeaveData();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // =====================================================
                // HEADER
                // =====================================================
                // Row(
                //   children: [
                //     // MENU / PROFILE
                //     Builder(
                //       builder: (context) {
                //         return InkWell(
                //           borderRadius: BorderRadius.circular(14),
                //           onTap: () {
                //             Scaffold.of(context).openDrawer();
                //           },
                //           child: Container(
                //             height: 44,
                //             width: 44,
                //             decoration: BoxDecoration(
                //               color: Colors.white,
                //               borderRadius: BorderRadius.circular(14),
                //               boxShadow: [
                //                 BoxShadow(
                //                   color: Colors.black.withOpacity(.05),
                //                   blurRadius: 10,
                //                   offset: const Offset(0, 3),
                //                 ),
                //               ],
                //             ),
                //             child: Center(
                //               child: Text(
                //                 name.isNotEmpty ? name[0].toUpperCase() : "U",
                //                 style: const TextStyle(
                //                   color: Color(0xFF7C3AED),
                //                   fontSize: 18,
                //                   fontWeight: FontWeight.bold,
                //                 ),
                //               ),
                //             ),
                //           ),
                //         );
                //       },
                //     ),

                //     const SizedBox(width: 12),

                //     const Expanded(
                //       child: Column(
                //         crossAxisAlignment: CrossAxisAlignment.start,
                //         children: [
                //           // Text(
                //           //   "Dashboard",
                //           //   style: TextStyle(
                //           //     fontSize: 22,
                //           //     fontWeight: FontWeight.w800,
                //           //     color: Color(0xFF172033),
                //           //   ),
                //           // ),
                //           SizedBox(height: 2),
                //           // Text(
                //           //   "Employee portal",
                //           //   style: TextStyle(
                //           //     fontSize: 12,
                //           //     color: Color(0xFF8A93A5),
                //           //     fontWeight: FontWeight.w500,
                //           //   ),
                //           // ),
                //         ],
                //       ),
                //     ),

                //     // NOTIFICATION
                //     Stack(
                //       clipBehavior: Clip.none,
                //       children: [
                //         InkWell(
                //           borderRadius: BorderRadius.circular(14),
                //           onTap: () async {
                //             await Navigator.push(
                //               context,
                //               MaterialPageRoute(
                //                 builder: (_) => const NotificationScreen(),
                //               ),
                //             );

                //             if (mounted) {
                //               setState(() {});
                //             }
                //           },
                //           child: Container(
                //             height: 44,
                //             width: 44,
                //             decoration: BoxDecoration(
                //               color: Colors.white,
                //               borderRadius: BorderRadius.circular(14),
                //               boxShadow: [
                //                 BoxShadow(
                //                   color: Colors.black.withOpacity(.05),
                //                   blurRadius: 10,
                //                   offset: const Offset(0, 3),
                //                 ),
                //               ],
                //             ),
                //             child: const Icon(
                //               Icons.notifications_none_rounded,
                //               color: Color(0xFF374151),
                //               size: 23,
                //             ),
                //           ),
                //         ),

                //         // NOTIFICATION COUNT
                //         StreamBuilder<QuerySnapshot>(
                //           stream: FirebaseFirestore.instance
                //               .collection('notifications')
                //               .where(
                //                 'uid',
                //                 isEqualTo:
                //                     FirebaseAuth.instance.currentUser!.uid,
                //               )
                //               .where('isRead', isEqualTo: false)
                //               .snapshots(),

                //           builder: (context, snapshot) {
                //             final count = snapshot.data?.docs.length ?? 0;

                //             if (count == 0) {
                //               return const SizedBox();
                //             }

                //             return Positioned(
                //               right: -3,
                //               top: -4,
                //               child: Container(
                //                 constraints: const BoxConstraints(
                //                   minWidth: 18,
                //                   minHeight: 18,
                //                 ),
                //                 padding: const EdgeInsets.symmetric(
                //                   horizontal: 4,
                //                 ),
                //                 decoration: const BoxDecoration(
                //                   color: Color(0xFFEF4444),
                //                   shape: BoxShape.circle,
                //                 ),
                //                 child: Center(
                //                   child: Text(
                //                     count > 99 ? "99+" : "$count",
                //                     style: const TextStyle(
                //                       color: Colors.white,
                //                       fontSize: 9,
                //                       fontWeight: FontWeight.bold,
                //                     ),
                //                   ),
                //                 ),
                //               ),
                //             );
                //           },
                //         ),
                //       ],
                //     ),
                //   ],
                // ),
                // const SizedBox(height: 20),

                // =====================================================
                // WELCOME CARD
                // =====================================================
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7034E6), Color(0xFF8B4DE8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7034E6).withOpacity(.22),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Welcome back 👋",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),

                            const SizedBox(height: 5),

                            Text(
                              name.isEmpty ? "Employee" : name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 23,
                                fontWeight: FontWeight.w800,
                              ),
                            ),

                            const SizedBox(height: 7),

                            const Text(
                              "Have a great day at work!",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 12),

                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ProfileScreen(),
                            ),
                          );
                        },
                        child: Container(
                          height: 64,
                          width: 64,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(.15),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            backgroundColor: const Color(0xFFF0E9FF),
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : "U",
                              style: const TextStyle(
                                color: Color(0xFF7034E6),
                                fontSize: 23,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 26),

                // =====================================================
                // LEAVE BALANCE HEADER
                // =====================================================
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Leave Balance",
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF172033),
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            "Your current leave overview",
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF8A93A5),
                            ),
                          ),
                        ],
                      ),
                    ),

                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LeaveHistoryScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        "View All",
                        style: TextStyle(
                          color: Color(0xFF7034E6),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // =====================================================
                // LEAVE CARDS
                // =====================================================
                Row(
                  children: [
                    _modernLeaveCard(
                      title: "CL Leave",
                      value: clLeave.toString(),
                      icon: Icons.event_available_rounded,
                      color: const Color(0xFF10B981),
                    ),

                    const SizedBox(width: 10),

                    _modernLeaveCard(
                      title: "SL Leave",
                      value: slLeave.toString(),
                      icon: Icons.medical_services_rounded,
                      color: const Color(0xFF3B82F6),
                    ),

                    const SizedBox(width: 10),

                    _modernLeaveCard(
                      title: "Remaining",
                      value: remainingLeave.toString(),
                      icon: Icons.star_rounded,
                      color: const Color(0xFF8B5CF6),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // =====================================================
                // QUICK ACTIONS
                // =====================================================
                const Text(
                  "Quick Actions",
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF172033),
                  ),
                ),

                const SizedBox(height: 4),

                const Text(
                  "Manage your attendance and leaves",
                  style: TextStyle(fontSize: 12, color: Color(0xFF8A93A5)),
                ),

                const SizedBox(height: 14),

                // ROW 1
                Row(
                  children: [
                    _modernActionCard(
                      title: "Apply Leave",
                      subtitle: "Submit a new request",
                      icon: Icons.edit_calendar_rounded,
                      color: const Color(0xFF10B981),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ApplyLeaveScreen(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(width: 12),

                    _modernActionCard(
                      title: "My Leaves",
                      subtitle: "Track leave status",
                      icon: Icons.description_rounded,
                      color: const Color(0xFF3B82F6),
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

                const SizedBox(height: 12),

                // ROW 2
                Row(
                  children: [
                    _modernActionCard(
                      title: "Attendance",
                      subtitle: "Punch In / Out",
                      icon: Icons.access_time_filled_rounded,
                      color: const Color(0xFF8B5CF6),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AttendanceScreen(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(width: 12),

                    _modernActionCard(
                      title: "My Attendance",
                      subtitle: "View attendance history",
                      icon: Icons.history_rounded,
                      color: const Color(0xFFF59E0B),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const EmployeeAttendanceScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 11),

                // =====================================================
                // LOGOUT
                // =====================================================
                // SizedBox(
                //   width: double.infinity,
                //   height: 52,
                //   child: OutlinedButton.icon(
                //     onPressed: () async {
                //       bool? shouldLogout = await showDialog<bool>(
                //         context: context,
                //         barrierDismissible: true,
                //         builder: (context) {
                //           return _logoutDialog(context);
                //         },
                //       );

                //       if (shouldLogout == true) {
                //         logout();
                //       }
                //     },

                //     icon: const Icon(Icons.logout_rounded, size: 19),

                //     label: const Text(
                //       "Logout",
                //       style: TextStyle(
                //         fontSize: 15,
                //         fontWeight: FontWeight.w700,
                //       ),
                //     ),

                //     style: OutlinedButton.styleFrom(
                //       foregroundColor: const Color(0xFFDC2626),
                //       side: const BorderSide(color: Color(0xFFFECACA)),
                //       backgroundColor: const Color(0xFFFFF7F7),
                //       shape: RoundedRectangleBorder(
                //         borderRadius: BorderRadius.circular(15),
                //       ),
                //     ),
                //   ),
                // ),
              ],
            ),
          ),
        ),
      ),
    );
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
}

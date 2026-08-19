import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emailjs/emailjs.dart' as emailjs;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:leave_application/screens/admin_attedance_screen.dart';
import 'package:leave_application/screens/admin_notification_screen.dart';
import 'package:leave_application/screens/login_screen.dart';
import 'package:leave_application/services/email_service.dart';
import 'package:leave_application/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminLeaveScreen extends StatefulWidget {
  const AdminLeaveScreen({super.key});

  @override
  State<AdminLeaveScreen> createState() => _AdminLeaveScreenState();
}

class _AdminLeaveScreenState extends State<AdminLeaveScreen> {
  String? selectedUid;
  List users = [];
  int totalLeave = 13;
  double usedLeave = 0;
  double clLeave = 3;
  double slLeave = 10;
  double remainingLeave = 0;
  @override
  void initState() {
    super.initState();
    getUsers();
    //  getLeaveData();
    markAllRead();
  }

  Future<void> getUsers() async {
    QuerySnapshot snap = await FirebaseFirestore.instance
        .collection('users')
        .get();

    setState(() {
      users = snap.docs;
    });
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
                  title: Text(punch['type']),
                  subtitle: Text(time.toString()),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> getLeaveData(String uid) async {
    try {
      if (uid.isEmpty) return;

      DocumentSnapshot leaveDoc = await FirebaseFirestore.instance
          .collection('toatl_leave')
          .doc(uid)
          .get();

      if (!leaveDoc.exists) return;

      final data = leaveDoc.data() as Map<String, dynamic>;

      // CURRENT REMAINING BALANCE
      double cl = double.tryParse(data['Cl'].toString()) ?? 0.0;
      double sl = double.tryParse(data['Sl'].toString()) ?? 0.0;

      double remaining = cl + sl;

      // USED LEAVE FROM APPROVED REQUESTS
      QuerySnapshot snap = await FirebaseFirestore.instance
          .collection('leave_requests')
          .where('uid', isEqualTo: uid)
          .where('status', isEqualTo: 'Approved')
          .get();

      double used = 0.0;

      for (var doc in snap.docs) {
        final days = doc['days'];

        if (days is num) {
          used += days.toDouble();
        } else {
          used += double.tryParse(days.toString()) ?? 0.0;
        }
      }

      setState(() {
        // FIXED YEARLY POLICY
        totalLeave = 13;

        clLeave = cl;
        slLeave = sl;

        usedLeave = used;

        remainingLeave = remaining;
      });
    } catch (e) {
      print("ERROR = $e");
    }
  }

  Future<void> markAllRead() async {
    QuerySnapshot snap = await FirebaseFirestore.instance
        .collection('notifications')
        .where('role', isEqualTo: 'admin')
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in snap.docs) {
      await doc.reference.update({"isRead": true});
    }
  }

  void testEmail() async {
    try {
      final response = await emailjs.send(
        'service_90wr32y',
        'template_b04xilb',
        {
          'email': 'siddheshwarshingare1999@gmail.com',
          'title': 'TEST SUBJECT',
          'name': 'TEST MESSAGE',
        },
        emailjs.Options(publicKey: '8erlfJzc6WZtfnz0o'),
      );

      print("SUCCESS = ${response.text}");
    } catch (e) {
      print("ERROR = $e");
    }
  }

  String formatLeave(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toString();
  }

  Future<void> approveLeave(
    String requestId,
    String uid,
    String leaveType,
    double days,
    String currentStatus,
  ) async {
    try {
      if (currentStatus == "Approved") {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Already Approved")));
        return;
      }

      // ============================================================
      // GET CURRENT LEAVE BALANCE
      // ============================================================

      DocumentSnapshot balanceDoc = await FirebaseFirestore.instance
          .collection('toatl_leave')
          .doc(uid)
          .get();

      if (!balanceDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Leave balance not found")),
        );
        return;
      }

      // IMPORTANT:
      // Firestore values are strings:
      // Cl = "1"
      // Sl = "6.5"
      //
      // Therefore use DOUBLE, not INT.

      double cl = double.tryParse(balanceDoc['Cl'].toString()) ?? 0.0;

      double sl = double.tryParse(balanceDoc['Sl'].toString()) ?? 0.0;

      print("Current CL = $cl");
      print("Current SL = $sl");
      print("Requested Days = $days");

      // ============================================================
      // DEDUCT LEAVE
      // ============================================================

      if (leaveType == "Casual Leave") {
        if (days > cl) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Only ${formatLeave(cl)} CL available")),
          );
          return;
        }

        double newCl = cl - days;

        await FirebaseFirestore.instance
            .collection('toatl_leave')
            .doc(uid)
            .update({"Cl": formatLeave(newCl)});
      }

      if (leaveType == "Sick Leave") {
        if (days > sl) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Only ${formatLeave(sl)} SL available")),
          );
          return;
        }

        double newSl = sl - days;

        await FirebaseFirestore.instance
            .collection('toatl_leave')
            .doc(uid)
            .update({"Sl": formatLeave(newSl)});
      }

      // ============================================================
      // UPDATE REQUEST STATUS
      // ============================================================

      await FirebaseFirestore.instance
          .collection('leave_requests')
          .doc(requestId)
          .update({"status": "Approved"});

      // ============================================================
      // GET USER
      // ============================================================

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      String token = userDoc['fcmToken'];

      // ============================================================
      // PUSH NOTIFICATION
      // ============================================================

      await NotificationService.sendPush(
        token: token,
        title: "Leave Approved",
        body: "Your leave request approved.",
      );

      // ============================================================
      // FIRESTORE NOTIFICATION
      // ============================================================

      await FirebaseFirestore.instance.collection('notifications').add({
        "uid": uid,
        "role": "employee",
        "title": "Leave Approved",
        "body": "Your leave request approved",
        "isRead": false,
        "createdAt": Timestamp.now(),
      });

      // ============================================================
      // GET LEAVE DATA
      // ============================================================

      DocumentSnapshot leaveDoc = await FirebaseFirestore.instance
          .collection('leave_requests')
          .doc(requestId)
          .get();

      final leaveData = leaveDoc.data() as Map<String, dynamic>;

      // ============================================================
      // EMAIL
      // ============================================================

      await emailjs.send(
        'service_90wr32y',
        'template_b04xilb',
        {
          'employee_name': leaveData['employeeName'],
          'employee_email': leaveData['employeeEmail'],
          'leave_type': leaveData['leaveType'],

          'from_date': (leaveData['fromDate'] as Timestamp)
              .toDate()
              .toString()
              .split(' ')[0],

          'to_date': (leaveData['toDate'] as Timestamp)
              .toDate()
              .toString()
              .split(' ')[0],

          'days': leaveData['days'].toString(),

          //  'status': "Approved",
          'approved': true,
          'rejected': false,
        },

        //  publicKey: '8erlfJzc6WZtfnz0o',
        //  privateKey: 'wRTOsFZnkQi6yxQX7D-rF',
        emailjs.Options(
          publicKey: '8erlfJzc6WZtfnz0o',
          privateKey: 'wRTOsFZnkQi6yxQX7D-rF',
        ),
      );

      // ============================================================
      // SUCCESS
      // ============================================================

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Leave Approved")));
    } catch (e) {
      print("APPROVE ERROR: $e");

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> rejectLeave(
    String requestId,
    String uid,
    String leaveType,
    double days,
    String currentStatus,
  ) async {
    try {
      // ============================================================
      // ALREADY REJECTED
      // ============================================================

      if (currentStatus == "Rejected") {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Already Rejected")));

        return;
      }

      // ============================================================
      // IF PREVIOUSLY APPROVED
      // RESTORE THE LEAVE BALANCE
      // ============================================================

      if (currentStatus == "Approved") {
        DocumentSnapshot balanceDoc = await FirebaseFirestore.instance
            .collection('toatl_leave')
            .doc(uid)
            .get();

        if (!balanceDoc.exists) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Leave balance not found")),
          );

          return;
        }

        // IMPORTANT:
        // Use DOUBLE because values can be 0.5, 6.5 etc.

        double cl = double.tryParse(balanceDoc['Cl'].toString()) ?? 0.0;

        double sl = double.tryParse(balanceDoc['Sl'].toString()) ?? 0.0;

        // ==========================================================
        // RESTORE CASUAL LEAVE
        // ==========================================================

        if (leaveType == "Casual Leave") {
          double newCl = cl + days;

          await FirebaseFirestore.instance
              .collection('toatl_leave')
              .doc(uid)
              .update({"Cl": newCl.toString()});
        }

        // ==========================================================
        // RESTORE SICK LEAVE
        // ==========================================================

        if (leaveType == "Sick Leave") {
          double newSl = sl + days;

          await FirebaseFirestore.instance
              .collection('toatl_leave')
              .doc(uid)
              .update({"Sl": newSl.toString()});
        }
      }

      // ============================================================
      // UPDATE LEAVE REQUEST
      // ============================================================

      await FirebaseFirestore.instance
          .collection('leave_requests')
          .doc(requestId)
          .update({"status": "Rejected"});

      // ============================================================
      // GET EMPLOYEE
      // ============================================================

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      // ============================================================
      // SEND PUSH NOTIFICATION
      // ============================================================

      if (userDoc.exists &&
          userDoc.data() != null &&
          (userDoc.data() as Map<String, dynamic>).containsKey('fcmToken')) {
        String token = (userDoc['fcmToken'] ?? '').toString();

        if (token.isNotEmpty) {
          await NotificationService.sendPush(
            token: token,
            title: "Leave Rejected",
            body: "Your leave request was rejected.",
          );
        }
      }

      // ============================================================
      // ADD IN-APP NOTIFICATION
      // ============================================================

      await FirebaseFirestore.instance.collection('notifications').add({
        "uid": uid,
        "role": "employee",
        "title": "Leave Rejected",
        "body": "Your leave request was rejected.",
        "isRead": false,
        "createdAt": Timestamp.now(),
      });

      // ============================================================
      // GET UPDATED LEAVE REQUEST
      // ============================================================

      DocumentSnapshot leaveDoc = await FirebaseFirestore.instance
          .collection('leave_requests')
          .doc(requestId)
          .get();

      if (!leaveDoc.exists) {
        throw Exception("Leave request not found");
      }

      final leaveData = leaveDoc.data() as Map<String, dynamic>;

      // ============================================================
      // SEND EMAIL
      // ============================================================

      await emailjs.send(
        'service_90wr32y',
        'template_b04xilb',
        {
          'employee_name': leaveData['employeeName'],

          'employee_email': leaveData['employeeEmail'],

          'leave_type': leaveData['leaveType'],

          'from_date': (leaveData['fromDate'] as Timestamp)
              .toDate()
              .toString()
              .split(' ')[0],

          'to_date': (leaveData['toDate'] as Timestamp)
              .toDate()
              .toString()
              .split(' ')[0],

          'days': leaveData['days'].toString(),
          'approved': false,
          'rejected': true,
          // 'status': 'Rejected',

          // IMPORTANT
        },

        emailjs.Options(
          publicKey: '8erlfJzc6WZtfnz0o',
          privateKey: 'wRTOsFZnkQi6yxQX7D-rF',
        ),
      );

      // ============================================================
      // REFRESH LEAVE SUMMARY
      // ============================================================

      if (selectedUid != null) {
        await getLeaveData(selectedUid!);
      }

      // ============================================================
      // SUCCESS MESSAGE
      // ============================================================

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Leave Rejected")));
      }
    } catch (e) {
      debugPrint("REJECT LEAVE ERROR: $e");

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to reject leave: $e")));
      }
    }
  } // Future<void> rejectLeave(String requestId, String status) async {
  //   if (status == "Rejected") {
  //     return;
  //   }

  //   await FirebaseFirestore.instance
  //       .collection('leave_requests')
  //       .doc(requestId)
  //       .update({"status": "Rejected"});

  //   ScaffoldMessenger.of(
  //     context,
  //   ).showSnackBar(const SnackBar(content: Text("Leave Rejected")));
  // }
  Widget attendanceWidget() {
    return StreamBuilder<QuerySnapshot>(
      stream: selectedUid == null
          ? FirebaseFirestore.instance
                .collection('attendance')
                .orderBy('date', descending: true)
                .snapshots()
          : FirebaseFirestore.instance
                .collection('attendance')
                .where('uid', isEqualTo: selectedUid)
                .orderBy('date', descending: true)
                .snapshots(),

      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const CircularProgressIndicator();
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return const Text("No Attendance Found");
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: docs.length,

          itemBuilder: (context, index) {
            var data = docs[index];

            return Card(
              child: ListTile(
                title: Text(data['employeeName']),

                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Date: ${data['date']}"),
                    Text("Working Hours: ${data['workingHours']}"),
                  ],
                ),

                trailing: IconButton(
                  icon: const Icon(Icons.visibility),

                  onPressed: () {
                    showPunchDetails(context, data.id);
                  },
                ),
              ),
            );
          },
        );
      },
    );
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

  Widget _buildSummaryItem({
    required String title,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 3),

        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF8A8FA3),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildLeaveDetail({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 17, color: const Color(0xFF6D28D9)),

        const SizedBox(width: 7),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF8A8FA3),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 2),

              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF374151),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String formatLeaveDate(dynamic fromValue, dynamic toValue) {
    if (fromValue is! Timestamp || toValue is! Timestamp) {
      return "Date not available";
    }

    final from = fromValue.toDate();
    final to = toValue.toDate();

    String formatDate(DateTime date) {
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

      return "${date.day} ${months[date.month - 1]} ${date.year}";
    }

    return "${formatDate(from)} → ${formatDate(to)}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),

      // ============================================================
      // APP BAR
      // ============================================================
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,

        title: const Text(
          "Admin Leave Requests",
          style: TextStyle(
            color: Color(0xFF17133A),
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),

        actions: [
          // ----------------------------------------------------------
          // LOGOUT
          // ----------------------------------------------------------
          IconButton(
            onPressed: logout,
            tooltip: "Logout",
            icon: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF0E9FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: Color(0xFF6D28D9),
                size: 21,
              ),
            ),
          ),

          // ----------------------------------------------------------
          // NOTIFICATIONS
          // ----------------------------------------------------------
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('role', isEqualTo: 'admin')
                .where('isRead', isEqualTo: false)
                .snapshots(),

            builder: (context, snapshot) {
              int count = snapshot.data?.docs.length ?? 0;

              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      tooltip: "Notifications",
                      icon: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0E9FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.notifications_none_rounded,
                          color: Color(0xFF6D28D9),
                          size: 23,
                        ),
                      ),

                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminNotificationScreen(),
                          ),
                        );

                        setState(() {});
                      },
                    ),

                    if (count > 0)
                      Positioned(
                        right: 2,
                        top: 0,
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Text(
                            count > 99 ? "99+" : count.toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),

      // ============================================================
      // BODY
      // ============================================================
      body: Column(
        children: [
          // ==========================================================
          // EMPLOYEE DROPDOWN
          // ==========================================================
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
            child: DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: "Select Employee",

                labelStyle: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),

                prefixIcon: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0E9FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    color: Color(0xFF6D28D9),
                    size: 21,
                  ),
                ),

                filled: true,
                fillColor: Colors.white,

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),

                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),

                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: Color(0xFF6D28D9),
                    width: 1.5,
                  ),
                ),

                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 16,
                ),
              ),

              value: selectedUid,

              isExpanded: true,

              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF6D28D9),
              ),

              items: users.map((user) {
                return DropdownMenuItem<String>(
                  value: user.id,
                  child: Text(
                    user['name'],
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF17133A),
                    ),
                  ),
                );
              }).toList(),

              onChanged: (value) {
                setState(() {
                  selectedUid = value;
                });

                if (value != null) {
                  getLeaveData(value);
                }
              },
            ),
          ),

          // ==========================================================
          // LEAVE SUMMARY
          // ==========================================================
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),

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

              child: Column(
                children: [
                  // ----------------------------------------------------
                  // SUMMARY HEADER
                  // ----------------------------------------------------
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFF6D28D9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.event_available_rounded,
                          color: Colors.white,
                          size: 27,
                        ),
                      ),

                      const SizedBox(width: 14),

                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Leave Summary",
                              style: TextStyle(
                                color: Color(0xFF17133A),
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),

                            SizedBox(height: 3),

                            Text(
                              "Employee leave balance",
                              style: TextStyle(
                                color: Color(0xFF8A8FA3),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // ----------------------------------------------------
                  // SUMMARY VALUES
                  // ----------------------------------------------------
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryItem(
                          title: "Total",
                          value: "13",
                          color: const Color(0xFF6D28D9),
                        ),
                      ),

                      Container(
                        width: 1,
                        height: 42,
                        color: const Color(0xFFE5E7EB),
                      ),

                      Expanded(
                        child: _buildSummaryItem(
                          title: "Used",
                          value: "$usedLeave",
                          color: const Color(0xFFF59E0B),
                        ),
                      ),

                      Container(
                        width: 1,
                        height: 42,
                        color: const Color(0xFFE5E7EB),
                      ),

                      Expanded(
                        child: _buildSummaryItem(
                          title: "Remaining",
                          value: "$remainingLeave",
                          color: const Color(0xFF16A34A),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 15),

                  // ----------------------------------------------------
                  // CL / SL
                  // ----------------------------------------------------
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F5FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 17,
                          color: Color(0xFF6D28D9),
                        ),

                        const SizedBox(width: 8),

                        Text(
                          "$clLeave CL",
                          style: const TextStyle(
                            color: Color(0xFF6D28D9),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),

                        const SizedBox(width: 8),

                        const Text(
                          "•",
                          style: TextStyle(color: Color(0xFF9CA3AF)),
                        ),

                        const SizedBox(width: 8),

                        Text(
                          "$slLeave SL",
                          style: const TextStyle(
                            color: Color(0xFF6D28D9),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),

                        const Spacer(),

                        const Text(
                          "Available",
                          style: TextStyle(
                            color: Color(0xFF16A34A),
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
          ),

          // ==========================================================
          // REFRESH + ATTENDANCE
          // ==========================================================
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Row(
              children: [
                // ------------------------------------------------------
                // REFRESH
                // ------------------------------------------------------
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (selectedUid == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Please select an employee first"),
                          ),
                        );
                        return;
                      }

                      getLeaveData(selectedUid!);
                    },

                    icon: const Icon(Icons.refresh_rounded, size: 19),

                    label: const Text(
                      "Refresh",
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),

                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6D28D9),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(0, 48),

                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // ------------------------------------------------------
                // ATTENDANCE
                // ------------------------------------------------------
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AdminAttendanceScreen(selectedUid: selectedUid),
                        ),
                      );
                    },

                    icon: const Icon(Icons.access_time_rounded, size: 19),

                    label: const Text(
                      "Attendance",
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),

                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5B21E8),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(0, 48),

                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ==========================================================
          // LEAVE REQUESTS
          // ==========================================================
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),

              child: Column(
                children: [
                  StreamBuilder(
                    stream: selectedUid == null
                        ? FirebaseFirestore.instance
                              .collection('leave_requests')
                              .orderBy('createdAt', descending: true)
                              .snapshots()
                        : FirebaseFirestore.instance
                              .collection('leave_requests')
                              .where('uid', isEqualTo: selectedUid)
                              .orderBy('createdAt', descending: true)
                              .snapshots(),

                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF6D28D9),
                            ),
                          ),
                        );
                      }

                      final docs = snapshot.data!.docs;

                      if (docs.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            children: [
                              Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0E9FF),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(
                                  Icons.inbox_rounded,
                                  color: Color(0xFF6D28D9),
                                  size: 34,
                                ),
                              ),

                              const SizedBox(height: 14),

                              const Text(
                                "No Requests Found",
                                style: TextStyle(
                                  color: Color(0xFF17133A),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),

                              const SizedBox(height: 5),

                              const Text(
                                "There are no leave requests to display.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFF8A8FA3),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),

                        itemCount: docs.length,

                        itemBuilder: (context, index) {
                          var data = docs[index];

                          DateTime fromDate = (data['fromDate'] as Timestamp)
                              .toDate();

                          bool isOldLeave = fromDate.isBefore(
                            DateTime(
                              DateTime.now().year,
                              DateTime.now().month,
                              DateTime.now().day,
                            ),
                          );

                          final String status =
                              data['status']?.toString() ?? "";

                          final bool isApproved = status == "Approved";

                          final bool isRejected = status == "Rejected";

                          // ------------------------------------------------
                          // STATUS COLORS
                          // ------------------------------------------------
                          Color statusColor;

                          Color statusBackground;

                          IconData statusIcon;

                          if (isApproved) {
                            statusColor = const Color(0xFF15803D);

                            statusBackground = const Color(0xFFDCFCE7);

                            statusIcon = Icons.check_circle_rounded;
                          } else if (isRejected) {
                            statusColor = const Color(0xFFDC2626);

                            statusBackground = const Color(0xFFFEE2E2);

                            statusIcon = Icons.cancel_rounded;
                          } else {
                            statusColor = const Color(0xFFD97706);

                            statusBackground = const Color(0xFFFEF3C7);

                            statusIcon = Icons.pending_rounded;
                          }

                          return Container(
                            width: double.infinity,
                            margin: const EdgeInsets.fromLTRB(18, 6, 18, 10),

                            padding: const EdgeInsets.all(17),

                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),

                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(.035),
                                  blurRadius: 14,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),

                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,

                              children: [
                                // ==========================================
                                // EMPLOYEE + STATUS
                                // ==========================================
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,

                                  children: [
                                    Container(
                                      width: 46,
                                      height: 46,

                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF0E9FF),
                                        borderRadius: BorderRadius.circular(14),
                                      ),

                                      child: const Icon(
                                        Icons.person_rounded,
                                        color: Color(0xFF6D28D9),
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
                                            data['employeeName'].toString(),

                                            maxLines: 1,

                                            overflow: TextOverflow.ellipsis,

                                            style: const TextStyle(
                                              color: Color(0xFF17133A),
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),

                                          const SizedBox(height: 3),

                                          Text(
                                            data['employeeEmail'].toString(),

                                            maxLines: 1,

                                            overflow: TextOverflow.ellipsis,

                                            style: const TextStyle(
                                              color: Color(0xFF8A8FA3),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(width: 8),

                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 6,
                                      ),

                                      decoration: BoxDecoration(
                                        color: statusBackground,
                                        borderRadius: BorderRadius.circular(20),
                                      ),

                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,

                                        children: [
                                          Icon(
                                            statusIcon,
                                            color: statusColor,
                                            size: 14,
                                          ),

                                          const SizedBox(width: 4),

                                          Text(
                                            status,
                                            style: TextStyle(
                                              color: statusColor,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),

                                // ==========================================
                                // LEAVE DETAILS
                                // ==========================================
                                Container(
                                  padding: const EdgeInsets.all(13),

                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8F7FC),
                                    borderRadius: BorderRadius.circular(15),
                                  ),

                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildLeaveDetail(
                                              icon: Icons.category_outlined,
                                              title: "Leave Type",
                                              value: data['leaveType']
                                                  .toString(),
                                            ),
                                          ),

                                          Expanded(
                                            child: _buildLeaveDetail(
                                              icon:
                                                  Icons.calendar_today_rounded,
                                              title: "Days",
                                              value: data['days'].toString(),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Icon(
                                            Icons.calendar_month_rounded,
                                            size: 17,
                                            color: Color(0xFF6D28D9),
                                          ),

                                          const SizedBox(width: 8),

                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  "Leave Date",
                                                  style: TextStyle(
                                                    color: Color(0xFF8A8FA3),
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),

                                                const SizedBox(height: 3),

                                                Text(
                                                  formatLeaveDate(
                                                    data['fromDate'],
                                                    data['toDate'],
                                                  ),
                                                  style: const TextStyle(
                                                    color: Color(0xFF374151),
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),

                                                const SizedBox(height: 2),

                                                Text(
                                                  "${data['days'] ?? 0} Days • ${data['leaveDuration'] ?? ''}",
                                                  style: const TextStyle(
                                                    color: Color(0xFF6D28D9),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 12),

                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,

                                        children: [
                                          const Icon(
                                            Icons.description_outlined,
                                            size: 17,
                                            color: Color(0xFF6D28D9),
                                          ),

                                          const SizedBox(width: 8),

                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  "Reason",
                                                  style: TextStyle(
                                                    color: Color(0xFF8A8FA3),
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),

                                                const SizedBox(height: 2),

                                                Text(
                                                  data['reason'].toString(),

                                                  style: const TextStyle(
                                                    color: Color(0xFF374151),
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 15),

                                // ==========================================
                                // APPROVE / REJECT
                                // ==========================================
                                Row(
                                  children: [
                                    // ============================================================
                                    // APPROVE BUTTON
                                    // ============================================================
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF16A34A,
                                          ),
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          disabledBackgroundColor: const Color(
                                            0xFFD1D5DB,
                                          ),
                                          disabledForegroundColor:
                                              Colors.white70,
                                          minimumSize: const Size(0, 46),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              13,
                                            ),
                                          ),
                                        ),

                                        onPressed: isOldLeave
                                            ? null
                                            : () {
                                                showDialog(
                                                  context: context,
                                                  builder: (dialogContext) {
                                                    return AlertDialog(
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              18,
                                                            ),
                                                      ),

                                                      title: const Row(
                                                        children: [
                                                          Icon(
                                                            Icons
                                                                .check_circle_outline_rounded,
                                                            color: Color(
                                                              0xFF16A34A,
                                                            ),
                                                          ),
                                                          SizedBox(width: 10),
                                                          Text(
                                                            "Confirm Approval",
                                                          ),
                                                        ],
                                                      ),

                                                      content: const Text(
                                                        "Are you sure you want to approve this leave?",
                                                      ),

                                                      actions: [
                                                        TextButton(
                                                          onPressed: () {
                                                            Navigator.pop(
                                                              dialogContext,
                                                            );
                                                          },
                                                          child: const Text(
                                                            "Cancel",
                                                            style: TextStyle(
                                                              color: Color(
                                                                0xFF6B7280,
                                                              ),
                                                            ),
                                                          ),
                                                        ),

                                                        ElevatedButton(
                                                          style:
                                                              ElevatedButton.styleFrom(
                                                                backgroundColor:
                                                                    const Color(
                                                                      0xFF16A34A,
                                                                    ),
                                                                foregroundColor:
                                                                    Colors
                                                                        .white,
                                                              ),

                                                          onPressed: () async {
                                                            // CLOSE DIALOG FIRST
                                                            Navigator.pop(
                                                              dialogContext,
                                                            );

                                                            // THEN APPROVE
                                                            await approveLeave(
                                                              data.id,
                                                              data['uid'],
                                                              data['leaveType'],
                                                              double.parse(
                                                                data['days']
                                                                    .toString(),
                                                              ),
                                                              data['status'],
                                                            );
                                                          },

                                                          child: const Text(
                                                            "Approve",
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                );
                                              },

                                        icon: const Icon(
                                          Icons.check_circle_outline_rounded,
                                          size: 18,
                                        ),

                                        label: const Text(
                                          "Approve",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(width: 10),

                                    // ============================================================
                                    // REJECT BUTTON
                                    // ============================================================
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFFDC2626,
                                          ),
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          disabledBackgroundColor: const Color(
                                            0xFFD1D5DB,
                                          ),
                                          disabledForegroundColor:
                                              Colors.white70,
                                          minimumSize: const Size(0, 46),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              13,
                                            ),
                                          ),
                                        ),

                                        onPressed: isOldLeave
                                            ? null
                                            : () {
                                                showDialog(
                                                  context: context,
                                                  builder: (dialogContext) {
                                                    return AlertDialog(
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              18,
                                                            ),
                                                      ),

                                                      title: const Row(
                                                        children: [
                                                          Icon(
                                                            Icons
                                                                .cancel_outlined,
                                                            color: Color(
                                                              0xFFDC2626,
                                                            ),
                                                          ),
                                                          SizedBox(width: 10),
                                                          Text("Reject Leave"),
                                                        ],
                                                      ),

                                                      content: const Text(
                                                        "Are you sure you want to reject this leave?",
                                                      ),

                                                      actions: [
                                                        TextButton(
                                                          onPressed: () {
                                                            Navigator.pop(
                                                              dialogContext,
                                                            );
                                                          },
                                                          child: const Text(
                                                            "Cancel",
                                                            style: TextStyle(
                                                              color: Color(
                                                                0xFF6B7280,
                                                              ),
                                                            ),
                                                          ),
                                                        ),

                                                        ElevatedButton(
                                                          style:
                                                              ElevatedButton.styleFrom(
                                                                backgroundColor:
                                                                    const Color(
                                                                      0xFFDC2626,
                                                                    ),
                                                                foregroundColor:
                                                                    Colors
                                                                        .white,
                                                              ),

                                                          onPressed: () async {
                                                            // Close confirmation popup
                                                            Navigator.pop(
                                                              dialogContext,
                                                            );

                                                            // Reject leave
                                                            await rejectLeave(
                                                              data.id,
                                                              data['uid'],
                                                              data['leaveType'],
                                                              double.parse(
                                                                data['days']
                                                                    .toString(),
                                                              ),
                                                              data['status'],
                                                            );
                                                          },

                                                          child: const Text(
                                                            "Reject",
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                );
                                              },

                                        icon: const Icon(
                                          Icons.cancel_outlined,
                                          size: 18,
                                        ),

                                        label: const Text(
                                          "Reject",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                // ==========================================
                                // OLD LEAVE MESSAGE
                                // ==========================================
                                if (isOldLeave) ...[
                                  const SizedBox(height: 9),

                                  Row(
                                    children: const [
                                      Icon(
                                        Icons.info_outline_rounded,
                                        size: 14,
                                        color: Color(0xFFD97706),
                                      ),

                                      SizedBox(width: 5),

                                      Expanded(
                                        child: Text(
                                          "This leave request is from a previous date.",
                                          style: TextStyle(
                                            color: Color(0xFFD97706),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      );
                    },
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

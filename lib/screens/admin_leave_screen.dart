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
  int usedLeave = 0;
  int clLeave = 3;
  int slLeave = 10;
  int remainingLeave = 0;
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
      int cl = int.tryParse(data['Cl'].toString()) ?? 0;
      int sl = int.tryParse(data['Sl'].toString()) ?? 0;

      int remaining = cl + sl;

      // USED LEAVE FROM APPROVED REQUESTS
      QuerySnapshot snap = await FirebaseFirestore.instance
          .collection('leave_requests')
          .where('uid', isEqualTo: uid)
          .where('status', isEqualTo: 'Approved')
          .get();

      int used = 0;

      for (var doc in snap.docs) {
        used += (doc['days'] as num?)?.toInt() ?? 0;
      }

      setState(() {
        // FIXED YEARLY POLICY
        totalLeave = 13;

        clLeave = cl;
        slLeave = sl;

        usedLeave = used;

        // CURRENT BALANCE
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

  Future<void> approveLeave(
    String requestId,
    String uid,
    String leaveType,
    int days,
    String currentStatus,
  ) async {
    try {
      if (currentStatus == "Approved") {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Already Approved")));

        return;
      }

      DocumentSnapshot balanceDoc = await FirebaseFirestore.instance
          .collection('toatl_leave')
          .doc(uid)
          .get();

      int cl = int.parse(balanceDoc['Cl'].toString());

      int sl = int.parse(balanceDoc['Sl'].toString());

      /// deduct ONLY when moving TO approved
      if (leaveType == "Casual Leave") {
        if (days > cl) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Only $cl CL available")));

          return;
        }

        await FirebaseFirestore.instance
            .collection('toatl_leave')
            .doc(uid)
            .update({"Cl": (cl - days).toString()});
      }

      if (leaveType == "Sick Leave") {
        if (days > sl) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Only $sl SL available")));

          return;
        }

        await FirebaseFirestore.instance
            .collection('toatl_leave')
            .doc(uid)
            .update({"Sl": (sl - days).toString()});
      }

      await FirebaseFirestore.instance
          .collection('leave_requests')
          .doc(requestId)
          .update({"status": "Approved"});
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      String token = userDoc['fcmToken'];

      await NotificationService.sendPush(
        token: token,
        title: "Leave Approved",
        body: "Your leave request approved.",
      );
      DocumentSnapshot leaveDoc = await FirebaseFirestore.instance
          .collection('leave_requests')
          .doc(requestId)
          .get();

      final leaveData = leaveDoc.data() as Map<String, dynamic>;
      await FirebaseFirestore.instance.collection('notifications').add({
        "uid": uid,
        "role": "employee",
        "title": "Leave Approved",
        "body": "Your leave request approved",
        "isRead": false,
        "createdAt": Timestamp.now(),
      });
      await emailjs.send(
        'service_90wr32y',
        'template_b04xilb',
        {
          'employee_name': leaveData['employeeName'],
          'employee_email': "siddheshwarshingare1999@gmail.com",
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

          'status': "Approved",
        },

        emailjs.Options(
          publicKey: '8erlfJzc6WZtfnz0o',
          privateKey: 'wRTOsFZnkQi6yxQX7D-rF',
        ),
      );
      // await EmailService.sendEmail(
      //   email: "siddheshwarshingare1999@gmail.com",
      //   subject: "Leave Approved",
      //   message: "Your leave approved",
      // );
      // testEmail();
      // await EmailService.sendEmail(
      //   toEmail: userDoc['email'],
      //   title: "Leave Approved",
      //   content:
      //       "Hello ${userDoc['name']}, Your leave request has been approved.",
      // );
      // await EmailService.sendEmail(
      //   email: userDoc['email'],c
      //   subject: "Leave Approved",
      //   message:
      //       "Hello ${userDoc['name']}, "
      //       "Your leave request has been approved.",
      // );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Leave Approved")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> rejectLeave(
    String requestId,
    String uid,
    String leaveType,
    int days,
    String currentStatus,
  ) async {
    try {
      if (currentStatus == "Rejected") {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Already Rejected")));

        return;
      }

      /// If previously approved → restore balance
      if (currentStatus == "Approved") {
        DocumentSnapshot balanceDoc = await FirebaseFirestore.instance
            .collection('toatl_leave')
            .doc(uid)
            .get();

        int cl = int.parse(balanceDoc['Cl'].toString());

        int sl = int.parse(balanceDoc['Sl'].toString());

        if (leaveType == "Casual Leave") {
          await FirebaseFirestore.instance
              .collection('toatl_leave')
              .doc(uid)
              .update({"Cl": (cl + days).toString()});
        }

        if (leaveType == "Sick Leave") {
          await FirebaseFirestore.instance
              .collection('toatl_leave')
              .doc(uid)
              .update({"Sl": (sl + days).toString()});
        }
      }
      if (currentStatus == "Rejected") {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Already Rejected. Cannot Approve.")),
        );

        return;
      }
      await FirebaseFirestore.instance
          .collection('leave_requests')
          .doc(requestId)
          .update({"status": "Rejected"});
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      String token = userDoc['fcmToken'];

      await NotificationService.sendPush(
        token: token,
        title: "Leave Rejected",
        body: "Your leave request rejected.",
      );
      await FirebaseFirestore.instance.collection('notifications').add({
        "uid": uid,
        "role": "employee",
        "title": "Leave Rejected",
        "body": "Your leave request rejected",
        "isRead": false,
        "createdAt": Timestamp.now(),
      });
      DocumentSnapshot leaveDoc = await FirebaseFirestore.instance
          .collection('leave_requests')
          .doc(requestId)
          .get();

      final leaveData = leaveDoc.data() as Map<String, dynamic>;

      await emailjs.send(
        'service_90wr32y',
        'template_b04xilb',

        {
          'employee_name': leaveData['employeeName'],
          'employee_email': "siddheshwarshingare1999@gmail.com",
          // 'employee_email': leaveData['employeeEmail'], // actual employee email
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

          'status': 'Rejected',
        },

        emailjs.Options(
          publicKey: '8erlfJzc6WZtfnz0o',
          privateKey: 'wRTOsFZnkQi6yxQX7D-rF',
        ),
      );
      // await emailjs.send(
      //   'service_90wr32y',
      //   'template_b04xilb',

      //   {
      //     'employee_name': leaveData['employeeName'],
      //     'employee_email': "siddheshwarshingare1999@gmail.com",
      //     'leave_type': leaveData['leaveType'],
      //     'status': "Rejected",
      //   },

      //   emailjs.Options(
      //     publicKey: '8erlfJzc6WZtfnz0o',
      //     privateKey: 'wRTOsFZnkQi6yxQX7D-rF',
      //   ),
      // );

      // await EmailService.sendEmail(

      //   toEmail: userDoc['email'],
      //   title: "Leave Rejected",
      //   content:
      //       "Hello ${userDoc['name']}, Your leave request has been rejected.",
      // );
      // await EmailService.sendEmail(
      //   email: userDoc['email'],
      //   subject: "Leave Rejected",
      //   message:
      //       "Hello ${userDoc['name']}, "
      //       "Your leave request has been rejected.",
      // );
      // await emailjs.send(
      //   'service_90wr32y',
      //   'template_b04xilb', // APPROVE/REJECT TEMPLATE
      //   {
      //     'to_email': userDoc['email'],
      //     'name': userDoc['name'],
      //     'title': 'Leave Approved',
      //     'message': 'Your leave request has been approved.',
      //   },

      //   emailjs.Options(
      //     publicKey: '8erlfJzc6WZtfnz0o',
      //     privateKey: 'wRTOsFZnkQi6yxQX7D-rF',
      //   ),
      // );

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Leave Rejected")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
  // Future<void> rejectLeave(String requestId, String status) async {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              "Admin Leave Requests",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            SizedBox(width: 12),
            IconButton(onPressed: logout, icon: const Icon(Icons.logout)),
          ],
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,

        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('role', isEqualTo: 'admin')
                .where('isRead', isEqualTo: false)
                .snapshots(),

            builder: (context, snapshot) {
              int count = snapshot.data?.docs.length ?? 0;

              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications),

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
                      right: 8,
                      top: 8,

                      child: Container(
                        padding: const EdgeInsets.all(5),

                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),

                        child: Text(
                          count.toString(),

                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: "Select Employee",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),

                value: selectedUid,
                isExpanded: true,

                items: users.map((user) {
                  return DropdownMenuItem<String>(
                    value: user.id,
                    child: Text(
                      user['name'],
                      style: const TextStyle(fontSize: 16),
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
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Leave Summary",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),

                            Text(
                              "Total Leave: 13",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                // color: Colors.blue,
                              ),
                            ),
                            Text(
                              "Used Leave: $usedLeave",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                // color: Colors.blue,
                              ),
                            ),
                            Text(
                              "Remaining: $remainingLeave ($clLeave CL + $slLeave SL)",
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Column(
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            if (selectedUid == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Please select an employee first",
                                  ),
                                ),
                              );
                              return;
                            }

                            getLeaveData(selectedUid!);
                          },
                          child: const Text(
                            "Refresh",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AdminAttendanceScreen(
                                  selectedUid: selectedUid,
                                ),
                              ),
                            );
                          },
                          child: const Text("Attendance"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Text("Total Leave: $totalLeave ($clLeave CL + $slLeave SL)"),
              // Text("Used Leave: $usedLeave"),
              // Text("Remaining Leave: $remainingLeave"),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
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
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = snapshot.data!.docs;

                      if (docs.isEmpty) {
                        return const Center(child: Text("No Requests Found"));
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
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
                          return Card(
                            margin: const EdgeInsets.all(10),

                            child: Padding(
                              padding: const EdgeInsets.all(12),

                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,

                                children: [
                                  Text(
                                    "Employee Name: ${data['employeeName']}",
                                    // data['employeeName'],
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),

                                  const SizedBox(height: 8),

                                  Text(
                                    "Email: ${data['employeeEmail']}",
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),

                                  Text(
                                    "Leave Type: ${data['leaveType']}",
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),

                                  Text(
                                    "Days: ${data['days']}",
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),

                                  Text(
                                    "Reason: ${data['reason']}",
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),

                                  Text(
                                    "Status: ${data['status']}",
                                    style: TextStyle(
                                      color: data['status'] == "Approved"
                                          ? Colors.green
                                          : data['status'] == "Rejected"
                                          ? Colors.red
                                          : Colors.orange,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),

                                  const SizedBox(height: 10),

                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                          ),

                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text(
                                                  "Confirm Approval",
                                                ),
                                                content: const Text(
                                                  "Are you sure you want to approve this leave?",
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(context),
                                                    child: const Text("Cancel"),
                                                  ),
                                                  // ElevatedButton(
                                                  //   style: ElevatedButton.styleFrom(
                                                  //     backgroundColor: Colors.green,
                                                  //   ),
                                                  //   onPressed: () {
                                                  //     Navigator.pop(context);

                                                  //     approveLeave(
                                                  //       data.id,
                                                  //       data['uid'],
                                                  //       data['leaveType'],
                                                  //       int.parse(
                                                  //         data['days'].toString(),
                                                  //       ),
                                                  //       data['status'],
                                                  //     );
                                                  //   },
                                                  //   child: const Text("Approve"),
                                                  // ),
                                                  ElevatedButton(
                                                    onPressed: isOldLeave
                                                        ? null
                                                        : () {
                                                            approveLeave(
                                                              data.id,
                                                              data['uid'],
                                                              data['leaveType'],
                                                              int.parse(
                                                                data['days']
                                                                    .toString(),
                                                              ),
                                                              data['status'],
                                                            );
                                                          },
                                                    child: const Text(
                                                      "Approve",
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },

                                          child: const Text(
                                            "Approve",
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(width: 10),

                                      Expanded(
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                          ),

                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text(
                                                  "Confirm Rejection",
                                                ),
                                                content: const Text(
                                                  "Are you sure you want to reject this leave?",
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(context),
                                                    child: const Text("Cancel"),
                                                  ),
                                                  ElevatedButton(
                                                    style:
                                                        ElevatedButton.styleFrom(
                                                          backgroundColor:
                                                              Colors.red,
                                                        ),
                                                    onPressed: isOldLeave
                                                        ? null
                                                        : () {
                                                            Navigator.pop(
                                                              context,
                                                            );

                                                            rejectLeave(
                                                              data.id,
                                                              data['uid'],
                                                              data['leaveType'],
                                                              int.parse(
                                                                data['days']
                                                                    .toString(),
                                                              ),
                                                              data['status'],
                                                            );
                                                          },
                                                    child: const Text(
                                                      "Reject",
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },

                                          child: const Text("Reject"),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
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

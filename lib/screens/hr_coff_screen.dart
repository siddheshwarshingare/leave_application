import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emailjs/emailjs.dart' as emailjs;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class HRCOffScreen extends StatefulWidget {
  const HRCOffScreen({super.key});

  @override
  State<HRCOffScreen> createState() => _HRCOffScreenState();
}

class _HRCOffScreenState extends State<HRCOffScreen> {
  bool loading = false;

  // ==========================================================
  // FORMAT DATE
  // ==========================================================

  String formatDate(String date) {
    try {
      final parts = date.split('-');

      if (parts.length != 3) {
        return date;
      }

      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);

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

      return "${day.toString().padLeft(2, '0')} "
          "${months[month - 1]} "
          "$year";
    } catch (e) {
      return date;
    }
  }

  // ==========================================================
  // APPROVE C-OFF
  // ==========================================================

  Future<void> approveCOff(String requestId, Map<String, dynamic> data) async {
    if (loading) return;

    final uid = data['uid']?.toString();

    if (uid == null || uid.isEmpty) {
      showMessage("Employee UID is missing.");
      return;
    }

    final employeeName = data['employeeName']?.toString() ?? "Employee";

    final workedDate = data['workedDate']?.toString() ?? "";

    final coffDays = _toDouble(data['coffDays'] ?? 1);

    // ========================================================
    // CONFIRM
    // ========================================================

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Approve C-Off"),
          content: Text(
            "Approve C-Off for $employeeName?\n\n"
            "Worked Date: ${formatDate(workedDate)}\n"
            "C-Off: $coffDays Day",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text("Approve"),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    try {
      setState(() {
        loading = true;
      });

      final hrUser = FirebaseAuth.instance.currentUser;

      if (hrUser == null) {
        throw Exception("HR user is not logged in.");
      }

      // ======================================================
      // REFERENCES
      // ======================================================

      final firestore = FirebaseFirestore.instance;

      final requestRef = firestore.collection('coff_requests').doc(requestId);

      final leaveRef = firestore.collection('toatl_leave').doc(uid);

      // ======================================================
      // TRANSACTION
      // ======================================================

      await firestore.runTransaction((transaction) async {
        // ----------------------------------------------------
        // READ REQUEST
        // ----------------------------------------------------

        final requestSnapshot = await transaction.get(requestRef);

        if (!requestSnapshot.exists) {
          throw Exception("C-Off request no longer exists.");
        }

        final requestData = requestSnapshot.data();

        if (requestData == null) {
          throw Exception("Invalid C-Off request.");
        }

        final currentStatus = requestData['status']?.toString() ?? "";

        // Already processed
        if (currentStatus != "Pending") {
          throw Exception("This request has already been $currentStatus.");
        }

        // ----------------------------------------------------
        // READ LEAVE BALANCE
        // ----------------------------------------------------

        final leaveSnapshot = await transaction.get(leaveRef);

        double currentCoffCl = 0;

        if (leaveSnapshot.exists) {
          final leaveData = leaveSnapshot.data();

          currentCoffCl = _toDouble(leaveData?['coffCl'] ?? 0);
        }

        // ----------------------------------------------------
        // NEW BALANCE
        // ----------------------------------------------------

        final newCoffCl = currentCoffCl + coffDays;

        // ----------------------------------------------------
        // UPDATE REQUEST
        // ----------------------------------------------------

        transaction.update(requestRef, {
          "status": "Approved",
          "approvedAt": FieldValue.serverTimestamp(),
          "approvedBy": hrUser.uid,
        });

        // ----------------------------------------------------
        // UPDATE TOTAL LEAVE
        // ----------------------------------------------------

        if (leaveSnapshot.exists) {
          transaction.update(leaveRef, {"coffCl": newCoffCl.toString()});
        } else {
          transaction.set(leaveRef, {
            "uid": uid,
            "coffCl": newCoffCl.toString(),
            "Sl": "0",
            "Cl": "0",
          }, SetOptions(merge: true));
        }
      });

      // ======================================================
      // EMPLOYEE NOTIFICATION
      // ======================================================

      await firestore.collection('notifications').add({
        "role": "employee",
        "uid": uid,
        "title": "C-Off Approved",
        "body":
            "Your C-Off request for ${formatDate(workedDate)} has been approved.",
        "isRead": false,
        "createdAt": FieldValue.serverTimestamp(),
      });
      // ======================================================
      // APPROVAL EMAIL TO EMPLOYEE
      // ======================================================

      // ======================================================
      // APPROVAL EMAIL TO EMPLOYEE
      // ======================================================

      try {
        final employeeEmail = data['employeeEmail']?.toString().trim() ?? "";

        debugPrint("========================================");
        debugPrint("C-OFF APPROVAL EMAIL");
        debugPrint("Employee Name: $employeeName");
        debugPrint("Employee Email: $employeeEmail");
        debugPrint("========================================");

        if (employeeEmail.isNotEmpty) {
          final response = await emailjs.send(
            "service_90wr32y",
            "template_b04xilb",
            {
              // =================================================
              // RECIPIENT
              // =================================================
              "to_email": employeeEmail,
              // "to_email": 'siddheshwar.shingare@en3.ca',
              //'employee_email': "siddheshwar.shingare@en3.ca",
              // =================================================
              // STATUS FLAGS
              // =================================================
              "approved": true,
              "rejected": false,

              // =================================================
              // REQUEST
              // =================================================
              "request_type": "C-Off",

              // =================================================
              // EMPLOYEE
              // =================================================
              "employee_name": employeeName,
              "employee_email": employeeEmail,
              // "employee_email": "siddheshwar.shingare@en3.ca",

              // =================================================
              // LEAVE
              // =================================================
              "leave_type": "C-Off",
              "leave_duration": "Full Day",
              "half_day_session": "-",

              // =================================================
              // DATES
              // =================================================
              "from_date": formatDate(workedDate),
              "to_date": formatDate(workedDate),

              // =================================================
              // DAYS
              // =================================================
              "days": coffDays.toString(),

              // =================================================
              // C-OFF SPECIFIC
              // =================================================
              "worked_dates": formatDate(workedDate),

              // =================================================
              // OTHER
              // =================================================
              "emergency": "No",
              "reason": data['reason']?.toString() ?? "-",

              // =================================================
              // STATUS
              // =================================================
              "status": "Approved",
              "admin_remarks": "-",
            },
            emailjs.Options(
              publicKey: '8erlfJzc6WZtfnz0o',
              privateKey: 'wRTOsFZnkQi6yxQX7D-rF',
            ),
          );

          debugPrint(
            "C-Off approval email sent: "
            "${response.status} - ${response.text}",
          );
        } else {
          debugPrint("C-Off approval email NOT sent: employee email is empty.");
        }
      } catch (emailError) {
        debugPrint("C-Off approval email failed: $emailError");
      }
      if (!mounted) return;

      showMessage(
        "C-Off approved successfully. $coffDays C-Off added.",
        color: Colors.green,
      );
    } catch (e) {
      if (!mounted) return;

      showMessage(
        e.toString().replaceFirst("Exception: ", ""),
        color: Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // ==========================================================
  // REJECT C-OFF
  // ==========================================================

  Future<void> rejectCOff(String requestId, Map<String, dynamic> data) async {
    if (loading) return;

    final employeeName = data['employeeName']?.toString() ?? "Employee";

    final workedDate = data['workedDate']?.toString() ?? "";

    final reasonController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Reject C-Off"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "$employeeName\n"
                "${formatDate(workedDate)}",
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "Rejection reason",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text("Reject"),
            ),
          ],
        );
      },
    );

    final rejectionReason = reasonController.text.trim();

    reasonController.dispose();

    if (result != true) {
      return;
    }

    try {
      setState(() {
        loading = true;
      });

      final hrUser = FirebaseAuth.instance.currentUser;

      if (hrUser == null) {
        throw Exception("HR user is not logged in.");
      }

      final requestRef = FirebaseFirestore.instance
          .collection('coff_requests')
          .doc(requestId);

      // ======================================================
      // TRANSACTION
      // ======================================================

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(requestRef);

        if (!snapshot.exists) {
          throw Exception("C-Off request no longer exists.");
        }

        final requestData = snapshot.data();

        if (requestData == null) {
          throw Exception("Invalid C-Off request.");
        }

        final currentStatus = requestData['status']?.toString() ?? "";

        if (currentStatus != "Pending") {
          throw Exception("This request has already been $currentStatus.");
        }

        transaction.update(requestRef, {
          "status": "Rejected",
          "rejectedAt": FieldValue.serverTimestamp(),
          "rejectedBy": hrUser.uid,
          "rejectionReason": rejectionReason.isEmpty
              ? "Rejected by HR"
              : rejectionReason,
        });
      });

      // ======================================================
      // NOTIFICATION
      // ======================================================

      final uid = data['uid']?.toString();

      if (uid != null && uid.isNotEmpty) {
        await FirebaseFirestore.instance.collection('notifications').add({
          "role": "employee",
          "uid": uid,
          "title": "C-Off Rejected",
          "body":
              "Your C-Off request for ${formatDate(workedDate)} was rejected."
              "${rejectionReason.isEmpty ? "" : " Reason: $rejectionReason"}",
          "isRead": false,
          "createdAt": FieldValue.serverTimestamp(),
        });
      }
      // ======================================================
      // REJECTION EMAIL TO EMPLOYEE
      // ======================================================

      try {
        final employeeEmail = data['employeeEmail']?.toString().trim() ?? "";

        if (employeeEmail.isNotEmpty) {
          await emailjs.send(
            "service_90wr32y",
            "template_b04xilb",
            {
              // "to_email": employeeEmail,
              "to_email": "siddheshwar.shingare@en3.ca",
              // =========================
              // REQUEST
              // =========================
              "request_type": "C-Off",

              // =========================
              // EMPLOYEE
              // =========================
              "employee_name": employeeName,
              "employee_email": employeeEmail,

              // =========================
              // COMMON FIELDS
              // =========================
              "leave_type": "-",
              "leave_duration": "Full Day",
              "half_day_session": "-",

              // =========================
              // DATES
              // =========================
              "from_date": formatDate(workedDate),
              "to_date": formatDate(workedDate),

              // =========================
              // DAYS
              // =========================
              "days": data['coffDays']?.toString() ?? "1",

              // =========================
              // C-OFF SPECIFIC
              // =========================
              "worked_dates": formatDate(workedDate),

              // =========================
              // OTHER
              // =========================
              "emergency": "No",

              "reason": data['reason']?.toString() ?? "-",

              // =========================
              // STATUS
              // =========================
              "status": "Rejected",

              // =========================
              // HR REMARKS
              // =========================
              "admin_remarks": rejectionReason.isEmpty
                  ? "Rejected by HR"
                  : rejectionReason,
            },
            emailjs.Options(
              publicKey: "8erlfJzc6WZtfnz0o",
              privateKey: "wRTOsFZnkQi6yxQX7D-rF",
            ),
          );
        }
      } catch (emailError) {
        debugPrint("C-Off rejection email failed: $emailError");
      }
      if (!mounted) return;

      showMessage("C-Off request rejected.", color: Colors.red);
    } catch (e) {
      if (!mounted) return;

      showMessage(
        e.toString().replaceFirst("Exception: ", ""),
        color: Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // ==========================================================
  // DOUBLE CONVERTER
  // ==========================================================

  double _toDouble(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0;
  }

  // ==========================================================
  // MESSAGE
  // ==========================================================

  void showMessage(String message, {Color color = const Color(0xFF6C2BD9)}) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  // ==========================================================
  // REQUEST CARD
  // ==========================================================

  Widget requestCard(String requestId, Map<String, dynamic> data) {
    final employeeName = data['employeeName']?.toString() ?? "Unknown Employee";

    final employeeEmail = data['employeeEmail']?.toString() ?? "";

    final workedDate = data['workedDate']?.toString() ?? "";

    final dayType = data['dayType']?.toString() ?? "Weekly Off";

    final reason = data['reason']?.toString() ?? "";

    final status = data['status']?.toString() ?? "Pending";

    final coffDays = _toDouble(data['coffDays'] ?? 1);

    Color statusColor;

    if (status == "Approved") {
      statusColor = Colors.green;
    } else if (status == "Rejected") {
      statusColor = Colors.red;
    } else {
      statusColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7E7ED)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 7,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ====================================================
          // EMPLOYEE
          // ====================================================
          Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F0FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person_outline,
                  color: Color(0xFF6C2BD9),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employeeName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    if (employeeEmail.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          employeeEmail,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF888888),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ====================================================
          // DATE
          // ====================================================
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8FC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_month_outlined,
                  size: 21,
                  color: Color(0xFF6C2BD9),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Worked Date",
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF888888),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        formatDate(workedDate),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      "C-Off",
                      style: TextStyle(fontSize: 10, color: Color(0xFF888888)),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      "$coffDays Day",
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6C2BD9),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ====================================================
          // DAY TYPE
          // ====================================================
          Row(
            children: [
              const Icon(
                Icons.event_available_outlined,
                size: 17,
                color: Colors.green,
              ),
              const SizedBox(width: 7),
              Text(
                dayType,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
            ],
          ),

          // ====================================================
          // REASON
          // ====================================================
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 12),

            const Text(
              "Reason",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF777777),
              ),
            ),

            const SizedBox(height: 4),

            Text(
              reason,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF444444),
                height: 1.4,
              ),
            ),
          ],

          // ====================================================
          // ACTIONS
          // ====================================================
          if (status == "Pending") ...[
            const SizedBox(height: 18),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: loading
                        ? null
                        : () {
                            rejectCOff(requestId, data);
                          },
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text("Reject"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: loading
                        ? null
                        : () {
                            approveCOff(requestId, data);
                          },
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text("Approve"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF202020),
        centerTitle: true,

        title: const Text(
          "C-Off Requests",
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),

      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('coff_requests')
              .orderBy('createdAt', descending: true)
              .snapshots(),

          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF6C2BD9)),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    "Unable to load C-Off requests.\n\n"
                    "${snapshot.error}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              );
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.event_available_outlined,
                      size: 55,
                      color: Color(0xFFBDBDBD),
                    ),
                    SizedBox(height: 12),
                    Text(
                      "No C-Off requests",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF777777),
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 25),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];

                return requestCard(doc.id, doc.data());
              },
            );
          },
        ),
      ),
    );
  }
}

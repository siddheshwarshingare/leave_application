//ApplyLeaveScreen LAtest Code

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emailjs/emailjs.dart' as emailjs;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:leave_application/services/email_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emailjs/emailjs.dart' as emailjs;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ApplyCOffScreen extends StatefulWidget {
  const ApplyCOffScreen({super.key});

  @override
  State<ApplyCOffScreen> createState() => _ApplyCOffScreenState();
}

class _ApplyCOffScreenState extends State<ApplyCOffScreen> {
  final formKey = GlobalKey<FormState>();

  final reasonController = TextEditingController();

  String? selectedLeaveType;
  String? halfDaySession;

  DateTime? fromDate;
  DateTime? toDate;

  bool loading = false;
  bool emergency = false;

  /// Full Day / Half Day
  String leaveDuration = "Full Day";

  /// Used only for UI preview
  double totalDays = 0;

  final List<String> leaveTypes = ["Work From Home", "C-Off"];

  // ----------------------------------------------------------
  // DISPOSE
  // ----------------------------------------------------------

  @override
  void dispose() {
    reasonController.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------
  // WEEKLY OFF
  // ----------------------------------------------------------

  bool isWeeklyOff(DateTime date, List weeklyOff) {
    final dayName = [
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday",
      "Saturday",
      "Sunday",
    ][date.weekday - 1];

    return weeklyOff.contains(dayName);
  }

  // ----------------------------------------------------------
  // CALCULATE WORKING DAYS
  // ----------------------------------------------------------

  int calculateWorkingDays(DateTime from, DateTime to, List weeklyOff) {
    int count = 0;

    for (
      DateTime d = from;
      !d.isAfter(to);
      d = d.add(const Duration(days: 1))
    ) {
      if (!isWeeklyOff(d, weeklyOff)) {
        count++;
      }
    }

    return count;
  }

  void updateTotalDaysPreview() {
    if (fromDate == null || toDate == null) {
      setState(() {
        totalDays = 0;
      });
      return;
    }

    if (toDate!.isBefore(fromDate!)) {
      setState(() {
        totalDays = 0;
      });
      return;
    }

    int days = toDate!.difference(fromDate!).inDays + 1;

    setState(() {
      if (leaveDuration == "Half Day") {
        totalDays = days * 0.5;
      } else {
        totalDays = days.toDouble();
      }
    });
  }

  // ----------------------------------------------------------
  // FROM DATE
  // ----------------------------------------------------------

  Future<void> pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      initialDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF6C2BD9),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        fromDate = picked;

        if (toDate != null && toDate!.isBefore(picked)) {
          toDate = null;
        }
      });

      updateTotalDaysPreview();
    }
  }

  // ----------------------------------------------------------
  // TO DATE
  // ----------------------------------------------------------

  Future<void> pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: fromDate ?? DateTime.now(),
      lastDate: DateTime(2030),
      initialDate: fromDate ?? DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF6C2BD9),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        toDate = picked;
      });

      updateTotalDaysPreview();
    }
  }

  // ----------------------------------------------------------
  // DUPLICATE LEAVE CHECK
  // ----------------------------------------------------------

  Future<bool> hasDuplicateLeave(String uid, DateTime from, DateTime to) async {
    final snap = await FirebaseFirestore.instance
        .collection('leave_requests')
        .where('uid', isEqualTo: uid)
        .get();

    for (final doc in snap.docs) {
      final existingFrom = (doc['fromDate'] as Timestamp).toDate();

      final existingTo = (doc['toDate'] as Timestamp).toDate();

      final overlap = !(to.isBefore(existingFrom) || from.isAfter(existingTo));

      if (overlap) {
        return true;
      }
    }

    return false;
  }

  // ----------------------------------------------------------
  // DATE FORMAT
  // ----------------------------------------------------------

  String formatDate(DateTime? date) {
    if (date == null) {
      return "";
    }

    return "${date.day.toString().padLeft(2, '0')} "
        "${_monthName(date.month)} "
        "${date.year}";
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

  // ----------------------------------------------------------
  // LEAVE BALANCE
  // ----------------------------------------------------------

  Future<void> submitLeave() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    if (fromDate == null || toDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please select dates")));
      return;
    }
    //
    // if (leaveDuration == "Half Day" && halfDaySession == null) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     const SnackBar(
    //       content: Text("Please select First Half or Second Half"),
    //     ),
    //   );
    //   return;
    // }

    try {
      setState(() {
        loading = true;
      });

      // ------------------------------------------------------
      // CURRENT USER
      // ------------------------------------------------------

      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception("User not logged in");
      }

      final uid = user.uid;

      // ------------------------------------------------------
      // FETCH LEAVE APPROVERS
      // ------------------------------------------------------

      final approverDoc = await FirebaseFirestore.instance
          .collection('email_recipients')
          .doc('leave_approvers')
          .get();

      if (!approverDoc.exists) {
        throw Exception("Leave approver configuration not found");
      }

      if (approverDoc['active'] != true) {
        throw Exception("Leave email notifications are disabled");
      }

      final List<String> notifyEmails = [];

      final primaryEmail = approverDoc['primaryEmail']?.toString().trim();

      final secondaryEmail = approverDoc['secondaryEmail']?.toString().trim();

      if (primaryEmail != null && primaryEmail.isNotEmpty) {
        notifyEmails.add(primaryEmail);
      }

      if (secondaryEmail != null && secondaryEmail.isNotEmpty) {
        notifyEmails.add(secondaryEmail);
      }

      // ------------------------------------------------------
      // DUPLICATE CHECK
      // ------------------------------------------------------

      final duplicate = await hasDuplicateLeave(uid, fromDate!, toDate!);

      if (duplicate) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Leave already applied for these dates"),
          ),
        );

        return;
      }

      // ------------------------------------------------------
      // FETCH USER
      // ------------------------------------------------------

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!userDoc.exists) {
        throw Exception("User information not found");
      }

      // ------------------------------------------------------
      // WEEKLY OFF
      // ------------------------------------------------------

      final List weeklyOff = userDoc['weeklyOff'] ?? [];

      // ------------------------------------------------------
      // CHECK WEEKLY OFF
      // ------------------------------------------------------

      bool selectedContainsWeeklyOff = false;

      for (
        DateTime d = fromDate!;
        !d.isAfter(toDate!);
        d = d.add(const Duration(days: 1))
      ) {
        if (isWeeklyOff(d, weeklyOff)) {
          selectedContainsWeeklyOff = true;
          break;
        }
      }

      if (selectedContainsWeeklyOff) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "This is your weekly off. Please select another date.",
            ),
          ),
        );

        return;
      }

      // ------------------------------------------------------
      // CALCULATE WORKING DAYS
      // ------------------------------------------------------

      final workingDays = calculateWorkingDays(fromDate!, toDate!, weeklyOff);

      if (workingDays <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Selected dates are weekly off / holidays"),
          ),
        );

        return;
      }

      // ------------------------------------------------------
      // CALCULATE REQUESTED DAYS
      //
      // FULL DAY  -> 1.0 per working day
      // HALF DAY  -> 0.5 per selected working day
      // ------------------------------------------------------

      final double requestedDays;

      if (leaveDuration == "Half Day") {
        requestedDays = workingDays * 0.5;
      } else {
        requestedDays = workingDays.toDouble();
      }

      // ------------------------------------------------------
      // LEAVE BALANCE
      // ------------------------------------------------------

      final balanceDoc = await FirebaseFirestore.instance
          .collection('toatl_leave')
          .doc(uid)
          .get();

      if (!balanceDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Leave balance not found")),
        );

        return;
      }

      final double cl = double.tryParse(balanceDoc['Cl'].toString()) ?? 0;

      final double sl = double.tryParse(balanceDoc['Sl'].toString()) ?? 0;

      // ------------------------------------------------------
      // CASUAL LEAVE BALANCE
      // ------------------------------------------------------

      if (selectedLeaveType == "Casual Leave" && requestedDays > cl) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Only $cl CL remaining")));

        return;
      }

      // ------------------------------------------------------
      // SICK LEAVE BALANCE
      // ------------------------------------------------------

      if (selectedLeaveType == "Sick Leave" && requestedDays > sl) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Only $sl SL remaining")));

        return;
      }

      // ------------------------------------------------------
      // SAVE LEAVE REQUEST
      // ------------------------------------------------------

      await FirebaseFirestore.instance.collection('leave_requests').add({
        "uid": uid,
        "employeeName": userDoc['name'],
        "employeeEmail": userDoc['email'],

        "leaveType": selectedLeaveType,

        "leaveDuration": leaveDuration,

        "halfDaySession": leaveDuration == "Half Day" ? halfDaySession : null,

        // 0.5 for half day
        // 1.0 for full day
        "days": requestedDays,

        "fromDate": Timestamp.fromDate(fromDate!),

        "toDate": Timestamp.fromDate(toDate!),

        "reason": reasonController.text.trim(),

        "emergency": emergency,

        "status": "Pending",

        "createdAt": Timestamp.now(),
      });

      // ------------------------------------------------------
      // SEND EMAIL
      // ------------------------------------------------------

      for (final receiverEmail in notifyEmails) {
        try {
          await emailjs.send(
            'service_90wr32y',
            'template_mga5feh',
            {
              'to_email': receiverEmail,
              'employee_name': userDoc['name'],
              'employee_email': userDoc['email'],
              'leave_type': selectedLeaveType,
              'from_date': fromDate.toString().split(' ')[0],
              'to_date': toDate.toString().split(' ')[0],
              'days': requestedDays.toString(),
              'reason': reasonController.text.trim(),
            },
            emailjs.Options(
              publicKey: '8erlfJzc6WZtfnz0o',
              privateKey: const String.fromEnvironment('wRTOsFZnkQi6yxQX7D-rF'),
            ),
          );

          debugPrint("Leave email sent to: $receiverEmail");
        } catch (emailError) {
          debugPrint("Failed to send leave email: $emailError");
        }
      }

      // ------------------------------------------------------
      // ADMIN NOTIFICATION
      // ------------------------------------------------------

      await FirebaseFirestore.instance.collection('notifications').add({
        "role": "admin",
        "uid": null,
        "title": "New Leave Request",
        "body": "${userDoc['name']} applied for $selectedLeaveType leave",
        "isRead": false,
        "createdAt": Timestamp.now(),
      });

      // ------------------------------------------------------
      // SUCCESS
      // ------------------------------------------------------

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Leave Applied Successfully")),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // ==========================================================
  // UI HELPERS
  // ==========================================================

  Widget sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 7),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF777777),
        ),
      ),
    );
  }

  Widget fieldContainer({
    required Widget child,
    VoidCallback? onTap,
    EdgeInsets padding = const EdgeInsets.symmetric(
      horizontal: 14,
      vertical: 13,
    ),
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8E8EE)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.035),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      ),
    );
  }

  Widget calendarIcon() {
    return const Icon(
      Icons.calendar_month_outlined,
      size: 21,
      color: Color(0xFF777777),
    );
  }

  Widget dateField({
    required String title,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return fieldContainer(
      onTap: onTap,
      child: Row(
        children: [
          calendarIcon(),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF888888),
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  date == null ? "Select date" : formatDate(date),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: date == null
                        ? const Color(0xFF999999)
                        : const Color(0xFF292929),
                  ),
                ),
              ],
            ),
          ),

          calendarIcon(),
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

        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 19),
          onPressed: () {
            Navigator.pop(context);
          },
        ),

        title: const Text(
          "Apply Request",
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),

      body: SafeArea(
        child: Form(
          key: formKey,

          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 25),

            children: [
              // =================================================
              // LEAVE TYPE
              // =================================================
              sectionLabel("Leave Type"),

              DropdownButtonFormField<String>(
                value: selectedLeaveType,

                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,

                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),

                  prefixIcon: const Icon(
                    Icons.work_outline,
                    color: Color(0xFF6C2BD9),
                    size: 21,
                  ),

                  suffixIcon: const Icon(
                    Icons.keyboard_arrow_down,
                    size: 21,
                    color: Color(0xFF777777),
                  ),

                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),

                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE8E8EE)),
                  ),

                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF6C2BD9),
                      width: 1.2,
                    ),
                  ),
                ),

                hint: const Text(
                  "Select Leave Type",
                  style: TextStyle(fontSize: 14, color: Color(0xFF999999)),
                ),

                items: leaveTypes.map((type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(
                      type,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),

                onChanged: (value) {
                  setState(() {
                    selectedLeaveType = value;
                  });
                },

                validator: (value) {
                  if (value == null) {
                    return "Select Leave Type";
                  }

                  return null;
                },
              ),

              const SizedBox(height: 17),

              // =================================================
              // FROM DATE
              // =================================================
              sectionLabel("From Date"),

              dateField(
                title: "From Date",
                date: fromDate,
                onTap: pickFromDate,
              ),

              const SizedBox(height: 13),

              // =================================================
              // TO DATE
              // =================================================
              sectionLabel("To Date"),

              dateField(title: "To Date", date: toDate, onTap: pickToDate),

              const SizedBox(height: 17),

              // =================================================
              // HALF DAY
              // =================================================

              // =================================================
              // HALF DAY SESSION
              // =================================================
              // if (leaveDuration == "Half Day") ...[
              //   const SizedBox(height: 15),
              //
              //   sectionLabel("Half Day Session"),
              //
              //   fieldContainer(
              //     child: Row(
              //       children: [
              //         Expanded(
              //           child: RadioListTile<String>(
              //             contentPadding: EdgeInsets.zero,
              //             dense: true,
              //             visualDensity: VisualDensity.compact,
              //             title: const Text(
              //               "First Half",
              //               style: TextStyle(fontSize: 13),
              //             ),
              //             value: "First Half",
              //             groupValue: halfDaySession,
              //             activeColor: const Color(0xFF6C2BD9),
              //             onChanged: (value) {
              //               setState(() {
              //                 halfDaySession = value;
              //               });
              //             },
              //           ),
              //         ),
              //
              //         Expanded(
              //           child: RadioListTile<String>(
              //             contentPadding: EdgeInsets.zero,
              //             dense: true,
              //             visualDensity: VisualDensity.compact,
              //             title: const Text(
              //               "Second Half",
              //               style: TextStyle(fontSize: 13),
              //             ),
              //             value: "Second Half",
              //             groupValue: halfDaySession,
              //             activeColor: const Color(0xFF6C2BD9),
              //             onChanged: (value) {
              //               setState(() {
              //                 halfDaySession = value;
              //               });
              //             },
              //           ),
              //         ),
              //       ],
              //     ),
              //   ),
              // ],
              //
              // const SizedBox(height: 17),

              // =================================================
              // REASON
              // =================================================
              sectionLabel("Reason"),

              TextFormField(
                controller: reasonController,
                maxLines: 4,

                style: const TextStyle(fontSize: 14),

                decoration: InputDecoration(
                  hintText: "Enter reason",
                  hintStyle: const TextStyle(
                    color: Color(0xFF999999),
                    fontSize: 14,
                  ),

                  filled: true,
                  fillColor: Colors.white,

                  contentPadding: const EdgeInsets.all(14),

                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),

                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE8E8EE)),
                  ),

                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF6C2BD9)),
                  ),
                ),

                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Enter reason";
                  }

                  if (value.trim().length < 10) {
                    return "Reason too short";
                  }

                  return null;
                },
              ),

              const SizedBox(height: 17),

              // =================================================
              // EMERGENCY LEAVE
              // =================================================
              // sectionLabel("Emergency Leave"),
              // fieldContainer(
              //   padding: const EdgeInsets.symmetric(
              //     horizontal: 14,
              //     vertical: 3,
              //   ),
              //   child: Row(
              //     children: [
              //       const Icon(
              //         Icons.emergency_outlined,
              //         color: Color(0xFF777777),
              //         size: 21,
              //       ),
              //
              //       const SizedBox(width: 10),
              //
              //       const Expanded(
              //         child: Text(
              //           "Emergency Leave",
              //           style: TextStyle(
              //             fontSize: 14,
              //             fontWeight: FontWeight.w500,
              //           ),
              //         ),
              //       ),
              //
              //       Switch(
              //         value: emergency,
              //         activeColor: const Color(0xFF6C2BD9),
              //         onChanged: (value) {
              //           setState(() {
              //             emergency = value;
              //           });
              //         },
              //       ),
              //     ],
              //   ),
              // ),
              const SizedBox(height: 17),

              // =================================================
              // TOTAL DAYS CARD
              // =================================================
              if (fromDate != null && toDate != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),

                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F0FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5DEFF)),
                  ),

                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Total Days",
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF777777),
                              ),
                            ),

                            const SizedBox(height: 4),

                            Text(
                              totalDays % 1 == 0
                                  ? "${totalDays.toInt()} ${totalDays == 1 ? "Day" : "Days"}"
                                  : "$totalDays Days",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF292929),
                              ),
                            ),
                          ],
                        ),
                      ),

                      Container(
                        width: 1,
                        height: 35,
                        color: const Color(0xFFDAD4EE),
                      ),

                      const SizedBox(width: 20),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "WFH or C-Off",
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF777777),
                              ),
                            ),

                            const SizedBox(height: 4),

                            Text(
                              selectedLeaveType.toString(),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF292929),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 50),

              // =================================================
              // SUBMIT BUTTON
              // =================================================
              SizedBox(
                height: 52,
                width: double.infinity,

                child: ElevatedButton(
                  onPressed: loading ? null : submitLeave,

                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C2BD9),
                    foregroundColor: Colors.white,

                    disabledBackgroundColor: const Color(0xFFB8A5E8),

                    elevation: 0,

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),

                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),

                    child: loading
                        ? const SizedBox(
                            key: ValueKey("loading"),
                            height: 23,
                            width: 23,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            "Submit Request",
                            key: ValueKey("submit"),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

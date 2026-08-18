import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emailjs/emailjs.dart' as emailjs;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ApplyLeaveScreen extends StatefulWidget {
  const ApplyLeaveScreen({super.key});

  @override
  State<ApplyLeaveScreen> createState() => _ApplyLeaveScreenState();
}

class _ApplyLeaveScreenState extends State<ApplyLeaveScreen> {
  final formKey = GlobalKey<FormState>();
  final reasonController = TextEditingController();

  double totalDays = 0;

  /// Employee-specific weekly offs loaded from Firebase.
  /// Example:
  /// ["Saturday", "Sunday"]
  List<String> employeeWeeklyOff = [];

  String? selectedLeaveType;
  String? halfDaySession;

  DateTime? fromDate;
  DateTime? toDate;

  bool loading = false;
  bool emergency = false;

  String leaveDuration = "Full Day";

  final List<String> leaveTypes = [
    "Casual Leave",
    "Sick Leave",
    "Paid Leave",
    "LWP",
  ];

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    /// Load employee weekly offs as soon as screen opens.
    loadEmployeeWeeklyOff();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    reasonController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD EMPLOYEE WEEKLY OFF
  // ============================================================

  Future<void> loadEmployeeWeeklyOff() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        return;
      }

      final DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        return;
      }

      final Map<String, dynamic>? data =
          userDoc.data() as Map<String, dynamic>?;

      if (data == null) {
        return;
      }

      final dynamic weeklyOffData = data['weeklyOff'];

      List<String> weeklyOff = [];

      if (weeklyOffData is List) {
        weeklyOff = weeklyOffData
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }

      debugPrint("EMPLOYEE WEEKLY OFF = $weeklyOff");

      if (!mounted) {
        return;
      }

      setState(() {
        employeeWeeklyOff = weeklyOff;
      });

      /// Recalculate if dates were already selected.
      calculateTotalDays();
    } catch (e) {
      debugPrint("Failed to load weekly off: $e");
    }
  }

  // ============================================================
  // CHECK WEEKLY OFF
  // ============================================================

  bool isWeeklyOff(DateTime date, List<String> weeklyOff) {
    const List<String> dayNames = [
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday",
      "Saturday",
      "Sunday",
    ];

    final String dayName = dayNames[date.weekday - 1];

    /// IMPORTANT:
    /// Use the weeklyOff parameter.
    /// Do NOT use employeeWeeklyOff here.
    return weeklyOff.contains(dayName);
  }

  // ============================================================
  // CALCULATE WORKING DAYS
  // ============================================================

  int calculateWorkingDays(DateTime from, DateTime to, List<String> weeklyOff) {
    int workingDays = 0;

    DateTime current = DateTime(from.year, from.month, from.day);

    final DateTime end = DateTime(to.year, to.month, to.day);

    while (!current.isAfter(end)) {
      /// Only count working days.
      if (!isWeeklyOff(current, weeklyOff)) {
        workingDays++;
      }

      current = current.add(const Duration(days: 1));
    }

    return workingDays;
  }

  // ============================================================
  // CALCULATE FINAL LEAVE DAYS
  // ============================================================

  double calculateLeaveDays(
    DateTime from,
    DateTime to,
    List<String> weeklyOff,
  ) {
    final int workingDays = calculateWorkingDays(from, to, weeklyOff);

    if (workingDays <= 0) {
      return 0;
    }

    /// Half day means deduct 0.5 from the
    /// total number of working days.
    ///
    /// Examples:
    ///
    /// 1 working day -> 0.5
    /// 2 working days -> 1.5
    /// 3 working days -> 2.5
    ///
    if (leaveDuration == "Half Day Only") {
      return workingDays - 0.5;
    }

    /// Full day.
    return workingDays.toDouble();
  }

  // ============================================================
  // CALCULATE TOTAL DAYS FOR UI
  // ============================================================

  void calculateTotalDays() {
    if (fromDate == null || toDate == null) {
      if (mounted) {
        setState(() {
          totalDays = 0;
        });
      }

      return;
    }

    final double calculatedDays = calculateLeaveDays(
      fromDate!,
      toDate!,
      employeeWeeklyOff,
    );

    if (mounted) {
      setState(() {
        totalDays = calculatedDays;
      });
    }
  }

  // ============================================================
  // DUPLICATE LEAVE CHECK
  // ============================================================

  Future<bool> hasDuplicateLeave(String uid, DateTime from, DateTime to) async {
    final QuerySnapshot snap = await FirebaseFirestore.instance
        .collection('leave_requests')
        .where('uid', isEqualTo: uid)
        .get();

    final DateTime selectedFrom = DateTime(from.year, from.month, from.day);

    final DateTime selectedTo = DateTime(to.year, to.month, to.day);

    for (final doc in snap.docs) {
      final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

      final String status = data['status']?.toString().toLowerCase() ?? '';

      /// Rejected/cancelled leaves don't block dates.
      if (status == 'rejected' || status == 'cancelled') {
        continue;
      }

      if (data['fromDate'] == null || data['toDate'] == null) {
        continue;
      }

      final DateTime existingFrom = (data['fromDate'] as Timestamp).toDate();

      final DateTime existingTo = (data['toDate'] as Timestamp).toDate();

      final DateTime existingFromDate = DateTime(
        existingFrom.year,
        existingFrom.month,
        existingFrom.day,
      );

      final DateTime existingToDate = DateTime(
        existingTo.year,
        existingTo.month,
        existingTo.day,
      );

      final bool overlap =
          !(selectedTo.isBefore(existingFromDate) ||
              selectedFrom.isAfter(existingToDate));

      if (overlap) {
        return true;
      }
    }

    return false;
  }

  // ============================================================
  // PICK FROM DATE
  // ============================================================

  Future<void> pickFromDate() async {
    final DateTime today = DateTime.now();

    final DateTime? picked = await showDatePicker(
      context: context,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: DateTime(2030),
      initialDate: fromDate ?? today,
    );

    if (picked == null) {
      return;
    }

    setState(() {
      fromDate = DateTime(picked.year, picked.month, picked.day);

      /// Reset To Date if it is before From Date.
      if (toDate != null && toDate!.isBefore(fromDate!)) {
        toDate = null;
      }
    });

    calculateTotalDays();
  }

  // ============================================================
  // PICK TO DATE
  // ============================================================

  Future<void> pickToDate() async {
    final DateTime today = DateTime.now();

    final DateTime? picked = await showDatePicker(
      context: context,
      firstDate: fromDate ?? today,
      lastDate: DateTime(2030),
      initialDate: toDate ?? fromDate ?? today,
    );

    if (picked == null) {
      return;
    }

    setState(() {
      toDate = DateTime(picked.year, picked.month, picked.day);
    });

    calculateTotalDays();
  }

  // ============================================================
  // SUBMIT LEAVE
  // ============================================================

  Future<void> submitLeave() async {
    if (loading) {
      return;
    }

    // ==========================================================
    // FORM VALIDATION
    // ==========================================================

    if (!formKey.currentState!.validate()) {
      return;
    }

    // ==========================================================
    // DATE VALIDATION
    // ==========================================================

    if (fromDate == null || toDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select From Date and To Date")),
      );

      return;
    }

    if (toDate!.isBefore(fromDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("To Date cannot be before From Date")),
      );

      return;
    }

    // ==========================================================
    // HALF DAY VALIDATION
    // ==========================================================

    if (leaveDuration == "Half Day Only" && halfDaySession == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select First Half or Second Half"),
        ),
      );

      return;
    }

    try {
      setState(() {
        loading = true;
      });

      // ==========================================================
      // CURRENT USER
      // ==========================================================

      final User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        throw Exception("User is not logged in");
      }

      final String uid = currentUser.uid;

      // ==========================================================
      // FETCH EMPLOYEE DATA
      // ==========================================================

      final DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!userDoc.exists) {
        throw Exception("Employee data not found");
      }

      final Map<String, dynamic> userData =
          userDoc.data() as Map<String, dynamic>;

      // ==========================================================
      // GET EMPLOYEE WEEKLY OFF FROM FIREBASE
      // ==========================================================

      final dynamic weeklyOffData = userData['weeklyOff'];

      final List<String> weeklyOff = weeklyOffData is List
          ? weeklyOffData
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList()
          : <String>[];

      debugPrint("EMPLOYEE WEEKLY OFF = $weeklyOff");

      // Update local value as well.
      if (mounted) {
        setState(() {
          employeeWeeklyOff = weeklyOff;
        });
      }

      // ==========================================================
      // DUPLICATE LEAVE CHECK
      // ==========================================================

      final bool duplicate = await hasDuplicateLeave(uid, fromDate!, toDate!);

      if (duplicate) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Leave already applied for these dates"),
          ),
        );

        return;
      }

      // ==========================================================
      // CALCULATE WORKING DAYS
      // ==========================================================

      final int workingDays = calculateWorkingDays(
        fromDate!,
        toDate!,
        weeklyOff,
      );

      debugPrint("WORKING DAYS = $workingDays");

      // ==========================================================
      // IF ONLY WEEKLY OFF DAYS WERE SELECTED
      // ==========================================================

      if (workingDays <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Selected dates contain only weekly off days"),
          ),
        );

        return;
      }

      // ==========================================================
      // FINAL LEAVE DAYS
      // ==========================================================

      final double requestedDays = leaveDuration == "Half Day Only"
          ? workingDays - 0.5
          : workingDays.toDouble();

      debugPrint("FINAL LEAVE DAYS = $requestedDays");

      // ==========================================================
      // LEAVE BALANCE
      // ==========================================================

      final DocumentSnapshot balanceDoc = await FirebaseFirestore.instance
          .collection('toatl_leave')
          .doc(uid)
          .get();

      if (!balanceDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Leave balance not found")),
        );

        return;
      }

      final Map<String, dynamic> balanceData =
          balanceDoc.data() as Map<String, dynamic>;

      final double cl =
          double.tryParse(balanceData['Cl']?.toString() ?? '0') ?? 0;

      final double sl =
          double.tryParse(balanceData['Sl']?.toString() ?? '0') ?? 0;

      // ==========================================================
      // CASUAL LEAVE BALANCE
      // ==========================================================

      if (selectedLeaveType == "Casual Leave" && requestedDays > cl) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Only $cl CL remaining")));

        return;
      }

      // ==========================================================
      // SICK LEAVE BALANCE
      // ==========================================================

      if (selectedLeaveType == "Sick Leave" && requestedDays > sl) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Only $sl SL remaining")));

        return;
      }

      // ==========================================================
      // SAVE LEAVE REQUEST
      // ==========================================================

      final Map<String, dynamic> leaveData = {
        "uid": uid,

        "employeeName": userData['name']?.toString() ?? "",

        "employeeEmail": userData['email']?.toString() ?? "",

        "leaveType": selectedLeaveType,

        "leaveDuration": leaveDuration,

        /// IMPORTANT
        ///
        /// Full Day:
        /// 1.0
        /// 2.0
        /// 3.0
        ///
        /// Half Day:
        /// 0.5
        /// 1.5
        /// 2.5
        "days": requestedDays,

        "fromDate": Timestamp.fromDate(fromDate!),

        "toDate": Timestamp.fromDate(toDate!),

        "reason": reasonController.text.trim(),

        "emergency": emergency,

        "halfDaySession": leaveDuration == "Half Day Only"
            ? halfDaySession
            : null,

        "status": "Pending",

        "createdAt": Timestamp.now(),
      };

      await FirebaseFirestore.instance
          .collection('leave_requests')
          .add(leaveData);

      // ==========================================================
      // FETCH APPROVER EMAILS
      // ==========================================================

      final DocumentSnapshot approverDoc = await FirebaseFirestore.instance
          .collection('email_recipients')
          .doc('leave_approvers')
          .get();

      final List<String> notifyEmails = [];

      if (approverDoc.exists) {
        final Map<String, dynamic> approverData =
            approverDoc.data() as Map<String, dynamic>;

        if (approverData['active'] == true) {
          final String? primaryEmail = approverData['primaryEmail']
              ?.toString()
              .trim();

          final String? secondaryEmail = approverData['secondaryEmail']
              ?.toString()
              .trim();

          if (primaryEmail != null && primaryEmail.isNotEmpty) {
            notifyEmails.add(primaryEmail);
          }

          if (secondaryEmail != null && secondaryEmail.isNotEmpty) {
            notifyEmails.add(secondaryEmail);
          }
        }
      }

      debugPrint("Leave notification emails: $notifyEmails");

      // ==========================================================
      // SEND EMAIL
      // ==========================================================

      for (final String receiverEmail in notifyEmails) {
        try {
          await emailjs.send(
            'service_90wr32y',
            'template_mga5feh',
            {
              'to_email': receiverEmail,

              'employee_name': userData['name']?.toString() ?? "",

              'employee_email': userData['email']?.toString() ?? "",

              'leave_type': selectedLeaveType ?? "",

              'leave_duration': leaveDuration,

              'half_day_session': leaveDuration == "Half Day Only"
                  ? halfDaySession ?? ""
                  : "",

              'from_date': _formatDate(fromDate!),

              'to_date': _formatDate(toDate!),

              'days': _formatLeaveDays(requestedDays),

              'reason': reasonController.text.trim(),
            },
            emailjs.Options(
              publicKey: '8erlfJzc6WZtfnz0o',

              privateKey: 'wRTOsFZnkQi6yxQX7D-rF',
            ),
          );

          debugPrint("Leave email sent to: $receiverEmail");
        } catch (emailError) {
          debugPrint(
            "Failed to send leave email to "
            "$receiverEmail: $emailError",
          );
        }
      }

      // ==========================================================
      // ADMIN NOTIFICATION
      // ==========================================================

      await FirebaseFirestore.instance.collection('notifications').add({
        "role": "admin",
        "uid": null,
        "title": "New Leave Request",
        "body":
            "${userData['name']} applied for "
            "$selectedLeaveType "
            "(${_formatLeaveDays(requestedDays)} day(s))",
        "isRead": false,
        "createdAt": Timestamp.now(),
      });

      // ==========================================================
      // SUCCESS
      // ==========================================================

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Leave Applied Successfully")),
      );

      Navigator.pop(context);
    } catch (e) {
      debugPrint("Submit leave error: $e");

      if (!mounted) {
        return;
      }

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

  // ============================================================
  // FORMAT LEAVE DAYS
  // ============================================================

  String _formatLeaveDays(double days) {
    if (days % 1 == 0) {
      return days.toInt().toString();
    }

    return days.toString();
  }

  // ============================================================
  // SECTION LABEL
  // ============================================================

  Widget _sectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 3, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF172033),
        ),
      ),
    );
  }

  // ============================================================
  // DATE CARD
  // ============================================================

  Widget _dateCard({
    required String title,
    required DateTime? date,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final bool selected = date != null;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFFC4B5FD) : const Color(0xFFE5E7EB),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0E9FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: const Color(0xFF6D28D9)),
                ),

                const Spacer(),

                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Text(
              title,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),

            const SizedBox(height: 4),

            Text(
              selected
                  ? "${date.day.toString().padLeft(2, '0')} "
                        "${_monthName(date.month)} "
                        "${date.year}"
                  : "Select date",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected
                    ? const Color(0xFF172033)
                    : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MONTH NAME
  // ============================================================

  String _monthName(int month) {
    const List<String> months = [
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

  // ============================================================
  // FORMAT DATE
  // ============================================================

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/"
        "${date.month.toString().padLeft(2, '0')}/"
        "${date.year}";
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),

      appBar: AppBar(
        title: const Text(
          "Apply Leave",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),

      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Form(
          key: formKey,
          child: ListView(
            physics: const BouncingScrollPhysics(),
            children: [
              // ========================================================
              // LEAVE TYPE
              // ========================================================
              _sectionLabel("Leave Type"),

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.03),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: DropdownButtonFormField<String>(
                  value: selectedLeaveType,

                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF64748B),
                  ),

                  decoration: InputDecoration(
                    prefixIcon: Container(
                      margin: const EdgeInsets.all(10),
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0E9FF),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.event_note_rounded,
                        color: Color(0xFF6D28D9),
                        size: 20,
                      ),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 15,
                    ),
                    labelText: "Leave Type",
                    labelStyle: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),

                  items: leaveTypes.map((type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(
                        type,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF172033),
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
              ),

              const SizedBox(height: 18),

              // ========================================================
              // LEAVE DURATION
              // ========================================================
              _sectionLabel("Leave Duration"),

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.03),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: DropdownButtonFormField<String>(
                  value: leaveDuration,

                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF64748B),
                  ),

                  decoration: InputDecoration(
                    prefixIcon: Container(
                      margin: const EdgeInsets.all(10),
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.access_time_rounded,
                        color: Color(0xFF2563EB),
                        size: 20,
                      ),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 15,
                    ),
                    labelText: "Duration",
                    labelStyle: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),

                  items: const [
                    DropdownMenuItem(
                      value: "Full Day",
                      child: Text(
                        "Full Day",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: "Half Day Only",
                      child: Text(
                        "Half Day Only",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],

                  onChanged: (value) {
                    setState(() {
                      leaveDuration = value!;

                      if (leaveDuration == "Full Day") {
                        halfDaySession = null;
                      }
                    });

                    calculateTotalDays();
                  },
                ),
              ),

              // ========================================================
              // HALF DAY SESSION
              // ========================================================
              if (leaveDuration == "Half Day Only") ...[
                const SizedBox(height: 18),

                _sectionLabel("Half Day Session"),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: halfDaySession,

                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF64748B),
                    ),

                    decoration: InputDecoration(
                      prefixIcon: Container(
                        margin: const EdgeInsets.all(10),
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(
                          Icons.timelapse_rounded,
                          color: Color(0xFFEA580C),
                          size: 20,
                        ),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 15,
                      ),
                      labelText: "Session",
                      labelStyle: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),

                    items: const [
                      DropdownMenuItem(
                        value: "First Half",
                        child: Text(
                          "First Half",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: "Second Half",
                        child: Text(
                          "Second Half",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],

                    onChanged: (value) {
                      setState(() {
                        halfDaySession = value;
                      });
                    },

                    validator: (value) {
                      if (leaveDuration == "Half Day Only" && value == null) {
                        return "Select Session";
                      }

                      return null;
                    },
                  ),
                ),
              ],

              const SizedBox(height: 18),

              // ========================================================
              // REASON
              // ========================================================
              _sectionLabel("Reason"),

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: TextFormField(
                  controller: reasonController,

                  maxLines: 4,

                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF172033),
                  ),

                  decoration: const InputDecoration(
                    hintText: "Tell us why you are taking leave...",
                    hintStyle: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 13,
                    ),
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(left: 14, right: 8, top: 14),
                      child: Icon(
                        Icons.notes_rounded,
                        color: Color(0xFF6D28D9),
                      ),
                    ),
                    prefixIconConstraints: BoxConstraints(
                      minWidth: 45,
                      minHeight: 45,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
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
              ),

              const SizedBox(height: 18),

              // ========================================================
              // DATES
              // ========================================================
              _sectionLabel("Leave Dates"),

              Row(
                children: [
                  Expanded(
                    child: _dateCard(
                      title: "From Date",
                      date: fromDate,
                      icon: Icons.calendar_today_rounded,
                      onTap: pickFromDate,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: _dateCard(
                      title: "To Date",
                      date: toDate,
                      icon: Icons.event_rounded,
                      onTap: pickToDate,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // ========================================================
              // SUMMARY
              // ========================================================
              if (fromDate != null && toDate != null) _buildLeaveSummary(),

              if (fromDate != null && toDate != null)
                const SizedBox(height: 18),

              // ========================================================
              // INFO
              // ========================================================
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFF5F3FF), Color(0xFFEDE9FE)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFDDD6FE)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.info_outline_rounded,
                        color: Color(0xFF6D28D9),
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Leave Request",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF312E81),
                            ),
                          ),

                          const SizedBox(height: 3),

                          Text(
                            employeeWeeklyOff.isEmpty
                                ? "Loading weekly off..."
                                : "Weekly offs (${employeeWeeklyOff.join(', ')}) are automatically excluded.",
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // ========================================================
              // SUBMIT BUTTON
              // ========================================================
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: loading ? null : submitLeave,

                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: const Color(0xFF6D28D9),
                    disabledBackgroundColor: const Color(0xFFB8A5E8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),

                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: loading
                        ? const SizedBox(
                            key: ValueKey("loading"),
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Row(
                            key: ValueKey("submit"),
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: 19,
                              ),
                              SizedBox(width: 9),
                              Text(
                                "Submit Leave Request",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              const Center(
                child: Text(
                  "Your request will be sent for approval",
                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // LEAVE SUMMARY UI
  // ============================================================

  Widget _buildLeaveSummary() {
    final int workingDays = calculateWorkingDays(
      fromDate!,
      toDate!,
      employeeWeeklyOff,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF0E9FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              color: Color(0xFF6D28D9),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Total Leave",
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),

                const SizedBox(height: 3),

                Text(
                  totalDays == 0
                      ? "No working days"
                      : "${_formatLeaveDays(totalDays)} "
                            "day${totalDays == 1 ? '' : 's'}",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF312E81),
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  "$workingDays working day${workingDays == 1 ? '' : 's'} in selected range",
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF6B7280),
                  ),
                ),

                if (employeeWeeklyOff.isNotEmpty) ...[
                  const SizedBox(height: 3),

                  Text(
                    "Weekly off: ${employeeWeeklyOff.join(', ')}",
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],

                if (leaveDuration == "Half Day Only" &&
                    halfDaySession != null) ...[
                  const SizedBox(height: 3),

                  Text(
                    halfDaySession!,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFEA580C),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FORMAT / END
  // ============================================================
}

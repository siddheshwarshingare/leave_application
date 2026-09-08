import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emailjs/emailjs.dart' as emailjs;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ApplyWFHScreen extends StatefulWidget {
  const ApplyWFHScreen({super.key});

  @override
  State<ApplyWFHScreen> createState() => _ApplyWFHScreenState();
}

class _ApplyWFHScreenState extends State<ApplyWFHScreen> {
  final formKey = GlobalKey<FormState>();
  final reasonController = TextEditingController();

  // ============================================================
  // STATE
  // ============================================================

  DateTime? fromDate;
  DateTime? toDate;

  double totalDays = 0;

  /// Employee-specific weekly offs.
  /// Example:
  /// ["Saturday", "Sunday"]
  List<String> employeeWeeklyOff = [];

  bool loading = false;

  /// WFH is fixed. No dropdown is required.
  final String requestType = "WFH";

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
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
      if (!isWeeklyOff(current, weeklyOff)) {
        workingDays++;
      }

      current = current.add(const Duration(days: 1));
    }

    return workingDays;
  }

  // ============================================================
  // CALCULATE TOTAL WFH DAYS
  // ============================================================

  double calculateWFHDays(DateTime from, DateTime to, List<String> weeklyOff) {
    final int workingDays = calculateWorkingDays(from, to, weeklyOff);

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

    final double calculatedDays = calculateWFHDays(
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
  // DUPLICATE / OVERLAPPING WFH CHECK
  // ============================================================

  Future<bool> hasDuplicateWFH(String uid, DateTime from, DateTime to) async {
    final QuerySnapshot snap = await FirebaseFirestore.instance
        .collection('leave_requests')
        .where('uid', isEqualTo: uid)
        .get();

    final DateTime selectedFrom = DateTime(from.year, from.month, from.day);

    final DateTime selectedTo = DateTime(to.year, to.month, to.day);

    for (final doc in snap.docs) {
      final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

      // Only check WFH requests.
      final String leaveType =
          data['leaveType']?.toString().trim().toUpperCase() ?? '';

      if (leaveType != 'WFH') {
        continue;
      }

      final String status = data['status']?.toString().toLowerCase() ?? '';

      // Rejected/cancelled requests don't block dates.
      if (status == 'rejected' || status == 'cancelled') {
        continue;
      }

      if (data['fromDate'] == null || data['toDate'] == null) {
        continue;
      }

      final dynamic fromValue = data['fromDate'];
      final dynamic toValue = data['toDate'];

      if (fromValue is! Timestamp || toValue is! Timestamp) {
        continue;
      }

      final DateTime existingFromRaw = fromValue.toDate();
      final DateTime existingToRaw = toValue.toDate();

      final DateTime existingFrom = DateTime(
        existingFromRaw.year,
        existingFromRaw.month,
        existingFromRaw.day,
      );

      final DateTime existingTo = DateTime(
        existingToRaw.year,
        existingToRaw.month,
        existingToRaw.day,
      );

      final bool overlap =
          !(selectedTo.isBefore(existingFrom) ||
              selectedFrom.isAfter(existingTo));

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
    if (loading) {
      return;
    }

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
    if (loading) {
      return;
    }

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
  // SUBMIT WFH
  // ============================================================

  Future<void> submitWFH() async {
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

      final String employeeName = userData['name']?.toString() ?? "";

      final String employeeEmail =
          userData['email']?.toString() ?? currentUser.email ?? "";

      // ==========================================================
      // GET WEEKLY OFF FROM FIREBASE
      // ==========================================================

      final dynamic weeklyOffData = userData['weeklyOff'];

      final List<String> weeklyOff = weeklyOffData is List
          ? weeklyOffData
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList()
          : <String>[];

      debugPrint("EMPLOYEE WEEKLY OFF = $weeklyOff");

      if (mounted) {
        setState(() {
          employeeWeeklyOff = weeklyOff;
        });
      }

      // ==========================================================
      // DUPLICATE WFH CHECK
      // ==========================================================

      final bool duplicate = await hasDuplicateWFH(uid, fromDate!, toDate!);

      if (duplicate) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("WFH already applied for these dates")),
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

      debugPrint("WFH WORKING DAYS = $workingDays");

      // ==========================================================
      // ONLY WEEKLY OFF SELECTED
      // ==========================================================

      if (workingDays <= 0) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Selected dates contain only weekly off days"),
          ),
        );

        return;
      }

      // ==========================================================
      // FINAL WFH DAYS
      // ==========================================================

      final double requestedDays = workingDays.toDouble();

      debugPrint("FINAL WFH DAYS = $requestedDays");

      // ==========================================================
      // SAVE WFH REQUEST
      // ==========================================================

      final Map<String, dynamic> wfhData = {
        "uid": uid,

        "employeeName": employeeName,

        "employeeEmail": employeeEmail,

        "leaveType": "WFH",

        "leaveDuration": "Full Day",

        "days": requestedDays,

        "fromDate": Timestamp.fromDate(fromDate!),

        "toDate": Timestamp.fromDate(toDate!),

        "reason": reasonController.text.trim(),

        "emergency": false,

        "halfDaySession": null,

        "status": "Pending",

        "createdAt": FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('leave_requests')
          .add(wfhData);

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

          if (secondaryEmail != null &&
              secondaryEmail.isNotEmpty &&
              secondaryEmail != primaryEmail) {
            notifyEmails.add(secondaryEmail);
          }
        }
      }

      debugPrint("WFH notification emails: $notifyEmails");

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

              'request_type': 'WFH',

              'employee_name': employeeName,
              'employee_email': employeeEmail,

              'leave_type': 'WFH',

              'leave_duration': 'Full Day',

              'half_day_session': '-',

              'from_date': _formatDate(fromDate!),
              'to_date': _formatDate(toDate!),

              'days': _formatLeaveDays(requestedDays),

              'worked_dates': '-',

              'emergency': 'No',

              'reason': reasonController.text.trim(),

              'status': 'Pending',
            },
            emailjs.Options(
              publicKey: '8erlfJzc6WZtfnz0o',
              privateKey: 'wRTOsFZnkQi6yxQX7D-rF',
            ),
          );

          debugPrint("WFH email sent to: $receiverEmail");
        } catch (emailError) {
          debugPrint(
            "Failed to send WFH email to "
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

        "title": "New WFH Request",

        "body":
            "$employeeName applied for WFH "
            "(${_formatLeaveDays(requestedDays)} day(s))",

        "isRead": false,

        "createdAt": FieldValue.serverTimestamp(),
      });

      // ==========================================================
      // SUCCESS
      // ==========================================================

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("WFH Applied Successfully")));

      Navigator.pop(context);
    } catch (e) {
      debugPrint("Submit WFH error: $e");

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))),
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // ============================================================
  // FORMAT DAYS
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
      onTap: loading ? null : onTap,
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
          "Apply WFH",
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
              // REQUEST TYPE
              // ========================================================
              _sectionLabel("Request Type"),

              Container(
                padding: const EdgeInsets.all(16),
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
                        Icons.home_work_rounded,
                        color: Color(0xFF6D28D9),
                      ),
                    ),

                    const SizedBox(width: 12),

                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Work From Home",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF172033),
                            ),
                          ),

                          SizedBox(height: 3),

                          Text(
                            "Apply for working remotely",
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
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
                        color: const Color(0xFFEDE9FE),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        "WFH",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6D28D9),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

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

                  enabled: !loading,

                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF172033),
                  ),

                  decoration: const InputDecoration(
                    hintText: "Tell us why you want to work from home...",

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
              _sectionLabel("WFH Dates"),

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
              if (fromDate != null && toDate != null) _buildWFHSummary(),

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
                            "WFH Request",
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
                  onPressed: loading ? null : submitWFH,

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
                                "Submit WFH Request",
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
                  "Your WFH request will be sent for approval",
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
  // WFH SUMMARY UI
  // ============================================================

  Widget _buildWFHSummary() {
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
              Icons.home_work_rounded,
              color: Color(0xFF6D28D9),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Total WFH",
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

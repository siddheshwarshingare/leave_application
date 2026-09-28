import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emailjs/emailjs.dart' as emailjs;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:leave_application/screens/to_admin_seletion_screen.dart';

class ApplyLeaveScreen extends StatefulWidget {
  const ApplyLeaveScreen({super.key});

  @override
  State<ApplyLeaveScreen> createState() => _ApplyLeaveScreenState();
}

class _ApplyLeaveScreenState extends State<ApplyLeaveScreen> {
  final formKey = GlobalKey<FormState>();
  final reasonController = TextEditingController();

  double totalDays = 0;
  double clBalance = 0;
  double slBalance = 0;
  double coffClBalance = 0;

  /// Employee-specific weekly offs loaded from Firebase.
  List<String> employeeWeeklyOff = [];

  String? selectedLeaveType;
  String? halfDaySession;

  DateTime? fromDate;
  DateTime? toDate;

  bool loading = false;
  bool loadingEmployees = false;
  bool emergency = false;

  String leaveDuration = "Full Day";

  final List<String> leaveTypes = [
    "Casual Leave",
    "Sick Leave",
    "UnPaid Leave",
    "C-OFF",
  ];

  // ============================================================
  // CC EMPLOYEES
  // ============================================================

  /// All employees available for CC selection.
  List<Map<String, String>> employees = [];

  /// Admins available for To selection.
  List<Map<String, String>> admins = [];

  /// Selected To admin email.
  final Set<String> selectedToEmails = {};

  final Set<String> selectedCcEmails = {};

  /// Maximum CC employees allowed.
  static const int maxCcEmployees = 100;

  // ============================================================
  // INIT
  // ============================================================
  // ============================================================
  // OPEN TO ADMIN SELECTION
  // ============================================================
  // ============================================================
  // TO ADMIN SELECTION UI
  // ============================================================

  Widget _buildToAdminSelector() {
    final bool hasSelection = selectedToEmails.isNotEmpty;

    String displayText;

    if (!hasSelection) {
      displayText = "Select admins";
    } else if (selectedToEmails.length == 1) {
      final String email = selectedToEmails.first;

      final Map<String, String>? admin = admins
          .cast<Map<String, String>?>()
          .firstWhere((item) => item?['email'] == email, orElse: () => null);

      displayText = admin?['name'] ?? email;
    } else {
      displayText = "${selectedToEmails.length} admins selected";
    }

    return Container(
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
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: loadingEmployees ? null : _openToAdminSelector,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.people_alt_rounded,
                  color: Color(0xFF2563EB),
                  size: 20,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "To Admins",
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      loadingEmployees ? "Loading admins..." : displayText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: hasSelection
                            ? const Color(0xFF172033)
                            : const Color(0xFF94A3B8),
                      ),
                    ),

                    if (hasSelection && selectedToEmails.length == 1) ...[
                      const SizedBox(height: 2),
                      Text(
                        selectedToEmails.first,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 8),

              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF64748B),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openToAdminSelector() async {
    final Set<String> initialSelection = Set<String>.from(selectedToEmails);

    final Set<String>? result = await showDialog<Set<String>>(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        return ToAdminSelectionDialog(
          admins: admins,
          initialSelection: initialSelection,
        );
      },
    );

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      selectedToEmails
        ..clear()
        ..addAll(result);
    });

    debugPrint("SELECTED TO ADMINS = $selectedToEmails");
  }

  @override
  void initState() {
    super.initState();

    loadEmployeeWeeklyOff();
    loadLeaveBalances();
    // loadEmployeesForCc();
    loadEmployeesAndAdmins();
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
  // LOAD LEAVE BALANCES
  // ============================================================

  Future<void> loadLeaveBalances() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        return;
      }

      final DocumentSnapshot balanceDoc = await FirebaseFirestore.instance
          .collection('toatl_leave')
          .doc(user.uid)
          .get();

      if (!balanceDoc.exists) {
        debugPrint("Leave balance document not found");
        return;
      }

      final Map<String, dynamic> data =
          balanceDoc.data() as Map<String, dynamic>;

      final double cl = double.tryParse(data['Cl']?.toString() ?? '0') ?? 0;

      final double sl = double.tryParse(data['Sl']?.toString() ?? '0') ?? 0;

      final double coff =
          double.tryParse(data['coffCl']?.toString() ?? '0') ?? 0;

      debugPrint("CL BALANCE   = $cl");
      debugPrint("SL BALANCE   = $sl");
      debugPrint("C-OFF BALANCE = $coff");

      if (!mounted) {
        return;
      }

      setState(() {
        clBalance = cl;
        slBalance = sl;
        coffClBalance = coff;
      });
    } catch (e) {
      debugPrint("Failed to load leave balances: $e");
    }
  }

  // ============================================================
  // LOAD EMPLOYEES FOR CC
  // ============================================================
  // ============================================================
  // LOAD EMPLOYEES + ADMINS FOR CC
  // ============================================================

  Future<void> loadEmployeesAndAdmins() async {
    try {
      if (mounted) {
        setState(() {
          loadingEmployees = true;
        });
      }

      final User? currentUser = FirebaseAuth.instance.currentUser;

      // ==========================================================
      // FETCH EMPLOYEES
      // ==========================================================

      final QuerySnapshot employeeSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'Employee')
          .get();

      // ==========================================================
      // FETCH ADMINS
      // ==========================================================

      final QuerySnapshot adminSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();

      final List<Map<String, String>> loadedEmployees = [];
      final List<Map<String, String>> loadedAdmins = [];

      final Set<String> addedCcEmails = {};

      // ==========================================================
      // CURRENT USER EMAIL
      // ==========================================================

      final String currentUserEmail =
          currentUser?.email?.trim().toLowerCase() ?? '';

      // ==========================================================
      // LOAD EMPLOYEES
      // ==========================================================

      for (final QueryDocumentSnapshot doc in employeeSnapshot.docs) {
        final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        final String email = data['email']?.toString().trim() ?? '';

        final String name = data['name']?.toString().trim() ?? '';

        if (email.isEmpty) {
          continue;
        }

        // Do not show current logged-in user.
        if (email.toLowerCase() == currentUserEmail) {
          continue;
        }

        final String normalizedEmail = email.toLowerCase();

        // Avoid duplicate email.
        if (addedCcEmails.contains(normalizedEmail)) {
          continue;
        }

        addedCcEmails.add(normalizedEmail);

        loadedEmployees.add({
          'uid': doc.id,
          'name': name.isEmpty ? email : name,
          'email': email,
          'role': 'Employee',
        });
      }

      // ==========================================================
      // LOAD ADMINS
      // ==========================================================

      for (final QueryDocumentSnapshot doc in adminSnapshot.docs) {
        final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        final String email = data['email']?.toString().trim() ?? '';

        final String name = data['name']?.toString().trim() ?? '';

        if (email.isEmpty) {
          continue;
        }

        // Do not show current logged-in user in CC.
        if (email.toLowerCase() == currentUserEmail) {
          continue;
        }

        final String normalizedEmail = email.toLowerCase();

        // Avoid duplicate email.
        if (addedCcEmails.contains(normalizedEmail)) {
          continue;
        }

        addedCcEmails.add(normalizedEmail);

        loadedEmployees.add({
          'uid': doc.id,
          'name': name.isEmpty ? email : name,
          'email': email,
          'role': 'admin',
        });

        // Admin list for To selection.
        loadedAdmins.add({
          'uid': doc.id,
          'name': name.isEmpty ? email : name,
          'email': email,
          'role': 'admin',
        });
      }

      // ==========================================================
      // SORT CC LIST
      // ==========================================================

      loadedEmployees.sort(
        (a, b) => a['name']!.toLowerCase().compareTo(b['name']!.toLowerCase()),
      );

      // ==========================================================
      // SORT ADMIN LIST
      // ==========================================================

      loadedAdmins.sort(
        (a, b) => a['name']!.toLowerCase().compareTo(b['name']!.toLowerCase()),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        employees = loadedEmployees;
        admins = loadedAdmins;
        loadingEmployees = false;
      });

      debugPrint("CC EMPLOYEES + ADMINS LOADED = ${employees.length}");

      debugPrint("TO ADMINS LOADED = ${admins.length}");
    } catch (e) {
      debugPrint("Failed to load employees/admins: $e");

      if (!mounted) {
        return;
      }

      setState(() {
        loadingEmployees = false;
      });
    }
  }

  // ============================================================
  // OPEN CC EMPLOYEE SELECTION
  // ============================================================
  Future<void> _openCcEmployeeSelector() async {
    final Set<String> initialSelection = Set<String>.from(selectedCcEmails);

    final Set<String>? result = await showDialog<Set<String>>(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        return CcEmployeeSelectionDialog(
          employees: employees,
          initialSelection: initialSelection,
          maxSelection: maxCcEmployees,
        );
      },
    );

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      selectedCcEmails
        ..clear()
        ..addAll(result);
    });
  } // ============================================================
  // CC SELECTION UI
  // ============================================================

  Widget _buildCcEmployeeSelector() {
    String displayText;

    if (selectedCcEmails.isEmpty) {
      displayText = "Select employees/admins";
    } else if (selectedCcEmails.length == 1) {
      final String email = selectedCcEmails.first;

      final Map<String, String>? employee = employees
          .cast<Map<String, String>?>()
          .firstWhere((item) => item?['email'] == email, orElse: () => null);

      displayText = employee?['name'] ?? email;
    } else {
      displayText = "${selectedCcEmails.length} employees selected";
    }

    return Container(
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
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: loadingEmployees ? null : _openCcEmployeeSelector,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0E9FF),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.people_alt_rounded,
                  color: Color(0xFF6D28D9),
                  size: 20,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "CC Employees",
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      loadingEmployees ? "Loading employees..." : displayText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: selectedCcEmails.isEmpty
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF172033),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF64748B),
              ),
            ],
          ),
        ),
      ),
    );
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

    if (leaveDuration == "Half Day Only") {
      return workingDays - 0.5;
    }

    return workingDays.toDouble();
  }

  // ============================================================
  // CALCULATE TOTAL DAYS
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
    if (selectedToEmails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one To Admin")),
      );

      return;
    }

    final String primaryEmail = selectedToEmails.join(',');

    final String ccEmails = selectedCcEmails.join(',');

    debugPrint("================================");
    debugPrint("SELECTED TO NAME  = $primaryEmail ");
    debugPrint("SELECTED TO EMAIL = $primaryEmail");
    debugPrint("CC EMAILS         = $ccEmails");
    debugPrint("================================");

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

      // ========================================================
      // CURRENT USER
      // ========================================================

      final User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        throw Exception("User is not logged in");
      }

      final String uid = currentUser.uid;

      // ========================================================
      // FETCH EMPLOYEE DATA
      // ========================================================

      final DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!userDoc.exists) {
        throw Exception("Employee data not found");
      }

      final Map<String, dynamic> userData =
          userDoc.data() as Map<String, dynamic>;

      // ========================================================
      // GET WEEKLY OFF
      // ========================================================

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

      // ========================================================
      // DUPLICATE LEAVE CHECK
      // ========================================================

      final bool duplicate = await hasDuplicateLeave(uid, fromDate!, toDate!);

      if (duplicate) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Leave already applied for these dates"),
          ),
        );

        return;
      }

      // ========================================================
      // CALCULATE WORKING DAYS
      // ========================================================

      final int workingDays = calculateWorkingDays(
        fromDate!,
        toDate!,
        weeklyOff,
      );

      debugPrint("WORKING DAYS = $workingDays");

      if (workingDays <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Selected dates contain only weekly off days"),
          ),
        );

        return;
      }

      // ========================================================
      // FINAL LEAVE DAYS
      // ========================================================

      final double requestedDays = leaveDuration == "Half Day Only"
          ? workingDays - 0.5
          : workingDays.toDouble();

      debugPrint("FINAL LEAVE DAYS = $requestedDays");

      // ========================================================
      // LEAVE BALANCE
      // ========================================================

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

      final double coffCl =
          double.tryParse(balanceData['coffCl']?.toString() ?? '0') ?? 0;

      debugPrint("================================");
      debugPrint("CL BALANCE    = $cl");
      debugPrint("SL BALANCE    = $sl");
      debugPrint("C-OFF BALANCE = $coffCl");
      debugPrint("REQUESTED     = $requestedDays");
      debugPrint("LEAVE TYPE    = $selectedLeaveType");
      debugPrint("CC EMPLOYEES  = $selectedCcEmails");
      debugPrint("================================");

      // ========================================================
      // CASUAL LEAVE BALANCE
      // ========================================================

      if (selectedLeaveType == "Casual Leave" && requestedDays > cl) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Only $cl CL remaining")));

        return;
      }

      // ========================================================
      // SICK LEAVE BALANCE
      // ========================================================

      if (selectedLeaveType == "Sick Leave" && requestedDays > sl) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Only $sl SL remaining")));

        return;
      }

      // ========================================================
      // C-OFF BALANCE
      // ========================================================

      if (selectedLeaveType == "C-OFF" && requestedDays > coffCl) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Only ${_formatLeaveDays(coffCl)} "
              "C-OFF day(s) available",
            ),
          ),
        );

        return;
      }

      // ========================================================
      // CC EMAIL STRING
      // ========================================================

      //    final String ccEmails = selectedCcEmails.join(',');

      debugPrint("FINAL CC EMAILS = $ccEmails");

      // ========================================================
      // SAVE LEAVE REQUEST
      // ========================================================

      final Map<String, dynamic> leaveData = {
        "uid": uid,

        "employeeName": userData['name']?.toString() ?? "",

        "employeeEmail": userData['email']?.toString() ?? "",

        "leaveType": selectedLeaveType,
        "toAdminEmails": selectedToEmails.toList(),

        "ccEmails": selectedCcEmails.toList(),

        "leaveDuration": leaveDuration,

        "days": requestedDays,

        "fromDate": Timestamp.fromDate(fromDate!),

        "toDate": Timestamp.fromDate(toDate!),

        "reason": reasonController.text.trim(),

        "emergency": emergency,

        "halfDaySession": leaveDuration == "Half Day Only"
            ? halfDaySession
            : null,

        // ======================================================
        // SAVE SELECTED CC EMAILS
        // ======================================================
        "ccEmails": selectedCcEmails.toList(),

        "status": "Pending",

        "createdAt": Timestamp.now(),
      };

      await FirebaseFirestore.instance
          .collection('leave_requests')
          .add(leaveData);

      // ========================================================
      // FETCH PRIMARY APPROVER
      // ========================================================

      // final DocumentSnapshot approverDoc = await FirebaseFirestore.instance
      //     .collection('email_recipients')
      //     .doc('leave_approvers')
      //     .get();

      // String primaryEmail = "siddheshwar.shingare@en3.ca";

      // if (approverDoc.exists) {
      //   final Map<String, dynamic> approverData =
      //       approverDoc.data() as Map<String, dynamic>;

      //   if (approverData['active'] == true) {
      //     final String configuredPrimary =
      //         approverData['primaryEmail']?.toString().trim() ?? "";

      //     if (configuredPrimary.isNotEmpty) {
      //       primaryEmail = configuredPrimary;
      //     }
      //   }
      // }

      debugPrint("EMAIL TO = $primaryEmail");

      debugPrint("EMAIL CC = $ccEmails");

      // ========================================================
      // SEND ONE EMAIL ONLY
      // ========================================================

      try {
        await emailjs.send(
          'service_90wr32y',
          'template_mga5feh',
          {
            // ==================================================
            // EMAIL RECIPIENTS
            // ==================================================

            'to_email': primaryEmail,

            'cc_email': ccEmails,

            'bcc_email': 'siddheshwar.shingare@en3.ca',

            // ==================================================
            // LEAVE INFORMATION
            // ==================================================
            'request_type': "Leave",

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

            'emergency': emergency ? "Yes" : "No",
          },

          emailjs.Options(
            publicKey: '8erlfJzc6WZtfnz0o',

            // IMPORTANT:
            // This private key should NOT be stored
            // inside a production Flutter application.
            // Rotate it and move email sending to
            // Firebase Cloud Functions for production.
            privateKey: 'wRTOsFZnkQi6yxQX7D-rF',
          ),
        );

        debugPrint("================================");

        debugPrint("LEAVE EMAIL SENT SUCCESSFULLY");

        debugPrint("TO  = $primaryEmail");

        debugPrint("CC  = $ccEmails");

        debugPrint("BCC = siddheshwar.shingare@en3.ca");

        debugPrint("================================");
      } catch (emailError) {
        debugPrint("Failed to send leave email: $emailError");
      }

      // ========================================================
      // ADMIN NOTIFICATION
      // ========================================================

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

      // ========================================================
      // SUCCESS
      // ========================================================

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
              // ====================================================
              // LEAVE TYPE
              // ====================================================

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

              // ====================================================
              // LEAVE DURATION
              // ====================================================
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

              // ====================================================
              // HALF DAY SESSION
              // ====================================================
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

              // ====================================================
              // REASON
              // ====================================================
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

              // ====================================================
              // TO ADMIN
              // ====================================================
              _sectionLabel("To"),

              _buildToAdminSelector(),

              const SizedBox(height: 18),

              // ====================================================
              // CC EMPLOYEES + ADMINS
              // ====================================================
              _sectionLabel("CC"),

              _buildCcEmployeeSelector(),

              if (selectedCcEmails.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 7, left: 4),
                  child: Text(
                    "Selected employees/admins will receive this leave email in CC.",
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),

              if (selectedCcEmails.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 7, left: 4),
                  child: Text(
                    "Selected employees will receive this leave email in CC.",
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),

              const SizedBox(height: 18),

              // ====================================================
              // DATES
              // ====================================================
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

              // ====================================================
              // SUMMARY
              // ====================================================
              if (fromDate != null && toDate != null) _buildLeaveSummary(),

              if (fromDate != null && toDate != null)
                const SizedBox(height: 18),

              // ====================================================
              // INFO
              // ====================================================
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

              // ====================================================
              // SUBMIT BUTTON
              // ====================================================
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
}

class CcEmployeeSelectionDialog extends StatefulWidget {
  final List<Map<String, String>> employees;
  final Set<String> initialSelection;
  final int maxSelection;

  const CcEmployeeSelectionDialog({
    super.key,
    required this.employees,
    required this.initialSelection,
    required this.maxSelection,
  });

  @override
  State<CcEmployeeSelectionDialog> createState() =>
      _CcEmployeeSelectionDialogState();
}

class _CcEmployeeSelectionDialogState extends State<CcEmployeeSelectionDialog> {
  late Set<String> selectedEmails;

  final TextEditingController searchController = TextEditingController();

  List<Map<String, String>> filteredEmployees = [];

  @override
  void initState() {
    super.initState();

    selectedEmails = Set<String>.from(widget.initialSelection);

    filteredEmployees = List<Map<String, String>>.from(widget.employees);

    searchController.addListener(_searchEmployees);
  }

  @override
  void dispose() {
    searchController.removeListener(_searchEmployees);
    searchController.dispose();

    super.dispose();
  }

  void _searchEmployees() {
    final String search = searchController.text.trim().toLowerCase();

    if (!mounted) {
      return;
    }

    setState(() {
      if (search.isEmpty) {
        filteredEmployees = List<Map<String, String>>.from(widget.employees);
        return;
      }

      filteredEmployees = widget.employees.where((employee) {
        final String name = employee['name']?.toLowerCase() ?? '';

        final String email = employee['email']?.toLowerCase() ?? '';

        return name.contains(search) || email.contains(search);
      }).toList();
    });
  }

  void _toggleEmployee(String email, bool checked) {
    if (!mounted) {
      return;
    }

    if (checked) {
      if (selectedEmails.contains(email)) {
        return;
      }

      if (selectedEmails.length >= widget.maxSelection) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "You can select maximum "
              "${widget.maxSelection} employees.",
            ),
          ),
        );

        return;
      }

      setState(() {
        selectedEmails.add(email);
      });
    } else {
      setState(() {
        selectedEmails.remove(email);
      });
    }
  }

  void _clearSearch() {
    searchController.clear();
  }

  void _cancel() {
    FocusManager.instance.primaryFocus?.unfocus();

    Navigator.of(context).pop();
  }

  void _done() {
    FocusManager.instance.primaryFocus?.unfocus();

    final Set<String> result = Set<String>.from(selectedEmails);

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),

      title: Row(
        children: [
          const Expanded(
            child: Text(
              "Select CC Employees",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF0E9FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "${selectedEmails.length}/${widget.maxSelection}",
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6D28D9),
              ),
            ),
          ),
        ],
      ),

      content: SizedBox(
        width: double.maxFinite,
        height: 480,
        child: Column(
          children: [
            // ==============================================
            // SEARCH
            // ==============================================

            TextField(
              controller: searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: "Search employee name or email",
                prefixIcon: const Icon(Icons.search_rounded),

                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        onPressed: _clearSearch,
                        icon: const Icon(Icons.clear_rounded),
                      )
                    : null,

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),

                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),

                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF6D28D9),
                    width: 1.5,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ==============================================
            // SELECTED COUNT INFO
            // ==============================================
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                selectedEmails.isEmpty
                    ? "No employees selected"
                    : "${selectedEmails.length} employee(s) selected",
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ==============================================
            // EMPLOYEE LIST
            // ==============================================
            Expanded(
              child: filteredEmployees.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_search_rounded,
                            size: 45,
                            color: Color(0xFFCBD5E1),
                          ),
                          SizedBox(height: 8),
                          Text(
                            "No employees found",
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,

                      itemCount: filteredEmployees.length,

                      separatorBuilder: (_, __) {
                        return const Divider(height: 1);
                      },

                      itemBuilder: (context, index) {
                        final Map<String, String> employee =
                            filteredEmployees[index];

                        final String name = employee['name'] ?? '';

                        final String email = employee['email'] ?? '';

                        final bool selected = selectedEmails.contains(email);

                        return CheckboxListTile(
                          dense: true,

                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 0,
                            vertical: 2,
                          ),

                          value: selected,

                          activeColor: const Color(0xFF6D28D9),

                          checkColor: Colors.white,

                          controlAffinity: ListTileControlAffinity.leading,

                          title: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          subtitle: Text(
                            email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),

                          onChanged: (bool? value) {
                            _toggleEmployee(email, value ?? false);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),

      actions: [
        TextButton(
          onPressed: _cancel,
          child: const Text(
            "Cancel",
            style: TextStyle(color: Color(0xFF64748B)),
          ),
        ),

        ElevatedButton(
          onPressed: _done,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6D28D9),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text(
            "Done",
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

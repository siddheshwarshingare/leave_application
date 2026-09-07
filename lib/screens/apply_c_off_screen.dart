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

  // ==========================================================
  // SELECTED DATES
  // ==========================================================

  final Set<String> selectedWorkedDates = {};

  final Map<String, String> selectedDayTypes = {};

  // ==========================================================
  // ALREADY CLAIMED
  // ==========================================================

  final Set<String> claimedDates = {};

  // ==========================================================
  // HOLIDAYS
  // ==========================================================

  final Map<String, String> holidayNames = {};

  // ==========================================================
  // WEEKLY OFF
  // ==========================================================

  List<String> weeklyOff = [];

  // ==========================================================
  // STATE
  // ==========================================================

  bool loading = false;
  bool loadingCalendar = false;

  DateTime displayedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  // ==========================================================
  // INIT
  // ==========================================================

  @override
  void initState() {
    super.initState();
    loadCalendarData();
  }

  // ==========================================================
  // DISPOSE
  // ==========================================================

  @override
  void dispose() {
    reasonController.dispose();
    super.dispose();
  }

  // ==========================================================
  // DATE KEY
  // ==========================================================

  String dateKey(DateTime date) {
    return "${date.year.toString().padLeft(4, '0')}-"
        "${date.month.toString().padLeft(2, '0')}-"
        "${date.day.toString().padLeft(2, '0')}";
  }

  // ==========================================================
  // PARSE DATE
  // ==========================================================

  DateTime parseDate(String value) {
    final parts = value.split("-");

    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  // ==========================================================
  // FORMAT DATE
  // ==========================================================

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

    return "${date.day.toString().padLeft(2, '0')} "
        "${months[date.month - 1]} "
        "${date.year}";
  }

  // ==========================================================
  // WEEKLY OFF
  // ==========================================================

  bool isWeeklyOff(DateTime date) {
    const days = [
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday",
      "Saturday",
      "Sunday",
    ];

    final dayName = days[date.weekday - 1];

    return weeklyOff.contains(dayName);
  }

  DateTime? parseHolidayDate(dynamic value) {
    if (value == null) return null;

    // Firestore Timestamp
    if (value is Timestamp) {
      return value.toDate();
    }

    final text = value.toString().trim();

    if (text.isEmpty) return null;

    // Already yyyy-MM-dd
    final isoParts = text.split("-");

    if (isoParts.length == 3 && isoParts[0].length == 4) {
      try {
        return DateTime(
          int.parse(isoParts[0]),
          int.parse(isoParts[1]),
          int.parse(isoParts[2]),
        );
      } catch (_) {}
    }

    // dd-MMM-yyyy
    // Example: 20-Oct-2026
    final parts = text.split("-");

    if (parts.length == 3) {
      try {
        const months = {
          "Jan": 1,
          "Feb": 2,
          "Mar": 3,
          "Apr": 4,
          "May": 5,
          "Jun": 6,
          "Jul": 7,
          "Aug": 8,
          "Sep": 9,
          "Oct": 10,
          "Nov": 11,
          "Dec": 12,
        };

        final day = int.parse(parts[0]);
        final month = months[parts[1]];
        final year = int.parse(parts[2]);

        if (month != null) {
          return DateTime(year, month, day);
        }
      } catch (_) {}
    }

    return null;
  }

  // ==========================================================
  // LOAD ALL CALENDAR DATA
  // ==========================================================

  Future<void> loadCalendarData() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    setState(() {
      loadingCalendar = true;
    });

    try {
      // ========================================================
      // USER
      // ========================================================

      final userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        throw Exception("User information not found.");
      }

      final userData = userDoc.data()!;

      weeklyOff = List<String>.from(userData["weeklyOff"] ?? []);

      // ========================================================
      // HOLIDAYS
      // ========================================================

      final holidaySnapshot = await FirebaseFirestore.instance
          .collection("holidays")
          .where("active")
          .get();

      holidayNames.clear();

      for (final doc in holidaySnapshot.docs) {
        final data = doc.data();

        final holidayDate = parseHolidayDate(data["date"]);

        if (holidayDate != null) {
          final key = dateKey(holidayDate);

          holidayNames[key] = data["holiday"]?.toString() ?? "Holiday";
        }
      }

      // ========================================================
      // EXISTING C-OFF REQUESTS
      // ========================================================

      final coffSnapshot = await FirebaseFirestore.instance
          .collection("coff_requests")
          .where("uid", isEqualTo: user.uid)
          .get();

      claimedDates.clear();

      for (final doc in coffSnapshot.docs) {
        final data = doc.data();

        final workedDate = data["workedDate"]?.toString();

        if (workedDate != null && workedDate.isNotEmpty) {
          claimedDates.add(workedDate);
        }
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))),
      );
    } finally {
      if (mounted) {
        setState(() {
          loadingCalendar = false;
        });
      }
    }
  }

  // ==========================================================
  // GET DAY TYPE
  // ==========================================================

  String? getDayType(DateTime date) {
    final key = dateKey(date);

    // Weekly off has priority
    if (isWeeklyOff(date)) {
      return "Weekly Off";
    }

    // Holiday
    if (holidayNames.containsKey(key)) {
      return "Holiday: ${holidayNames[key]}";
    }

    return null;
  }

  // ==========================================================
  // IS VALID C-OFF DATE
  // ==========================================================

  bool isValidCOffDate(DateTime date) {
    final key = dateKey(date);

    // Already claimed
    if (claimedDates.contains(key)) {
      return false;
    }

    // Weekly off
    if (isWeeklyOff(date)) {
      return true;
    }

    // Holiday
    if (holidayNames.containsKey(key)) {
      return true;
    }

    return false;
  }

  // ==========================================================
  // SELECT / UNSELECT DATE
  // ==========================================================

  void toggleDate(DateTime date) {
    final key = dateKey(date);

    if (!isValidCOffDate(date)) {
      return;
    }

    setState(() {
      if (selectedWorkedDates.contains(key)) {
        selectedWorkedDates.remove(key);
        selectedDayTypes.remove(key);
      } else {
        final type = getDayType(date);

        if (type != null) {
          selectedWorkedDates.add(key);
          selectedDayTypes[key] = type;
        }
      }
    });
  }

  // ==========================================================
  // MONTH NAME
  // ==========================================================

  String monthName(DateTime date) {
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

    return months[date.month - 1];
  }

  // ==========================================================
  // PREVIOUS MONTH
  // ==========================================================

  void previousMonth() {
    setState(() {
      displayedMonth = DateTime(displayedMonth.year, displayedMonth.month - 1);
    });
  }

  // ==========================================================
  // NEXT MONTH
  // ==========================================================

  void nextMonth() {
    setState(() {
      displayedMonth = DateTime(displayedMonth.year, displayedMonth.month + 1);
    });
  }

  // ==========================================================
  // CALENDAR
  // ==========================================================

  Widget buildCalendar() {
    final firstDay = DateTime(displayedMonth.year, displayedMonth.month, 1);

    final lastDay = DateTime(displayedMonth.year, displayedMonth.month + 1, 0);

    // Monday = 1
    final startingOffset = firstDay.weekday - 1;

    final totalCells = startingOffset + lastDay.day;

    final rows = (totalCells / 7).ceil();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E8EE)),
      ),
      child: Column(
        children: [
          // ====================================================
          // MONTH HEADER
          // ====================================================
          Row(
            children: [
              IconButton(
                onPressed: previousMonth,
                icon: const Icon(Icons.chevron_left, color: Color(0xFF6C2BD9)),
              ),

              Expanded(
                child: Text(
                  "${monthName(displayedMonth)} ${displayedMonth.year}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              IconButton(
                onPressed: nextMonth,
                icon: const Icon(Icons.chevron_right, color: Color(0xFF6C2BD9)),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ====================================================
          // WEEK DAYS
          // ====================================================
          Row(
            children: ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"].map((
              day,
            ) {
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF888888),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 8),

          // ====================================================
          // DAYS
          // ====================================================
          Column(
            children: List.generate(rows, (row) {
              return Row(
                children: List.generate(7, (column) {
                  final cellIndex = row * 7 + column;

                  final dayNumber = cellIndex - startingOffset + 1;

                  if (dayNumber < 1 || dayNumber > lastDay.day) {
                    return const Expanded(child: SizedBox(height: 52));
                  }

                  final date = DateTime(
                    displayedMonth.year,
                    displayedMonth.month,
                    dayNumber,
                  );

                  return Expanded(child: buildDayCell(date));
                }),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // DAY CELL
  // ==========================================================

  Widget buildDayCell(DateTime date) {
    final key = dateKey(date);

    final valid = isValidCOffDate(date);

    final selected = selectedWorkedDates.contains(key);

    final claimed = claimedDates.contains(key);

    final type = getDayType(date);

    Color backgroundColor = Colors.transparent;
    Color textColor = const Color(0xFF444444);

    if (claimed) {
      backgroundColor = const Color(0xFFECECEC);
      textColor = const Color(0xFFAAAAAA);
    } else if (selected) {
      backgroundColor = const Color(0xFF6C2BD9);
      textColor = Colors.white;
    } else if (valid) {
      backgroundColor = const Color(0xFFF3F0FF);
      textColor = const Color(0xFF6C2BD9);
    } else {
      textColor = const Color(0xFFCCCCCC);
    }

    return GestureDetector(
      onTap: valid ? () => toggleDate(date) : null,
      child: Container(
        height: 52,
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: selected
              ? Border.all(color: const Color(0xFF6C2BD9), width: 2)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "${date.day}",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),

            const SizedBox(height: 2),

            if (claimed)
              const Icon(Icons.check, size: 11, color: Color(0xFF999999))
            else if (selected)
              const Icon(Icons.check, size: 11, color: Colors.white)
            else if (type != null)
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: Color(0xFF6C2BD9),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // SELECTED DATES LIST
  // ==========================================================

  Widget buildSelectedDates() {
    final dates = selectedWorkedDates.map(parseDate).toList()..sort();

    if (dates.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFE5A8)),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFFB77900)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "Select one or more weekly-off or holiday dates.",
                style: TextStyle(fontSize: 13, color: Color(0xFF765300)),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1FFF5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD0F0D8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.green),
              const SizedBox(width: 8),
              Text(
                "${dates.length} date${dates.length == 1 ? '' : 's'} selected",
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.green,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          ...dates.map((date) {
            final key = dateKey(date);

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 15,
                    color: Color(0xFF6C2BD9),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "${formatDate(date)} • ${selectedDayTypes[key]}",
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedWorkedDates.remove(key);
                        selectedDayTypes.remove(key);
                      });
                    },
                    child: const Icon(Icons.close, size: 18, color: Colors.red),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ==========================================================
  // SUBMIT
  // ==========================================================

  Future<void> submitCOff() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    if (selectedWorkedDates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select at least one worked date."),
        ),
      );
      return;
    }

    try {
      setState(() {
        loading = true;
      });

      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception("User not logged in.");
      }

      final uid = user.uid;

      // ========================================================
      // USER
      // ========================================================

      final userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .get();

      if (!userDoc.exists) {
        throw Exception("User information not found.");
      }

      final userData = userDoc.data()!;

      final employeeName = userData["name"]?.toString() ?? "";

      final employeeEmail = userData["email"]?.toString() ?? user.email ?? "";

      // ========================================================
      // SORT DATES
      // ========================================================

      final dates = selectedWorkedDates.map(parseDate).toList()..sort();

      // ========================================================
      // FINAL VALIDATION
      // ========================================================

      for (final date in dates) {
        final key = dateKey(date);

        final type = getDayType(date);

        if (type == null) {
          throw Exception("$key is not a weekly-off or holiday.");
        }

        if (claimedDates.contains(key)) {
          throw Exception("$key has already been claimed.");
        }
      }

      // ========================================================
      // CREATE ONE DOCUMENT PER DATE
      // ========================================================

      final firestore = FirebaseFirestore.instance;

      final batch = firestore.batch();

      for (final date in dates) {
        final key = dateKey(date);

        // Deterministic document ID
        //
        // This prevents the same employee from creating
        // another request for the same worked date.
        final docId = "${uid}_$key";

        final requestRef = firestore.collection("coff_requests").doc(docId);

        batch.set(requestRef, {
          "uid": uid,

          "employeeName": employeeName,

          "employeeEmail": employeeEmail,

          "workedDate": key,

          "workedDateTimestamp": Timestamp.fromDate(date),

          "dayType": getDayType(date),

          "reason": reasonController.text.trim(),

          "status": "Pending",

          "coffDays": 1,

          "createdAt": FieldValue.serverTimestamp(),

          "approvedAt": null,

          "approvedBy": null,
        });
      }

      await batch.commit();

      // ========================================================
      // ADMIN NOTIFICATION
      // ========================================================

      final formattedDates = dates.map(formatDate).join(", ");

      await firestore.collection("notifications").add({
        "role": "admin",

        "uid": null,

        "title": "New C-Off Request",

        "body": "$employeeName applied for C-Off for $formattedDates",

        "isRead": false,

        "createdAt": FieldValue.serverTimestamp(),
      });

      // ========================================================
      // EMAIL
      // ========================================================

      try {
        final approverDoc = await firestore
            .collection("email_recipients")
            .doc("leave_approvers")
            .get();

        if (approverDoc.exists && approverDoc.data()?["active"] == true) {
          final notifyEmails = <String>[];

          final primaryEmail = approverDoc
              .data()?["primaryEmail"]
              ?.toString()
              .trim();

          final secondaryEmail = approverDoc
              .data()?["secondaryEmail"]
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

          for (final receiverEmail in notifyEmails) {
            try {
              await emailjs.send(
                "service_90wr32y",
                "template_mga5feh",
                {
                  "to_email": receiverEmail,

                  "employee_name": employeeName,

                  "employee_email": employeeEmail,

                  "leave_type": "C-Off",

                  "from_date": formatDate(dates.first),

                  "to_date": formatDate(dates.last),

                  "days": dates.length.toString(),

                  "reason": reasonController.text.trim(),

                  "worked_dates": formattedDates,
                },
                emailjs.Options(
                  publicKey: "8erlfJzc6WZtfnz0o",
                  privateKey: const String.fromEnvironment(
                    "wRTOsFZnkQi6yxQX7D-rF",
                  ),
                ),
              );
            } catch (emailError) {
              debugPrint("C-Off email failed: $emailError");
            }
          }
        }
      } catch (emailError) {
        debugPrint("Email configuration error: $emailError");
      }

      // ========================================================
      // SUCCESS
      // ========================================================

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "${dates.length} C-Off date${dates.length == 1 ? '' : 's'} submitted successfully.",
          ),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

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

  // ==========================================================
  // SECTION LABEL
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

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final selectedCount = selectedWorkedDates.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF202020),
        centerTitle: true,

        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 19),
          onPressed: loading ? null : () => Navigator.pop(context),
        ),

        title: const Text(
          "Apply C-Off",
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
              // INFORMATION
              // =================================================
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F0FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5DEFF)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFF6C2BD9)),

                    SizedBox(width: 10),

                    Expanded(
                      child: Text(
                        "Select all dates on which you worked "
                        "during your weekly-off or a company holiday. "
                        "Each approved date gives you 1 C-Off.",
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: Color(0xFF555555),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // =================================================
              // CALENDAR
              // =================================================
              sectionLabel("Select Worked Dates"),

              if (loadingCalendar)
                Container(
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(color: Color(0xFF6C2BD9)),
                  ),
                )
              else
                buildCalendar(),

              const SizedBox(height: 15),

              // =================================================
              // SELECTED DATES
              // =================================================
              buildSelectedDates(),

              const SizedBox(height: 17),

              // =================================================
              // REASON
              // =================================================
              sectionLabel("Reason"),

              TextFormField(
                controller: reasonController,
                maxLines: 4,

                enabled: !loading,

                style: const TextStyle(fontSize: 14),

                decoration: InputDecoration(
                  hintText: "Explain why you worked on these dates",

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
              // COFF SUMMARY
              // =================================================
              if (selectedCount > 0)
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
                              "C-Off After Approval",
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF777777),
                              ),
                            ),

                            const SizedBox(height: 4),

                            Text(
                              "$selectedCount Day${selectedCount == 1 ? '' : 's'}",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF292929),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Icon(
                        Icons.card_giftcard_outlined,
                        color: Color(0xFF6C2BD9),
                        size: 28,
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 35),

              // =================================================
              // SUBMIT
              // =================================================
              SizedBox(
                height: 52,
                width: double.infinity,

                child: ElevatedButton(
                  onPressed: loading || loadingCalendar ? null : submitCOff,

                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C2BD9),

                    foregroundColor: Colors.white,

                    disabledBackgroundColor: const Color(0xFFB8A5E8),

                    elevation: 0,

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),

                  child: loading
                      ? const SizedBox(
                          height: 23,
                          width: 23,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          selectedCount == 0
                              ? "Select C-Off Dates"
                              : "Submit $selectedCount C-Off ${selectedCount == 1 ? 'Request' : 'Requests'}",
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
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

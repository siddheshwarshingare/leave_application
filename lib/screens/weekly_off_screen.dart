import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ManageWeeklyOffScreen extends StatefulWidget {
  const ManageWeeklyOffScreen({super.key});

  @override
  State<ManageWeeklyOffScreen> createState() => _ManageWeeklyOffScreenState();
}

class _ManageWeeklyOffScreenState extends State<ManageWeeklyOffScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? selectedUid;

  Set<String> selectedDays = {};

  bool saving = false;

  // ============================================================
  // DAYS
  // ============================================================

  final List<String> weekDays = [
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
    "Sunday",
  ];

  // ============================================================
  // USERS
  // ============================================================

  Stream<QuerySnapshot> getEmployees() {
    return _firestore
        .collection('users')
        .where('role', isNotEqualTo: 'admin')
        .snapshots();
  }

  // ============================================================
  // LOAD SELECTED EMPLOYEE WEEKLY OFF
  // ============================================================

  void loadWeeklyOff(Map<String, dynamic> data) {
    final weeklyOff = data['weeklyOff'];

    setState(() {
      if (weeklyOff is List) {
        selectedDays = weeklyOff.map((e) => e.toString()).toSet();
      } else {
        selectedDays = {};
      }
    });
  }

  // ============================================================
  // SAVE
  // ============================================================

  Future<void> saveWeeklyOff() async {
    if (selectedUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select an employee")),
      );

      return;
    }

    setState(() {
      saving = true;
    });

    try {
      await _firestore.collection('users').doc(selectedUid).update({
        'weeklyOff': selectedDays.toList(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Weekly off updated successfully"),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error updating weekly off: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  // ============================================================
  // DAY ITEM
  // ============================================================

  Widget dayItem(String day) {
    final isSelected = selectedDays.contains(day);

    return InkWell(
      borderRadius: BorderRadius.circular(14),

      onTap: () {
        setState(() {
          if (isSelected) {
            selectedDays.remove(day);
          } else {
            selectedDays.add(day);
          }
        });
      },

      child: Container(
        margin: const EdgeInsets.only(bottom: 9),

        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),

        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0E9FF) : Colors.white,

          borderRadius: BorderRadius.circular(14),

          border: Border.all(
            color: isSelected
                ? const Color(0xFF6D28D9)
                : const Color(0xFFE5E7EB),
          ),
        ),

        child: Row(
          children: [
            // ======================================================
            // CHECKBOX
            // ======================================================
            Container(
              width: 22,
              height: 22,

              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF6D28D9)
                    : Colors.transparent,

                borderRadius: BorderRadius.circular(6),

                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF6D28D9)
                      : const Color(0xFFD1D5DB),
                ),
              ),

              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 15)
                  : null,
            ),

            const SizedBox(width: 12),

            // ======================================================
            // DAY
            // ======================================================
            Expanded(
              child: Text(
                day,

                style: TextStyle(
                  color: isSelected
                      ? const Color(0xFF6D28D9)
                      : const Color(0xFF374151),

                  fontSize: 14,

                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),

            // ======================================================
            // LABEL
            // ======================================================
            if (isSelected)
              const Text(
                "Weekly Off",
                style: TextStyle(
                  color: Color(0xFF6D28D9),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),

      appBar: AppBar(
        backgroundColor: Colors.white,

        elevation: 0,

        surfaceTintColor: Colors.white,

        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF17133A)),

          onPressed: () {
            Navigator.pop(context);
          },
        ),

        title: const Text(
          "Manage Weekly Off",

          style: TextStyle(
            color: Color(0xFF17133A),
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: getEmployees(),

        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF6D28D9)),
            );
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final employees = snapshot.data?.docs ?? [];

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),

            padding: const EdgeInsets.all(18),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                // ==================================================
                // HEADER
                // ==================================================
                Container(
                  width: double.infinity,

                  padding: const EdgeInsets.all(18),

                  decoration: BoxDecoration(
                    color: Colors.white,

                    borderRadius: BorderRadius.circular(20),
                  ),

                  child: const Row(
                    children: [
                      Icon(
                        Icons.event_repeat_rounded,
                        color: Color(0xFF6D28D9),
                        size: 28,
                      ),

                      SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [
                            Text(
                              "Employee Weekly Off",

                              style: TextStyle(
                                color: Color(0xFF17133A),
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),

                            SizedBox(height: 3),

                            Text(
                              "Set different weekly offs for employees",

                              style: TextStyle(
                                color: Color(0xFF8A8FA3),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // ==================================================
                // EMPLOYEE
                // ==================================================
                const Text(
                  "Select Employee",

                  style: TextStyle(
                    color: Color(0xFF17133A),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 8),

                Container(
                  width: double.infinity,

                  padding: const EdgeInsets.symmetric(horizontal: 14),

                  decoration: BoxDecoration(
                    color: Colors.white,

                    borderRadius: BorderRadius.circular(14),

                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),

                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedUid,

                      isExpanded: true,

                      hint: const Text(
                        "Choose employee",
                        style: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 13,
                        ),
                      ),

                      items: employees.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;

                        final name = data['name']?.toString() ?? "Employee";

                        final department = data['department']?.toString() ?? "";

                        return DropdownMenuItem<String>(
                          value: doc.id,

                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,

                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0E9FF),

                                  borderRadius: BorderRadius.circular(10),
                                ),

                                child: const Icon(
                                  Icons.person_rounded,
                                  color: Color(0xFF6D28D9),
                                  size: 18,
                                ),
                              ),

                              const SizedBox(width: 10),

                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,

                                  crossAxisAlignment: CrossAxisAlignment.start,

                                  children: [
                                    Text(
                                      name,

                                      style: const TextStyle(
                                        color: Color(0xFF374151),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),

                                    if (department.isNotEmpty)
                                      Text(
                                        department,

                                        style: const TextStyle(
                                          color: Color(0xFF9CA3AF),
                                          fontSize: 9,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),

                      onChanged: (uid) {
                        if (uid == null) {
                          return;
                        }

                        final doc = employees.firstWhere(
                          (element) => element.id == uid,
                        );

                        final data = doc.data() as Map<String, dynamic>;

                        setState(() {
                          selectedUid = uid;
                        });

                        loadWeeklyOff(data);
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                // ==================================================
                // WEEKLY OFF
                // ==================================================
                const Text(
                  "Select Weekly Off",

                  style: TextStyle(
                    color: Color(0xFF17133A),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 4),

                const Text(
                  "You can select one or multiple days",

                  style: TextStyle(color: Color(0xFF8A8FA3), fontSize: 10),
                ),

                const SizedBox(height: 10),

                ...weekDays.map((day) => dayItem(day)),

                const SizedBox(height: 15),

                // ==================================================
                // SAVE BUTTON
                // ==================================================
                SizedBox(
                  width: double.infinity,

                  height: 52,

                  child: ElevatedButton(
                    onPressed: saving || selectedUid == null
                        ? null
                        : saveWeeklyOff,

                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6D28D9),

                      disabledBackgroundColor: const Color(0xFFD1D5DB),

                      elevation: 0,

                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),

                    child: saving
                        ? const SizedBox(
                            width: 21,
                            height: 21,

                            child: CircularProgressIndicator(
                              strokeWidth: 2,

                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            "Save Changes",

                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
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
    );
  }
}

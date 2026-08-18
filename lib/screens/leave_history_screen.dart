import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:leave_application/screens/leave_details_screen.dart';

class LeaveHistoryScreen extends StatefulWidget {
  const LeaveHistoryScreen({super.key});

  @override
  State<LeaveHistoryScreen> createState() => _LeaveHistoryScreenState();
}

class _LeaveHistoryScreenState extends State<LeaveHistoryScreen> {
  String selectedStatus = "All";
  final TextEditingController searchController = TextEditingController();
  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Widget _leaveInfo({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,

          decoration: BoxDecoration(
            color: color.withOpacity(.09),
            borderRadius: BorderRadius.circular(9),
          ),

          child: Icon(icon, size: 17, color: color),
        ),

        const SizedBox(width: 8),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 2),

              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,

                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF334155),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statusChip(String status) {
    final bool selected = selectedStatus == status;

    Color color;

    switch (status) {
      case "Approved":
        color = const Color(0xFF16A34A);
        break;

      case "Rejected":
        color = const Color(0xFFDC2626);
        break;

      case "Pending":
        color = const Color(0xFFD97706);
        break;

      default:
        color = const Color(0xFF6D28D9);
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedStatus = status;
        });
      },

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),

        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),

        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(30),

          border: Border.all(color: selected ? color : const Color(0xFFE2E8F0)),

          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withOpacity(.20),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),

        child: Text(
          status,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF475569),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  String formatLeaveDate(DateTime date) {
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

  String getLeaveDateText(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final from = data["fromDate"];
    final to = data["toDate"];

    if (from == null) return "";

    final DateTime fromDate = from is Timestamp
        ? from.toDate()
        : DateTime.now();

    final DateTime toDate = to is Timestamp ? to.toDate() : fromDate;

    final bool sameDate =
        fromDate.year == toDate.year &&
        fromDate.month == toDate.month &&
        fromDate.day == toDate.day;

    if (sameDate) {
      return formatLeaveDate(fromDate);
    }

    return "${formatLeaveDate(fromDate)} → ${formatLeaveDate(toDate)}";
  }
  // String getLeaveDateText(QueryDocumentSnapshot doc) {
  //   final data = doc.data() as Map<String, dynamic>;

  //   final Timestamp? fromTimestamp = data['fromDate'] as Timestamp?;
  //   final Timestamp? toTimestamp = data['toDate'] as Timestamp?;

  //   if (fromTimestamp == null || toTimestamp == null) {
  //     return "Date not available";
  //   }

  //   final from = fromTimestamp.toDate();
  //   final to = toTimestamp.toDate();

  //   final fromText = DateFormat('dd MMM yyyy').format(from);
  //   final toText = DateFormat('dd MMM yyyy').format(to);

  //   // Same day
  //   if (from.year == to.year &&
  //       from.month == to.month &&
  //       from.day == to.day) {
  //     return fromText;
  //   }

  //   // Multiple days
  //   return "$fromText → $toText";
  // }
  String formatLeaveDays(dynamic value) {
    final double days = double.tryParse(value.toString()) ?? 0;

    if (days == days.roundToDouble()) {
      return "${days.toInt()} ${days == 1 ? 'Day' : 'Days'}";
    }

    return "$days Days";
  }

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case "approved":
        return const Color(0xFF16A34A);

      case "rejected":
        return const Color(0xFFDC2626);

      case "pending":
        return const Color(0xFFD97706);

      case "cancelled":
        return const Color(0xFF64748B);

      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    String uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xff1F2937)),
        title: const Text(
          "My Leaves",
          style: TextStyle(
            color: Color(0xff1F2937),
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),

      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('leave_requests')
            .where('uid', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),

        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No Leave Requests Found"));
          }

          var docs = snapshot.data!.docs;
          List<QueryDocumentSnapshot> filteredDocs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;

            bool matchesStatus =
                selectedStatus == "All" || data["status"] == selectedStatus;

            bool matchesSearch = data["leaveType"]
                .toString()
                .toLowerCase()
                .contains(searchController.text.toLowerCase());

            return matchesStatus && matchesSearch;
          }).toList();
          return Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 15, 20, 10),
                child: TextField(
                  controller: searchController,

                  onChanged: (value) {
                    setState(() {});
                  },

                  decoration: InputDecoration(
                    hintText: "Search leaves",
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xff2563EB)),
                    ),
                  ),
                ),
              ),

              // Tabs
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _statusChip("All"),
                    const SizedBox(width: 10),
                    _statusChip("Pending"),
                    const SizedBox(width: 10),
                    _statusChip("Approved"),
                    const SizedBox(width: 10),
                    _statusChip("Rejected"),
                  ],
                ),
              ),

              const Divider(height: 25),

              Expanded(
                child: filteredDocs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEDE9FE),
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: const Icon(
                                Icons.event_busy_rounded,
                                size: 36,
                                color: Color(0xFF6D28D9),
                              ),
                            ),

                            const SizedBox(height: 16),

                            const Text(
                              "No Leaves Found",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1F2937),
                              ),
                            ),

                            const SizedBox(height: 5),

                            Text(
                              "Try changing your search or filter",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 25),
                        physics: const BouncingScrollPhysics(),
                        itemCount: filteredDocs.length,
                        itemBuilder: (context, index) {
                          final doc = filteredDocs[index];

                          final Map<String, dynamic> data =
                              doc.data() as Map<String, dynamic>;

                          final String status =
                              data['status']?.toString() ?? "Pending";

                          final String leaveType =
                              data['leaveType']?.toString() ?? "Leave";

                          final String duration =
                              data['leaveDuration']?.toString() ?? "Full Day";

                          final String? halfDaySession = data['halfDaySession']
                              ?.toString();

                          final Color statusColor = getStatusColor(status);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),

                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),

                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(.055),
                                  blurRadius: 18,
                                  offset: const Offset(0, 7),
                                ),
                              ],
                            ),

                            child: Material(
                              color: Colors.transparent,

                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),

                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          LeaveDetailsScreen(data: data),
                                    ),
                                  );
                                },

                                child: Padding(
                                  padding: const EdgeInsets.all(16),

                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,

                                    children: [
                                      // ==================================================
                                      // TOP ROW
                                      // ==================================================
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,

                                        children: [
                                          // Leave Icon
                                          Container(
                                            width: 48,
                                            height: 48,

                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF0E9FF),
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                            ),

                                            child: const Icon(
                                              Icons.event_note_rounded,
                                              color: Color(0xFF6D28D9),
                                              size: 24,
                                            ),
                                          ),

                                          const SizedBox(width: 12),

                                          // Leave information
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,

                                              children: [
                                                Text(
                                                  leaveType,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,

                                                  style: const TextStyle(
                                                    fontSize: 17,
                                                    fontWeight: FontWeight.w800,
                                                    color: Color(0xFF1F2937),
                                                  ),
                                                ),

                                                const SizedBox(height: 5),

                                                Row(
                                                  children: [
                                                    const Icon(
                                                      Icons
                                                          .calendar_today_rounded,
                                                      size: 13,
                                                      color: Color(0xFF64748B),
                                                    ),

                                                    const SizedBox(width: 5),

                                                    Expanded(
                                                      child: Text(
                                                        getLeaveDateText(doc),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,

                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Color(
                                                            0xFF64748B,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),

                                          const SizedBox(width: 8),

                                          // Status
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 11,
                                              vertical: 6,
                                            ),

                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(
                                                .10,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(30),
                                            ),

                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,

                                              children: [
                                                Container(
                                                  width: 7,
                                                  height: 7,

                                                  decoration: BoxDecoration(
                                                    color: statusColor,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),

                                                const SizedBox(width: 6),

                                                Text(
                                                  status,
                                                  style: TextStyle(
                                                    color: statusColor,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 15),

                                      // ==================================================
                                      // DIVIDER
                                      // ==================================================
                                      Container(
                                        height: 1,
                                        color: const Color(0xFFF1F5F9),
                                      ),

                                      const SizedBox(height: 14),

                                      // ==================================================
                                      // DETAILS
                                      // ==================================================
                                      Row(
                                        children: [
                                          // Duration
                                          Expanded(
                                            child: _leaveInfo(
                                              icon: Icons.access_time_rounded,
                                              title: "Duration",
                                              value: duration,
                                              color: const Color(0xFF2563EB),
                                            ),
                                          ),

                                          // Days
                                          Expanded(
                                            child: _leaveInfo(
                                              icon: Icons.timelapse_rounded,
                                              title: "Leave Days",
                                              value: formatLeaveDays(
                                                data['days'],
                                              ),
                                              color: const Color(0xFF7C3AED),
                                            ),
                                          ),

                                          // Arrow
                                          Container(
                                            width: 34,
                                            height: 34,

                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF8FAFC),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),

                                            child: const Icon(
                                              Icons.arrow_forward_ios_rounded,
                                              size: 14,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),

                                      // ==================================================
                                      // HALF DAY
                                      // ==================================================
                                      if (duration == "Half Day Only" &&
                                          halfDaySession != null) ...[
                                        const SizedBox(height: 12),

                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 9,
                                          ),

                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFF7ED),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: const Color(0xFFFED7AA),
                                            ),
                                          ),

                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.timelapse_rounded,
                                                size: 16,
                                                color: Color(0xFFEA580C),
                                              ),

                                              const SizedBox(width: 8),

                                              Text(
                                                halfDaySession,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF9A3412),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

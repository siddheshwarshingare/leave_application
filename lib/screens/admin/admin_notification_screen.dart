import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminNotificationScreen extends StatefulWidget {
  const AdminNotificationScreen({super.key});

  @override
  State<AdminNotificationScreen> createState() =>
      _AdminNotificationScreenState();
}

class _AdminNotificationScreenState extends State<AdminNotificationScreen> {
  // ============================================================
  // MARK NOTIFICATION AS READ
  // ============================================================

  Future<void> markAsRead(String notificationId) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(notificationId)
        .update({"isRead": true});
  }

  // ============================================================
  // FORMAT DATE
  // ============================================================

  String formatDate(Timestamp? timestamp) {
    if (timestamp == null) {
      return "No date";
    }

    final date = timestamp.toDate();

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

    String hour = date.hour > 12
        ? (date.hour - 12).toString().padLeft(2, '0')
        : date.hour.toString().padLeft(2, '0');

    if (hour == "00") {
      hour = "12";
    }

    final minute = date.minute.toString().padLeft(2, '0');

    final period = date.hour >= 12 ? "PM" : "AM";

    return "${date.day} ${months[date.month - 1]} ${date.year}, "
        "$hour:$minute $period";
  }

  // ============================================================
  // SHOW LEAVE DETAILS
  // ============================================================

  void showLeaveDetails(BuildContext context, Map<String, dynamic> data) {
    final Timestamp? fromDate = data['fromDate'] is Timestamp
        ? data['fromDate'] as Timestamp
        : null;

    final Timestamp? toDate = data['toDate'] is Timestamp
        ? data['toDate'] as Timestamp
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 25),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ==================================================
                  // HANDLE
                  // ==================================================

                  Center(
                    child: Container(
                      width: 45,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1D5DB),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ==================================================
                  // HEADER
                  // ==================================================
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0E9FF),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(
                          Icons.event_note_rounded,
                          color: Color(0xFF6D28D9),
                          size: 26,
                        ),
                      ),

                      const SizedBox(width: 12),

                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Leave Request",
                              style: TextStyle(
                                color: Color(0xFF17133A),
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              "Employee leave details",
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

                  const SizedBox(height: 22),

                  // ==================================================
                  // EMPLOYEE
                  // ==================================================
                  _detailItem(
                    icon: Icons.person_outline_rounded,
                    title: "Employee",
                    value:
                        data['employeeName']?.toString() ?? "Unknown Employee",
                  ),

                  _detailItem(
                    icon: Icons.email_outlined,
                    title: "Email",
                    value: data['employeeEmail']?.toString() ?? "-",
                  ),

                  _detailItem(
                    icon: Icons.category_outlined,
                    title: "Leave Type",
                    value: data['leaveType']?.toString() ?? "-",
                  ),

                  _detailItem(
                    icon: Icons.calendar_today_outlined,
                    title: "Days",
                    value: data['days']?.toString() ?? "0",
                  ),

                  _detailItem(
                    icon: Icons.date_range_outlined,
                    title: "From Date",
                    value: fromDate != null ? formatDate(fromDate) : "No date",
                  ),

                  _detailItem(
                    icon: Icons.event_outlined,
                    title: "To Date",
                    value: toDate != null ? formatDate(toDate) : "No date",
                  ),

                  _detailItem(
                    icon: Icons.timelapse_outlined,
                    title: "Duration",
                    value: data['leaveDuration']?.toString() ?? "-",
                  ),

                  _detailItem(
                    icon: Icons.description_outlined,
                    title: "Reason",
                    value: data['reason']?.toString() ?? "-",
                  ),

                  _detailItem(
                    icon: Icons.info_outline_rounded,
                    title: "Status",
                    value: data['status']?.toString() ?? "Pending",
                  ),

                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6D28D9),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        "Close",
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // DETAIL ITEM
  // ============================================================

  Widget _detailItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F7FC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: const Color(0xFF6D28D9)),

          const SizedBox(width: 10),

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

                const SizedBox(height: 3),

                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF374151),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
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
        title: const Text(
          "Admin Notifications",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF17133A),
        elevation: 0,
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('role', isEqualTo: 'admin')
            .orderBy('createdAt', descending: true)
            .snapshots(),

        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF6D28D9)),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  snapshot.error.toString(),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 60,
                    color: Color(0xFFB8B5C3),
                  ),
                  SizedBox(height: 12),
                  Text(
                    "No Notifications",
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          // ==========================================================
          // UNREAD COUNT
          // ==========================================================

          final unreadCount = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['isRead'] != true;
          }).length;

          return Column(
            children: [
              // ========================================================
              // NOTIFICATION SUMMARY
              // ========================================================

              if (unreadCount > 0)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(15, 15, 15, 5),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0E9FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.notifications_active_rounded,
                        color: Color(0xFF6D28D9),
                        size: 20,
                      ),

                      const SizedBox(width: 9),

                      Text(
                        "$unreadCount unread notification"
                        "${unreadCount == 1 ? '' : 's'}",
                        style: const TextStyle(
                          color: Color(0xFF6D28D9),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

              // ========================================================
              // LIST
              // ========================================================
              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(top: 10, bottom: 20),
                  itemCount: docs.length,

                  itemBuilder: (context, index) {
                    final doc = docs[index];

                    final data = doc.data() as Map<String, dynamic>;

                    final bool isRead = data['isRead'] == true;

                    final Timestamp? createdAt = data['createdAt'] is Timestamp
                        ? data['createdAt'] as Timestamp
                        : null;

                    final String employeeName =
                        data['employeeName']?.toString() ?? "Employee";

                    final String title =
                        data['title']?.toString() ?? "Leave Request";

                    final String body =
                        data['body']?.toString() ?? "New leave request";

                    // ==================================================
                    // NOTIFICATION CARD
                    // ==================================================

                    return InkWell(
                      onTap: () async {
                        // Mark ONLY this notification as read
                        if (!isRead) {
                          await FirebaseFirestore.instance
                              .collection('notifications')
                              .doc(docs[index].id)
                              .update({'isRead': true});
                        }

                        // Show details if required
                      },
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(15, 6, 15, 8),
                        padding: const EdgeInsets.all(15),

                        decoration: BoxDecoration(
                          // UNREAD = light purple
                          // READ = white
                          color: isRead
                              ? Colors.white
                              : const Color(0xFFF0E9FF),

                          borderRadius: BorderRadius.circular(18),

                          border: Border.all(
                            color: isRead
                                ? const Color(0xFFE5E7EB)
                                : const Color(0xFF6D28D9),
                            width: isRead ? 1 : 1.5,
                          ),

                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(
                                isRead ? 0.025 : 0.07,
                              ),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),

                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ICON
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: isRead
                                    ? const Color(0xFFF3F4F6)
                                    : const Color(0xFF6D28D9),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                isRead
                                    ? Icons.notifications_none_rounded
                                    : Icons.notifications_active_rounded,
                                color: isRead
                                    ? const Color(0xFF6B7280)
                                    : Colors.white,
                              ),
                            ),

                            const SizedBox(width: 12),

                            // CONTENT
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          data['title'] ?? '',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: const Color(0xFF17133A),

                                            // UNREAD = BOLD
                                            fontWeight: isRead
                                                ? FontWeight.w600
                                                : FontWeight.w800,
                                          ),
                                        ),
                                      ),

                                      // RED DOT ONLY FOR UNREAD
                                      if (!isRead)
                                        Container(
                                          width: 9,
                                          height: 9,
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),

                                  const SizedBox(height: 5),

                                  Text(
                                    data['body'] ?? '',
                                    style: TextStyle(
                                      color: isRead
                                          ? const Color(0xFF8A8FA3)
                                          : const Color(0xFF374151),
                                      fontSize: 12,
                                      fontWeight: isRead
                                          ? FontWeight.w400
                                          : FontWeight.w600,
                                    ),
                                  ),

                                  const SizedBox(height: 7),

                                  Text(
                                    data['createdAt'] != null
                                        ? data['createdAt'].toDate().toString()
                                        : '',
                                    style: const TextStyle(
                                      color: Color(0xFF9CA3AF),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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

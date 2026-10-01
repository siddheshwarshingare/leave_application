import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  Future<void> markNotificationRead(String notificationId) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  String formatDate(Timestamp? timestamp) {
    if (timestamp == null) return "No Date";

    final date = timestamp.toDate();

    String twoDigits(int value) {
      return value.toString().padLeft(2, '0');
    }

    return "${twoDigits(date.day)}/"
        "${twoDigits(date.month)}/"
        "${date.year} "
        "${twoDigits(date.hour)}:"
        "${twoDigits(date.minute)}";
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text("User not logged in")));
    }

    final String uid = user.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),

      appBar: AppBar(
        title: const Text(
          "Notifications",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF17133A),
        elevation: 0,
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('uid', isEqualTo: uid)
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
              child: Text(
                "Error: ${snapshot.error}",
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No Notifications",
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 15),
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),

            itemCount: docs.length,

            itemBuilder: (context, index) {
              final doc = docs[index];

              final data = doc.data() as Map<String, dynamic>;

              // ==========================================
              // READ / UNREAD
              // ==========================================

              final bool isRead = data['isRead'] == true;

              final String title = data['title']?.toString() ?? "Notification";

              final String body = data['body']?.toString() ?? "";

              final Timestamp? timestamp = data['createdAt'] is Timestamp
                  ? data['createdAt'] as Timestamp
                  : null;

              // ==========================================
              // NOTIFICATION TYPE
              // ==========================================

              final bool isApproved = title.toLowerCase().contains("approved");

              final bool isRejected = title.toLowerCase().contains("rejected");

              Color iconColor;
              Color iconBackground;
              IconData icon;

              if (isApproved) {
                iconColor = const Color(0xFF16A34A);
                iconBackground = const Color(0xFFDCFCE7);
                icon = Icons.check_circle_rounded;
              } else if (isRejected) {
                iconColor = const Color(0xFFDC2626);
                iconBackground = const Color(0xFFFEE2E2);
                icon = Icons.cancel_rounded;
              } else {
                iconColor = const Color(0xFF6D28D9);
                iconBackground = const Color(0xFFF0E9FF);
                icon = Icons.notifications_rounded;
              }

              return GestureDetector(
                onTap: () async {
                  // ==========================================
                  // ONLY THIS NOTIFICATION BECOMES READ
                  // ==========================================

                  if (!isRead) {
                    await markNotificationRead(doc.id);
                  }

                  // Optional:
                  // Here you can navigate to leave details.
                },

                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),

                  margin: const EdgeInsets.only(bottom: 10),

                  padding: const EdgeInsets.all(14),

                  decoration: BoxDecoration(
                    // ==========================================
                    // UNREAD = LIGHT PURPLE
                    // READ = WHITE
                    // ==========================================

                    color: isRead ? Colors.white : const Color(0xFFF3EEFF),

                    borderRadius: BorderRadius.circular(16),

                    border: Border.all(
                      color: isRead
                          ? const Color(0xFFE5E7EB)
                          : const Color(0xFFD8C8FF),

                      width: isRead ? 1 : 1.3,
                    ),

                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isRead ? .025 : .06),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),

                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      // ==========================================
                      // ICON
                      // ==========================================

                      Container(
                        width: 44,
                        height: 44,

                        decoration: BoxDecoration(
                          color: iconBackground,
                          borderRadius: BorderRadius.circular(13),
                        ),

                        child: Icon(icon, color: iconColor, size: 23),
                      ),

                      const SizedBox(width: 12),

                      // ==========================================
                      // CONTENT
                      // ==========================================
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,

                              children: [
                                Expanded(
                                  child: Text(
                                    title,

                                    style: TextStyle(
                                      color: const Color(0xFF17133A),

                                      fontSize: 14,

                                      fontWeight: isRead
                                          ? FontWeight.w600
                                          : FontWeight.w800,
                                    ),
                                  ),
                                ),

                                // ==================================
                                // UNREAD DOT
                                // ==================================
                                if (!isRead)
                                  Container(
                                    width: 9,
                                    height: 9,

                                    margin: const EdgeInsets.only(
                                      left: 8,
                                      top: 5,
                                    ),

                                    decoration: const BoxDecoration(
                                      color: Color(0xFF6D28D9),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),

                            const SizedBox(height: 5),

                            Text(
                              body,

                              style: TextStyle(
                                color: const Color(0xFF4B5563),

                                fontSize: 12,

                                fontWeight: isRead
                                    ? FontWeight.w400
                                    : FontWeight.w500,

                                height: 1.4,
                              ),
                            ),

                            const SizedBox(height: 8),

                            // ==========================================
                            // TIME
                            // ==========================================
                            Row(
                              children: [
                                const Icon(
                                  Icons.access_time_rounded,
                                  size: 13,
                                  color: Color(0xFF9CA3AF),
                                ),

                                const SizedBox(width: 4),

                                Text(
                                  formatDate(timestamp),

                                  style: const TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),

                                const Spacer(),

                                // ======================================
                                // READ / UNREAD LABEL
                                // ======================================
                                Text(
                                  isRead ? "Read" : "Unread",

                                  style: TextStyle(
                                    color: isRead
                                        ? const Color(0xFF9CA3AF)
                                        : const Color(0xFF6D28D9),

                                    fontSize: 10,

                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminNotificationScreen extends StatefulWidget {
  const AdminNotificationScreen({super.key});

  @override
  State<AdminNotificationScreen> createState() =>
      _AdminNotificationScreenState();
}

class _AdminNotificationScreenState extends State<AdminNotificationScreen> {
  @override
  void initState() {
    super.initState();
    markAllRead();
  }

  Future<void> markAllRead() async {
    QuerySnapshot snap = await FirebaseFirestore.instance
        .collection('notifications')
        .where('type', isEqualTo: 'admin')
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in snap.docs) {
      await doc.reference.update({"isRead": true});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Admin Notifications",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('role', isEqualTo: 'admin')
            .orderBy('createdAt', descending: true)
            .snapshots(),

        builder: (context, snapshot) {
          print(snapshot.data?.docs.length);

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No Notifications"));
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,

            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;

              Timestamp? ts = data['createdAt'];

              return Card(
                margin: const EdgeInsets.all(10),

                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: Icon(Icons.notifications, color: Colors.white),
                  ),

                  title: Text(
                    data['title'] ?? "",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),

                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      const SizedBox(height: 5),

                      Text(data['body'] ?? ""),

                      const SizedBox(height: 5),

                      Text(
                        ts != null ? ts.toDate().toString() : "No Date",

                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
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

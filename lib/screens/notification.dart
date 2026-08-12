import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      markAllRead();
    });
  }

  Future<void> markAllRead() async {
    String uid = FirebaseAuth.instance.currentUser!.uid;

    QuerySnapshot snap = await FirebaseFirestore.instance
        .collection('notifications')
        .where('uid', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .get();

    WriteBatch batch = FirebaseFirestore.instance.batch();

    for (var doc in snap.docs) {
      batch.update(doc.reference, {"isRead": true});
    }

    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    String uid = FirebaseAuth.instance.currentUser!.uid;

    print("LOGIN UID = $uid");

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Notifications",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('uid', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            print("STREAM ERROR = ${snapshot.error}");

            return Center(child: Text("Error: ${snapshot.error}"));
          }

          if (!snapshot.hasData) {
            return const Center(child: Text("No Data Found"));
          }

          final docs = snapshot.data!.docs;

          print("TOTAL DOCS = ${docs.length}");

          if (docs.isEmpty) {
            return const Center(child: Text("No Notifications"));
          }

          return ListView.builder(
            itemCount: docs.length,

            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;

              print("NOTIFICATION DATA = $data");

              bool approved = (data['title'] ?? "").toString().contains(
                "Approved",
              );

              Timestamp? ts = data['createdAt'];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),

                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: approved ? Colors.green : Colors.red,

                    child: Icon(
                      approved ? Icons.check : Icons.close,

                      color: Colors.white,
                    ),
                  ),

                  title: Text(
                    data['title'] ?? "No Title",

                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),

                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      const SizedBox(height: 5),

                      Text(data['body'] ?? "No Body"),

                      const SizedBox(height: 5),

                      Text(
                        ts != null ? ts.toDate().toString() : "No Date",

                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                                                                                 
                      const SizedBox(height: 5),

                      Text(
                        "UID: ${data['uid'] ?? ''}",
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 11,
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

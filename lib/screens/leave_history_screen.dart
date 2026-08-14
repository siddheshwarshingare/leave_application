import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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

  Widget _statusChip(String title) {
    bool isSelected = selectedStatus == title;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(25),
        onTap: () {
          setState(() {
            selectedStatus = title;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xff2563EB) : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
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
                child: ListView.builder(
                  itemCount: filteredDocs.length,

                  itemBuilder: (context, index) {
                    var data = filteredDocs[index];
                    Color statusColor = data['status'] == 'Approved'
                        ? Colors.green
                        : data['status'] == 'Rejected'
                        ? Colors.red
                        : Colors.orange;

                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,

                          MaterialPageRoute(
                            builder: (_) => LeaveDetailsScreen(
                              data: data.data() as Map<String, dynamic>,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(.12),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),

                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            /// Top Row
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data["leaveType"],
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xff1F2937),
                                        ),
                                      ),

                                      const SizedBox(height: 8),

                                      Text(
                                        data["leaveDuration"],
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(.12),
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Text(
                                    data["status"],
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 18),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    data["reason"],
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),

                                Text(
                                  "${data["days"]} Day${data["days"] == "1" ? "" : "s"}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: Color(0xff1F2937),
                                  ),
                                ),
                              ],
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

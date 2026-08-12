import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:leave_application/screens/attendance_screen.dart';
import 'package:leave_application/screens/employee_attedance_screen.dart';
import 'package:leave_application/screens/leave_history_screen.dart';
import 'package:leave_application/screens/leave_screen.dart';
import 'package:leave_application/screens/notification.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String name = "";
  String role = "";
  String email = "";
  int totalLeave = 0;
  int usedLeave = 0;
  int clLeave = 3;
  int slLeave = 10;
  int remainingLeave = 0;

  @override
  void initState() {
    super.initState();
    getUserData();
    getLeaveData();
    markAllRead();
  }

  Future<void> showPunchDetails(
    BuildContext context,
    String attendanceId,
  ) async {
    QuerySnapshot snap = await FirebaseFirestore.instance
        .collection('attendance')
        .doc(attendanceId)
        .collection('punches')
        .orderBy('time')
        .get();

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Attendance Details"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: snap.docs.length,
              itemBuilder: (_, index) {
                var punch = snap.docs[index];

                DateTime time = (punch['time'] as Timestamp).toDate();

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: punch['type'] == "IN"
                        ? Colors.green
                        : Colors.red,
                    child: Icon(
                      punch['type'] == "IN" ? Icons.login : Icons.logout,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(punch['type'] == "IN" ? "Punch In" : "Punch Out"),
                  subtitle: Text(time.toString()),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> getLeaveData() async {
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;

      // 1. FIXED LEAVE BALANCE (DO NOT CHANGE IN DB)
      DocumentSnapshot leaveDoc = await FirebaseFirestore.instance
          .collection('toatl_leave')
          .doc(uid)
          .get();

      //    int clLeave = int.tryParse(leaveData['Cl'].toString()) ?? 0;
      //int slLeave = int.tryParse(leaveData['Sl'].toString()) ?? 0;

      int total = clLeave + slLeave;

      // 2. USED LEAVE = ONLY FROM REQUESTS
      QuerySnapshot snap = await FirebaseFirestore.instance
          .collection('leave_requests')
          .where('uid', isEqualTo: uid)
          .where('status', isEqualTo: 'Approved')
          .get();

      int used = snap.docs.fold(0, (sum, doc) {
        return sum + ((doc['days'] as num?)?.toInt() ?? 1);
      });

      // 3. FINAL
      setState(() {
        totalLeave = total;
        usedLeave = used;
        remainingLeave = total - used;
      });
    } catch (e) {
      print("ERROR: $e");
    }
  }

  Widget actionCard({
    required IconData icon,
    required String title,
    required Color iconColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          height: 115,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),

              const Spacer(),

              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> markAllRead() async {
    String uid = FirebaseAuth.instance.currentUser!.uid;

    QuerySnapshot snap = await FirebaseFirestore.instance
        .collection('notifications')
        .where('uid', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in snap.docs) {
      await doc.reference.update({"isRead": true});
    }
  }

  getUserData() async {
    String uid = FirebaseAuth.instance.currentUser!.uid;

    DocumentSnapshot user = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    setState(() {
      name = user['name'];
      role = user['role'];
      email = user['email'];
    });
  }

  logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.clear();

    await FirebaseAuth.instance.signOut();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Widget quickActionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: colors.first.withOpacity(.30),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Container(
            height: 161,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.20),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.white, size: 26),
                ),

                const Spacer(),

                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),

                const SizedBox(height: 10),

                Row(
                  children: const [
                    Spacer(),

                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget leaveCard({
    required String title,
    required String value,
    required Color startColor,
    required Color endColor,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        height: 135,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [startColor, endColor],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: startColor.withOpacity(.25),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),

            const Spacer(),

            Text(
              value,
              style: const TextStyle(
                fontSize: 30,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF7F8FC),

      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ///================ APP BAR =================
                Row(
                  children: [
                    Container(
                      height: 42,
                      width: 42,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 8),
                        ],
                      ),
                      child: const Icon(
                        Icons.menu_rounded,
                        color: Color(0xff1F2937),
                      ),
                    ),

                    const Spacer(),

                    const Text(
                      "Dashboard",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xff1F2937),
                      ),
                    ),
                    const Spacer(),

                    Stack(
                      children: [
                        InkWell(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const NotificationScreen(),
                              ),
                            );

                            setState(() {});
                          },
                          child: Container(
                            height: 42,
                            width: 42,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 8),
                              ],
                            ),
                            child: const Icon(Icons.notifications_none),
                          ),
                        ),

                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('notifications')
                              .where(
                                'uid',
                                isEqualTo:
                                    FirebaseAuth.instance.currentUser!.uid,
                              )
                              .where('isRead', isEqualTo: false)
                              .snapshots(),
                          builder: (context, snapshot) {
                            int count = snapshot.data?.docs.length ?? 0;

                            if (count == 0) {
                              return const SizedBox();
                            }

                            return Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                height: 18,
                                width: 18,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    "$count",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 11),

                ///================ GREETING =================
                // Row(
                //   children: [
                //     Expanded(
                //       child: Column(
                //         crossAxisAlignment: CrossAxisAlignment.start,
                //         children: [
                //           Text(
                //             "Hi, $name 👋",
                //             style: const TextStyle(
                //               fontSize: 28,
                //               fontWeight: FontWeight.bold,
                //             ),
                //           ),

                //           const SizedBox(height: 6),

                //           const Text(
                //             "Have a nice day!",
                //             style: TextStyle(color: Colors.grey, fontSize: 16),
                //           ),
                //         ],
                //       ),
                //     ),

                //     CircleAvatar(
                //       radius: 28,
                //       backgroundColor: Colors.blue.shade100,
                //       child: const Icon(
                //         Icons.person,
                //         size: 30,
                //         color: Colors.blue,
                //       ),
                //     ),
                //   ],
                // ),
                Divider(color: Colors.grey.shade300, thickness: 1),
                const SizedBox(height: 11),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Hi, $name 👋",
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xff1F2937),
                            ),
                          ),

                          const SizedBox(height: 6),

                          const Text(
                            "Have a nice day!",
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Container(
                      height: 62,
                      width: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(.08),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 30,
                        backgroundColor: const Color(0xffE8F0FE),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : "U",
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Color(0xff2563EB),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 11),

                ///================ LEAVE HEADER =================
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Leave Balance",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff1F2937),
                      ),
                    ),

                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LeaveHistoryScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        "View All",
                        style: TextStyle(
                          color: Color(0xff2563EB),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                Row(
                  children: [
                    leaveCard(
                      title: "CL Leave",
                      value: clLeave.toString(),
                      icon: Icons.event_available,
                      startColor: const Color(0xff34D399),
                      endColor: const Color(0xff10B981),
                    ),

                    const SizedBox(width: 12),

                    leaveCard(
                      title: "SL Leave",
                      value: slLeave.toString(),
                      icon: Icons.medical_services,
                      startColor: const Color(0xff60A5FA),
                      endColor: const Color(0xff2563EB),
                    ),

                    const SizedBox(width: 12),

                    leaveCard(
                      title: "Remaining",
                      value: remainingLeave.toString(),
                      icon: Icons.star,
                      startColor: const Color(0xff8B5CF6),
                      endColor: const Color(0xff6D28D9),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                const Text(
                  "Quick Actions",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 18),

                Row(
                  children: [
                    quickActionCard(
                      context: context,
                      title: "Apply Leave",
                      subtitle: "Submit a new request",
                      icon: Icons.edit_calendar_rounded,
                      colors: const [Color(0xff6366F1), Color(0xff4F46E5)],
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ApplyLeaveScreen(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(width: 16),

                    quickActionCard(
                      context: context,
                      title: "My Leaves",
                      subtitle: "Track leave status",
                      icon: Icons.description_rounded,
                      colors: const [Color(0xff06B6D4), Color(0xff0891B2)],
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LeaveHistoryScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    quickActionCard(
                      context: context,
                      title: "Attendance",
                      subtitle: "Punch In / Out",
                      icon: Icons.access_time_filled_rounded,
                      colors: const [Color(0xffF59E0B), Color(0xffD97706)],
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AttendanceScreen(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(width: 16),

                    quickActionCard(
                      context: context,
                      title: "My Attendance",
                      subtitle: "View history",
                      icon: Icons.history_rounded,
                      colors: const [Color(0xff10B981), Color(0xff059669)],
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const EmployeeAttendanceScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      bool? shouldLogout = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text("Logout"),
                          content: const Text(
                            "Are you sure you want to logout?",
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text("Cancel"),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text("Logout"),
                            ),
                          ],
                        ),
                      );

                      if (shouldLogout == true) {
                        logout();
                      }
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text(
                      "Logout",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ), // const SizedBox(height: 10),
                // Row(
                //   children: [
                //     actionCard(
                //       title: "Apply Leave",
                //       icon: Icons.add_box_rounded,
                //       iconColor: Colors.indigo,
                //       bgColor: const Color(0xffEEF2FF),
                //       onTap: () {
                //         Navigator.push(
                //           context,
                //           MaterialPageRoute(
                //             builder: (_) => const ApplyLeaveScreen(),
                //           ),
                //         );
                //       },
                //     ),

                //     const SizedBox(width: 15),

                //     actionCard(
                //       title: "My Leaves",
                //       icon: Icons.description_rounded,
                //       iconColor: Colors.blue,
                //       bgColor: const Color(0xffEAF7FF),
                //       onTap: () {
                //         Navigator.push(
                //           context,
                //           MaterialPageRoute(
                //             builder: (_) => const LeaveHistoryScreen(),
                //           ),
                //         );
                //       },
                //     ),
                //   ],
                // ),

                // const SizedBox(height: 15),

                // Row(
                //   children: [
                //     actionCard(
                //       title: "Attendance",
                //       icon: Icons.access_time_filled_rounded,
                //       iconColor: Colors.orange,
                //       bgColor: const Color(0xffFFF7EA),
                //       onTap: () {
                //         Navigator.push(
                //           context,
                //           MaterialPageRoute(
                //             builder: (_) => const AttendanceScreen(),
                //           ),
                //         );
                //       },
                //     ),

                //     const SizedBox(width: 15),

                //     actionCard(
                //       title: "My Attendance",
                //       icon: Icons.history_rounded,
                //       iconColor: Colors.purple,
                //       bgColor: const Color(0xffF4EEFF),
                //       onTap: () {
                //         Navigator.push(
                //           context,
                //           MaterialPageRoute(
                //             builder: (_) => const EmployeeAttendanceScreen(),
                //           ),
                //         );
                //       },
                //     ),
                //   ],
                // ),
              ],
            ),
          ),
        ),
      ),
    );
    // return Scaffold(
    //   //  backgroundColor: const Color(0xFFF5F5F5),
    //   appBar: AppBar(
    //     title: const Text(
    //       "Dashboard",
    //       style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
    //     ),
    //     actions: [
    //       IconButton(onPressed: logout, icon: const Icon(Icons.logout)),
    //     ],
    //     backgroundColor: Colors.blue,

    //     foregroundColor: Colors.white,
    //   ),

    //   body:
    //   Padding(
    //     padding: const EdgeInsets.all(20),

    //     child: Column(
    //       crossAxisAlignment: CrossAxisAlignment.start,

    //       children: [
    //         Row(
    //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
    //           children: [
    //             Text(
    //               "Welcome  $name",
    //               style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    //             ),
    //             StreamBuilder<QuerySnapshot>(
    //               stream: FirebaseFirestore.instance
    //                   .collection('notifications')
    //                   .where(
    //                     'uid',
    //                     isEqualTo: FirebaseAuth.instance.currentUser!.uid,
    //                   )
    //                   .where('isRead', isEqualTo: false)
    //                   .snapshots(),

    //               builder: (context, snapshot) {
    //                 int count = snapshot.data?.docs.length ?? 0;

    //                 return Stack(
    //                   children: [
    //                     IconButton(
    //                       icon: const Icon(Icons.notifications),

    //                       onPressed: () async {
    //                         await Navigator.push(
    //                           context,
    //                           MaterialPageRoute(
    //                             builder: (_) => const NotificationScreen(),
    //                           ),
    //                         );

    //                         setState(() {});
    //                       },
    //                     ),

    //                     if (count > 0)
    //                       Positioned(
    //                         right: 8,
    //                         top: 8,

    //                         child: Container(
    //                           padding: const EdgeInsets.all(5),

    //                           decoration: const BoxDecoration(
    //                             color: Colors.red,
    //                             shape: BoxShape.circle,
    //                           ),

    //                           constraints: const BoxConstraints(
    //                             minWidth: 20,
    //                             minHeight: 20,
    //                           ),

    //                           child: Text(
    //                             "$count",

    //                             textAlign: TextAlign.center,

    //                             style: const TextStyle(
    //                               color: Colors.white,
    //                               fontSize: 12,
    //                               fontWeight: FontWeight.bold,
    //                             ),
    //                           ),
    //                         ),
    //                       ),
    //                   ],
    //                 );
    //               },
    //             ),
    //           ],
    //         ),

    //         const SizedBox(height: 4),

    //         Card(
    //           elevation: 8,
    //           color: const Color.fromARGB(255, 99, 204, 186),
    //           child: Padding(
    //             padding: const EdgeInsets.all(20),

    //             child: Column(
    //               crossAxisAlignment: CrossAxisAlignment.start,

    //               children: [
    //                 Text(
    //                   "Name : $name",
    //                   style: const TextStyle(
    //                     fontSize: 18,
    //                     color: Colors.white,
    //                     fontWeight: FontWeight.bold,
    //                   ),
    //                 ),

    //                 const SizedBox(height: 10),

    //                 Text(
    //                   "Email : $email",
    //                   style: const TextStyle(
    //                     fontSize: 18,
    //                     color: Colors.white,
    //                     fontWeight: FontWeight.bold,
    //                   ),
    //                 ),

    //                 const SizedBox(height: 10),

    //                 Text(
    //                   "Role : $role",
    //                   style: const TextStyle(
    //                     fontSize: 18,
    //                     color: Colors.white,
    //                     fontWeight: FontWeight.bold,
    //                   ),
    //                 ),
    //               ],
    //             ),
    //           ),
    //         ),

    //         const SizedBox(height: 4),
    //         Card(
    //           elevation: 4,
    //           child: Padding(
    //             padding: const EdgeInsets.all(20),
    //             child: Column(
    //               crossAxisAlignment: CrossAxisAlignment.start,
    //               children: [
    //                 Text(
    //                   "Total Leave: $totalLeave ==$clLeave CL + $slLeave SL",
    //                   style: const TextStyle(fontSize: 16),
    //                 ),
    //                 const SizedBox(height: 10),
    //                 Text(
    //                   "Used Leave: $usedLeave",
    //                   style: const TextStyle(fontSize: 16),
    //                 ),
    //                 const SizedBox(height: 10),
    //                 Text(
    //                   "Remaining Leave: $remainingLeave",
    //                   style: const TextStyle(
    //                     fontSize: 16,
    //                     fontWeight: FontWeight.bold,
    //                     color: Colors.green,
    //                   ),
    //                 ),
    //                 ElevatedButton(
    //                   onPressed: () {
    //                     getLeaveData();
    //                     getLeaveData(); // refresh
    //                   },
    //                   child: const Text(
    //                     "Refresh Leave",
    //                     style: TextStyle(
    //                       fontSize: 14,
    //                       fontWeight: FontWeight.w600,
    //                     ),
    //                   ),
    //                 ),
    //               ],
    //             ),
    //           ),
    //         ),
    //         const SizedBox(height: 30),

    //         Row(
    //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
    //           children: [
    //             ElevatedButton(
    //               onPressed: () {
    //                 Navigator.push(
    //                   context,

    //                   MaterialPageRoute(
    //                     builder: (_) => const ApplyLeaveScreen(),
    //                   ),
    //                 );
    //               },

    //               child: const Text(
    //                 "Apply Leave",
    //                 style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    //               ),
    //             ),
    //             const SizedBox(width: 20),
    //             ElevatedButton(
    //               onPressed: () {
    //                 Navigator.push(
    //                   context,

    //                   MaterialPageRoute(
    //                     builder: (_) => const LeaveHistoryScreen(),
    //                   ),
    //                 );
    //               },

    //               child: const Text(
    //                 "My Leave Status",
    //                 style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    //               ),
    //             ),
    //           ],
    //         ),

    //         InkWell(
    //           borderRadius: BorderRadius.circular(16),
    //           onTap: () {
    //             Navigator.push(
    //               context,
    //               MaterialPageRoute(builder: (_) => const AttendanceScreen()),
    //             );
    //           },
    //           child: Container(
    //             margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    //             padding: const EdgeInsets.all(16),
    //             decoration: BoxDecoration(
    //               borderRadius: BorderRadius.circular(16),
    //               gradient: const LinearGradient(
    //                 colors: [Color(0xff1976D2), Color(0xff42A5F5)],
    //               ),
    //               boxShadow: [
    //                 BoxShadow(
    //                   color: Colors.blue.withOpacity(0.3),
    //                   blurRadius: 10,
    //                   offset: const Offset(0, 5),
    //                 ),
    //               ],
    //             ),
    //             child: Row(
    //               children: [
    //                 Container(
    //                   padding: const EdgeInsets.all(12),
    //                   decoration: BoxDecoration(
    //                     color: Colors.white.withOpacity(0.2),
    //                     borderRadius: BorderRadius.circular(12),
    //                   ),
    //                   child: const Icon(
    //                     Icons.access_time_filled,
    //                     color: Colors.white,
    //                     size: 28,
    //                   ),
    //                 ),

    //                 const SizedBox(width: 15),

    //                 const Expanded(
    //                   child: Column(
    //                     crossAxisAlignment: CrossAxisAlignment.start,
    //                     children: [
    //                       Text(
    //                         "Attendance",
    //                         style: TextStyle(
    //                           color: Colors.white,
    //                           fontSize: 18,
    //                           fontWeight: FontWeight.bold,
    //                         ),
    //                       ),

    //                       SizedBox(height: 4),

    //                       Text(
    //                         "Punch In / Punch Out",
    //                         style: TextStyle(
    //                           color: Colors.white70,
    //                           fontSize: 13,
    //                         ),
    //                       ),
    //                     ],
    //                   ),
    //                 ),

    //                 const Icon(
    //                   Icons.arrow_forward_ios,
    //                   color: Colors.white,
    //                   size: 18,
    //                 ),
    //               ],
    //             ),
    //           ),
    //         ),
    //         const SizedBox(height: 30),

    //         Center(
    //           child: ElevatedButton.icon(
    //             icon: const Icon(Icons.history),
    //             label: const Text("My Attendance"),
    //             onPressed: () {
    //               Navigator.push(
    //                 context,
    //                 MaterialPageRoute(
    //                   builder: (_) => const EmployeeAttendanceScreen(),
    //                 ),
    //               );
    //             },
    //           ),
    //         ),
    //       ],
    //     ),
    //   ),

    // );
  }
}

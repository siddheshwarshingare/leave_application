import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// class EmployeeAttendanceScreen extends StatelessWidget {
//   const EmployeeAttendanceScreen({super.key});

//   Future<void> showPunchDetails(
//     BuildContext context,
//     String attendanceId,
//   ) async {
//     QuerySnapshot snap = await FirebaseFirestore.instance
//         .collection('attendance')
//         .doc(attendanceId)
//         .collection('punches')
//         .orderBy('time')
//         .get();

//     showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: const Text("Punch Details"),
//         content: SizedBox(
//           width: double.maxFinite,
//           child: ListView.builder(
//             shrinkWrap: true,
//             itemCount: snap.docs.length,
//             itemBuilder: (_, index) {
//               var punch = snap.docs[index];

//               DateTime time = (punch['time'] as Timestamp).toDate();

//               return ListTile(
//                 leading: Icon(
//                   punch['type'] == "IN" ? Icons.login : Icons.logout,
//                   color: punch['type'] == "IN" ? Colors.green : Colors.red,
//                 ),
//                 title: Text(punch['type']),
//                 subtitle: Text(time.toString()),
//               );
//             },
//           ),
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     String uid = FirebaseAuth.instance.currentUser!.uid;

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text(
//           "My Attendance",
//           style: TextStyle(fontWeight: FontWeight.bold),
//         ),
//         backgroundColor: Colors.blue,
//         //foregroundColor: Colors.black,
//       ),

//       body: StreamBuilder<QuerySnapshot>(
//         stream: FirebaseFirestore.instance
//             .collection('attendance')
//             .where('uid', isEqualTo: uid)
//             .orderBy('date', descending: true)
//             .snapshots(),

//         builder: (context, snapshot) {
//           if (!snapshot.hasData) {
//             return const Center(child: CircularProgressIndicator());
//           }

//           final docs = snapshot.data!.docs;

//           if (docs.isEmpty) {
//             return const Center(child: Text("No Attendance Found"));
//           }

//           return ListView.builder(
//             itemCount: docs.length,
//             itemBuilder: (context, index) {
//               var data = docs[index];

//               return Card(
//                 elevation: 6,
//                 margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(18),
//                 ),
//                 child: Container(
//                   padding: const EdgeInsets.all(16),
//                   decoration: BoxDecoration(
//                     borderRadius: BorderRadius.circular(18),
//                     gradient: LinearGradient(
//                       colors: [Colors.blue.shade50, Colors.white],
//                     ),
//                   ),
//                   child: Row(
//                     children: [
//                       Container(
//                         padding: const EdgeInsets.all(14),
//                         decoration: BoxDecoration(
//                           color: Colors.blue.shade100,
//                           borderRadius: BorderRadius.circular(14),
//                         ),
//                         child: const Icon(
//                           Icons.calendar_month,
//                           color: Colors.blue,
//                           size: 30,
//                         ),
//                       ),

//                       const SizedBox(width: 15),

//                       Expanded(
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               data['date'],
//                               style: const TextStyle(
//                                 fontSize: 17,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),

//                             const SizedBox(height: 8),

//                             Row(
//                               children: [
//                                 const Icon(
//                                   Icons.access_time,
//                                   size: 18,
//                                   color: Colors.green,
//                                 ),

//                                 const SizedBox(width: 5),

//                                 Text(
//                                   data['workingHours'],
//                                   style: const TextStyle(
//                                     fontSize: 15,
//                                     fontWeight: FontWeight.w600,
//                                     color: Colors.green,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ],
//                         ),
//                       ),

//                       InkWell(
//                         onTap: () {
//                           showPunchDetails(context, data.id);
//                         },
//                         borderRadius: BorderRadius.circular(12),
//                         child: Container(
//                           padding: const EdgeInsets.all(10),
//                           decoration: BoxDecoration(
//                             color: Colors.blue.shade50,
//                             borderRadius: BorderRadius.circular(12),
//                           ),
//                           child: const Icon(
//                             Icons.visibility,
//                             color: Colors.blue,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }
// }
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'attendance_history_screen.dart';

class EmployeeAttendanceScreen extends StatelessWidget {
  const EmployeeAttendanceScreen({super.key});

  static const Color primaryBlue = Color(0xFF0878D1);
  static const Color darkText = Color(0xFF101828);
  static const Color subText = Color(0xFF52627A);
  static const Color background = Color(0xFFF7F9FC);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            _header(context),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Column(
                  children: [
                    Transform.translate(
                      offset: const Offset(0, -2),
                      child: _employeeCard(),
                    ),

                    const SizedBox(height: 14),

                    _dateCard(),

                    const SizedBox(height: 12),

                    _attendanceTimingCard(),

                    const SizedBox(height: 14),

                    _todayStatusCard(),

                    const SizedBox(height: 22),

                    _sectionHeading(
                      title: 'Monthly Summary',
                      trailing: 'September 2026',
                    ),

                    const SizedBox(height: 12),

                    _monthlySummary(),

                    const SizedBox(height: 24),
                    _sectionHeading(
                      title: 'Recent Attendance',
                      trailing: 'View All',
                      trailingColor: primaryBlue,
                      onTrailingTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AttendanceHistoryScreen(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 10),

                    _recentAttendance(),

                    const SizedBox(height: 18),

                    _infoCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 14, 16, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF102A56), Color(0xFF173867)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(22),
          bottomRight: Radius.circular(22),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),

          const Expanded(
            child: Column(
              children: [
                Text(
                  'My Attendance',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Attendance is captured from biometric machine',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
              ],
            ),
          ),

          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _employeeCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            height: 65,
            width: 65,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFE3F2FD),
              shape: BoxShape.circle,
            ),
            child: const Text(
              'MM',
              style: TextStyle(
                color: primaryBlue,
                fontWeight: FontWeight.w700,
                fontSize: 24,
              ),
            ),
          ),

          const SizedBox(width: 14),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mohan Mitkari',
                  style: TextStyle(
                    color: darkText,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'EMP-1024',
                  style: TextStyle(color: subText, fontSize: 13),
                ),
                SizedBox(height: 3),
                Text(
                  'Software Engineer',
                  style: TextStyle(color: subText, fontSize: 13),
                ),
              ],
            ),
          ),

          _statusChip(
            text: 'Present',
            textColor: const Color(0xFF159447),
            background: const Color(0xFFE8F8EE),
            iconColor: const Color(0xFF21B84E),
          ),
        ],
      ),
    );
  }

  Widget _dateCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: _cardDecoration(),
      child: const Row(
        children: [
          Icon(
            Icons.calendar_month_outlined,
            color: Color(0xFF173B63),
            size: 21,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Today, 11 September 2026',
              style: TextStyle(
                color: darkText,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text('Friday', style: TextStyle(color: subText, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _attendanceTimingCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Expanded(
            child: _timeItem(
              icon: Icons.arrow_forward_rounded,
              iconBackground: const Color(0xFF2CC56B),
              title: 'Check In',
              value: '09:12 AM',
              subtitle: 'From Machine',
            ),
          ),
          _verticalDivider(),
          Expanded(
            child: _timeItem(
              icon: Icons.arrow_back_rounded,
              iconBackground: const Color(0xFFFF5252),
              title: 'Check Out',
              value: '06:15 PM',
              subtitle: 'From Machine',
            ),
          ),
          _verticalDivider(),
          Expanded(
            child: _timeItem(
              icon: Icons.access_time_filled_rounded,
              iconBackground: const Color(0xFF7664E9),
              title: 'Working Hours',
              value: '09h 03m',
              subtitle: 'Calculated',
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeItem({
    required IconData icon,
    required Color iconBackground,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Column(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(height: 10),
        Text(title, style: const TextStyle(color: subText, fontSize: 12)),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            color: darkText,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: subText, fontSize: 11)),
      ],
    );
  }

  Widget _verticalDivider() {
    return Container(width: 1, height: 110, color: const Color(0xFFEAECF0));
  }

  Widget _todayStatusCard() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE5FAEB), Color(0xFFF1FBF5)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            height: 56,
            width: 56,
            decoration: const BoxDecoration(
              color: Color(0xFF1EB74E),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),

          const SizedBox(width: 14),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Today's Status",
                  style: TextStyle(color: subText, fontSize: 12),
                ),
                SizedBox(height: 4),
                Text(
                  'Present',
                  style: TextStyle(
                    color: Color(0xFF11963C),
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Have a great day!',
                  style: TextStyle(color: subText, fontSize: 12),
                ),
              ],
            ),
          ),

          const Column(
            children: [
              Icon(Icons.location_on, size: 18, color: Color(0xFF55718E)),
              SizedBox(height: 4),
              Text(
                'Office - Pune',
                style: TextStyle(color: subText, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionHeading({
    required String title,
    required String trailing,
    Color trailingColor = subText,
    VoidCallback? onTrailingTap,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: darkText,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),

        GestureDetector(
          onTap: onTrailingTap,
          child: Text(
            trailing,
            style: TextStyle(
              color: trailingColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _monthlySummary() {
    final items = [
      {
        'icon': Icons.people_alt_rounded,
        'title': 'Present',
        'value': '18',
        'background': const Color(0xFFE6F8EE),
        'iconColor': const Color(0xFF20B45B),
      },
      {
        'icon': Icons.cancel_rounded,
        'title': 'Absent',
        'value': '02',
        'background': const Color(0xFFFFE9EA),
        'iconColor': const Color(0xFFF34B50),
      },
      {
        'icon': Icons.access_time_filled,
        'title': 'Late',
        'value': '03',
        'background': const Color(0xFFFFF5D9),
        'iconColor': const Color(0xFFE0A21B),
      },
      {
        'icon': Icons.calendar_month_rounded,
        'title': 'On Leave',
        'value': '01',
        'background': const Color(0xFFF0E9FF),
        'iconColor': const Color(0xFF7764E8),
      },
      {
        'icon': Icons.date_range_rounded,
        'title': 'Working Days',
        'value': '22',
        'background': const Color(0xFFE4F3FF),
        'iconColor': primaryBlue,
      },
    ];

    return Row(
      children: items.map((item) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            decoration: BoxDecoration(
              color: item['background'] as Color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  item['icon'] as IconData,
                  color: item['iconColor'] as Color,
                  size: 24,
                ),
                const SizedBox(height: 8),
                FittedBox(
                  child: Text(
                    item['title'] as String,
                    style: const TextStyle(color: subText, fontSize: 10),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  item['value'] as String,
                  style: const TextStyle(
                    color: darkText,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _recentAttendance() {
    final attendance = [
      {
        'date': '11\nSep',
        'in': '09:12 AM',
        'out': '06:15 PM',
        'hours': '09h 03m',
        'status': 'Present',
      },
      {
        'date': '10\nSep',
        'in': '09:05 AM',
        'out': '06:28 PM',
        'hours': '09h 23m',
        'status': 'Present',
      },
      {
        'date': '09\nSep',
        'in': '09:42 AM',
        'out': '06:10 PM',
        'hours': '08h 28m',
        'status': 'Late',
      },
      {
        'date': '08\nSep',
        'in': '--:--',
        'out': '--:--',
        'hours': '--:--',
        'status': 'Absent',
      },
      {
        'date': '07\nSep',
        'in': '09:08 AM',
        'out': '06:35 PM',
        'hours': '09h 27m',
        'status': 'Present',
      },
    ];

    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: attendance.map((item) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFEEF1F5))),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  child: Text(
                    item['date']!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: darkText,
                      fontSize: 11,
                      height: 1.25,
                    ),
                  ),
                ),

                Expanded(
                  child: Text(
                    item['in']!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),

                Expanded(
                  child: Text(
                    item['out']!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),

                Expanded(
                  child: Text(
                    item['hours']!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),

                _attendanceStatus(item['status']!),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _attendanceStatus(String status) {
    Color bg;
    Color text;

    switch (status) {
      case 'Present':
        bg = const Color(0xFFE1F7E9);
        text = const Color(0xFF159447);
        break;

      case 'Late':
        bg = const Color(0xFFFFF4D7);
        text = const Color(0xFFC78C12);
        break;

      default:
        bg = const Color(0xFFFFE7E9);
        text = const Color(0xFFD63038);
    }

    return Container(
      width: 85,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(
        status,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: text,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _infoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Color(0xFF48A1E8),
            child: Icon(Icons.info_outline, color: Colors.white),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Attendance is recorded from the biometric machine.\n'
              'Please contact HR for any discrepancies.',
              style: TextStyle(color: subText, fontSize: 11, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomNavigation() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE9EEF5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _bottomItem(Icons.home_outlined, 'Home', false),
          _bottomItem(Icons.access_time_filled, 'Attendance', true),
          _bottomItem(Icons.calendar_month_outlined, 'Leave', false),
          _bottomItem(Icons.person_outline, 'Profile', false),
        ],
      ),
    );
  }

  Widget _bottomItem(IconData icon, String title, bool selected) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 25,
          color: selected ? primaryBlue : const Color(0xFF536B89),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            color: selected ? primaryBlue : const Color(0xFF536B89),
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _statusChip({
    required String text,
    required Color textColor,
    required Color background,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            text,
            style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFECF0F5)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(.025),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }
}

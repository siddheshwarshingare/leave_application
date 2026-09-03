import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HolidayListScreen extends StatefulWidget {
  const HolidayListScreen({super.key});

  @override
  State<HolidayListScreen> createState() => _HolidayListScreenState();
}

class _HolidayListScreenState extends State<HolidayListScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        foregroundColor: Colors.black,
        title: Text(
          "Holiday List",
          style: TextStyle(
            fontSize: 18,
            color: Colors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(child: _holidaysSection()),
    );
  }

  Widget _holidaysSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('holidays').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text('No upcoming holidays');
        }

        final now = DateTime.now();

        // final upcomingHolidays = snapshot.data!.docs.where((doc) {
        //   try {
        //     // Document ID example: 01-Jan-2026
        //     final date = DateFormat('dd-MMM-yyyy').parse(doc.id);
        //     return date.isBefore(DateTime(now.year, now.month, now.day));
        //   } catch (e) {
        //     return false;
        //   }
        // }).toList();

        final upcomingHolidays = snapshot.data!.docs.toList()
          ..sort((a, b) {
            try {
              final dateA = DateFormat('dd-MMM-yyyy').parse(a.id);
              final dateB = DateFormat('dd-MMM-yyyy').parse(b.id);
              return dateA.compareTo(dateB);
            } catch (e) {
              return 0;
            }
          });

        return Container(
          padding: EdgeInsets.only(top: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE9ECF2)),
          ),
          child: Column(
            children: List.generate(upcomingHolidays.length, (index) {
              final doc = upcomingHolidays[index];

              final data = doc.data() as Map<String, dynamic>;

              final date = DateFormat('dd-MMM-yyyy').parse(doc.id);

              final day = DateFormat('dd').format(date);
              final month = DateFormat('MMM').format(date).toUpperCase();

              final holidayName =
                  data['holiday']?.toString() ??
                  data['holiday']?.toString() ??
                  'Holiday';

              final weekday = DateFormat('EEEE').format(date);

              return SingleChildScrollView(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3EC),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  day,
                                  style: const TextStyle(
                                    color: Colors.deepOrange,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  month,
                                  style: const TextStyle(
                                    color: Colors.deepOrange,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 10),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  holidayName,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  weekday,
                                  style: const TextStyle(
                                    color: Colors.black45,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const Icon(
                            Icons.calendar_month_outlined,
                            color: Colors.orangeAccent,
                            size: 18,
                          ),
                        ],
                      ),
                    ),

                    if (index != upcomingHolidays.length - 1)
                      const Divider(
                        height: 1,
                        indent: 10,
                        endIndent: 10,
                        color: Color(0xFFF0F1F4),
                      ),
                  ],
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

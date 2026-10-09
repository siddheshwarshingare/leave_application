import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class AdminCalendarScreen extends StatefulWidget {
  const AdminCalendarScreen({super.key});

  @override
  State<AdminCalendarScreen> createState() => _AdminCalendarScreenState();
}

class _AdminCalendarScreenState extends State<AdminCalendarScreen> {
  DateTime focusedDay = DateTime.now();
  DateTime selectedDay = DateTime.now();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================
  // COLORS
  // ============================================================

  static const Color primary = Color(0xFF6D28D9);

  // Pending / Applied
  static const Color pendingColor = Color(0xFF22C55E);

  // Approved
  static const Color approvedColor = Color(0xFFFF3B30);

  // Rejected
  static const Color rejectedColor = Color(0xFF3B82F6);

  // ============================================================
  // LEAVE REQUESTS
  // ============================================================

  Stream<QuerySnapshot> getLeaveRequests() {
    return _firestore.collection('leave_requests').snapshots();
  }

  // ============================================================
  // NORMALIZE DATE
  // ============================================================

  DateTime onlyDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  // ============================================================
  // FIREBASE DATE
  // ============================================================

  DateTime? firebaseDate(dynamic value) {
    if (value is Timestamp) {
      return onlyDate(value.toDate());
    }

    if (value is DateTime) {
      return onlyDate(value);
    }

    return null;
  }

  // ============================================================
  // FORMAT DATE
  // ============================================================

  String formatDate(DateTime date) {
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

    return "${date.day} ${months[date.month - 1]} ${date.year}";
  }

  // ============================================================
  // GET LEAVES FOR DATE
  //
  // IMPORTANT:
  // ONLY LEAVE REQUESTS ARE RETURNED.
  // NO EMPLOYEE WITHOUT LEAVE WILL APPEAR.
  // ============================================================

  List<Map<String, dynamic>> getLeavesForDate(
    DateTime date,
    List<QueryDocumentSnapshot> docs,
  ) {
    final selected = onlyDate(date);

    final List<Map<String, dynamic>> result = [];

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;

      final from = firebaseDate(data['fromDate']);

      final to = firebaseDate(data['toDate']);

      if (from == null || to == null) {
        continue;
      }

      // Is selected date inside leave range?
      if (!selected.isBefore(from) && !selected.isAfter(to)) {
        result.add({...data, 'id': doc.id});
      }
    }

    return result;
  }

  // ============================================================
  // STATUS COLOR
  // ============================================================

  Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'applied':
        return pendingColor;

      case 'approved':
        return approvedColor;

      case 'rejected':
        return rejectedColor;

      default:
        return const Color(0xFF9CA3AF);
    }
  }

  // ============================================================
  // STATUS ICON
  // ============================================================

  IconData statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'applied':
        return Icons.hourglass_top_rounded;

      case 'approved':
        return Icons.check_circle_rounded;

      case 'rejected':
        return Icons.cancel_rounded;

      default:
        return Icons.info_outline_rounded;
    }
  }

  // ============================================================
  // CALENDAR
  // ============================================================

  Widget leaveCalendar(List<QueryDocumentSnapshot> docs) {
    return TableCalendar(
      firstDay: DateTime(2020),
      lastDay: DateTime(2035),

      focusedDay: focusedDay,

      selectedDayPredicate: (day) {
        return isSameDay(selectedDay, day);
      },

      onDaySelected: (selected, focused) {
        setState(() {
          selectedDay = selected;
          focusedDay = focused;
        });
      },

      onPageChanged: (focused) {
        setState(() {
          focusedDay = focused;
        });
      },

      calendarStyle: const CalendarStyle(
        todayDecoration: BoxDecoration(color: Colors.transparent),

        selectedDecoration: BoxDecoration(color: Colors.transparent),

        weekendTextStyle: TextStyle(color: Color(0xFF6B7280)),
      ),

      calendarBuilders: CalendarBuilders(
        // ========================================================
        // NORMAL DAY
        // ========================================================
        defaultBuilder: (context, day, focusedDay) {
          return _buildCalendarDay(day: day, docs: docs);
        },

        // ========================================================
        // TODAY
        // ========================================================
        todayBuilder: (context, day, focusedDay) {
          return _buildCalendarDay(day: day, docs: docs, isToday: true);
        },

        // ========================================================
        // SELECTED
        // ========================================================
        selectedBuilder: (context, day, focusedDay) {
          return _buildCalendarDay(day: day, docs: docs, isSelected: true);
        },

        // ========================================================
        // OUTSIDE MONTH
        // ========================================================
        outsideBuilder: (context, day, focusedDay) {
          return Center(
            child: Text(
              '${day.day}',
              style: const TextStyle(color: Color(0xFFB0B3BD)),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // CALENDAR DAY
  // ============================================================

  Widget _buildCalendarDay({
    required DateTime day,
    required List<QueryDocumentSnapshot> docs,
    bool isToday = false,
    bool isSelected = false,
  }) {
    final leaves = getLeavesForDate(day, docs);

    // ==========================================================
    // COUNT STATUS
    // ==========================================================

    int pending = 0;
    int approved = 0;
    int rejected = 0;

    for (final leave in leaves) {
      final status = leave['status']?.toString().toLowerCase();

      if (status == 'pending' || status == 'applied') {
        pending++;
      }

      if (status == 'approved') {
        approved++;
      }

      if (status == 'rejected') {
        rejected++;
      }
    }

    // ==========================================================
    // SELECTED / TODAY BORDER
    // ==========================================================

    return Container(
      margin: const EdgeInsets.all(3),

      decoration: BoxDecoration(
        color: isSelected ? primary.withOpacity(.08) : Colors.transparent,

        borderRadius: BorderRadius.circular(10),

        border: isSelected
            ? Border.all(color: primary, width: 1.5)
            : isToday
            ? Border.all(color: primary.withOpacity(.35))
            : null,
      ),

      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,

        children: [
          // ======================================================
          // DATE
          // ======================================================
          Text(
            '${day.day}',
            style: TextStyle(
              color: isToday ? primary : const Color(0xFF374151),

              fontSize: 13,

              fontWeight: isToday || isSelected
                  ? FontWeight.w800
                  : FontWeight.w500,
            ),
          ),

          const SizedBox(height: 4),

          // ======================================================
          // LEAVE STATUS DOTS
          // ======================================================
          Row(
            mainAxisAlignment: MainAxisAlignment.center,

            children: [
              // Pending
              if (pending > 0) _statusDot(pendingColor, pending),

              // Approved
              if (approved > 0) _statusDot(approvedColor, approved),

              // Rejected
              if (rejected > 0) _statusDot(rejectedColor, rejected),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STATUS DOT + COUNT
  // ============================================================

  Widget _statusDot(Color color, int count) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),

      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,

            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),

          if (count > 1) ...[
            const SizedBox(width: 1),

            Text(
              '$count',
              style: TextStyle(
                color: color,
                fontSize: 7,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // LEAVE CARD
  // ============================================================
  Widget leaveCard(Map<String, dynamic> data) {
    final employeeName =
        data['employeeName']?.toString() ??
        data['name']?.toString() ??
        'Employee';

    final leaveType = data['leaveType']?.toString() ?? 'Leave';

    final reason = data['reason']?.toString() ?? '';

    final days = data['days']?.toString() ?? '';

    final duration = data['leaveDuration']?.toString() ?? '';

    final status = data['status']?.toString() ?? 'Pending';

    final from = firebaseDate(data['fromDate']);

    final to = firebaseDate(data['toDate']);

    final color = statusColor(status);

    return _ExpandableLeaveCard(
      employeeName: employeeName,
      leaveType: leaveType,
      status: status,
      color: color,
      statusIcon: statusIcon(status),
      from: from,
      to: to,
      days: days,
      duration: duration,
      reason: reason,
      formatDate: formatDate,
    );
  }

  // ============================================================
  // DETAIL ITEM
  // ============================================================

  Widget _detailItem(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Icon(icon, size: 16, color: primary),

        const SizedBox(width: 6),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Text(
                title,

                style: const TextStyle(
                  color: Color(0xFF8A8FA3),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 2),

              Text(
                value,

                maxLines: 2,

                overflow: TextOverflow.ellipsis,

                style: const TextStyle(
                  color: Color(0xFF374151),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // LEGEND
  // ============================================================

  Widget legend() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(18),
      ),

      child: Wrap(
        spacing: 18,
        runSpacing: 10,

        children: [
          _legendItem(pendingColor, "Applied"),

          _legendItem(approvedColor, "Approved"),

          _legendItem(rejectedColor, "Rejected"),
        ],
      ),
    );
  }

  // ============================================================
  // LEGEND ITEM
  // ============================================================

  Widget _legendItem(Color color, String title) {
    return Row(
      mainAxisSize: MainAxisSize.min,

      children: [
        Container(
          width: 9,
          height: 9,

          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),

        const SizedBox(width: 6),

        Text(
          title,

          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
          "Leave Calendar",

          style: TextStyle(
            color: Color(0xFF17133A),
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: getLeaveRequests(),

        builder: (context, snapshot) {
          // ======================================================
          // LOADING
          // ======================================================

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: primary),
            );
          }

          // ======================================================
          // ERROR
          // ======================================================

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final docs = snapshot.data?.docs ?? [];

          // ======================================================
          // SELECTED DATE LEAVES
          // ======================================================

          final selectedLeaves = getLeavesForDate(selectedDay, docs);

          // ======================================================
          // BUILD
          // ======================================================

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

                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.035),

                        blurRadius: 15,

                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),

                  child: const Row(
                    children: [
                      Icon(
                        Icons.event_available_rounded,
                        color: primary,
                        size: 28,
                      ),

                      SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [
                            Text(
                              "Employee Leave Calendar",

                              style: TextStyle(
                                color: Color(0xFF17133A),
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),

                            SizedBox(height: 3),

                            Text(
                              "View leave applications from all employees",

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
                ),

                const SizedBox(height: 16),

                // ==================================================
                // CALENDAR
                // ==================================================
                Container(
                  width: double.infinity,

                  padding: const EdgeInsets.all(12),

                  decoration: BoxDecoration(
                    color: Colors.white,

                    borderRadius: BorderRadius.circular(22),

                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.035),

                        blurRadius: 15,

                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),

                  child: leaveCalendar(docs),
                ),

                const SizedBox(height: 12),

                // ==================================================
                // LEGEND
                // ==================================================
                legend(),

                const SizedBox(height: 18),

                // ==================================================
                // SELECTED DATE
                // ==================================================
                Row(
                  children: [
                    const Icon(
                      Icons.event_note_rounded,
                      color: primary,
                      size: 21,
                    ),

                    const SizedBox(width: 8),

                    Text(
                      formatDate(selectedDay),

                      style: const TextStyle(
                        color: Color(0xFF17133A),
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // ==================================================
                // COUNT
                // ==================================================
                if (selectedLeaves.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),

                    child: Text(
                      "${selectedLeaves.length} leave "
                      "${selectedLeaves.length == 1 ? 'application' : 'applications'}",

                      style: const TextStyle(
                        color: Color(0xFF8A8FA3),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                // ==================================================
                // ONLY EMPLOYEES WITH LEAVE
                // ==================================================
                if (selectedLeaves.isEmpty)
                  Container(
                    width: double.infinity,

                    padding: const EdgeInsets.all(20),

                    decoration: BoxDecoration(
                      color: Colors.white,

                      borderRadius: BorderRadius.circular(18),
                    ),

                    child: const Column(
                      children: [
                        Icon(
                          Icons.event_busy_rounded,
                          color: Color(0xFF9CA3AF),
                          size: 35,
                        ),

                        SizedBox(height: 8),

                        Text(
                          "No leave applications",

                          style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...selectedLeaves.map((leave) => leaveCard(leave)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ExpandableLeaveCard extends StatefulWidget {
  final String employeeName;
  final String leaveType;
  final String status;
  final Color color;
  final IconData statusIcon;

  final DateTime? from;
  final DateTime? to;

  final String days;
  final String duration;
  final String reason;

  final String Function(DateTime) formatDate;

  const _ExpandableLeaveCard({
    required this.employeeName,
    required this.leaveType,
    required this.status,
    required this.color,
    required this.statusIcon,
    required this.from,
    required this.to,
    required this.days,
    required this.duration,
    required this.reason,
    required this.formatDate,
  });

  @override
  State<_ExpandableLeaveCard> createState() => _ExpandableLeaveCardState();
}

class _ExpandableLeaveCardState extends State<_ExpandableLeaveCard> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,

      margin: const EdgeInsets.only(bottom: 10),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(17),

        border: Border.all(color: const Color(0xFFEDEDF2)),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.025),

            blurRadius: 10,

            offset: const Offset(0, 3),
          ),
        ],
      ),

      child: Column(
        children: [
          // ======================================================
          // MAIN COMPACT ROW
          // ======================================================
          InkWell(
            borderRadius: BorderRadius.circular(17),

            onTap: () {
              setState(() {
                expanded = !expanded;
              });
            },

            child: Padding(
              padding: const EdgeInsets.all(14),

              child: Row(
                children: [
                  // ==================================================
                  // AVATAR
                  // ==================================================
                  Container(
                    width: 43,
                    height: 43,

                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(.10),

                      borderRadius: BorderRadius.circular(12),
                    ),

                    child: Icon(
                      Icons.person_rounded,
                      color: widget.color,
                      size: 21,
                    ),
                  ),

                  const SizedBox(width: 11),

                  // ==================================================
                  // EMPLOYEE + LEAVE + DATE
                  // ==================================================
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        // Employee name
                        Text(
                          widget.employeeName,

                          maxLines: 1,

                          overflow: TextOverflow.ellipsis,

                          style: const TextStyle(
                            color: Color(0xFF17133A),
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),

                        const SizedBox(height: 3),

                        // Leave type
                        Text(
                          widget.leaveType,

                          maxLines: 1,

                          overflow: TextOverflow.ellipsis,

                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 5),

                        // Date range
                        Row(
                          children: [
                            const Icon(
                              Icons.date_range_rounded,
                              size: 13,
                              color: Color(0xFF9CA3AF),
                            ),

                            const SizedBox(width: 4),

                            Text(
                              widget.from == null
                                  ? "-"
                                  : widget.formatDate(widget.from!),

                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 5),
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                size: 12,
                                color: Color(0xFFB0B3BD),
                              ),
                            ),

                            Text(
                              widget.to == null
                                  ? "-"
                                  : widget.formatDate(widget.to!),

                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // ==================================================
                  // STATUS + ARROW
                  // ==================================================
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),

                        decoration: BoxDecoration(
                          color: widget.color.withOpacity(.10),

                          borderRadius: BorderRadius.circular(20),
                        ),

                        child: Row(
                          mainAxisSize: MainAxisSize.min,

                          children: [
                            Icon(
                              widget.statusIcon,
                              size: 12,
                              color: widget.color,
                            ),

                            const SizedBox(width: 4),

                            Text(
                              widget.status,

                              style: TextStyle(
                                color: widget.color,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 6),

                      Icon(
                        expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,

                        color: const Color(0xFF9CA3AF),

                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ======================================================
          // EXPANDED DETAILS
          // ======================================================
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),

            secondChild: _expandedDetails(),

            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,

            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EXPANDED DETAILS
  // ============================================================

  Widget _expandedDetails() {
    return Container(
      width: double.infinity,

      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),

      padding: const EdgeInsets.all(13),

      decoration: BoxDecoration(
        color: const Color(0xFFF8F7FC),

        borderRadius: BorderRadius.circular(13),
      ),

      child: Column(
        children: [
          // ======================================================
          // LEAVE TYPE + DAYS
          // ======================================================
          Row(
            children: [
              Expanded(
                child: _detailItem(
                  Icons.category_outlined,
                  "Leave Type",
                  widget.leaveType,
                ),
              ),

              Expanded(
                child: _detailItem(
                  Icons.calendar_today_rounded,
                  "Days",
                  widget.days.isEmpty ? "-" : widget.days,
                ),
              ),
            ],
          ),

          // ======================================================
          // FROM + TO
          // ======================================================
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _detailItem(
                  Icons.date_range_rounded,
                  "From",
                  widget.from == null ? "-" : widget.formatDate(widget.from!),
                ),
              ),

              Expanded(
                child: _detailItem(
                  Icons.event_rounded,
                  "To",
                  widget.to == null ? "-" : widget.formatDate(widget.to!),
                ),
              ),
            ],
          ),

          // ======================================================
          // DURATION
          // ======================================================
          if (widget.duration.isNotEmpty) ...[
            const SizedBox(height: 12),

            _detailItem(Icons.timelapse_rounded, "Duration", widget.duration),
          ],

          // ======================================================
          // REASON
          // ======================================================
          if (widget.reason.isNotEmpty) ...[
            const SizedBox(height: 12),

            _detailItem(Icons.description_outlined, "Reason", widget.reason),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // DETAIL ITEM
  // ============================================================

  Widget _detailItem(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Icon(icon, size: 16, color: const Color(0xFF6D28D9)),

        const SizedBox(width: 6),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Text(
                title,

                style: const TextStyle(
                  color: Color(0xFF8A8FA3),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 2),

              Text(
                value,

                maxLines: 3,

                overflow: TextOverflow.ellipsis,

                style: const TextStyle(
                  color: Color(0xFF374151),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LeaveDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> data;

  const LeaveDetailsScreen({super.key, required this.data});
  // ============================================================
  // STATUS BADGE
  // ============================================================

  Widget _statusBadge(String status) {
    Color color;

    switch (status.toLowerCase()) {
      case "approved":
        color = const Color(0xFF16A34A);
        break;

      case "rejected":
        color = const Color(0xFFDC2626);
        break;

      case "pending":
        color = const Color(0xFFF59E0B);
        break;

      default:
        color = const Color(0xFF64748B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,

        children: [
          Container(
            width: 7,
            height: 7,

            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),

          const SizedBox(width: 6),

          Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _sectionTitle({required IconData icon, required String title}) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,

          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(10),
          ),

          child: Icon(icon, size: 18, color: const Color(0xFF2563EB)),
        ),

        const SizedBox(width: 10),

        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Color(0xFF172033),
          ),
        ),
      ],
    );
  }
  // ============================================================
  // DATE ITEM
  // ============================================================

  Widget _dateItem({
    required String title,
    required dynamic timestamp,
    required IconData icon,
    required Color color,
  }) {
    DateTime? date;

    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is DateTime) {
      date = timestamp;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,

        children: [
          Container(
            width: 38,
            height: 38,

            decoration: BoxDecoration(
              color: color.withOpacity(.10),
              borderRadius: BorderRadius.circular(11),
            ),

            child: Icon(icon, size: 19, color: color),
          ),

          const SizedBox(height: 8),

          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF94A3B8),
            ),
          ),

          const SizedBox(height: 3),

          Text(
            date == null ? "-" : DateFormat("dd MMM yyyy").format(date),

            textAlign: TextAlign.center,

            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }
  // ============================================================
  // INFO CARD
  // ============================================================

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),

        border: Border.all(color: const Color(0xFFE5E7EB)),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.025),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Container(
            width: 38,
            height: 38,

            decoration: BoxDecoration(
              color: color.withOpacity(.10),
              borderRadius: BorderRadius.circular(11),
            ),

            child: Icon(icon, color: color, size: 20),
          ),

          const SizedBox(height: 12),

          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,

            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }
  // ============================================================
  // EMPLOYEE INFO ROW
  // ============================================================

  Widget _employeeInfoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,

      children: [
        Container(
          width: 40,
          height: 40,

          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),

          child: Icon(icon, color: const Color(0xFF475569), size: 20),
        ),

        const SizedBox(width: 13),

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

              const SizedBox(height: 3),

              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,

                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1F2937),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDays(dynamic value) {
    final double days = double.tryParse(value?.toString() ?? "0") ?? 0;

    if (days == days.toInt()) {
      return "${days.toInt()} Day${days == 1 ? '' : 's'}";
    }

    return "$days Days";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,

        title: const Text(
          "Leave Details",
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),

        centerTitle: false,
      ),

      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),

        padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            // ============================================================
            // HEADER CARD
            // ============================================================
            Container(
              width: double.infinity,

              padding: const EdgeInsets.all(20),

              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],

                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),

                borderRadius: BorderRadius.circular(24),

                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withOpacity(.20),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),

              child: Row(
                children: [
                  // Leave icon
                  Container(
                    width: 58,
                    height: 58,

                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.18),
                      borderRadius: BorderRadius.circular(17),
                    ),

                    child: const Icon(
                      Icons.event_available_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),

                  const SizedBox(width: 15),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        Text(
                          data['leaveType']?.toString() ?? "Leave",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),

                        const SizedBox(height: 6),

                        Text(
                          data['leaveDuration']?.toString() ?? "",
                          style: TextStyle(
                            color: Colors.white.withOpacity(.80),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Status
                  _statusBadge(data['status']?.toString() ?? "Unknown"),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // ============================================================
            // DATE SECTION
            // ============================================================
            _sectionTitle(
              icon: Icons.calendar_month_rounded,
              title: "Leave Period",
            ),

            const SizedBox(height: 10),

            Container(
              width: double.infinity,

              padding: const EdgeInsets.all(18),

              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),

                border: Border.all(color: const Color(0xFFE5E7EB)),

                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.035),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),

              child: Row(
                children: [
                  // FROM
                  Expanded(
                    child: _dateItem(
                      title: "FROM",
                      timestamp: data['fromDate'],
                      icon: Icons.login_rounded,
                      color: const Color(0xFF2563EB),
                    ),
                  ),

                  // Arrow
                  Container(
                    width: 38,
                    height: 38,

                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),

                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Color(0xFF64748B),
                      size: 20,
                    ),
                  ),

                  // TO
                  Expanded(
                    child: _dateItem(
                      title: "TO",
                      timestamp: data['toDate'],
                      icon: Icons.logout_rounded,
                      color: const Color(0xFF7C3AED),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ============================================================
            // DAYS + SESSION
            // ============================================================
            Row(
              children: [
                // DAYS
                Expanded(
                  child: _infoCard(
                    icon: Icons.timelapse_rounded,
                    title: "Total Days",
                    value: _formatDays(data['days']),
                    color: const Color(0xFF7C3AED),
                  ),
                ),

                const SizedBox(width: 12),

                // SESSION / DURATION
                Expanded(
                  child: _infoCard(
                    icon: Icons.access_time_rounded,
                    title: "Duration",
                    value: data['leaveDuration'] == "Half Day Only"
                        ? "${data['halfDaySession'] ?? 'Half Day'}"
                        : "Full Day",
                    color: const Color(0xFF0891B2),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ============================================================
            // REASON
            // ============================================================
            _sectionTitle(icon: Icons.description_rounded, title: "Reason"),

            const SizedBox(height: 10),

            Container(
              width: double.infinity,

              padding: const EdgeInsets.all(18),

              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),

                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),

              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Container(
                    width: 40,
                    height: 40,

                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(12),
                    ),

                    child: const Icon(
                      Icons.notes_rounded,
                      color: Color(0xFF7C3AED),
                      size: 21,
                    ),
                  ),

                  const SizedBox(width: 13),

                  Expanded(
                    child: Text(
                      data['reason']?.toString() ?? "No reason provided",
                      style: const TextStyle(
                        color: Color(0xFF374151),
                        fontSize: 14,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ============================================================
            // EMPLOYEE INFORMATION
            // ============================================================
            _sectionTitle(
              icon: Icons.person_rounded,
              title: "Employee Information",
            ),

            const SizedBox(height: 10),

            Container(
              width: double.infinity,

              padding: const EdgeInsets.all(18),

              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),

                border: Border.all(color: const Color(0xFFE5E7EB)),

                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.025),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),

              child: Column(
                children: [
                  _employeeInfoRow(
                    icon: Icons.person_outline_rounded,
                    title: "Employee",
                    value: data['employeeName']?.toString() ?? "-",
                  ),

                  const Divider(height: 25, color: Color(0xFFE5E7EB)),

                  _employeeInfoRow(
                    icon: Icons.email_outlined,
                    title: "Email",
                    value: data['employeeEmail']?.toString() ?? "-",
                  ),

                  const Divider(height: 25, color: Color(0xFFE5E7EB)),

                  _employeeInfoRow(
                    icon: Icons.warning_amber_rounded,
                    title: "Emergency",
                    value: data['emergency'] == true ? "Yes" : "No",
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ============================================================
            // REQUEST SUMMARY
            // ============================================================
            Container(
              width: double.infinity,

              padding: const EdgeInsets.all(18),

              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(20),

                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),

              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Container(
                    width: 42,
                    height: 42,

                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(13),
                    ),

                    child: const Icon(
                      Icons.info_outline_rounded,
                      color: Color(0xFF2563EB),
                    ),
                  ),

                  const SizedBox(width: 13),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        const Text(
                          "Leave Request",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),

                        const SizedBox(height: 5),

                        Text(
                          data['leaveDuration'] == "Half Day Only"
                              ? "Half day leave • "
                                    "${data['halfDaySession'] ?? ''}"
                              : "${_formatDays(data['days'])} leave request",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

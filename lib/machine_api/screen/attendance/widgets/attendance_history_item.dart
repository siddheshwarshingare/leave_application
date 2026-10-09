import 'package:flutter/material.dart';

class AttendanceHistoryItem extends StatelessWidget {
  final String date;
  final String day;
  final String checkIn;
  final String checkOut;
  final String workingHours;
  final String status;

  const AttendanceHistoryItem({
    super.key,
    required this.date,
    required this.day,
    required this.checkIn,
    required this.checkOut,
    required this.workingHours,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final statusStyle = _getStatusStyle(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EDF3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF5FF),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      date,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF101828),
                      ),
                    ),
                    const Text(
                      'Sep',
                      style: TextStyle(fontSize: 11, color: Color(0xFF52627A)),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      day,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF101828),
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'September 2026',
                      style: TextStyle(fontSize: 11, color: Color(0xFF7A889B)),
                    ),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: statusStyle.background,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusStyle.textColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Container(height: 1, color: const Color(0xFFEEF2F6)),

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: _dataItem(
                  icon: Icons.login_rounded,
                  iconColor: const Color(0xFF1EB75A),
                  label: 'Check In',
                  value: checkIn,
                ),
              ),

              _divider(),

              Expanded(
                child: _dataItem(
                  icon: Icons.logout_rounded,
                  iconColor: const Color(0xFFF05252),
                  label: 'Check Out',
                  value: checkOut,
                ),
              ),

              _divider(),

              Expanded(
                child: _dataItem(
                  icon: Icons.access_time_filled,
                  iconColor: const Color(0xFF725DD9),
                  label: 'Working',
                  value: workingHours,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dataItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF7A889B), fontSize: 10),
        ),
        const SizedBox(height: 4),
        FittedBox(
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFF101828),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _divider() {
    return Container(height: 45, width: 1, color: const Color(0xFFEEF2F6));
  }

  _StatusStyle _getStatusStyle(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return const _StatusStyle(
          background: Color(0xFFE3F8EB),
          textColor: Color(0xFF159447),
        );

      case 'late':
        return const _StatusStyle(
          background: Color(0xFFFFF3D5),
          textColor: Color(0xFFC4880D),
        );

      case 'absent':
        return const _StatusStyle(
          background: Color(0xFFFFE6E8),
          textColor: Color(0xFFD5363D),
        );

      case 'on leave':
        return const _StatusStyle(
          background: Color(0xFFF0E9FF),
          textColor: Color(0xFF7158D9),
        );

      default:
        return const _StatusStyle(
          background: Color(0xFFEAF2FF),
          textColor: Color(0xFF1478C9),
        );
    }
  }
}

class _StatusStyle {
  final Color background;
  final Color textColor;

  const _StatusStyle({required this.background, required this.textColor});
}

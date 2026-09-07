import 'package:flutter/material.dart';

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

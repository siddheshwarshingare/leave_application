import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:leave_application/machine_api/controller/get_all_employee_controller.dart';

class AdminAttendanceScreen extends StatefulWidget {
  const AdminAttendanceScreen({super.key});

  @override
  State<AdminAttendanceScreen> createState() => _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends State<AdminAttendanceScreen> {
  final EmployeeController employeeController = Get.put(
    EmployeeController(
      apiKey: const String.fromEnvironment('EMPLOYEE_API_KEY'),
    ),
  );

  static const Color primaryBlue = Color(0xFF0878D1);
  static const Color darkText = Color(0xFF101828);
  static const Color subText = Color(0xFF52627A);

  int selectedTab = 0;

  String selectedFilter = 'All';

  String searchText = '';

  DateTime selectedDate = DateTime.now();

  final TextEditingController searchController = TextEditingController();

  final List<String> filters = ['All', 'Present', 'Absent', 'Late', 'On Leave'];

  // Adapt API employee objects to the existing attendance card design.
  // Attendance-specific values require a separate attendance API.
  List<Map<String, String>> get employees {
    final response = employeeController.employeeList.value;
    if (response == null) return [];
    return response.data.map<Map<String, String>>((employee) {
      final name = employee.fullName.trim();
      final parts = name
          .split(RegExp(r'\s+'))
          .where((s) => s.isNotEmpty)
          .toList();
      final initials = parts.isEmpty
          ? '?'
          : parts.take(2).map((part) => part[0].toUpperCase()).join();
      return <String, String>{
        'initial': initials,
        'name': name.isEmpty ? 'Unknown Employee' : name,
        'id': employee.empCode.toString(),
        'in': '--:--',
        'out': '--:--',
        'hours': '--:--',
        'status': 'Not Available',
        'department': employee.department?.deptName ?? 'N/A',
        'email': employee.email.isEmpty ? 'N/A' : employee.email,
      };
    }).toList();
  }

  @override
  void initState() {
    // TODO: implement initState

    super.initState();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<Map<String, String>> get filteredEmployees {
    return employees.where((employee) {
      final name = employee['name']!.toLowerCase();

      final id = employee['id']!.toLowerCase();

      final status = employee['status']!;

      final query = searchText.toLowerCase().trim();

      final matchesSearch = name.contains(query) || id.contains(query);

      bool matchesStatus = true;

      if (selectedFilter == 'Present') {
        matchesStatus = status == 'Present' || status == 'Currently IN';
      } else if (selectedFilter != 'All') {
        matchesStatus = status == selectedFilter;
      }

      return matchesSearch && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      body: SafeArea(
        child: Column(
          children: [
            _header(),

            _topTabs(),

            Expanded(child: _buildTabContent()),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TAB CONTENT
  // ============================================================

  Widget _buildTabContent() {
    switch (selectedTab) {
      case 1:
        return _employeesTab();

      case 2:
        return _reportsTab();

      default:
        return _overviewTab();
    }
  }

  // ============================================================
  // OVERVIEW TAB
  // ============================================================

  Widget _overviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _dateSelector(),

          const SizedBox(height: 18),

          _sectionTitle('Attendance Overview'),

          const SizedBox(height: 10),

          Obx(() => _overviewGrid()),

          const SizedBox(height: 22),

          _sectionTitle("Today's Attendance Status"),

          const SizedBox(height: 10),

          _attendanceGraphCard(),

          const SizedBox(height: 22),

          Row(
            children: [
              Expanded(child: _sectionTitle('Employees Attendance')),

              TextButton(
                onPressed: () {
                  setState(() {
                    selectedTab = 1;
                  });
                },
                child: const Text(
                  'View All',
                  style: TextStyle(
                    color: primaryBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          _employeeList(limit: 4),

          const SizedBox(height: 16),

          _exportCard(),
        ],
      ),
    );
  }

  // ============================================================
  // EMPLOYEE TAB
  // ============================================================

  Widget _employeesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            children: [
              _dateSelector(),
              const SizedBox(height: 14),
              _searchBar(),
              const SizedBox(height: 10),
              _filterBar(),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Obx(() {
            if (employeeController.isLoading.value &&
                employeeController.employeeList.value == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (employeeController.employeeList.value == null &&
                employeeController.errorMessage.value.isNotEmpty) {
              return _employeeErrorState();
            }
            final list = filteredEmployees;
            if (list.isEmpty) return _emptyEmployeeState();
            return RefreshIndicator(
              onRefresh: employeeController.refreshEmployees,
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollUpdateNotification &&
                      notification.metrics.extentAfter < 200 &&
                      employeeController.hasMore &&
                      !employeeController.isLoadMore.value) {
                    employeeController.loadMoreEmployees();
                  }
                  return false;
                },
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  itemCount:
                      list.length +
                      (employeeController.isLoadMore.value ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == list.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _employeeCard(list[index]),
                    );
                  },
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _employeeErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 36),
            const SizedBox(height: 10),
            Text(
              employeeController.errorMessage.value,
              textAlign: TextAlign.center,
            ),
            TextButton(
              onPressed: employeeController.fetchEmployees,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // REPORTS TAB
  // ============================================================

  Widget _reportsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _dateSelector(),

          const SizedBox(height: 20),

          _sectionTitle('Attendance Reports'),

          const SizedBox(height: 12),

          _reportCard(
            icon: Icons.calendar_month_outlined,
            title: 'Daily Attendance',
            subtitle: 'Generate attendance report for selected date',
            onTap: () {
              _showExportSheet(reportName: 'Daily Attendance Report');
            },
          ),

          const SizedBox(height: 10),

          _reportCard(
            icon: Icons.date_range_outlined,
            title: 'Monthly Attendance',
            subtitle: 'Generate monthly employee attendance',
            onTap: () {
              _showMonthPicker();
            },
          ),

          const SizedBox(height: 10),

          _reportCard(
            icon: Icons.person_search_outlined,
            title: 'Employee Report',
            subtitle: 'Generate report for specific employee',
            onTap: () {
              _showEmployeeSelector();
            },
          ),

          const SizedBox(height: 10),

          _reportCard(
            icon: Icons.access_time_outlined,
            title: 'Late Attendance',
            subtitle: 'View employees who arrived late',
            onTap: () {
              setState(() {
                selectedFilter = 'Late';
                selectedTab = 1;
              });
            },
          ),

          const SizedBox(height: 10),

          _reportCard(
            icon: Icons.person_off_outlined,
            title: 'Absent Employees',
            subtitle: 'View absence report',
            onTap: () {
              setState(() {
                selectedFilter = 'Absent';
                selectedTab = 1;
              });
            },
          ),

          const SizedBox(height: 20),

          _exportCard(),
        ],
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF102A56), Color(0xFF173867)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 18,
            ),
          ),

          const Expanded(
            child: Column(
              children: [
                Text(
                  'Attendance',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                SizedBox(height: 3),

                Text(
                  "Monitor your team's attendance",
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),

          IconButton(
            onPressed: _showFilterBottomSheet,
            icon: const Icon(Icons.filter_alt_outlined, color: Colors.white),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TOP TABS
  // ============================================================

  Widget _topTabs() {
    const tabs = ['Overview', 'Employees', 'Reports'];

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final active = selectedTab == index;

          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                FocusScope.of(context).unfocus();

                setState(() {
                  selectedTab = index;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: active ? primaryBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  tabs[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: active ? Colors.white : const Color(0xFF43546A),
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ============================================================
  // DATE
  // ============================================================

  Widget _dateSelector() {
    return Center(
      child: InkWell(
        onTap: _selectDate,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.calendar_month_outlined,
                color: Color(0xFF274969),
                size: 20,
              ),

              const SizedBox(width: 8),

              Text(
                _formattedDate(selectedDate),
                style: const TextStyle(fontSize: 12, color: darkText),
              ),

              const SizedBox(width: 12),

              const Icon(Icons.keyboard_arrow_down, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryBlue,
              onPrimary: Colors.white,
              onSurface: darkText,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    setState(() {
      selectedDate = picked;
    });

    debugPrint('Selected date: $selectedDate');

    // TODO: Call attendance API here.
    //
    // await controller.getAttendance(
    //   date: selectedDate,
    // );
  }

  String _formattedDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final today = DateTime.now();

    final isToday =
        today.year == date.year &&
        today.month == date.month &&
        today.day == date.day;

    final prefix = isToday ? 'Today, ' : '';

    return '$prefix${date.day} '
        '${months[date.month - 1]} '
        '${date.year}';
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: darkText,
        fontWeight: FontWeight.w700,
        fontSize: 17,
      ),
    );
  }

  // ============================================================
  // OVERVIEW
  // ============================================================

  Widget _overviewGrid() {
    final items = [
      {
        'title': 'Total\nEmployees',
        'value': employeeController.totalCount.value.toString(),
        'percent': '',
        'filter': 'All',
        'icon': Icons.groups_rounded,
        'color': const Color(0xFF1595E7),
        'background': const Color(0xFFEAF6FF),
      },
      {
        'title': 'Present',
        'value': '--',
        'percent': '',
        'filter': 'Present',
        'icon': Icons.check,
        'color': const Color(0xFF29B967),
        'background': const Color(0xFFE9F9EF),
      },
      {
        'title': 'Absent',
        'value': '--',
        'percent': '',
        'filter': 'Absent',
        'icon': Icons.close,
        'color': const Color(0xFFFF4C52),
        'background': const Color(0xFFFFECEC),
      },
      {
        'title': 'Late',
        'value': '--',
        'percent': '',
        'filter': 'Late',
        'icon': Icons.access_time_filled,
        'color': const Color(0xFFE6A415),
        'background': const Color(0xFFFFF6DA),
      },
      {
        'title': 'Currently IN',
        'value': '--',
        'percent': '',
        'filter': 'Present',
        'icon': Icons.login_rounded,
        'color': const Color(0xFF5360DC),
        'background': const Color(0xFFEEEDFF),
      },
      {
        'title': 'Currently OUT',
        'value': '--',
        'percent': '',
        'filter': 'All',
        'icon': Icons.logout_rounded,
        'color': primaryBlue,
        'background': const Color(0xFFE5F3FF),
      },
    ];

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: .95,
        crossAxisSpacing: 8,
        mainAxisSpacing: 9,
      ),
      itemBuilder: (context, index) {
        final item = items[index];

        return InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: () {
            setState(() {
              selectedFilter = item['filter'] as String;
              selectedTab = 1;
            });
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: item['background'] as Color,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: item['color'] as Color,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        item['icon'] as IconData,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),

                    const SizedBox(width: 7),

                    Expanded(
                      child: Text(
                        item['title'] as String,
                        style: const TextStyle(color: subText, fontSize: 10),
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                Center(
                  child: Text(
                    item['value'] as String,
                    style: const TextStyle(
                      color: darkText,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                if ((item['percent'] as String).isNotEmpty)
                  Center(
                    child: Text(
                      item['percent'] as String,
                      style: TextStyle(
                        color: item['color'] as Color,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // GRAPH
  // ============================================================

  Widget _attendanceGraphCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: primaryBlue),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Attendance summary will appear after connecting the transactions API.',
              style: TextStyle(fontSize: 12, color: subText),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Widget _searchBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 46,
            decoration: _cardDecoration(),
            child: TextField(
              controller: searchController,
              onChanged: (value) {
                setState(() {
                  searchText = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search by name or ID...',

                hintStyle: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8A99AB),
                ),

                prefixIcon: const Icon(Icons.search, color: Color(0xFF47617E)),

                suffixIcon: searchText.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          searchController.clear();

                          setState(() {
                            searchText = '';
                          });
                        },
                        icon: const Icon(Icons.close, size: 18),
                      ),

                border: InputBorder.none,

                contentPadding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ),

        const SizedBox(width: 8),

        Container(
          width: 48,
          height: 46,
          decoration: _cardDecoration(),
          child: IconButton(
            onPressed: _showFilterBottomSheet,
            icon: const Icon(
              Icons.filter_alt_outlined,
              color: Color(0xFF42607C),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // FILTER CHIPS
  // ============================================================

  Widget _filterBar() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, index) {
          final title = filters[index];

          final active = selectedFilter == title;

          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              setState(() {
                selectedFilter = title;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? primaryBlue : const Color(0xFFF4F6F9),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                title,
                style: TextStyle(
                  color: active ? Colors.white : const Color(0xFF52627A),
                  fontSize: 10,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // EMPLOYEE LIST
  // ============================================================

  Widget _employeeList({int? limit}) {
    return Obx(() {
      if (employeeController.isLoading.value &&
          employeeController.employeeList.value == null) {
        return const Padding(
          padding: EdgeInsets.all(30),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (employeeController.employeeList.value == null &&
          employeeController.errorMessage.value.isNotEmpty) {
        return _employeeErrorState();
      }
      var list = filteredEmployees;
      if (limit != null && list.length > limit) {
        list = list.take(limit).toList();
      }
      if (list.isEmpty) return _emptyEmployeeState();
      return Column(
        children: list
            .map(
              (employee) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: _employeeCard(employee),
              ),
            )
            .toList(),
      );
    });
  }

  Widget _employeeCard(Map<String, String> employee) {
    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: () {
        _showEmployeeDetails(employee);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            CircleAvatar(
              radius: 21,
              backgroundColor: const Color(0xFFE6F3FF),
              child: Text(
                employee['initial']!,
                style: const TextStyle(
                  color: primaryBlue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    employee['name']!,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: darkText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    employee['id']!,
                    style: const TextStyle(color: subText, fontSize: 9),
                  ),
                ],
              ),
            ),

            Expanded(
              flex: 3,
              child: Column(
                children: [
                  Row(
                    children: [
                      const SizedBox(
                        width: 24,
                        child: Text(
                          'IN',
                          style: TextStyle(color: subText, fontSize: 9),
                        ),
                      ),

                      Text(
                        employee['in']!,
                        style: const TextStyle(fontSize: 9, color: darkText),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  Row(
                    children: [
                      const SizedBox(
                        width: 24,
                        child: Text(
                          'OUT',
                          style: TextStyle(color: subText, fontSize: 9),
                        ),
                      ),

                      Text(
                        employee['out']!,
                        style: const TextStyle(fontSize: 9, color: darkText),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            _employeeStatus(employee['status']!),

            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.more_vert,
                size: 18,
                color: Color(0xFF52627A),
              ),
              onSelected: (value) {
                if (value == 'details') {
                  _showEmployeeDetails(employee);
                }

                if (value == 'edit') {
                  _showEditAttendance(employee);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'details',
                  child: Row(
                    children: [
                      Icon(Icons.visibility_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('View Details'),
                    ],
                  ),
                ),

                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Update Status'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // STATUS
  // ============================================================

  Widget _employeeStatus(String status) {
    Color bg;
    Color text;

    switch (status) {
      case 'Present':
        bg = const Color(0xFFE4F7EA);
        text = const Color(0xFF119447);
        break;

      case 'Currently IN':
        bg = const Color(0xFFE8F4FF);
        text = primaryBlue;
        break;

      case 'Late':
        bg = const Color(0xFFFFF5D8);
        text = const Color(0xFFBB8211);
        break;

      case 'On Leave':
        bg = const Color(0xFFF1EBFF);
        text = const Color(0xFF7655D8);
        break;

      case 'Left Early':
        bg = const Color(0xFFFFE8E9);
        text = const Color(0xFFD83438);
        break;

      default:
        bg = const Color(0xFFFFE8E9);
        text = const Color(0xFFD83438);
    }

    return Container(
      constraints: const BoxConstraints(minWidth: 60),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        status,
        textAlign: TextAlign.center,
        style: TextStyle(color: text, fontWeight: FontWeight.w500, fontSize: 8),
      ),
    );
  }

  // ============================================================
  // FILTER BOTTOM SHEET
  // ============================================================

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 25),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD5DBE3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'Filter Attendance',
                  style: TextStyle(
                    color: darkText,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 12),

                ...filters.map(
                  (filter) => RadioListTile<String>(
                    value: filter,
                    groupValue: selectedFilter,
                    activeColor: primaryBlue,
                    contentPadding: EdgeInsets.zero,
                    title: Text(filter, style: const TextStyle(fontSize: 13)),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }

                      setState(() {
                        selectedFilter = value;
                        selectedTab = 1;
                      });

                      Navigator.pop(sheetContext);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // EMPLOYEE DETAILS
  // ============================================================

  void _showEmployeeDetails(Map<String, String> employee) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 25),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD5DBE3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),

                const SizedBox(height: 22),

                CircleAvatar(
                  radius: 34,
                  backgroundColor: const Color(0xFFE6F3FF),
                  child: Text(
                    employee['initial']!,
                    style: const TextStyle(
                      color: primaryBlue,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  employee['name']!,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: darkText,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  employee['id']!,
                  style: const TextStyle(color: subText, fontSize: 12),
                ),

                const SizedBox(height: 20),

                _detailsRow('Department', employee['department']!),

                _detailsRow('Email', employee['email']!),

                _detailsRow('Check In', employee['in']!),

                _detailsRow('Check Out', employee['out']!),

                _detailsRow('Working Hours', employee['hours']!),

                const SizedBox(height: 8),

                Row(
                  children: [
                    const Text(
                      'Status',
                      style: TextStyle(color: subText, fontSize: 12),
                    ),

                    const Spacer(),

                    _employeeStatus(employee['status']!),
                  ],
                ),

                const SizedBox(height: 22),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);

                      _showEditAttendance(employee);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Update Attendance'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailsRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(title, style: const TextStyle(color: subText, fontSize: 12)),

          const Spacer(),

          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: darkText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EDIT ATTENDANCE
  // ============================================================

  void _showEditAttendance(Map<String, String> employee) {
    String tempStatus = employee['status']!;

    final allowedStatuses = [
      'Present',
      'Absent',
      'Late',
      'On Leave',
      'Currently IN',
      'Left Early',
      'Not Available',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, sheetSetState) {
            return SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 25),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD5DBE3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      'Update Attendance',
                      style: TextStyle(
                        color: darkText,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      employee['name']!,
                      style: const TextStyle(color: subText, fontSize: 12),
                    ),

                    const SizedBox(height: 18),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: tempStatus,
                          isExpanded: true,
                          items: allowedStatuses.map((status) {
                            return DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }

                            sheetSetState(() {
                              tempStatus = value;
                            });
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            employee['status'] = tempStatus;
                          });

                          Navigator.pop(sheetContext);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Status changed locally (not saved to server): $tempStatus',
                              ),
                              backgroundColor: const Color(0xFF16A34A),
                            ),
                          );

                          // TODO:
                          // Call update attendance API here.
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Save Changes'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // EXPORT
  // ============================================================

  Widget _exportCard() {
    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: () {
        _showExportSheet(reportName: 'Attendance Report');
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF5FF),
          borderRadius: BorderRadius.circular(13),
        ),
        child: const Row(
          children: [
            Icon(Icons.file_present_outlined, color: primaryBlue, size: 28),

            SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Export Attendance Report',
                    style: TextStyle(
                      color: darkText,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  SizedBox(height: 3),

                  Text(
                    'Download PDF or Excel',
                    style: TextStyle(color: subText, fontSize: 11),
                  ),
                ],
              ),
            ),

            Icon(Icons.chevron_right, color: Color(0xFF52627A)),
          ],
        ),
      ),
    );
  }

  void _showExportSheet({required String reportName}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 25),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD5DBE3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  reportName,
                  style: const TextStyle(
                    color: darkText,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 5),

                const Text(
                  'Choose download format',
                  style: TextStyle(color: subText, fontSize: 12),
                ),

                const SizedBox(height: 20),

                _exportOption(
                  icon: Icons.picture_as_pdf,
                  title: 'Download PDF',
                  color: const Color(0xFFDC2626),
                  onTap: () {
                    Navigator.pop(sheetContext);

                    _showMessage('PDF export selected');

                    // TODO:
                    // Connect PDF export API/service.
                  },
                ),

                const SizedBox(height: 10),

                _exportOption(
                  icon: Icons.table_chart,
                  title: 'Download Excel',
                  color: const Color(0xFF16A34A),
                  onTap: () {
                    Navigator.pop(sheetContext);

                    _showMessage('Excel export selected');

                    // TODO:
                    // Connect Excel export API/service.
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _exportOption({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 26),

            const SizedBox(width: 12),

            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: darkText,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),

            const Icon(Icons.chevron_right, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // REPORT CARDS
  // ============================================================

  Widget _reportCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF5FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: primaryBlue),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: darkText,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    subtitle,
                    style: const TextStyle(color: subText, fontSize: 10),
                  ),
                ],
              ),
            ),

            const Icon(Icons.chevron_right, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MONTH PICKER
  // ============================================================

  void _showMonthPicker() {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    int tempMonth = selectedDate.month;

    int tempYear = selectedDate.year;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, sheetSetState) {
            return SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 25),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Month',
                      style: TextStyle(
                        color: darkText,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 16),

                    DropdownButtonFormField<int>(
                      value: tempMonth,
                      decoration: const InputDecoration(
                        labelText: 'Month',
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(12, (index) {
                        return DropdownMenuItem(
                          value: index + 1,
                          child: Text(months[index]),
                        );
                      }),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }

                        sheetSetState(() {
                          tempMonth = value;
                        });
                      },
                    ),

                    const SizedBox(height: 12),

                    DropdownButtonFormField<int>(
                      value: tempYear,
                      decoration: const InputDecoration(
                        labelText: 'Year',
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(8, (index) {
                        final year = DateTime.now().year - 5 + index;

                        return DropdownMenuItem(
                          value: year,
                          child: Text(year.toString()),
                        );
                      }),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }

                        sheetSetState(() {
                          tempYear = value;
                        });
                      },
                    ),

                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            selectedDate = DateTime(tempYear, tempMonth, 1);
                          });

                          Navigator.pop(sheetContext);

                          _showExportSheet(
                            reportName:
                                '${months[tempMonth - 1]} $tempYear Attendance',
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Generate Report'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // EMPLOYEE SELECTOR
  // ============================================================

  void _showEmployeeSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * .70,
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD5DBE3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),

                const SizedBox(height: 18),

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Select Employee',
                    style: TextStyle(
                      color: darkText,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Expanded(
                  child: Obx(
                    () => ListView.separated(
                      itemCount: employees.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final employee = employees[index];

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFE6F3FF),
                            child: Text(
                              employee['initial']!,
                              style: const TextStyle(color: primaryBlue),
                            ),
                          ),
                          title: Text(employee['name']!),
                          subtitle: Text(employee['id']!),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.pop(sheetContext);

                            _showExportSheet(
                              reportName: '${employee['name']} Attendance',
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _emptyEmployeeState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 50),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.person_search, size: 55, color: Color(0xFF9AA8B8)),

            const SizedBox(height: 10),

            const Text(
              'No employees found',
              style: TextStyle(
                color: darkText,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 4),

            TextButton(
              onPressed: () {
                searchController.clear();

                setState(() {
                  searchText = '';
                  selectedFilter = 'All';
                });
              },
              child: const Text('Clear Filters'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: const Color(0xFFE9EEF4)),
    );
  }
}

// ============================================================
// LEGEND
// ============================================================

class AttendanceLegend extends StatelessWidget {
  final Color color;
  final String title;
  final String value;
  final String percent;

  const AttendanceLegend({
    super.key,
    required this.color,
    required this.title,
    required this.value,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 10, color: Color(0xFF52627A)),
            ),
          ),

          SizedBox(
            width: 28,
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10),
            ),
          ),

          Text(
            percent,
            style: const TextStyle(color: Color(0xFF718096), fontSize: 9),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CIRCLE CHART
// ============================================================

class AttendanceCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final radius = size.width / 2 - 9;

    final rect = Rect.fromCircle(center: center, radius: radius);

    const strokeWidth = 17.0;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    double startAngle = -1.5708;

    final data = [
      [0.817, const Color(0xFF22B85B)],
      [0.100, const Color(0xFFFF5353)],
      [0.050, const Color(0xFFFFBD32)],
      [0.033, const Color(0xFF7765E5)],
    ];

    for (final item in data) {
      final value = item[0] as double;

      final color = item[1] as Color;

      final sweep = 6.28318 * value;

      paint.color = color;

      canvas.drawArc(rect, startAngle, sweep, false, paint);

      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

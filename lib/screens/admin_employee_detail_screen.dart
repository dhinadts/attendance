import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/industrial_theme.dart';
import '../widgets/admin_bottom_nav.dart';
import '../widgets/app_shell.dart';
import '../widgets/industrial_card.dart';
import '../widgets/status_chip.dart';

class AdminEmployeeDetailScreen extends StatefulWidget {
  const AdminEmployeeDetailScreen({
    super.key,
    required this.employeeId,
    this.initialTab,
  });

  final String employeeId;
  final String? initialTab;

  @override
  State<AdminEmployeeDetailScreen> createState() => _AdminEmployeeDetailScreenState();
}

enum AttendanceFilterType { day, week, month, year, custom }

class _AdminEmployeeDetailScreenState extends State<AdminEmployeeDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Filter States
  AttendanceFilterType _filterType = AttendanceFilterType.month;
  String _statusFilter = 'ALL'; // ALL, PRESENT, LATE, ABSENT, LEAVE
  DateTime _selectedDate = DateTime.now();
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    int initialIdx = 0;
    if (widget.initialTab != null) {
      initialIdx = int.tryParse(widget.initialTab!) ?? 0;
    }
    _tabController = TabController(length: 2, vsync: this, initialIndex: initialIdx);
    
    // Initialize date range for custom filter
    final today = DateTime.now();
    _selectedDateRange = DateTimeRange(
      start: today.subtract(const Duration(days: 7)),
      end: today,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Date formatting helper
  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  String _formatMonth(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }

  String _formatTime(String? timeIso) {
    if (timeIso == null || timeIso.isEmpty) return '-';
    final parsed = DateTime.tryParse(timeIso);
    if (parsed == null) return timeIso;
    final hour = parsed.hour > 12 ? parsed.hour - 12 : (parsed.hour == 0 ? 12 : parsed.hour);
    final period = parsed.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')} $period';
  }

  // Date range calculations for weekly filter
  DateTimeRange _getWeekRange(DateTime date) {
    final weekday = date.weekday;
    final start = date.subtract(Duration(days: weekday - 1)); // Monday
    final end = start.add(const Duration(days: 6)); // Sunday
    return DateTimeRange(start: start, end: end);
  }

  bool _isLogVisible(Map<String, dynamic> log) {
    final logDateStr = log['loginDateIst'] as String?;
    if (logDateStr == null) return false;
    final logDate = DateTime.tryParse(logDateStr);
    if (logDate == null) return false;

    // 1. Time range filter
    bool inRange = false;
    switch (_filterType) {
      case AttendanceFilterType.day:
        inRange = logDateStr == _formatDate(_selectedDate);
        break;
      case AttendanceFilterType.week:
        final range = _getWeekRange(_selectedDate);
        final start = DateTime(range.start.year, range.start.month, range.start.day);
        final end = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59);
        inRange = logDate.isAfter(start.subtract(const Duration(seconds: 1))) &&
            logDate.isBefore(end.add(const Duration(seconds: 1)));
        break;
      case AttendanceFilterType.month:
        inRange = logDate.year == _selectedDate.year && logDate.month == _selectedDate.month;
        break;
      case AttendanceFilterType.year:
        inRange = logDate.year == _selectedDate.year;
        break;
      case AttendanceFilterType.custom:
        if (_selectedDateRange == null) return false;
        final start = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
        final end = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day, 23, 59, 59);
        inRange = logDate.isAfter(start.subtract(const Duration(seconds: 1))) &&
            logDate.isBefore(end.add(const Duration(seconds: 1)));
        break;
    }

    if (!inRange) return false;

    // 2. Status filter
    if (_statusFilter == 'ALL') return true;
    final status = (log['attendanceStatus'] as String? ?? '').toLowerCase();
    final baseStatus = (log['status'] as String? ?? '').toLowerCase();
    final dayStatus = (log['dayStatus'] as String? ?? '').toLowerCase();

    if (_statusFilter == 'PRESENT') {
      return status == 'attendance_considered';
    } else if (_statusFilter == 'LATE') {
      return status == 'not_considered_attendance' && baseStatus == 'present';
    } else if (_statusFilter == 'ABSENT') {
      return baseStatus == 'absent';
    } else if (_statusFilter == 'LEAVE') {
      return baseStatus == 'leave' || status == 'leave' || dayStatus == 'approved_leave';
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Employee Profile',
      bottomNavigationBar: const AdminBottomNav(currentIndex: 1),
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _firestore.collection('employee_profiles').doc(widget.employeeId).snapshots(),
        builder: (context, profileSnapshot) {
          if (profileSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final profileData = profileSnapshot.data?.data();
          if (profileData == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text('Profile not found in Firestore.'),
              ),
            );
          }

          final name = profileData['employeeName'] as String? ?? 'Employee Details';
          final dept = profileData['department'] as String? ?? 'TECH';
          final role = profileData['role'] as String? ?? 'EMPLOYEE';

          return Column(
            children: [
              // Employee Quick Header Info
              Container(
                width: double.infinity,
                color: IndustrialColors.surface,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: IndustrialColors.primary,
                      foregroundColor: IndustrialColors.onPrimary,
                      child: Text(
                        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'E',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$role | $dept',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontSize: 14,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              TabBar(
                controller: _tabController,
                indicatorColor: IndustrialColors.primary,
                labelColor: IndustrialColors.primary,
                unselectedLabelColor: IndustrialColors.onSurfaceVariant,
                tabs: const [
                  Tab(icon: Icon(Icons.person), text: 'Profile Info'),
                  Tab(icon: Icon(Icons.calendar_month), text: 'Attendance'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildProfileTab(profileData),
                    _buildAttendanceTab(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // 1. Profile Tab
  Widget _buildProfileTab(Map<String, dynamic> data) {
    final joiningDate = data['joiningDate'] as String? ?? 'Not specified';
    final dob = data['dateOfBirth'] as String? ?? 'Not specified';
    final contact = data['contactNumber'] as String? ?? 'Not specified';
    final email = data['email'] as String? ?? 'Not specified';
    final empId = data['employeeId'] as String? ?? widget.employeeId;
    final nickName = data['nickName'] as String? ?? 'Not specified';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personal Details',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          IndustrialCard(
            child: Column(
              children: [
                _buildInfoRow(Icons.badge, 'Employee ID', empId),
                const Divider(height: 20),
                _buildInfoRow(Icons.face, 'Nickname', nickName),
                const Divider(height: 20),
                _buildInfoRow(Icons.email, 'Email Address', email),
                const Divider(height: 20),
                _buildInfoRow(Icons.phone, 'Contact Number', contact),
                const Divider(height: 20),
                _buildInfoRow(Icons.cake, 'Date of Birth', dob),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Company Placement',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          IndustrialCard(
            child: Column(
              children: [
                _buildInfoRow(
                  Icons.event_available,
                  'Joining Date',
                  joiningDate,
                  highlight: true,
                ),
                const Divider(height: 20),
                _buildInfoRow(Icons.factory, 'Department / Team', data['department'] as String? ?? 'TECH'),
                const Divider(height: 20),
                _buildInfoRow(Icons.engineering, 'Assigned Role', data['role'] as String? ?? 'EMPLOYEE'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: IndustrialColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: IndustrialColors.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: highlight ? IndustrialColors.secondary : IndustrialColors.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 2. Attendance Tab
  Widget _buildAttendanceTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('attendance')
          .where('employeeId', isEqualTo: widget.employeeId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final logs = (snapshot.data?.docs ?? []).map((doc) => doc.data()).toList();
        final filteredLogs = logs.where(_isLogVisible).toList()
          ..sort((a, b) {
            final dateA = a['loginDateIst'] as String? ?? '';
            final dateB = b['loginDateIst'] as String? ?? '';
            return dateB.compareTo(dateA); // descending order
          });

        // Compute Statistics
        int presentCount = 0;
        int lateCount = 0;
        int leaveCount = 0;
        double totalHours = 0.0;

        for (final log in filteredLogs) {
          final status = (log['attendanceStatus'] as String? ?? '').toLowerCase();
          final baseStatus = (log['status'] as String? ?? '').toLowerCase();
          final dayStatus = (log['dayStatus'] as String? ?? '').toLowerCase();
          final officeMinutes = (log['officeMinutes'] as num?)?.toDouble() ?? 0.0;
          totalHours += officeMinutes / 60.0;

          if (status == 'attendance_considered') {
            presentCount++;
          } else if (status == 'not_considered_attendance' && baseStatus == 'present') {
            lateCount++;
          } else if (baseStatus == 'leave' || status == 'leave' || dayStatus == 'approved_leave') {
            leaveCount++;
          }
        }

        return Column(
          children: [
            // Filter Selectors Pane
            Container(
              color: IndustrialColors.surface,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Filter Type Selector (Chips)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: AttendanceFilterType.values.map((type) {
                        final isSelected = _filterType == type;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(type.name.toUpperCase()),
                            selected: isSelected,
                            selectedColor: IndustrialColors.primaryContainer,
                            backgroundColor: IndustrialColors.surfaceContainerLow,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : IndustrialColors.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _filterType = type;
                                });
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Date Picker Display & Selector Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _getFilterDateText(),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _selectDateOrRange,
                        icon: const Icon(Icons.date_range, size: 18),
                        label: const Text('Change Date'),
                        style: TextButton.styleFrom(
                          foregroundColor: IndustrialColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  // Status Filter Dropdown
                  Row(
                    children: [
                      const Text(
                        'Status Filter: ',
                        style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _statusFilter,
                        isDense: true,
                        style: const TextStyle(
                          color: IndustrialColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'ALL', child: Text('All Logs')),
                          DropdownMenuItem(value: 'PRESENT', child: Text('Present Only')),
                          DropdownMenuItem(value: 'LATE', child: Text('Late/Deductions')),
                          DropdownMenuItem(value: 'ABSENT', child: Text('Absent Only')),
                          DropdownMenuItem(value: 'LEAVE', child: Text('Approved Leaves')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _statusFilter = val);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Statistics Pane
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.1,
                children: [
                  _buildStatBox('Present', '$presentCount', IndustrialColors.secondary),
                  _buildStatBox('Late', '$lateCount', Colors.orange.shade800),
                  _buildStatBox('Leave', '$leaveCount', Colors.blue.shade800),
                  _buildStatBox('Hours', '${totalHours.toStringAsFixed(1)}h', IndustrialColors.primary),
                ],
              ),
            ),

            // List of Logs
            Expanded(
              child: filteredLogs.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Text(
                          'No logs found matching selection.',
                          style: TextStyle(color: IndustrialColors.onSurfaceVariant),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: filteredLogs.length,
                      itemBuilder: (context, idx) {
                        final log = filteredLogs[idx];
                        return _buildLogCard(log);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatBox(String label, String value, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: IndustrialColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: IndustrialColors.outlineVariant),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: IndustrialColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
    final dateStr = log['loginDateIst'] as String? ?? 'Unknown';
    final loginTime = _formatTime(log['loginAtIst'] as String?);
    final logoutTime = _formatTime(log['logoutAtIst'] as String?);
    final officeMin = log['officeMinutes'] as num? ?? 0;
    final sessionStatus = log['sessionStatus'] as String? ?? 'closed';
    final device = log['device'] as Map<String, dynamic>?;

    final attendanceStatus = (log['attendanceStatus'] as String? ?? '').toLowerCase();
    final baseStatus = (log['status'] as String? ?? '').toLowerCase();
    final dayStatus = (log['dayStatus'] as String? ?? '').toLowerCase();

    // Determine Chip type
    String chipLabel = 'PENDING';
    StatusChipType chipType = StatusChipType.pending;

    if (attendanceStatus == 'attendance_considered') {
      chipLabel = 'PRESENT';
      chipType = StatusChipType.success;
    } else if (attendanceStatus == 'not_considered_attendance' && baseStatus == 'present') {
      chipLabel = 'LATE';
      chipType = StatusChipType.alert;
    } else if (baseStatus == 'absent') {
      chipLabel = 'ABSENT';
      chipType = StatusChipType.neutral;
    } else if (baseStatus == 'leave' || attendanceStatus == 'leave' || dayStatus == 'approved_leave') {
      chipLabel = 'LEAVE';
      chipType = StatusChipType.pending;
    }

    if (sessionStatus == 'active') {
      chipLabel = 'ACTIVE';
      chipType = StatusChipType.success;
    }

    final officeHours = officeMin ~/ 60;
    final officeMinsRemaining = (officeMin % 60).toInt();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: IndustrialCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dateStr,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                StatusChip(label: chipLabel, type: chipType),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('CHECK IN', style: TextStyle(fontSize: 10, color: IndustrialColors.onSurfaceVariant)),
                    Text(loginTime, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('CHECK OUT', style: TextStyle(fontSize: 10, color: IndustrialColors.onSurfaceVariant)),
                    Text(sessionStatus == 'active' ? 'Active now' : logoutTime,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: sessionStatus == 'active' ? IndustrialColors.secondary : IndustrialColors.onSurface,
                        )),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('OFFICE TIME', style: TextStyle(fontSize: 10, color: IndustrialColors.onSurfaceVariant)),
                    Text(
                      '${officeHours}h ${officeMinsRemaining}m',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
            if (device != null) ...[
              const Divider(height: 16),
              Row(
                children: [
                  const Icon(Icons.devices, size: 14, color: IndustrialColors.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${device['deviceName'] ?? "Device"} (${device['platform'] ?? "unknown"})',
                      style: const TextStyle(fontSize: 11, color: IndustrialColors.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getFilterDateText() {
    switch (_filterType) {
      case AttendanceFilterType.day:
        return 'Date: ${_formatDate(_selectedDate)}';
      case AttendanceFilterType.week:
        final range = _getWeekRange(_selectedDate);
        return 'Week: ${_formatDate(range.start)} to ${_formatDate(range.end)}';
      case AttendanceFilterType.month:
        return 'Month: ${_formatMonth(_selectedDate)}';
      case AttendanceFilterType.year:
        return 'Year: ${_selectedDate.year}';
      case AttendanceFilterType.custom:
        if (_selectedDateRange == null) return 'No range selected';
        return 'Range: ${_formatDate(_selectedDateRange!.start)} to ${_formatDate(_selectedDateRange!.end)}';
    }
  }

  Future<void> _selectDateOrRange() async {
    final now = DateTime.now();

    if (_filterType == AttendanceFilterType.custom) {
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 2),
        lastDate: now,
        initialDateRange: _selectedDateRange,
      );
      if (range != null) {
        setState(() {
          _selectedDateRange = range;
        });
      }
      return;
    }

    // Default: select a date
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDatePickerMode: _filterType == AttendanceFilterType.year
          ? DatePickerMode.year
          : DatePickerMode.day,
    );

    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
    }
  }
}

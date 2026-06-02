import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/attendance_session_service.dart';
import '../theme/industrial_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/employee_bottom_nav.dart';
import '../widgets/industrial_card.dart';
import '../widgets/status_chip.dart';
import '../services/app_firestore.dart';

class AttendanceDetailsScreen extends StatefulWidget {
  const AttendanceDetailsScreen({super.key});

  @override
  State<AttendanceDetailsScreen> createState() =>
      _AttendanceDetailsScreenState();
}

class _AttendanceDetailsScreenState extends State<AttendanceDetailsScreen> {
  final _service = AttendanceSessionService();
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDate = DateTime.now();
  EmployeeProfile? _profile;
  bool _outsideOfficeSession = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await _service.loadEmployeeProfile();
    final outsideOffice = await _service.hasOutsideOfficeSession();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _outsideOfficeSession = outsideOffice;
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _attendanceStream() {
    final profile = _profile;
    if (profile == null) {
      return const Stream.empty();
    }
    return FirebaseFirestore.instance
        .appCollection('attendance')
        .where('employeeId', isEqualTo: profile.employeeId)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _leaveStream() {
    final profile = _profile;
    if (profile == null) {
      return const Stream.empty();
    }
    return FirebaseFirestore.instance
        .appCollection('leave_requests')
        .where('employeeId', isEqualTo: profile.employeeId)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Attendance',
      bottomNavigationBar: EmployeeBottomNav(
        currentIndex: 1,
        attendanceAlert: _outsideOfficeSession,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attendance Details',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '7 office hours required to consider attendance',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: IndustrialColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _buildMonthHeader(),
            const SizedBox(height: 12),
            if (_profile == null)
              const Center(child: CircularProgressIndicator())
            else
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _attendanceStream(),
                builder: (context, snapshot) {
                  final records = snapshot.data?.docs ?? [];
                  final byDate = <String, Map<String, dynamic>>{};
                  for (final record in records) {
                    final data = record.data();
                    final date = data['loginDateIst'] as String?;
                    if (date == null || !_isVisibleMonth(date)) continue;
                    byDate[date] = data;
                  }
                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _leaveStream(),
                    builder: (context, leaveSnapshot) {
                      final leaveRecords = leaveSnapshot.data?.docs ?? [];
                      final leavesByDate = <String, Map<String, dynamic>>{};
                      for (final record in leaveRecords) {
                        final data = record.data();
                        final date = data['date'] as String?;
                        if (date == null || !_isVisibleMonth(date)) continue;
                        leavesByDate[date] = data;
                      }
                      return Column(
                        children: [
                          _buildCalendar(byDate, leavesByDate),
                          const SizedBox(height: 12),
                          _buildSelectedDateActions(byDate, leavesByDate),
                        ],
                      );
                    },
                  );
                },
              ),
            const SizedBox(height: 20),
            _buildLegend(),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthHeader() {
    final label =
        '${_monthNames[_visibleMonth.month - 1]} ${_visibleMonth.year}';
    return Row(
      children: [
        IconButton(
          onPressed: () {
            final previousMonth = DateTime(
              _visibleMonth.year,
              _visibleMonth.month - 1,
            );
            setState(() {
              _visibleMonth = previousMonth;
              _selectedDate = _defaultSelectedDateFor(previousMonth);
            });
          },
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: () {
            final nextMonth = DateTime(
              _visibleMonth.year,
              _visibleMonth.month + 1,
            );
            setState(() {
              _visibleMonth = nextMonth;
              _selectedDate = _defaultSelectedDateFor(nextMonth);
            });
          },
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _buildCalendar(
    Map<String, Map<String, dynamic>> byDate,
    Map<String, Map<String, dynamic>> leavesByDate,
  ) {
    final daysInMonth = DateUtils.getDaysInMonth(
      _visibleMonth.year,
      _visibleMonth.month,
    );
    final firstWeekday = DateTime(
      _visibleMonth.year,
      _visibleMonth.month,
    ).weekday;
    final cells = <Widget>[];

    for (var i = 1; i < firstWeekday; i++) {
      cells.add(const SizedBox.shrink());
    }

    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_visibleMonth.year, _visibleMonth.month, day);
      final key = _dateKey(date);
      final data = byDate[key];
      final leaveData = leavesByDate[key];
      final status = _statusForDate(date, data, leaveData);
      cells.add(_dayCell(day, key, status, data, leaveData, date));
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: cells,
    );
  }

  Widget _dayCell(
    int day,
    String dateKey,
    _AttendanceDayStatus status,
    Map<String, dynamic>? data,
    Map<String, dynamic>? leaveData,
    DateTime date,
  ) {
    final selected = _dateKey(_selectedDate) == dateKey;
    return InkWell(
      onTap: () => setState(() => _selectedDate = date),
      child: Container(
        decoration: BoxDecoration(
          color: status.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? IndustrialColors.primary : status.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: status.foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Icon(status.icon, size: 14, color: status.foreground),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedDateActions(
    Map<String, Map<String, dynamic>> byDate,
    Map<String, Map<String, dynamic>> leavesByDate,
  ) {
    final selectedKey = _dateKey(_selectedDate);
    final attendanceData = byDate[selectedKey];
    final leaveData = leavesByDate[selectedKey];
    final status = _statusForDate(_selectedDate, attendanceData, leaveData);
    final leaveStatus = leaveData?['status'] as String?;
    final hasOpenLeave =
        leaveStatus == 'requested_leave' || leaveStatus == 'approved_leave';

    return IndustrialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Selected date: $selectedKey',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              StatusChip(label: status.label, type: status.chipType),
            ],
          ),
          if ((leaveData?['reason'] as String?)?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text('Reason: ${leaveData!['reason']}'),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: hasOpenLeave
                      ? null
                      : () => _showRequestLeaveDialog(selectedKey),
                  icon: const Icon(Icons.event_busy),
                  label: Text(
                    hasOpenLeave ? 'LEAVE ALREADY SENT' : 'REQUEST LEAVE',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                tooltip: 'Leave status is also available in Profile',
                onPressed: () => context.go('/profile'),
                icon: const Icon(Icons.person_search),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showRequestLeaveDialog(String dateKey) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Request Leave - $dateKey'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason',
            hintText: 'Enter leave reason',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('SEND REQUEST'),
          ),
        ],
      ),
    );
    if (reason == null) return;

    try {
      await _service.requestLeave(dateKey: dateKey, reason: reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Leave request sent for $dateKey')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Widget _buildLegend() {
    const items = [
      _AttendanceDayStatus(
        label: 'LEAVE',
        icon: Icons.beach_access,
        background: Color(0xFFFFF3E0),
        foreground: Color(0xFF7A4100),
        border: Color(0xFFFFCC80),
        chipType: StatusChipType.pending,
      ),
      _AttendanceDayStatus(
        label: 'NOT CONSIDER',
        icon: Icons.timer_off,
        background: Color(0xFFFFEBEE),
        foreground: Color(0xFFBA1A1A),
        border: Color(0xFFFFCDD2),
        chipType: StatusChipType.alert,
      ),
      _AttendanceDayStatus(
        label: 'ABSENT',
        icon: Icons.close,
        background: Color(0xFFF1F3F5),
        foreground: Color(0xFF444653),
        border: Color(0xFFC4C5D5),
        chipType: StatusChipType.neutral,
      ),
      _AttendanceDayStatus(
        label: 'APPROVED LEAVE',
        icon: Icons.check_circle,
        background: Color(0xFFE8F5E9),
        foreground: Color(0xFF006D30),
        border: Color(0xFFA5D6A7),
        chipType: StatusChipType.success,
      ),
      _AttendanceDayStatus(
        label: 'REQUESTED LEAVE',
        icon: Icons.hourglass_top,
        background: Color(0xFFE6EEFF),
        foreground: Color(0xFF00288E),
        border: Color(0xFFA8B8FF),
        chipType: StatusChipType.pending,
      ),
      _AttendanceDayStatus(
        label: 'REJECTED LEAVE',
        icon: Icons.cancel,
        background: Color(0xFFFFEBEE),
        foreground: Color(0xFFBA1A1A),
        border: Color(0xFFFFCDD2),
        chipType: StatusChipType.alert,
      ),
    ];

    return IndustrialCard(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items
            .map((item) => StatusChip(label: item.label, type: item.chipType))
            .toList(),
      ),
    );
  }

  _AttendanceDayStatus _statusForDate(
    DateTime date,
    Map<String, dynamic>? data,
    Map<String, dynamic>? leaveData,
  ) {
    final now = DateTime.now();
    final requestStatus =
        (leaveData?['status'] as String?) ?? (data?['leaveStatus'] as String?);
    if (requestStatus == 'approved_leave') return _statuses['approved']!;
    if (requestStatus == 'requested_leave') return _statuses['requested']!;
    if (requestStatus == 'rejected_leave' || requestStatus == 'rejected') {
      return _statuses['rejected']!;
    }

    if (data == null) {
      if (date.isAfter(DateTime(now.year, now.month, now.day))) {
        return _statuses['leave']!;
      }
      return _statuses['absent']!;
    }

    final rawStatus = data['attendanceStatus'] as String?;
    if (rawStatus == 'attendance_considered') return _statuses['present']!;
    if (rawStatus == 'not_considered_attendance') {
      return _statuses['notConsider']!;
    }
    if (data['status'] == 'leave') return _statuses['leave']!;
    return _statuses['present']!;
  }

  bool _isVisibleMonth(String dateKey) {
    return dateKey.startsWith(
      '${_visibleMonth.year.toString().padLeft(4, '0')}-'
      '${_visibleMonth.month.toString().padLeft(2, '0')}',
    );
  }

  String _dateKey(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  DateTime _defaultSelectedDateFor(DateTime month) {
    final today = DateTime.now();
    if (today.year == month.year && today.month == month.month) {
      return today;
    }
    return DateTime(month.year, month.month);
  }

  static const _monthNames = [
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

  static const _statuses = {
    'present': _AttendanceDayStatus(
      label: 'PRESENT',
      icon: Icons.check,
      background: Color(0xFFE8F5E9),
      foreground: Color(0xFF006D30),
      border: Color(0xFFA5D6A7),
      chipType: StatusChipType.success,
    ),
    'leave': _AttendanceDayStatus(
      label: 'LEAVE',
      icon: Icons.beach_access,
      background: Color(0xFFFFF3E0),
      foreground: Color(0xFF7A4100),
      border: Color(0xFFFFCC80),
      chipType: StatusChipType.pending,
    ),
    'notConsider': _AttendanceDayStatus(
      label: 'NOT CONSIDER',
      icon: Icons.timer_off,
      background: Color(0xFFFFEBEE),
      foreground: Color(0xFFBA1A1A),
      border: Color(0xFFFFCDD2),
      chipType: StatusChipType.alert,
    ),
    'absent': _AttendanceDayStatus(
      label: 'ABSENT',
      icon: Icons.close,
      background: Color(0xFFF1F3F5),
      foreground: Color(0xFF444653),
      border: Color(0xFFC4C5D5),
      chipType: StatusChipType.neutral,
    ),
    'approved': _AttendanceDayStatus(
      label: 'APPROVED LEAVE',
      icon: Icons.check_circle,
      background: Color(0xFFE8F5E9),
      foreground: Color(0xFF006D30),
      border: Color(0xFFA5D6A7),
      chipType: StatusChipType.success,
    ),
    'requested': _AttendanceDayStatus(
      label: 'REQUESTED LEAVE',
      icon: Icons.hourglass_top,
      background: Color(0xFFE6EEFF),
      foreground: Color(0xFF00288E),
      border: Color(0xFFA8B8FF),
      chipType: StatusChipType.pending,
    ),
    'rejected': _AttendanceDayStatus(
      label: 'REJECTED LEAVE',
      icon: Icons.cancel,
      background: Color(0xFFFFEBEE),
      foreground: Color(0xFFBA1A1A),
      border: Color(0xFFFFCDD2),
      chipType: StatusChipType.alert,
    ),
  };
}

class _AttendanceDayStatus {
  const _AttendanceDayStatus({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.border,
    required this.chipType,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final Color border;
  final StatusChipType chipType;
}

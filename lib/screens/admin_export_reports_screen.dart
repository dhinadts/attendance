import '../widgets/app_shell.dart';
import '../widgets/status_chip.dart';
import 'package:flutter/material.dart';
import '../theme/industrial_theme.dart';
import '../services/app_firestore.dart';
import '../widgets/industrial_card.dart';
import '../widgets/admin_bottom_nav.dart';
import '../widgets/primary_action_button.dart';
import '../constants/organization_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendance/utils/csv_download.dart';

class AdminExportReportsScreen extends StatefulWidget {
  const AdminExportReportsScreen({super.key});

  @override
  State<AdminExportReportsScreen> createState() =>
      _AdminExportReportsScreenState();
}

class _AdminExportReportsScreenState extends State<AdminExportReportsScreen> {
  final _firestore = FirebaseFirestore.instance;
  bool _isExporting = false;
  String? _lastFilePath;
  DateTimeRange? _dateRange;
  final Set<String> _selectedEmployeeIds = {};

  Future<void> _exportAttendanceCsv({
    required Map<String, Map<String, dynamic>> employeeProfiles,
    Set<String>? employeeIds,
    String scopeLabel = 'all_employees',
  }) async {
    setState(() => _isExporting = true);
    try {
      final attendance = await _firestore.appCollection('attendance').get();
      final selectedIds = employeeIds
          ?.where((id) => id.trim().isNotEmpty)
          .toSet();
      final matchedEmployeeDateKeys = <String, Set<String>>{};
      final recordRows = <List<String>>[];

      for (final doc in attendance.docs) {
        final data = doc.data();
        final employee = data['employee'] as Map<String, dynamic>?;
        final currentEmployeeId = '${data['employeeId'] ?? ''}';
        final loginDate = '${data['loginDateIst'] ?? ''}';
        if (selectedIds != null && !selectedIds.contains(currentEmployeeId)) {
          continue;
        }
        if (!_isDateInRange(loginDate)) {
          continue;
        }
        matchedEmployeeDateKeys
            .putIfAbsent(currentEmployeeId, () => <String>{})
            .add(loginDate);
        final profile = employeeProfiles[currentEmployeeId];
        final team =
            employee?['department'] ??
            profile?['department'] ??
            data['department'];
        final name =
            data['employeeName'] ??
            employee?['employeeName'] ??
            profile?['employeeName'] ??
            profile?['displayName'];
        final role =
            employee?['employeeRole'] ??
            employee?['role'] ??
            profile?['employeeRole'] ??
            profile?['role'] ??
            '';
        final attendanceStatus =
            data['attendanceStatus'] ??
            data['dayStatus'] ??
            data['status'] ??
            '';

        recordRows.add([
          loginDate,
          '${team ?? ''}',
          '$role',
          '$name',
          currentEmployeeId,
          '$attendanceStatus',
        ]);
      }

      final targetProfileIds = selectedIds ?? employeeProfiles.keys.toSet();
      final noRecordDates = _noRecordDateKeys();
      final targetProfiles =
          targetProfileIds
              .map((id) => employeeProfiles[id])
              .whereType<Map<String, dynamic>>()
              .toList()
            ..sort((a, b) => _employeeName(a).compareTo(_employeeName(b)));

      for (final profile in targetProfiles) {
        final employeeId = _employeeId(profile);
        final matchedDates =
            matchedEmployeeDateKeys[employeeId] ?? const <String>{};
        for (final dateKey in noRecordDates) {
          if (matchedDates.contains(dateKey)) continue;
          recordRows.add([
            dateKey,
            _departmentFor(profile),
            _employeeRole(profile),
            _employeeName(profile),
            employeeId,
            'no_records',
          ]);
        }
      }

      if (recordRows.isEmpty) {
        throw StateError('No attendance records found for this export.');
      }

      recordRows.sort((a, b) {
        final dateCompare = a[0].compareTo(b[0]);
        if (dateCompare != 0) return dateCompare;
        final teamCompare = a[1].compareTo(b[1]);
        if (teamCompare != 0) return teamCompare;
        return a[3].compareTo(b[3]);
      });

      final scopedLabel = _dateRange == null
          ? scopeLabel
          : '${scopeLabel}_${_dateKey(_dateRange!.start)}_to_${_dateKey(_dateRange!.end)}';
      final safeScope = scopedLabel
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
          .replaceAll(RegExp(r'_+'), '_')
          .replaceAll(RegExp(r'^_|_$'), '');
      final fileName =
          'attendance_report_${safeScope}_${DateTime.now().millisecondsSinceEpoch}.csv';
      final csv = [_csvHeader, ...recordRows].map(_csvRow).join('\n');
      final path = await saveCsvFile(fileName, csv);
      if (!mounted) return;
      setState(() => _lastFilePath = path);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Attendance report exported: $path')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('CSV export failed: $error')));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  static const _csvHeader = [
    'DATE',
    'TEAM',
    'EMPLOYEE ROLE',
    'EMPLOYEE NAME',
    'EMPLOYEE ID/CODE',
    'ATTENDANCE',
  ];

  String _csvRow(List<String> values) {
    return values.map((value) => '"${value.replaceAll('"', '""')}"').join(',');
  }

  bool _isDateInRange(String dateKey) {
    final range = _dateRange;
    if (range == null) return true;
    if (dateKey.length != 10) return false;
    final start = _dateKey(range.start);
    final end = _dateKey(range.end);
    return dateKey.compareTo(start) >= 0 && dateKey.compareTo(end) <= 0;
  }

  String _dateKey(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  List<String> _noRecordDateKeys() {
    final range = _dateRange;
    if (range == null) {
      return [_dateKey(DateTime.now())];
    }
    final start = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final end = DateTime(range.end.year, range.end.month, range.end.day);
    final dates = <String>[];
    for (
      var cursor = start;
      !cursor.isAfter(end);
      cursor = cursor.add(const Duration(days: 1))
    ) {
      dates.add(_dateKey(cursor));
    }
    return dates;
  }

  String get _dateRangeLabel {
    final range = _dateRange;
    if (range == null) return 'All dates';
    final start = _dateKey(range.start);
    final end = _dateKey(range.end);
    return start == end ? start : '$start to $end';
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initialRange =
        _dateRange ??
        DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month, now.day),
        );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: initialRange,
      helpText: 'Select attendance export dates',
    );
    if (picked == null || !mounted) return;
    setState(() => _dateRange = picked);
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Export Reports',
      showBackButton: false,
      bottomNavigationBar: const AdminBottomNav(currentIndex: 1),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore.appCollection('employee_profiles').snapshots(),
        builder: (context, snapshot) {
          final grouped = _groupEmployees(snapshot.data?.docs ?? []);
          final departments = grouped.keys.toList()..sort();
          final employeeProfiles = _employeeProfileMap(grouped);
          final selectedCount = _selectedEmployeeIds.length;

          return LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth >= 820
                  ? 390.0
                  : constraints.maxWidth;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Attendance Export',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Export all employees, full teams, selected teams, one employee, or employees selected across multiple teams as CSV for all dates or a custom date range.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: IndustrialColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 18),
                  IndustrialCard(
                    padding: const EdgeInsets.all(14),
                    borderRadius: 8,
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusChip(
                          label: _dateRangeLabel,
                          type: _dateRange == null
                              ? StatusChipType.neutral
                              : StatusChipType.success,
                          icon: Icons.date_range,
                        ),
                        TextButton.icon(
                          onPressed: _isExporting ? null : _pickDateRange,
                          icon: const Icon(Icons.calendar_month),
                          label: const Text('Custom Date'),
                        ),
                        TextButton.icon(
                          onPressed: _isExporting || _dateRange == null
                              ? null
                              : () => setState(() => _dateRange = null),
                          icon: const Icon(Icons.event_busy),
                          label: const Text('All Dates'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: constraints.maxWidth >= 320
                            ? 220
                            : constraints.maxWidth,
                        child: PrimaryActionButton(
                          label: _isExporting ? 'EXPORTING...' : 'EXPORT ALL',
                          icon: Icons.download,
                          isLoading: _isExporting,
                          onPressed: _isExporting
                              ? null
                              : () => _exportAttendanceCsv(
                                  employeeProfiles: employeeProfiles,
                                ),
                        ),
                      ),
                      SizedBox(
                        width: constraints.maxWidth >= 360
                            ? 260
                            : constraints.maxWidth,
                        child: PrimaryActionButton(
                          label: selectedCount == 0
                              ? 'EXPORT SELECTED'
                              : 'EXPORT SELECTED ($selectedCount)',
                          icon: Icons.checklist,
                          isLoading: _isExporting,
                          onPressed: _isExporting || selectedCount == 0
                              ? null
                              : () => _exportAttendanceCsv(
                                  employeeProfiles: employeeProfiles,
                                  employeeIds: _selectedEmployeeIds,
                                  scopeLabel:
                                      'selected_${selectedCount}_employees',
                                ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _isExporting || selectedCount == 0
                            ? null
                            : () => setState(_selectedEmployeeIds.clear),
                        icon: const Icon(Icons.clear),
                        label: const Text('Clear'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final department in departments)
                        SizedBox(
                          width: cardWidth,
                          child: _ExportDepartmentCard(
                            department: department,
                            employees: grouped[department] ?? const [],
                            selectedEmployeeIds: _selectedEmployeeIds,
                            isExporting: _isExporting,
                            onToggleTeam: (selected) {
                              setState(() {
                                final teamIds =
                                    (grouped[department] ?? const [])
                                        .map(_employeeId)
                                        .where((id) => id.trim().isNotEmpty);
                                if (selected == true) {
                                  _selectedEmployeeIds.addAll(teamIds);
                                } else {
                                  _selectedEmployeeIds.removeAll(teamIds);
                                }
                              });
                            },
                            onToggleEmployee: (employee, selected) {
                              final employeeId = _employeeId(employee);
                              setState(() {
                                if (selected == true) {
                                  _selectedEmployeeIds.add(employeeId);
                                } else {
                                  _selectedEmployeeIds.remove(employeeId);
                                }
                              });
                            },
                            onExportTeam: () {
                              final employeeIds =
                                  (grouped[department] ?? const [])
                                      .map(_employeeId)
                                      .toSet();
                              _exportAttendanceCsv(
                                employeeProfiles: employeeProfiles,
                                employeeIds: employeeIds,
                                scopeLabel: department,
                              );
                            },
                            onExportEmployee: (employee) {
                              final employeeId = _employeeId(employee);
                              _exportAttendanceCsv(
                                employeeProfiles: employeeProfiles,
                                employeeIds: {employeeId},
                                scopeLabel: _employeeName(employee),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                  if (_lastFilePath != null) ...[
                    const SizedBox(height: 16),
                    StatusChip(
                      label: _lastFilePath!.startsWith('Downloaded')
                          ? _lastFilePath!
                          : 'Saved to app documents',
                      type: StatusChipType.success,
                      icon: Icons.check_circle,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _lastFilePath!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }

  Map<String, List<Map<String, dynamic>>> _groupEmployees(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final team in OrganizationOptions.teams) {
      grouped[team.toUpperCase()] = [];
    }
    for (final doc in docs) {
      final data = doc.data();
      final department = _departmentFor(data);
      grouped.putIfAbsent(department, () => []);
      grouped[department]!.add({'id': doc.id, ...data});
    }
    return grouped;
  }

  Map<String, Map<String, dynamic>> _employeeProfileMap(
    Map<String, List<Map<String, dynamic>>> grouped,
  ) {
    final employees = <String, Map<String, dynamic>>{};
    for (final teamEmployees in grouped.values) {
      for (final employee in teamEmployees) {
        employees[_employeeId(employee)] = employee;
      }
    }
    return employees;
  }

  String _employeeId(Map<String, dynamic> data) =>
      '${data['employeeId'] ?? data['id'] ?? ''}';

  String _employeeName(Map<String, dynamic> data) {
    final employeeName = (data['employeeName'] as String?)?.trim();
    if (employeeName != null && employeeName.isNotEmpty) return employeeName;
    final first = (data['firstName'] as String?)?.trim() ?? '';
    final last = (data['lastName'] as String?)?.trim() ?? '';
    final fullName = '$first $last'.trim();
    if (fullName.isNotEmpty) return fullName;
    final nickName = (data['nickName'] as String?)?.trim();
    if (nickName != null && nickName.isNotEmpty) return nickName;
    return _employeeId(data);
  }

  String _employeeRole(Map<String, dynamic> data) {
    return ((data['employeeRole'] as String?) ??
            (data['role'] as String?) ??
            '')
        .trim();
  }

  String _departmentFor(Map<String, dynamic> data) {
    final rawDepartment = (data['department'] as String?)?.trim();
    final role =
        ((data['employeeRole'] as String?) ?? (data['role'] as String?) ?? '')
            .trim()
            .toUpperCase();
    if (rawDepartment != null && rawDepartment.isNotEmpty) {
      return rawDepartment.toUpperCase();
    }
    if (role == 'DIRECTOR' || role == 'CEO') return role;
    return 'TECH';
  }
}

class _ExportDepartmentCard extends StatelessWidget {
  const _ExportDepartmentCard({
    required this.department,
    required this.employees,
    required this.selectedEmployeeIds,
    required this.isExporting,
    required this.onToggleTeam,
    required this.onToggleEmployee,
    required this.onExportTeam,
    required this.onExportEmployee,
  });

  final String department;
  final List<Map<String, dynamic>> employees;
  final Set<String> selectedEmployeeIds;
  final bool isExporting;
  final ValueChanged<bool?> onToggleTeam;
  final void Function(Map<String, dynamic> employee, bool? selected)
  onToggleEmployee;
  final VoidCallback onExportTeam;
  final ValueChanged<Map<String, dynamic>> onExportEmployee;

  @override
  Widget build(BuildContext context) {
    final selectedCount = employees
        .where(
          (employee) => selectedEmployeeIds.contains(_employeeId(employee)),
        )
        .length;
    final teamSelected =
        employees.isNotEmpty && selectedCount == employees.length;
    final teamPartiallySelected = selectedCount > 0 && !teamSelected;

    return IndustrialCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: Checkbox(
            value: teamPartiallySelected ? null : teamSelected,
            tristate: true,
            onChanged: employees.isEmpty || isExporting ? null : onToggleTeam,
          ),
          title: Text(
            department,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            selectedCount == 0
                ? '${employees.length} employees'
                : '$selectedCount of ${employees.length} selected',
          ),
          trailing: IconButton(
            tooltip: 'Export team CSV',
            onPressed: employees.isEmpty || isExporting ? null : onExportTeam,
            icon: const Icon(Icons.download, size: 20),
          ),
          children: [
            if (employees.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: StatusChip(
                  label: 'No employees mapped',
                  type: StatusChipType.neutral,
                ),
              )
            else
              for (final employee in employees)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ExportEmployeeRow(
                    employee: employee,
                    selected: selectedEmployeeIds.contains(
                      _employeeId(employee),
                    ),
                    isExporting: isExporting,
                    onSelected: (selected) =>
                        onToggleEmployee(employee, selected),
                    onExport: () => onExportEmployee(employee),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _ExportEmployeeRow extends StatelessWidget {
  const _ExportEmployeeRow({
    required this.employee,
    required this.selected,
    required this.isExporting,
    required this.onSelected,
    required this.onExport,
  });

  final Map<String, dynamic> employee;
  final bool selected;
  final bool isExporting;
  final ValueChanged<bool?> onSelected;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final employeeId = _employeeId(employee);
    final name = _employeeName(employee);
    final role =
        employee['employeeRole'] as String? ??
        employee['role'] as String? ??
        'EMPLOYEE';

    return IndustrialCard(
      padding: const EdgeInsets.all(10),
      borderRadius: 8,
      child: Row(
        children: [
          Checkbox(value: selected, onChanged: isExporting ? null : onSelected),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  'ID: $employeeId | $role',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: isExporting ? null : onExport,
            icon: const Icon(Icons.file_download_outlined, size: 18),
            label: const Text('CSV'),
          ),
        ],
      ),
    );
  }
}

String _employeeId(Map<String, dynamic> data) =>
    '${data['employeeId'] ?? data['id'] ?? ''}';

String _employeeName(Map<String, dynamic> data) {
  final employeeName = (data['employeeName'] as String?)?.trim();
  if (employeeName != null && employeeName.isNotEmpty) return employeeName;
  final first = (data['firstName'] as String?)?.trim() ?? '';
  final last = (data['lastName'] as String?)?.trim() ?? '';
  final fullName = '$first $last'.trim();
  if (fullName.isNotEmpty) return fullName;
  final nickName = (data['nickName'] as String?)?.trim();
  if (nickName != null && nickName.isNotEmpty) return nickName;
  return _employeeId(data);
}

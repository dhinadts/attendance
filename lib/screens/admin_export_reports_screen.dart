import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../constants/organization_options.dart';
import '../theme/industrial_theme.dart';
import '../utils/csv_download_stub.dart'
    if (dart.library.html) '../utils/csv_download_web.dart'
    if (dart.library.io) '../utils/csv_download_io.dart';
import '../widgets/admin_bottom_nav.dart';
import '../widgets/app_shell.dart';
import '../widgets/industrial_card.dart';
import '../widgets/primary_action_button.dart';
import '../widgets/status_chip.dart';

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

  Future<void> _exportAttendanceCsv({
    String? department,
    Set<String>? employeeIds,
    String? employeeName,
  }) async {
    setState(() => _isExporting = true);
    try {
      final attendance = await _firestore.collection('attendance').get();
      final rows = <List<String>>[
        [
          'Employee ID',
          'Employee Name',
          'Team',
          'Date',
          'Status',
          'Attendance Status',
          'Login',
          'Logout',
          'Office Minutes',
          'Break Minutes',
          'Session Status',
        ],
      ];

      for (final doc in attendance.docs) {
        final data = doc.data();
        final employee = data['employee'] as Map<String, dynamic>?;
        final currentEmployeeId = '${data['employeeId'] ?? ''}';
        if (employeeIds != null && !employeeIds.contains(currentEmployeeId)) {
          continue;
        }

        rows.add([
          currentEmployeeId,
          '${data['employeeName'] ?? employee?['employeeName'] ?? ''}',
          '${employee?['department'] ?? data['department'] ?? department ?? ''}',
          '${data['loginDateIst'] ?? ''}',
          '${data['status'] ?? ''}',
          '${data['attendanceStatus'] ?? ''}',
          '${data['loginAtIst'] ?? ''}',
          '${data['logoutAtIst'] ?? ''}',
          '${data['officeMinutes'] ?? ''}',
          '${data['breakMinutes'] ?? ''}',
          '${data['sessionStatus'] ?? ''}',
        ]);
      }

      final safeScope = (employeeName ?? department ?? 'all_employees')
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
          .replaceAll(RegExp(r'_+'), '_')
          .replaceAll(RegExp(r'^_|_$'), '');
      final fileName =
          'attendance_report_${safeScope}_${DateTime.now().millisecondsSinceEpoch}.csv';
      final csv = rows.map(_csvRow).join('\n');
      final path = await saveCsvFile(fileName, csv);
      if (!mounted) return;
      setState(() => _lastFilePath = path);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Attendance report exported: $path')),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  String _csvRow(List<String> values) {
    return values.map((value) => '"${value.replaceAll('"', '""')}"').join(',');
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Export Reports',
      bottomNavigationBar: const AdminBottomNav(currentIndex: 1),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore.collection('employee_profiles').snapshots(),
        builder: (context, snapshot) {
          final grouped = _groupEmployees(snapshot.data?.docs ?? []);
          final departments = grouped.keys.toList()..sort();

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
                    'Export all employees, team-wise reports, or a selected employee attendance report as CSV for Excel.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: IndustrialColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: constraints.maxWidth >= 320
                        ? 260
                        : constraints.maxWidth,
                    child: PrimaryActionButton(
                      label: _isExporting ? 'EXPORTING...' : 'EXPORT ALL CSV',
                      icon: Icons.download,
                      isLoading: _isExporting,
                      onPressed: _isExporting
                          ? null
                          : () => _exportAttendanceCsv(),
                    ),
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
                            isExporting: _isExporting,
                            onExportTeam: () {
                              final employeeIds = (grouped[department] ?? const [])
                                  .map(
                                    (employee) =>
                                        '${employee['employeeId'] ?? employee['id']}',
                                  )
                                  .toSet();
                              _exportAttendanceCsv(
                                department: department,
                                employeeIds: employeeIds,
                              );
                            },
                            onExportEmployee: (employee) {
                              final employeeId =
                                  '${employee['employeeId'] ?? employee['id']}';
                              _exportAttendanceCsv(
                                department: department,
                                employeeIds: {employeeId},
                                employeeName:
                                    employee['employeeName'] as String? ??
                                    employeeId,
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
    required this.isExporting,
    required this.onExportTeam,
    required this.onExportEmployee,
  });

  final String department;
  final List<Map<String, dynamic>> employees;
  final bool isExporting;
  final VoidCallback onExportTeam;
  final ValueChanged<Map<String, dynamic>> onExportEmployee;

  @override
  Widget build(BuildContext context) {
    return IndustrialCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: const CircleAvatar(
            backgroundColor: IndustrialColors.primary,
            foregroundColor: IndustrialColors.onPrimary,
            child: Icon(Icons.table_view, size: 20),
          ),
          title: Text(
            department,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          subtitle: Text('${employees.length} employees'),
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
                    isExporting: isExporting,
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
    required this.isExporting,
    required this.onExport,
  });

  final Map<String, dynamic> employee;
  final bool isExporting;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final employeeId = '${employee['employeeId'] ?? employee['id']}';
    final name = employee['employeeName'] as String? ?? 'Employee';
    final role =
        employee['employeeRole'] as String? ??
        employee['role'] as String? ??
        'EMPLOYEE';

    return IndustrialCard(
      padding: const EdgeInsets.all(10),
      borderRadius: 8,
      child: Row(
        children: [
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

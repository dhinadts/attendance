import '../widgets/app_shell.dart';
import '../widgets/status_chip.dart';
import 'package:flutter/material.dart';
import '../theme/industrial_theme.dart';
import '../services/app_firestore.dart';
import '../widgets/industrial_card.dart';
import 'package:go_router/go_router.dart';
import '../widgets/admin_bottom_nav.dart';
import '../constants/organization_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class AdminAttendanceLogsScreen extends StatelessWidget {
  const AdminAttendanceLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Attendance Logs',
      bottomNavigationBar: const AdminBottomNav(currentIndex: 1),
      showBackButton: false,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .appCollection('employee_profiles')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final grouped = _groupEmployees(snapshot.data?.docs ?? []);
          final departments = grouped.keys.toList()..sort();

          return LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth >= 760
                  ? 360.0
                  : constraints.maxWidth;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Department Attendance',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Open a department, choose an employee, then view today, week, month, year or custom date attendance logs.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: IndustrialColors.onSurfaceVariant,
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
                          child: _DepartmentAttendanceCard(
                            department: department,
                            employees: grouped[department] ?? const [],
                          ),
                        ),
                    ],
                  ),
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

class _DepartmentAttendanceCard extends StatelessWidget {
  const _DepartmentAttendanceCard({
    required this.department,
    required this.employees,
  });

  final String department;
  final List<Map<String, dynamic>> employees;

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
            child: Icon(Icons.groups, size: 20),
          ),
          title: Text(
            department,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          subtitle: Text('${employees.length} employees'),
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
                  child: _EmployeeAttendanceRow(employee: employee),
                ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeAttendanceRow extends StatelessWidget {
  const _EmployeeAttendanceRow({required this.employee});

  final Map<String, dynamic> employee;

  @override
  Widget build(BuildContext context) {
    final employeeId =
        employee['employeeId'] as String? ?? employee['id'] as String;
    final name = employee['employeeName'] as String? ?? 'Employee';
    final role =
        employee['employeeRole'] as String? ??
        employee['role'] as String? ??
        'EMPLOYEE';

    return IndustrialCard(
      padding: const EdgeInsets.all(10),
      borderRadius: 8,
      onTap: () => context.go(
        '/admin-employee-detail?employeeId=${Uri.encodeComponent(employeeId)}&initialTab=1',
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: IndustrialColors.surfaceContainerHigh,
            foregroundColor: IndustrialColors.primary,
            child: Text(name.isEmpty ? 'E' : name[0].toUpperCase()),
          ),
          const SizedBox(width: 10),
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
          const Icon(Icons.calendar_month, color: IndustrialColors.primary),
        ],
      ),
    );
  }
}

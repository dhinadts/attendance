import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/organization_options.dart';
import '../theme/industrial_theme.dart';
import '../widgets/admin_bottom_nav.dart';
import '../widgets/app_shell.dart';
import '../widgets/industrial_card.dart';
import '../widgets/status_chip.dart';
import '../services/app_firestore.dart';

class AdminEmployeesScreen extends StatefulWidget {
  const AdminEmployeesScreen({super.key});

  @override
  State<AdminEmployeesScreen> createState() => _AdminEmployeesScreenState();
}

class _AdminEmployeesScreenState extends State<AdminEmployeesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Employees & Teams',
      bottomNavigationBar: const AdminBottomNav(currentIndex: 1),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore.appCollection('employee_profiles').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading employees: ${snapshot.error}',
                style: const TextStyle(color: IndustrialColors.error),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          final grouped = <String, List<Map<String, dynamic>>>{};

          // Initialize all standard teams to guarantee they exist in the UI
          for (final team in OrganizationOptions.teams) {
            grouped[team.toUpperCase()] = [];
          }

          for (final doc in docs) {
            final data = doc.data();
            final dept = _departmentFor(data);
            if (!grouped.containsKey(dept)) {
              grouped[dept] = [];
            }
            grouped[dept]!.add({'id': doc.id, ...data});
          }

          // Filter out empty teams or show them? Show them but with a "No employees" placeholder, which is super helpful for managers!
          final sortedDepts = grouped.keys.toList()..sort();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedDepts.length,
            itemBuilder: (context, index) {
              final dept = sortedDepts[index];
              final employees = grouped[dept]!;
              final count = employees.length;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(
                      color: IndustrialColors.outlineVariant,
                      width: 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      backgroundColor: IndustrialColors.surfaceContainerLow,
                      collapsedBackgroundColor:
                          IndustrialColors.surfaceContainerLowest,
                      leading: const CircleAvatar(
                        backgroundColor: IndustrialColors.primary,
                        foregroundColor: IndustrialColors.onPrimary,
                        child: Icon(Icons.groups, size: 20),
                      ),
                      title: Text(
                        dept,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      subtitle: Text(
                        '$count ${count == 1 ? "employee" : "employees"}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      childrenPadding: const EdgeInsets.all(12),
                      children: [
                        if (employees.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: StatusChip(
                                label: 'No employees in this team',
                                type: StatusChipType.neutral,
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: employees.length,
                            separatorBuilder: (context, idx) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, idx) {
                              final emp = employees[idx];
                              final empId =
                                  emp['employeeId'] as String? ??
                                  emp['id'] as String;
                              final name =
                                  emp['employeeName'] as String? ?? 'Employee';
                              final role =
                                  emp['employeeRole'] as String? ??
                                  emp['role'] as String? ??
                                  'EMPLOYEE';
                              final initials = name.isNotEmpty
                                  ? name.substring(0, 1).toUpperCase()
                                  : 'E';

                              return IndustrialCard(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                onTap: () => context.go(
                                  '/admin-employee-detail?employeeId=$empId',
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor:
                                          IndustrialColors.primaryContainer,
                                      foregroundColor:
                                          IndustrialColors.onPrimary,
                                      child: Text(
                                        initials,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                            ),
                                          ),
                                          Text(
                                            'ID: $empId | $role',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Attendance Icon Action
                                    IconButton(
                                      tooltip: 'View Attendance Logs',
                                      icon: const Icon(
                                        Icons.calendar_month,
                                        color: IndustrialColors.primary,
                                      ),
                                      onPressed: () => context.go(
                                        '/admin-employee-detail?employeeId=$empId&initialTab=1',
                                      ),
                                    ),
                                    // Detail Arrow Action
                                    const Icon(
                                      Icons.chevron_right,
                                      color: IndustrialColors.outline,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
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

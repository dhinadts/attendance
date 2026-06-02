import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/industrial_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/industrial_card.dart';
import '../widgets/status_chip.dart';

class NotificationTeamScreen extends StatelessWidget {
  const NotificationTeamScreen({super.key, required this.team});

  final String team;

  @override
  Widget build(BuildContext context) {
    final normalizedTeam = team.trim().toUpperCase();
    return AppShell(
      title: normalizedTeam,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('employee_profiles')
            .snapshots(),
        builder: (context, snapshot) {
          final employees =
              (snapshot.data?.docs ?? []).where((doc) {
                final department = (doc.data()['department'] as String?)
                    ?.trim()
                    .toUpperCase();
                return department == normalizedTeam;
              }).toList()..sort((a, b) {
                final aName = _employeeName(a.data());
                final bName = _employeeName(b.data());
                return aName.compareTo(bName);
              });

          if (employees.isEmpty) {
            return const Center(
              child: StatusChip(
                label: 'No employees in this team',
                type: StatusChipType.neutral,
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: employees.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final data = employees[index].data();
              final employeeId =
                  data['employeeId'] as String? ?? employees[index].id;
              final name = _employeeName(data);
              final role = data['role'] as String? ?? 'EMPLOYEE';
              return IndustrialCard(
                onTap: () => context.go(
                  '/admin-notifications/employee?employeeId=${Uri.encodeComponent(employeeId)}',
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: IndustrialColors.primary,
                      foregroundColor: IndustrialColors.onPrimary,
                      child: Text(
                        name.isNotEmpty
                            ? name.characters.first.toUpperCase()
                            : 'E',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.isEmpty ? employeeId : name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$role | Code: $employeeId',
                            style: const TextStyle(
                              color: IndustrialColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: IndustrialColors.onSurfaceVariant,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  static String _employeeName(Map<String, dynamic> data) {
    final explicit = (data['employeeName'] as String?)?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    return '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
  }
}

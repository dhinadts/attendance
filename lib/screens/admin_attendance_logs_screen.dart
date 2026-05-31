import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/industrial_theme.dart';
import '../widgets/admin_bottom_nav.dart';
import '../widgets/app_shell.dart';
import '../widgets/industrial_card.dart';
import '../widgets/status_chip.dart';

class AdminAttendanceLogsScreen extends StatelessWidget {
  const AdminAttendanceLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Attendance Logs',
      bottomNavigationBar: const AdminBottomNav(currentIndex: 1),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('attendance').snapshots(),
        builder: (context, snapshot) {
          final logs = snapshot.data?.docs ?? [];
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final data = logs[index].data();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: IndustrialCard(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person_pin_circle,
                        color: IndustrialColors.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data['employeeName'] as String? ?? 'Employee'),
                            Text(
                              '${data['loginDateIst'] ?? '-'} | ${data['attendanceStatus'] ?? data['status'] ?? '-'}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      StatusChip(
                        label: data['sessionStatus'] as String? ?? 'log',
                        type: data['sessionStatus'] == 'active'
                            ? StatusChipType.success
                            : StatusChipType.neutral,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

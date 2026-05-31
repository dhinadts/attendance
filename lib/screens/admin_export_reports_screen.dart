import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../theme/industrial_theme.dart';
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

  Future<void> _exportAttendanceCsv() async {
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
        ],
      ];

      for (final doc in attendance.docs) {
        final data = doc.data();
        final employee = data['employee'] as Map<String, dynamic>?;
        rows.add([
          '${data['employeeId'] ?? ''}',
          '${data['employeeName'] ?? employee?['employeeName'] ?? ''}',
          '${employee?['department'] ?? data['department'] ?? ''}',
          '${data['loginDateIst'] ?? ''}',
          '${data['status'] ?? ''}',
          '${data['attendanceStatus'] ?? ''}',
          '${data['loginAtIst'] ?? ''}',
          '${data['logoutAtIst'] ?? ''}',
          '${data['officeMinutes'] ?? ''}',
          '${data['breakMinutes'] ?? ''}',
        ]);
      }

      final csv = rows.map(_csvRow).join('\n');
      final dir = await getApplicationDocumentsDirectory();
      final file = File(
        '${dir.path}/attendance_report_${DateTime.now().millisecondsSinceEpoch}.csv',
      );
      await file.writeAsString(csv, flush: true);
      if (!mounted) return;
      setState(() => _lastFilePath = file.path);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Attendance report exported: ${file.path}')),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  String _csvRow(List<String> values) {
    return values
        .map((value) {
          final escaped = value.replaceAll('"', '""');
          return '"$escaped"';
        })
        .join(',');
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Export Reports',
      bottomNavigationBar: const AdminBottomNav(currentIndex: 1),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Attendance Export',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Exports every employee attendance record as a CSV file that opens in Excel.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: IndustrialColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          IndustrialCard(
            highlighted: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.table_view, color: IndustrialColors.primary),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Employee Attendance Excel Export',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                PrimaryActionButton(
                  label: _isExporting ? 'EXPORTING...' : 'EXPORT CSV',
                  icon: Icons.download,
                  isLoading: _isExporting,
                  onPressed: _isExporting ? null : _exportAttendanceCsv,
                ),
              ],
            ),
          ),
          if (_lastFilePath != null) ...[
            const SizedBox(height: 16),
            StatusChip(
              label: 'Saved to app documents',
              type: StatusChipType.success,
              icon: Icons.check_circle,
            ),
            const SizedBox(height: 8),
            Text(_lastFilePath!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

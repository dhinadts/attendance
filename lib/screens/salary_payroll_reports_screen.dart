import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../app/state/app_providers.dart';
import '../theme/industrial_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/employee_bottom_nav.dart';
import '../widgets/industrial_card.dart';
import '../widgets/primary_action_button.dart';
import '../widgets/status_chip.dart';

class SalaryPayrollReportsScreen extends ConsumerWidget {
  const SalaryPayrollReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentEmployeeProfileProvider);
    final selection = ref.watch(salarySlipSelectionProvider);
    final savedPath = ref.watch(salarySlipSavedPathProvider);

    return AppShell(
      title: 'Salary',
      bottomNavigationBar: const EmployeeBottomNav(currentIndex: 4),
      child: profileAsync.when(
        skipLoadingOnRefresh: false,
        skipLoadingOnReload: false,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (profile) {
          final recordsAsync = ref.watch(
            salaryRecordsStreamProvider(profile.employeeId),
          );
          final joiningDate = DateTime.tryParse(profile.joiningDate);
          final yearStart = joiningDate?.year ?? DateTime.now().year - 2;
          final years = [
            for (var year = yearStart; year <= DateTime.now().year; year++)
              year,
          ];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Salary Download',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Download salary slips uploaded by payroll admin.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: IndustrialColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                IndustrialCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: selection.month,
                              decoration: const InputDecoration(
                                labelText: 'Month',
                                prefixIcon: Icon(Icons.calendar_month),
                              ),
                              items: [
                                for (var i = 1; i <= 12; i++)
                                  DropdownMenuItem(
                                    value: i,
                                    child: Text(_monthNames[i - 1]),
                                  ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                ref
                                    .read(salarySlipSelectionProvider.notifier)
                                    .update(selection.copyWith(month: value));
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: selection.year,
                              decoration: const InputDecoration(
                                labelText: 'Year',
                                prefixIcon: Icon(Icons.date_range),
                              ),
                              items: years
                                  .map(
                                    (year) => DropdownMenuItem(
                                      value: year,
                                      child: Text('$year'),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                ref
                                    .read(salarySlipSelectionProvider.notifier)
                                    .update(selection.copyWith(year: value));
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      recordsAsync.when(
                        skipLoadingOnRefresh: false,
                        skipLoadingOnReload: false,
                        loading: () => const LinearProgressIndicator(),
                        error: (error, _) => Text(error.toString()),
                        data: (records) {
                          final record = records
                              .where(
                                (item) =>
                                    item['monthKey'] == selection.monthKey,
                              )
                              .firstOrNull;
                          if (record == null) {
                            return const StatusChip(
                              label:
                                  'Salary slip not uploaded for selected month',
                              type: StatusChipType.pending,
                            );
                          }
                          return _SalaryRecordView(
                            record: record,
                            onDownload: () async {
                              final path = await _downloadSlip(profile, record);
                              ref
                                  .read(salarySlipSavedPathProvider.notifier)
                                  .setPath(path);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Salary slip saved: $path'),
                                  ),
                                );
                              }
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
                if (savedPath != null) ...[
                  const SizedBox(height: 16),
                  const StatusChip(
                    label: 'Saved to app documents',
                    type: StatusChipType.success,
                    icon: Icons.check_circle,
                  ),
                  const SizedBox(height: 8),
                  Text(savedPath, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  static Future<String> _downloadSlip(
    dynamic profile,
    Map<String, dynamic> record,
  ) async {
    final pdfBytes = _simplePdf([
      'dhinadts Salary Slip',
      'Employee: ${profile.employeeName}',
      'Employee ID: ${profile.employeeId}',
      'Department: ${profile.department}',
      'Role: ${profile.role}',
      'Month: ${record['monthKey']}',
      'Payable Days: ${record['payableDays']}',
      'Office Minutes: ${record['officeMinutes']}',
      'Not Considered Days: ${record['notConsideredDays']}',
      'Leave Days: ${record['leaveDays']}',
      'Gross Salary: INR ${record['grossSalary']}',
      'Deductions: INR ${record['deductions']}',
      'Net Salary: INR ${record['netSalary']}',
      'Notes: ${record['notes'] ?? ''}',
    ]);

    final directory = await getApplicationDocumentsDirectory();
    final file = File(
      '${directory.path}/salary_${profile.employeeId}_${record['monthKey']}.pdf',
    );
    await file.writeAsBytes(pdfBytes, flush: true);
    return file.path;
  }

  static List<int> _simplePdf(List<String> lines) {
    final objects = <String>[];
    final escapedLines = lines
        .map(
          (line) => line
              .replaceAll('\\', '\\\\')
              .replaceAll('(', '\\(')
              .replaceAll(')', '\\)'),
        )
        .toList();
    final text = StringBuffer('BT /F1 18 Tf 72 760 Td ');
    for (final line in escapedLines) {
      text.write('($line) Tj 0 -30 Td ');
    }
    text.write('ET');

    objects.add('1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj\n');
    objects.add('2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj\n');
    objects.add(
      '3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >> endobj\n',
    );
    objects.add(
      '4 0 obj << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> endobj\n',
    );
    objects.add(
      '5 0 obj << /Length ${text.length} >> stream\n$text\nendstream endobj\n',
    );

    final buffer = StringBuffer('%PDF-1.4\n');
    final offsets = <int>[0];
    for (final object in objects) {
      offsets.add(utf8.encode(buffer.toString()).length);
      buffer.write(object);
    }
    final xrefOffset = utf8.encode(buffer.toString()).length;
    buffer.write('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n');
    for (final offset in offsets.skip(1)) {
      buffer.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
    }
    buffer.write(
      'trailer << /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n$xrefOffset\n%%EOF',
    );
    return utf8.encode(buffer.toString());
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
}

class _SalaryRecordView extends StatelessWidget {
  const _SalaryRecordView({required this.record, required this.onDownload});

  final Map<String, dynamic> record;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _line('Base Salary', 'INR ${record['baseSalary'] ?? 0}'),
        _line('Payable Days', '${record['payableDays'] ?? 0}'),
        _line('Office Minutes', '${record['officeMinutes'] ?? 0}'),
        _line('Gross Salary', 'INR ${record['grossSalary'] ?? 0}'),
        _line('Deductions', 'INR ${record['deductions'] ?? 0}'),
        _line('Net Salary', 'INR ${record['netSalary'] ?? 0}'),
        const SizedBox(height: 20),
        PrimaryActionButton(
          label: 'DOWNLOAD PDF',
          icon: Icons.download,
          onPressed: onDownload,
        ),
      ],
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

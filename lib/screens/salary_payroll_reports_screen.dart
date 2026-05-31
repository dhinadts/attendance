import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../services/attendance_session_service.dart';
import '../theme/industrial_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/employee_bottom_nav.dart';
import '../widgets/industrial_card.dart';
import '../widgets/primary_action_button.dart';
import '../widgets/status_chip.dart';

class SalaryPayrollReportsScreen extends StatefulWidget {
  const SalaryPayrollReportsScreen({super.key});

  @override
  State<SalaryPayrollReportsScreen> createState() =>
      _SalaryPayrollReportsScreenState();
}

class _SalaryPayrollReportsScreenState
    extends State<SalaryPayrollReportsScreen> {
  final _service = AttendanceSessionService();
  EmployeeProfile? _profile;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  String? _lastFilePath;
  Map<String, dynamic>? _salaryRecord;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await _service.loadEmployeeProfile();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      final joiningYear = DateTime.tryParse(profile.joiningDate)?.year;
      if (joiningYear != null && _selectedYear < joiningYear) {
        _selectedYear = joiningYear;
      }
    });
  }

  Future<void> _downloadSlip() async {
    final profile = _profile;
    if (profile == null) return;

    final record = await _service.generateSalaryRecord(
      year: _selectedYear,
      month: _selectedMonth,
    );
    final monthName = _monthNames[_selectedMonth - 1];
    final pdfBytes = _simplePdf([
      'dhinadts Salary Slip',
      'Employee: ${profile.employeeName}',
      'Employee ID: ${profile.employeeId}',
      'Department: ${profile.department}',
      'Role: ${profile.role}',
      'Month: $monthName $_selectedYear',
      'Payable Days: ${record['payableDays']}',
      'Office Minutes: ${record['officeMinutes']}',
      'Not Considered Days: ${record['notConsideredDays']}',
      'Leave Days: ${record['leaveDays']}',
      'Gross Salary: INR ${record['grossSalary']}',
      'Deductions: INR ${record['deductions']}',
      'Net Salary: INR ${record['netSalary']}',
    ]);

    final directory = await getApplicationDocumentsDirectory();
    final file = File(
      '${directory.path}/salary_${profile.employeeId}_${_selectedYear}_${_selectedMonth.toString().padLeft(2, '0')}.pdf',
    );
    await file.writeAsBytes(pdfBytes, flush: true);

    if (!mounted) return;
    setState(() {
      _lastFilePath = file.path;
      _salaryRecord = record;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Salary slip saved: ${file.path}')));
  }

  @override
  Widget build(BuildContext context) {
    final joiningDate = DateTime.tryParse(_profile?.joiningDate ?? '');
    final yearStart = joiningDate?.year ?? DateTime.now().year - 2;
    final years = [
      for (var year = yearStart; year <= DateTime.now().year; year++) year,
    ];

    return AppShell(
      title: 'Salary',
      bottomNavigationBar: const EmployeeBottomNav(currentIndex: 3),
      child: SingleChildScrollView(
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
              'Generate monthly slips from joining date till selected month',
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
                          initialValue: _selectedMonth,
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
                            setState(() => _selectedMonth = value);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _selectedYear,
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
                            setState(() => _selectedYear = value);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _salaryLine(
                    'Base Salary',
                    'INR ${_salaryRecord?['baseSalary'] ?? AttendanceSessionService.monthlyBaseSalary}',
                  ),
                  _salaryLine(
                    'Payable Days',
                    '${_salaryRecord?['payableDays'] ?? '-'}',
                  ),
                  _salaryLine(
                    'Office Minutes',
                    '${_salaryRecord?['officeMinutes'] ?? '-'}',
                  ),
                  _salaryLine(
                    'Net Salary',
                    _salaryRecord == null
                        ? 'Generate slip'
                        : 'INR ${_salaryRecord!['netSalary']}',
                  ),
                  const SizedBox(height: 20),
                  PrimaryActionButton(
                    label: 'DOWNLOAD PDF',
                    icon: Icons.download,
                    onPressed: _downloadSlip,
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
              Text(
                _lastFilePath!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _salaryLine(String label, String value) {
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

  List<int> _simplePdf(List<String> lines) {
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

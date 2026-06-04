import '../widgets/app_shell.dart';
import '../widgets/status_chip.dart';
import 'package:flutter/material.dart';
import '../theme/industrial_theme.dart';
import '../app/state/app_providers.dart';
import '../widgets/industrial_card.dart';
import '../widgets/admin_bottom_nav.dart';
import '../widgets/primary_action_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


class AdminSalaryScreen extends ConsumerStatefulWidget {
  const AdminSalaryScreen({super.key});

  @override
  ConsumerState<AdminSalaryScreen> createState() => _AdminSalaryScreenState();
}

class _AdminSalaryScreenState extends ConsumerState<AdminSalaryScreen> {
  final _baseController = TextEditingController(text: '24500');
  final _grossController = TextEditingController(text: '24500');
  final _deductionsController = TextEditingController(text: '0');
  final _netController = TextEditingController(text: '24500');
  final _payableDaysController = TextEditingController(text: '26');
  final _officeMinutesController = TextEditingController(text: '0');
  final _leaveDaysController = TextEditingController(text: '0');
  final _notConsideredController = TextEditingController(text: '0');
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _baseController.dispose();
    _grossController.dispose();
    _deductionsController.dispose();
    _netController.dispose();
    _payableDaysController.dispose();
    _officeMinutesController.dispose();
    _leaveDaysController.dispose();
    _notConsideredController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _upload(List<Map<String, dynamic>> employees) async {
    final draft = ref.read(payrollUploadDraftProvider);
    final employee = employees.firstWhere(
      (item) => item['employeeId'] == draft.employeeId,
      orElse: () => const <String, dynamic>{},
    );
    if (employee.isEmpty || draft.year == null || draft.month == null) {
      ref
          .read(payrollUploadStatusProvider.notifier)
          .setMessage('Select employee, month, and year');
      return;
    }

    ref.read(payrollUploadBusyProvider.notifier).setValue(true);
    ref.read(payrollUploadStatusProvider.notifier).setMessage(null);
    try {
      await ref.read(payrollApiServiceProvider).uploadSalaryRecord({
        'employeeId': draft.employeeId,
        'employeeName': employee['employeeName'] ?? '',
        'department': employee['department'] ?? '',
        'role': employee['role'] ?? '',
        'year': draft.year,
        'month': draft.month,
        'baseSalary': _number(_baseController.text),
        'grossSalary': _number(_grossController.text),
        'deductions': _number(_deductionsController.text),
        'netSalary': _number(_netController.text),
        'payableDays': _number(_payableDaysController.text),
        'officeMinutes': _number(_officeMinutesController.text),
        'leaveDays': _number(_leaveDaysController.text),
        'notConsideredDays': _number(_notConsideredController.text),
        'notes': _notesController.text.trim(),
      });
      ref
          .read(payrollUploadStatusProvider.notifier)
          .setMessage('Salary uploaded through payroll API');
    } catch (error) {
      ref
          .read(payrollUploadStatusProvider.notifier)
          .setMessage(error.toString());
    } finally {
      ref.read(payrollUploadBusyProvider.notifier).setValue(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(employeeProfilesStreamProvider);
    final recordsAsync = ref.watch(salaryRecordsStreamProvider(null));

    return AppShell(
      title: 'Payroll Admin',
      showBackButton: false,
      bottomNavigationBar: const AdminBottomNav(currentIndex: 2),
      child: employeesAsync.when(
        skipLoadingOnRefresh: false,
        skipLoadingOnReload: false,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (employees) => LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final uploadPanel = _uploadPanel(employees);
            final recordsPanel = _recordsPanel(recordsAsync);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payroll Upload',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Web admin workflow for uploading employee salary slips through the backend payroll API.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: IndustrialColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 5, child: uploadPanel),
                        const SizedBox(width: 16),
                        Expanded(flex: 4, child: recordsPanel),
                      ],
                    )
                  else
                    Column(
                      children: [
                        uploadPanel,
                        const SizedBox(height: 16),
                        recordsPanel,
                      ],
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _uploadPanel(List<Map<String, dynamic>> employees) {
    final draft = ref.watch(payrollUploadDraftProvider);
    final busy = ref.watch(payrollUploadBusyProvider);
    final status = ref.watch(payrollUploadStatusProvider);
    final months = [for (var index = 1; index <= 12; index++) index];
    final currentYear = DateTime.now().year;
    final years = [
      for (var year = currentYear - 2; year <= currentYear + 1; year++) year,
    ];

    return IndustrialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Upload Salary For Employee',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: draft.employeeId.isEmpty ? null : draft.employeeId,
            decoration: const InputDecoration(
              labelText: 'Employee',
              prefixIcon: Icon(Icons.person_search),
            ),
            items: employees
                .where((employee) => employee['employeeId'] is String)
                .map(
                  (employee) => DropdownMenuItem<String>(
                    value: employee['employeeId'] as String,
                    child: Text(
                      '${employee['employeeName'] ?? employee['firstName'] ?? 'Employee'} (${employee['employeeId'] ?? '-'})',
                    ),
                  ),
                )
                .where((item) => item.value != null)
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              ref
                  .read(payrollUploadDraftProvider.notifier)
                  .update(draft.copyWith(employeeId: value));
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: draft.month,
                  decoration: const InputDecoration(
                    labelText: 'Month',
                    prefixIcon: Icon(Icons.calendar_month),
                  ),
                  items: months
                      .map(
                        (month) => DropdownMenuItem(
                          value: month,
                          child: Text('$month'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    ref
                        .read(payrollUploadDraftProvider.notifier)
                        .update(draft.copyWith(month: value));
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: draft.year,
                  decoration: const InputDecoration(
                    labelText: 'Year',
                    prefixIcon: Icon(Icons.date_range),
                  ),
                  items: years
                      .map(
                        (year) =>
                            DropdownMenuItem(value: year, child: Text('$year')),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    ref
                        .read(payrollUploadDraftProvider.notifier)
                        .update(draft.copyWith(year: value));
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _numberField(_baseController, 'Base Salary'),
              _numberField(_grossController, 'Gross Salary'),
              _numberField(_deductionsController, 'Deductions'),
              _numberField(_netController, 'Net Salary'),
              _numberField(_payableDaysController, 'Payable Days'),
              _numberField(_officeMinutesController, 'Office Minutes'),
              _numberField(_leaveDaysController, 'Leave Days'),
              _numberField(_notConsideredController, 'Not Considered'),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notes',
              prefixIcon: Icon(Icons.notes),
            ),
          ),
          const SizedBox(height: 16),
          PrimaryActionButton(
            label: busy ? 'UPLOADING...' : 'UPLOAD VIA API',
            icon: Icons.cloud_upload,
            isLoading: busy,
            onPressed: busy ? null : () => _upload(employees),
          ),
          if (status != null) ...[
            const SizedBox(height: 12),
            StatusChip(
              label: status,
              type: status.startsWith('Salary uploaded')
                  ? StatusChipType.success
                  : StatusChipType.alert,
            ),
          ],
        ],
      ),
    );
  }

  Widget _recordsPanel(AsyncValue<List<Map<String, dynamic>>> recordsAsync) {
    return IndustrialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Uploaded Salary Records',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 12),
          recordsAsync.when(
            skipLoadingOnRefresh: false,
            skipLoadingOnReload: false,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text(error.toString()),
            data: (records) {
              if (records.isEmpty) {
                return const StatusChip(
                  label: 'No salary records uploaded',
                  type: StatusChipType.neutral,
                );
              }
              return Column(
                children: [
                  for (final record in records.take(12))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _recordTile(record),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _recordTile(Map<String, dynamic> record) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: IndustrialColors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long, color: IndustrialColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${record['employeeName'] ?? 'Employee'} | ${record['monthKey'] ?? '-'}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text('Net Salary: INR ${record['netSalary'] ?? 0}'),
              ],
            ),
          ),
          const StatusChip(label: 'UPLOADED', type: StatusChipType.success),
        ],
      ),
    );
  }

  Widget _numberField(TextEditingController controller, String label) {
    return SizedBox(
      width: 180,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  num _number(String value) => num.tryParse(value.trim()) ?? 0;
}

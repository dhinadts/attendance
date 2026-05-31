import 'package:flutter/material.dart';

import '../theme/industrial_theme.dart';
import '../widgets/admin_bottom_nav.dart';
import '../widgets/app_shell.dart';
import '../widgets/industrial_card.dart';
import '../widgets/status_chip.dart';

class AdminSalaryScreen extends StatelessWidget {
  const AdminSalaryScreen({super.key});

  static const _payroll = [
    ('EMP001', 'Dhinakaran', 'TECH', 'INR 42,000', 'INR 1,500', 'INR 40,500'),
    (
      'EMP002',
      'Employee 2',
      'OPERATIONS',
      'INR 31,000',
      'INR 900',
      'INR 30,100',
    ),
    ('EMP003', 'Priya Singh', 'SALES', 'INR 38,500', 'INR 1,250', 'INR 37,250'),
    (
      'EMP004',
      'Analyst User',
      'ANALYST',
      'INR 35,000',
      'INR 700',
      'INR 34,300',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Payroll Admin',
      bottomNavigationBar: const AdminBottomNav(currentIndex: 2),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Hard-coded Payroll Preview',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Temporary payroll view until API payroll integration is connected.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: IndustrialColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          for (final item in _payroll)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: IndustrialCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.payments,
                          color: IndustrialColors.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.$2,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${item.$1} | ${item.$3}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const StatusChip(
                          label: 'API PENDING',
                          type: StatusChipType.pending,
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    _salaryLine('Gross Salary', item.$4),
                    _salaryLine('Deductions', item.$5),
                    _salaryLine('Net Salary', item.$6, highlight: true),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _salaryLine(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: highlight ? IndustrialColors.secondary : null,
            ),
          ),
        ],
      ),
    );
  }
}

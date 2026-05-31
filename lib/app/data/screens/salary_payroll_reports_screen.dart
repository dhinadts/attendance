import 'package:attendance/theme/industrial_theme.dart';
import 'package:attendance/widgets/app_shell.dart';
import 'package:attendance/widgets/industrial_card.dart';
import 'package:attendance/widgets/primary_action_button.dart';
import 'package:attendance/widgets/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SalaryPayrollReportsScreen extends StatefulWidget {
  const SalaryPayrollReportsScreen({super.key});

  @override
  State<SalaryPayrollReportsScreen> createState() =>
      _SalaryPayrollReportsScreenState();
}

class _SalaryPayrollReportsScreenState
    extends State<SalaryPayrollReportsScreen> {
  final List<Map<String, dynamic>> _staffList = [
    {
      'name': 'Arjun Sharma',
      'role': 'Loom Operator',
      'id': '482',
      'salary': '₹ 24,500',
      'status': 'PAID',
      'statusType': StatusChipType.success,
      'avatar': '👨‍🔧',
    },
    {
      'name': 'Priya Verma',
      'role': 'Inventory Lead',
      'id': '105',
      'salary': '₹ 31,200',
      'status': 'PENDING',
      'statusType': StatusChipType.pending,
      'avatar': '👩‍💼',
    },
    {
      'name': 'Rohan Das',
      'role': 'Maintenance',
      'id': '772',
      'salary': '₹ 18,900',
      'status': 'PAID',
      'statusType': StatusChipType.success,
      'avatar': '👨‍🔧',
    },
    {
      'name': 'Sanya Mehta',
      'role': 'Quality Checker',
      'id': '221',
      'salary': '₹ 22,000',
      'status': 'PAID',
      'statusType': StatusChipType.success,
      'avatar': '👩‍🔬',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return AppShell(
      showAppBar: true,
      title: 'WorkSync Pro',
      bottomNavigationBar: _buildBottomNav(),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Month Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payroll Report',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: IndustrialColors.onSurface,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'DhinaDTS IT Solutions and Support (OPC) Private Limited.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 14,
                          color: IndustrialColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: IndustrialColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: IndustrialColors.outline,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'October 2023',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                fontSize: 13,
                                color: IndustrialColors.primary,
                              ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.keyboard_arrow_down,
                          color: IndustrialColors.primary,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Total Salary Payout Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: IndustrialColors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: IndustrialColors.primary, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: IndustrialColors.primary.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -20,
                      bottom: -20,
                      child: Opacity(
                        opacity: 0.1,
                        child: Icon(
                          Icons.receipt_long,
                          size: 120,
                          color: IndustrialColors.onPrimary,
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Salary Payout',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    fontSize: 13,
                                    color: IndustrialColors.onPrimary
                                        .withValues(alpha: 0.9),
                                  ),
                            ),
                            Icon(
                              Icons.payments,
                              color: IndustrialColors.onPrimary.withValues(
                                alpha: 0.8,
                              ),
                              size: 22,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '₹ 12,45,800',
                          style: Theme.of(context).textTheme.headlineLarge
                              ?.copyWith(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: IndustrialColors.onPrimary,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '142 Employees',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontSize: 14,
                                color: IndustrialColors.onPrimary.withValues(
                                  alpha: 0.8,
                                ),
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Stats Cards Grid
              Row(
                children: [
                  Expanded(
                    child: IndustrialCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.history,
                                size: 16,
                                color: IndustrialColors.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Overtime',
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      fontSize: 11,
                                      color: IndustrialColors.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '842 Hrs',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: IndustrialColors.onSurface,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '+12% vs last month',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontSize: 11,
                                  color: IndustrialColors.secondary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: IndustrialCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.account_balance_wallet,
                                size: 16,
                                color: IndustrialColors.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Deductions',
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      fontSize: 11,
                                      color: IndustrialColors.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '₹ 42,300',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: IndustrialColors.tertiary,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Advance Repayments',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontSize: 11,
                                  color: IndustrialColors.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: PrimaryActionButton(
                      label: 'Export PDF',
                      icon: Icons.picture_as_pdf,
                      onPressed: () {},
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: IndustrialColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: IndustrialColors.outlineVariant,
                        width: 1,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {},
                        child: Icon(
                          Icons.share,
                          color: IndustrialColors.onSurfaceVariant,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Staff Breakdown
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Staff Breakdown',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Sort by: Status',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      color: IndustrialColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Column(
                children: _staffList
                    .map(
                      (staff) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: IndustrialCard(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: IndustrialColors.surfaceContainer,
                                  border: Border.all(
                                    color: IndustrialColors.outlineVariant,
                                    width: 1,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    staff['avatar'],
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      staff['name'],
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: IndustrialColors.onSurface,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${staff['role']} • ID: ${staff['id']}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            fontSize: 12,
                                            color: IndustrialColors
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    staff['salary'],
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: IndustrialColors.onSurface,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  StatusChip(
                                    label: staff['status'],
                                    type: staff['statusType'],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: IndustrialColors.surface,
        border: Border(
          top: BorderSide(color: IndustrialColors.outlineVariant, width: 1),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: 2,
        onTap: (index) {
          switch (index) {
            case 0:
              context.go('/dashboard');
              break;
            case 1:
              context.go('/attendance');
              break;
            case 2:
              context.go('/salary');
              break;
            case 3:
              context.go('/settings');
              break;
          }
        },
        backgroundColor: IndustrialColors.surface,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: Icon(
              Icons.dashboard,
              color: IndustrialColors.onSurfaceVariant,
            ),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.location_on,
              color: IndustrialColors.onSurfaceVariant,
            ),
            label: 'Attendance',
          ),
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: IndustrialColors.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.payments,
                color: IndustrialColors.onSecondaryContainer,
                size: 20,
              ),
            ),
            label: 'Salary',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.settings,
              color: IndustrialColors.onSurfaceVariant,
            ),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

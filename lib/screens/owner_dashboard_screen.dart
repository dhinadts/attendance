import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/industrial_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/admin_bottom_nav.dart';
import '../widgets/industrial_card.dart';
import '../widgets/status_chip.dart';
import '../widgets/section_header.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  final List<Map<String, dynamic>> _recentActivity = [
    {
      'description': 'Dhinakaran done the task 1 within time',
      'status': 'ACHIEVEMENT',
      'statusType': StatusChipType.success,
      'icon': Icons.emoji_events,
    },
    {
      'description':
          'Employee 2 done the risky customer handling smoothly today, good response got from customer',
      'status': 'ACHIEVEMENT',
      'statusType': StatusChipType.success,
      'icon': Icons.star,
    },
    {
      'description': 'Priya Singh onboarded 3 new clients today',
      'status': 'ACHIEVEMENT',
      'statusType': StatusChipType.success,
      'icon': Icons.business_center,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return AppShell(
      showAppBar: true,
      title: 'WorkSync Pro',
      floatingActionButton: FloatingActionButton(
        backgroundColor: IndustrialColors.primary,
        onPressed: () {},
        child: Icon(Icons.add, color: IndustrialColors.onPrimary, size: 28),
      ),
      bottomNavigationBar: const AdminBottomNav(currentIndex: 0),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Section
              Text(
                'MONDAY, OCT 23',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: 12,
                  color: IndustrialColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Admin Portal',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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
              const SizedBox(height: 24),

              // Today's Summary Card
              IndustrialCard(
                padding: const EdgeInsets.all(16),
                highlighted: true,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Today's Summary",
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        Icon(
                          Icons.info_outline,
                          color: IndustrialColors.onSurfaceVariant,
                          size: 18,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Stats Grid
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: IndustrialColors.surfaceContainer,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: IndustrialColors.outlineVariant,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '18/22',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                        color: IndustrialColors.secondary,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'PRESENT',
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        fontSize: 11,
                                        color:
                                            IndustrialColors.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: IndustrialColors.surfaceContainer,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: IndustrialColors.outlineVariant,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '2',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                        color: IndustrialColors.tertiary,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'LEAVE',
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        fontSize: 11,
                                        color:
                                            IndustrialColors.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: IndustrialColors.surfaceContainer,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: IndustrialColors.outlineVariant,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '2',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                        color: IndustrialColors.error,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'LATE',
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        fontSize: 11,
                                        color:
                                            IndustrialColors.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(color: IndustrialColors.outlineVariant, height: 1),
                    const SizedBox(height: 16),
                    // Productivity
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Overall Productivity',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          '82%',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: IndustrialColors.secondary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: 0.82,
                        minHeight: 8,
                        backgroundColor: IndustrialColors.surfaceVariant,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          IndustrialColors.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Quick Actions
              SectionHeader(title: 'Quick Actions'),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildActionButton(
                    context,
                    'Mark Attendance',
                    Icons.how_to_reg,
                    IndustrialColors.primaryContainer,
                    IndustrialColors.onPrimary,
                    () => context.go('/admin-mark-attendance'),
                  ),
                  _buildActionButton(
                    context,
                    'View Payroll',
                    Icons.payments,
                    IndustrialColors.surfaceContainerHigh,
                    IndustrialColors.primary,
                    () => context.go('/admin-salary'),
                  ),
                  _buildActionButton(
                    context,
                    'Approve Leaves',
                    Icons.event_available,
                    IndustrialColors.surfaceContainerHigh,
                    IndustrialColors.primary,
                    () => context.go('/admin-leave-requests'),
                  ),
                  _buildActionButton(
                    context,
                    'Export Reports',
                    Icons.ios_share,
                    IndustrialColors.surfaceContainerHigh,
                    IndustrialColors.primary,
                    () => context.go('/admin-export-reports'),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Recent Activity
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Activity',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: Text(
                      'VIEW ALL',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontSize: 12,
                        color: IndustrialColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Column(
                children: _recentActivity
                    .map(
                      (activity) => Padding(
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
                                child: Icon(
                                  activity['icon'] as IconData,
                                  color: IndustrialColors.primary,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.emoji_events,
                                          size: 14,
                                          color: IndustrialColors.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            activity['description'] as String,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color: IndustrialColors
                                                      .onSurface,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              StatusChip(
                                label: activity['status'],
                                type: activity['statusType'],
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

  Widget _buildActionButton(
    BuildContext context,
    String label,
    IconData icon,
    Color bgColor,
    Color iconColor,
    VoidCallback onTap,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: bgColor == IndustrialColors.surfaceContainerHigh
              ? IndustrialColors.outlineVariant
              : IndustrialColors.primary,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: iconColor),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: 12,
                  color: bgColor == IndustrialColors.primaryContainer
                      ? IndustrialColors.onPrimary
                      : IndustrialColors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

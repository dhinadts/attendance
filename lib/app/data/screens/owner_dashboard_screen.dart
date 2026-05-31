import 'package:attendance/theme/industrial_theme.dart';
import 'package:attendance/widgets/app_shell.dart';
import 'package:attendance/widgets/industrial_card.dart';
import 'package:attendance/widgets/section_header.dart';
import 'package:attendance/widgets/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  final List<Map<String, dynamic>> _recentActivity = [
    {
      'name': 'Rajesh Kumar',
      'time': 'Checked in at 08:45 AM',
      'status': 'ON TIME',
      'statusType': StatusChipType.success,
      'avatar': '👨‍💼',
    },
    {
      'name': 'Priya Singh',
      'time': 'Checked in at 09:12 AM',
      'status': 'LATE',
      'statusType': StatusChipType.alert,
      'avatar': '👩‍💼',
    },
    {
      'name': 'Anil Verma',
      'time': 'Checked in at 08:58 AM',
      'status': 'ON TIME',
      'statusType': StatusChipType.success,
      'avatar': '👨‍💻',
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
      bottomNavigationBar: _buildBottomNav(),
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
                  ),
                  _buildActionButton(
                    context,
                    'View Payroll',
                    Icons.payments,
                    IndustrialColors.surfaceContainerHigh,
                    IndustrialColors.primary,
                  ),
                  _buildActionButton(
                    context,
                    'Approve Leaves',
                    Icons.event_available,
                    IndustrialColors.surfaceContainerHigh,
                    IndustrialColors.primary,
                  ),
                  _buildActionButton(
                    context,
                    'Export Reports',
                    Icons.ios_share,
                    IndustrialColors.surfaceContainerHigh,
                    IndustrialColors.primary,
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
                                child: Center(
                                  child: Text(
                                    activity['avatar'],
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
                                      activity['name'],
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.schedule,
                                          size: 14,
                                          color:
                                              IndustrialColors.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          activity['time'],
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
          onTap: () {},
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

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: IndustrialColors.surface,
        border: Border(
          top: BorderSide(color: IndustrialColors.outlineVariant, width: 1),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: 0,
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
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: IndustrialColors.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.dashboard,
                color: IndustrialColors.onSecondaryContainer,
                size: 20,
              ),
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
            icon: Icon(
              Icons.payments,
              color: IndustrialColors.onSurfaceVariant,
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

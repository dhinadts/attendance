import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/industrial_theme.dart';
import '../widgets/admin_bottom_nav.dart';
import '../widgets/app_shell.dart';
import '../widgets/industrial_card.dart';
import '../widgets/section_header.dart';
import '../widgets/status_chip.dart';

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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          final cardWidth = isWide ? 176.0 : _mobileCardWidth(context);
          final activityWidth = isWide
              ? 380.0
              : constraints.maxWidth.clamp(280.0, 640.0);
          final pagePadding = isWide
              ? const EdgeInsets.fromLTRB(28, 24, 28, 32)
              : const EdgeInsets.symmetric(horizontal: 16, vertical: 16);

          return SingleChildScrollView(
            child: Padding(
              padding: pagePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  _buildSummaryCard(context, isWide: isWide),
                  const SizedBox(height: 24),
                  SectionHeader(title: 'Quick Actions'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildActionButton(
                        context,
                        'Mark Attendance',
                        Icons.how_to_reg,
                        IndustrialColors.primaryContainer,
                        IndustrialColors.onPrimary,
                        () => context.go('/admin-mark-attendance'),
                        width: cardWidth,
                      ),
                      _buildActionButton(
                        context,
                        'View Payroll',
                        Icons.payments,
                        IndustrialColors.surfaceContainerHigh,
                        IndustrialColors.primary,
                        () => context.go('/admin-salary'),
                        width: cardWidth,
                      ),
                      _buildActionButton(
                        context,
                        'Approve Leaves',
                        Icons.event_available,
                        IndustrialColors.surfaceContainerHigh,
                        IndustrialColors.primary,
                        () => context.go('/admin-leave-requests'),
                        width: cardWidth,
                      ),
                      _buildActionButton(
                        context,
                        'Export Reports',
                        Icons.ios_share,
                        IndustrialColors.surfaceContainerHigh,
                        IndustrialColors.primary,
                        () => context.go('/admin-export-reports'),
                        width: cardWidth,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Activity',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      Text(
                        'VIEW ALL',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontSize: 12,
                          color: IndustrialColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _recentActivity
                        .map(
                          (activity) => SizedBox(
                            width: activityWidth,
                            child: _buildActivityCard(context, activity),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, {required bool isWide}) {
    final metricWidth = isWide ? 150.0 : _mobileCardWidth(context);

    return IndustrialCard(
      padding: EdgeInsets.all(isWide ? 18 : 16),
      highlighted: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Today's Summary",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
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
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildMetricCard(
                context,
                value: '18/22',
                label: 'PRESENT',
                color: IndustrialColors.secondary,
                width: metricWidth,
              ),
              _buildMetricCard(
                context,
                value: '2',
                label: 'LEAVE',
                color: IndustrialColors.tertiary,
                width: metricWidth,
              ),
              _buildMetricCard(
                context,
                value: '2',
                label: 'LATE',
                color: IndustrialColors.error,
                width: metricWidth,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: IndustrialColors.outlineVariant, height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Overall Productivity',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                '82%',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String value,
    required String label,
    required Color color,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: Container(
        height: 84,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: IndustrialColors.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: IndustrialColors.outlineVariant, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: 11,
                color: IndustrialColors.onSurfaceVariant,
              ),
            ),
          ],
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
    VoidCallback onTap, {
    required double width,
  }) {
    return SizedBox(
      width: width,
      height: 104,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
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
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 26, color: iconColor),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
        ),
      ),
    );
  }

  Widget _buildActivityCard(
    BuildContext context,
    Map<String, dynamic> activity,
  ) {
    return IndustrialCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
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
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              activity['description'] as String,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: IndustrialColors.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 12),
          StatusChip(label: activity['status'], type: activity['statusType']),
        ],
      ),
    );
  }

  double _mobileCardWidth(BuildContext context) {
    final availableWidth = MediaQuery.sizeOf(context).width - 44;
    if (availableWidth < 340) return availableWidth;
    return (availableWidth - 12) / 2;
  }
}

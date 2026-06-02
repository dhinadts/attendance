import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/app_firestore.dart';
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
  final _firestore = FirebaseFirestore.instance;

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
          final cardWidth = isWide ? 150.0 : _mobileCardWidth(context);
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
                  const SizedBox(height: 20),
                  SectionHeader(title: 'Quick Actions'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
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
                        'Payroll',
                        Icons.payments,
                        IndustrialColors.surfaceContainerHigh,
                        IndustrialColors.primary,
                        () => context.go('/admin-salary'),
                        width: cardWidth,
                      ),
                      _buildActionButton(
                        context,
                        'Leaves',
                        Icons.event_available,
                        IndustrialColors.surfaceContainerHigh,
                        IndustrialColors.primary,
                        () => context.go('/admin-leave-requests'),
                        width: cardWidth,
                      ),
                      _buildActionButton(
                        context,
                        'Tasks',
                        Icons.task_alt,
                        IndustrialColors.surfaceContainerHigh,
                        IndustrialColors.primary,
                        () => context.go('/admin-tasks'),
                        width: cardWidth,
                      ),
                      _buildActionButton(
                        context,
                        'Push',
                        Icons.notifications,
                        IndustrialColors.surfaceContainerHigh,
                        IndustrialColors.primary,
                        () => context.go('/admin-notifications'),
                        width: cardWidth,
                      ),
                      _buildActionButton(
                        context,
                        'Reports',
                        Icons.ios_share,
                        IndustrialColors.surfaceContainerHigh,
                        IndustrialColors.primary,
                        () => context.go('/admin-export-reports'),
                        width: cardWidth,
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  _buildRecentActivitySection(context),
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
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  context,
                  value: '18/22',
                  label: 'PRESENT',
                  color: IndustrialColors.secondary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricCard(
                  context,
                  value: '2',
                  label: 'LEAVE',
                  color: IndustrialColors.tertiary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricCard(
                  context,
                  value: '2',
                  label: 'LATE',
                  color: IndustrialColors.error,
                ),
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
  }) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
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
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontSize: 10,
              color: IndustrialColors.onSurfaceVariant,
            ),
          ),
        ],
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
      height: 78,
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
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 22, color: iconColor),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontSize: 11,
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

  Widget _buildRecentActivitySection(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore.appCollection('leave_requests').snapshots(),
      builder: (context, leaveSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _firestore.appCollection('team_messages').snapshots(),
          builder: (context, messageSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firestore.appCollection('tasks').snapshots(),
              builder: (context, taskSnapshot) {
                final activities = <Map<String, dynamic>>[];
                activities.addAll(
                  (leaveSnapshot.data?.docs ?? []).map((doc) {
                    final data = doc.data();
                    final status = (data['status'] ?? 'requested_leave')
                        .toString()
                        .replaceAll('_', ' ');
                    return {
                      'description':
                          '${data['employeeName'] ?? 'Employee'} leave request for ${data['date'] ?? '-'} is $status',
                      'status': 'LEAVE',
                      'statusType': status.contains('approved')
                          ? StatusChipType.success
                          : (status.contains('rejected')
                                ? StatusChipType.alert
                                : StatusChipType.pending),
                      'icon': Icons.event_available,
                      'sort':
                          (data['decisionAtIst'] ??
                                  data['requestedAtIst'] ??
                                  data['date'] ??
                                  '')
                              .toString(),
                    };
                  }),
                );
                activities.addAll(
                  (messageSnapshot.data?.docs ?? []).map((doc) {
                    final data = doc.data();
                    return {
                      'description':
                          '${data['title'] ?? 'Push notification'} - ${data['body'] ?? ''}',
                      'status': 'PUSH',
                      'statusType': StatusChipType.neutral,
                      'icon': Icons.notifications_active,
                      'sort': (data['createdAtIst'] ?? '').toString(),
                    };
                  }),
                );
                activities.addAll(
                  (taskSnapshot.data?.docs ?? [])
                      .where((doc) {
                        final data = doc.data();
                        return (data['latestAchievement'] ?? '')
                                .toString()
                                .trim()
                                .isNotEmpty ||
                            (data['latestFeedback'] ?? '')
                                .toString()
                                .trim()
                                .isNotEmpty;
                      })
                      .map((doc) {
                        final data = doc.data();
                        return {
                          'description':
                              '${data['assignedToName'] ?? 'Employee'}: ${data['latestAchievement'] ?? data['latestFeedback']}',
                          'status': 'SCRUM',
                          'statusType': StatusChipType.success,
                          'icon': Icons.emoji_events,
                          'sort':
                              (data['feedbackAtIst'] ??
                                      data['updatedAtIst'] ??
                                      '')
                                  .toString(),
                        };
                      }),
                );
                activities.sort(
                  (a, b) =>
                      (b['sort'] as String).compareTo(a['sort'] as String),
                );
                final visible = activities.take(8).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                        TextButton(
                          onPressed: () => context.go('/admin-tasks'),
                          child: const Text('TASKS'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (visible.isEmpty)
                      const StatusChip(
                        label: 'No recent activity',
                        type: StatusChipType.neutral,
                      )
                    else
                      ...visible.map(
                        (activity) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildActivityCard(context, activity),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  double _mobileCardWidth(BuildContext context) {
    final availableWidth = MediaQuery.sizeOf(context).width - 44;
    if (availableWidth < 340) return availableWidth;
    return (availableWidth - 20) / 3;
  }
}

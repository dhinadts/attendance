import 'package:attendance/theme/industrial_theme.dart';
import 'package:attendance/widgets/industrial_card.dart';
import 'package:attendance/widgets/primary_action_button.dart';
import 'package:attendance/widgets/stat_card.dart';
import 'package:attendance/widgets/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../widgets/app_shell.dart';

class AttendanceGpsTrackingScreen extends StatefulWidget {
  const AttendanceGpsTrackingScreen({super.key});

  @override
  State<AttendanceGpsTrackingScreen> createState() =>
      _AttendanceGpsTrackingScreenState();
}

class _AttendanceGpsTrackingScreenState
    extends State<AttendanceGpsTrackingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String get _currentTime {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';
  }

  String get _currentDate {
    final now = DateTime.now();
    final days = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];
    final months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return '${days[now.weekday % 7]}, ${months[now.month - 1]} ${now.day}, ${now.year}';
  }

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
              // Time Section
              Text(
                _currentDate.toUpperCase(),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: 12,
                  color: IndustrialColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _currentTime,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                  color: IndustrialColors.onSurface,
                ),
              ),
              const SizedBox(height: 24),

              // Map & GPS Card
              IndustrialCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    // Map placeholder
                    Container(
                      width: double.infinity,
                      height: 160,
                      decoration: BoxDecoration(
                        color: IndustrialColors.surfaceDim,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.map,
                            size: 64,
                            color: IndustrialColors.primary.withValues(
                              alpha: 0.3,
                            ),
                          ),
                          // GPS Pulse
                          ScaleTransition(
                            scale: Tween<double>(
                              begin: 1.0,
                              end: 1.3,
                            ).animate(_pulseController),
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: IndustrialColors.primary.withValues(
                                    alpha: 0.5,
                                  ),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: IndustrialColors.primary,
                              boxShadow: [
                                BoxShadow(
                                  color: IndustrialColors.primary.withValues(
                                    alpha: 0.4,
                                  ),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      size: 18,
                                      color: IndustrialColors.secondary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Precision Textiles Hub',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            fontSize: 13,
                                            color: IndustrialColors.onSurface,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Industrial Sector 4, Wing B',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        fontSize: 12,
                                        color:
                                            IndustrialColors.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusChip(
                            label: 'Verified',
                            type: StatusChipType.success,
                            icon: Icons.check_circle,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Check In / Out Buttons
              PrimaryActionButton(
                label: 'FACE CHECK IN',
                icon: Icons.face,
                style: ActionButtonStyle.secondary,
                onPressed: () => context.go('/login'),
              ),
              const SizedBox(height: 12),
              PrimaryActionButton(
                label: 'CHECK OUT',
                icon: Icons.logout,
                style: ActionButtonStyle.outline,
                onPressed: () {},
              ),
              const SizedBox(height: 20),

              // Shift Summary Card
              IndustrialCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.assessment,
                              color: IndustrialColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Shift Summary',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
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
                          child: StatCard(
                            label: 'Hours Worked',
                            value: '06:42',
                            icon: Icons.schedule,
                            valueColor: IndustrialColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatCard(
                            label: 'Est. Overtime',
                            value: '+01:12',
                            icon: Icons.access_time,
                            valueColor: IndustrialColors.secondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(color: IndustrialColors.outlineVariant, height: 16),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: IndustrialColors.secondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Shift Status: ',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: IndustrialColors.onSurfaceVariant,
                                  ),
                            ),
                            Text(
                              'Active',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: IndustrialColors.onSurface,
                                  ),
                            ),
                          ],
                        ),
                        Text(
                          'Target: 08:00',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: IndustrialColors.primary,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
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
        currentIndex: 1,
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
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: IndustrialColors.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.location_on,
                color: IndustrialColors.onSecondaryContainer,
                size: 20,
              ),
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

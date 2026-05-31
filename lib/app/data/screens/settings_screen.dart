import 'package:attendance/theme/industrial_theme.dart';
import 'package:attendance/widgets/app_shell.dart';
import 'package:attendance/widgets/industrial_card.dart';
import 'package:attendance/widgets/primary_action_button.dart';
import 'package:attendance/widgets/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _templates = [
    {
      'title': 'Attendance Logs',
      'collection': 'attendance',
      'fields': 'employeeId, employeeName, loginAtIst, logoutAtIst, status',
      'icon': Icons.fact_check,
    },
    {
      'title': 'Geofence Exceptions',
      'collection': 'attendance',
      'fields': 'reason, distanceMeters, loginDateIst, device.deviceId',
      'icon': Icons.location_off,
    },
    {
      'title': 'Device Audit',
      'collection': 'attendance',
      'fields': 'deviceId, deviceName, platform, method',
      'icon': Icons.devices,
    },
    {
      'title': 'Salary Inputs',
      'collection': 'payroll_templates',
      'fields': 'employeeId, totalMinutes, overtime, deductions',
      'icon': Icons.payments,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Settings',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Employer Settings',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            StatusChip(
              label: 'Android MVP configuration',
              type: StatusChipType.neutral,
              icon: Icons.tune,
            ),
            const SizedBox(height: 20),
            IndustrialCard(
              child: Column(
                children: [
                  _buildSettingRow(
                    context,
                    icon: Icons.face,
                    title: 'Daily face authentication',
                    value: 'Required',
                  ),
                  const Divider(height: 24),
                  _buildSettingRow(
                    context,
                    icon: Icons.radio_button_checked,
                    title: 'Login zone radius',
                    value: '10 meters',
                  ),
                  const Divider(height: 24),
                  _buildSettingRow(
                    context,
                    icon: Icons.timer,
                    title: 'Auto logout cap',
                    value: '9 hours',
                  ),
                  const Divider(height: 24),
                  _buildSettingRow(
                    context,
                    icon: Icons.visibility,
                    title: 'Face login mode',
                    value: 'Foreground only',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Employer Log Templates',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ..._templates.map(
              (template) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: IndustrialCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        template['icon'] as IconData,
                        color: IndustrialColors.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              template['title'] as String,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Collection: ${template['collection']}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: IndustrialColors.onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              template['fields'] as String,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            PrimaryActionButton(
              label: 'EDIT EMPLOYEE PROFILE',
              icon: Icons.person,
              style: ActionButtonStyle.outline,
              onPressed: () => context.go('/profile'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: IndustrialColors.primary, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: IndustrialColors.primary),
        ),
      ],
    );
  }
}

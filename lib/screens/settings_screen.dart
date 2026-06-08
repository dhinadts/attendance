import '../widgets/app_shell.dart';
import '../widgets/status_chip.dart';
import 'package:flutter/material.dart';
import '../theme/industrial_theme.dart';
import '../theme/theme_controller.dart';
import '../widgets/industrial_card.dart';
import 'package:go_router/go_router.dart';
import '../widgets/admin_bottom_nav.dart';
import '../widgets/primary_action_button.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/attendance_session_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _service = AttendanceSessionService();

  Future<void> _clearCache() async {
    await _service.clearLocalCache();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Local cache cleared')));
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final isAdmin = path.startsWith('/admin');
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 700;

    return AppShell(
      title: 'Settings',
      showBackButton: false,
      bottomNavigationBar: isAdmin
          ? const AdminBottomNav(currentIndex: 4)
          : null,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSaaSStatusCard(isMobile: isMobile),
            SizedBox(height: isMobile ? 16 : 24),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 700) {
                  return Column(
                    children: [
                      _buildSettingCard(
                        title: 'Appearance',
                        subtitle: 'Toggle light / dark mode',
                        icon: Icons.dark_mode,
                        onPressed: _toggleTheme,
                        buttonLabel: 'CHANGE THEME',
                        compact: true,
                      ),
                      const SizedBox(height: 12),
                      _buildSettingCard(
                        title: 'Local Storage',
                        subtitle: 'Clear local profile/session cache',
                        icon: Icons.cleaning_services,
                        onPressed: _clearCache,
                        buttonLabel: 'CLEAR CACHE',
                        compact: true,
                      ),
                      const SizedBox(height: 12),
                      _buildSettingCard(
                        title: 'Session',
                        subtitle: 'Logout from this device',
                        icon: Icons.logout,
                        onPressed: _logout,
                        buttonLabel: 'LOGOUT',
                        buttonStyle: ActionButtonStyle.tertiary,
                        compact: true,
                      ),
                    ],
                  );
                }

                final crossAxisCount = constraints.maxWidth >= 800 ? 3 : 1;
                final desiredSettingHeight =
                    MediaQuery.of(context).size.height * 0.35;
                final itemWidth =
                    (constraints.maxWidth - (crossAxisCount - 1) * 20) /
                    crossAxisCount;
                final childAspect = itemWidth / desiredSettingHeight;
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                  childAspectRatio: childAspect,
                  children: [
                    SizedBox(
                      height: desiredSettingHeight,
                      child: _buildSettingCard(
                        title: 'Appearance',
                        subtitle: 'Toggle light / dark mode',
                        icon: Icons.dark_mode,
                        onPressed: _toggleTheme,
                        buttonLabel: 'CHANGE THEME',
                      ),
                    ),
                    SizedBox(
                      height: desiredSettingHeight,
                      child: _buildSettingCard(
                        title: 'Local Storage',
                        subtitle: 'Clear local profile/session cache',
                        icon: Icons.cleaning_services,
                        onPressed: _clearCache,
                        buttonLabel: 'CLEAR CACHE',
                      ),
                    ),
                    SizedBox(
                      height: desiredSettingHeight,
                      child: _buildSettingCard(
                        title: 'Session',
                        subtitle: 'Logout from this device',
                        icon: Icons.logout,
                        onPressed: _logout,
                        buttonLabel: 'LOGOUT',
                        buttonStyle: ActionButtonStyle.tertiary,
                      ),
                    ),
                  ],
                );
              },
            ),
            SizedBox(height: isMobile ? 20 : 32),
            _buildSaaSFooter(),
          ],
        ),
      ),
    );
  }

  void _toggleTheme() {
    themeModeNotifier.value = themeModeNotifier.value == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
  }

  Widget _buildSaaSStatusCard({required bool isMobile}) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            IndustrialColors.primary.withValues(alpha: 0.1),
            IndustrialColors.primary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: IndustrialColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _statusIcon(),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'SaaS Plan: Enterprise',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const StatusChip(
                      label: 'Active',
                      type: StatusChipType.success,
                      icon: Icons.check_circle,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Active subscription - DhinaDTS Cloud Platform',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: IndustrialColors.onSurfaceVariant,
                  ),
                ),
              ],
            )
          : Row(
              children: [
                _statusIcon(),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SaaS Plan: Enterprise',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Active subscription - DhinaDTS Cloud Platform',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: IndustrialColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const StatusChip(
                  label: 'Active',
                  type: StatusChipType.success,
                  icon: Icons.check_circle,
                ),
              ],
            ),
    );
  }

  Widget _statusIcon() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: IndustrialColors.primary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.cloud_queue,
        color: IndustrialColors.primary,
        size: 32,
      ),
    );
  }

  Widget _buildSettingCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onPressed,
    required String buttonLabel,
    ActionButtonStyle buttonStyle = ActionButtonStyle.outline,
    bool compact = false,
  }) {
    if (compact) {
      return IndustrialCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: IndustrialColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 24, color: IndustrialColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: IndustrialColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            PrimaryActionButton(
              label: buttonLabel,
              icon: icon,
              style: buttonStyle,
              onPressed: onPressed,
            ),
          ],
        ),
      );
    }

    return IndustrialCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: IndustrialColors.primary),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: IndustrialColors.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          PrimaryActionButton(
            label: buttonLabel,
            icon: icon,
            style: buttonStyle,
            onPressed: onPressed,
          ),
        ],
      ),
    );
  }

  Widget _buildSaaSFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: IndustrialColors.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DhinaDTS Cloud Platform',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Secure enterprise attendance management - GDPR Compliant - 99.9% Uptime SLA',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: IndustrialColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 24,
            runSpacing: 10,
            children: [
              _buildFooterLink('Privacy Policy'),
              _buildFooterLink('Terms of Service'),
              _buildFooterLink('Support'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '(c) 2024 DhinaDTS. All rights reserved. Version 2.0.0',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: IndustrialColors.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterLink(String text) {
    return GestureDetector(
      onTap: () {
        if (text == 'Privacy Policy') {
          context.go('/privacy');
        } else if (text == 'Terms of Service') {
          context.go('/terms');
        } else if (text == 'Support') {
          context.go('/support');
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$text - Coming soon')));
        }
      },
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: IndustrialColors.primary,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}

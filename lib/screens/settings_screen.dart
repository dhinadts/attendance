import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/attendance_session_service.dart';
import '../theme/industrial_theme.dart';
import '../theme/theme_controller.dart';
import '../widgets/app_shell.dart';
import '../widgets/admin_bottom_nav.dart';
import '../widgets/industrial_card.dart';
import '../widgets/primary_action_button.dart';
import '../widgets/status_chip.dart';

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

    return AppShell(
      title: 'Settings',
      bottomNavigationBar: isAdmin ? const AdminBottomNav(currentIndex: 3) : null,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settings',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const StatusChip(
              label: 'Employee app',
              type: StatusChipType.neutral,
              icon: Icons.tune,
            ),
            const SizedBox(height: 20),
            IndustrialCard(
              child: Column(
                children: [
                  _row('Theme', 'Toggle light / dark', Icons.dark_mode),
                  const SizedBox(height: 12),
                  PrimaryActionButton(
                    label: 'CHANGE THEME',
                    icon: Icons.brightness_6,
                    style: ActionButtonStyle.outline,
                    onPressed: () {
                      themeModeNotifier.value =
                          themeModeNotifier.value == ThemeMode.dark
                          ? ThemeMode.light
                          : ThemeMode.dark;
                    },
                  ),
                  const Divider(height: 28),
                  _row(
                    'Cache',
                    'Clear local profile/session cache',
                    Icons.cleaning_services,
                  ),
                  const SizedBox(height: 12),
                  PrimaryActionButton(
                    label: 'CLEAR CACHE',
                    icon: Icons.delete_sweep,
                    style: ActionButtonStyle.outline,
                    onPressed: _clearCache,
                  ),
                  const Divider(height: 28),
                  _row('Account', 'Logout from this device', Icons.logout),
                  const SizedBox(height: 12),
                  PrimaryActionButton(
                    label: 'LOGOUT',
                    icon: Icons.logout,
                    style: ActionButtonStyle.tertiary,
                    onPressed: _logout,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String title, String subtitle, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: IndustrialColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
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
    );
  }
}

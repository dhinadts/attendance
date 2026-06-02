import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_role_service.dart';
import '../services/fcm_notification_service.dart';

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  final _authRoleService = AuthRoleService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _routeFromAuthState());
  }

  Future<void> _routeFromAuthState() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      context.go('/login');
      return;
    }

    final role = await _authRoleService.currentRole() ?? AppUserRole.employee;
    if (!mounted) return;
    final pendingRoute = FcmNotificationService.instance.consumePendingRouteFor(
      role,
    );
    context.go(
      pendingRoute ?? (role.isAdminLike ? '/admin-dashboard' : '/dashboard'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    return Scaffold(
      body: ColoredBox(
        color: isDark ? const Color(0xFF121C2A) : const Color(0xFFF8F9FF),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              isDark
                  ? 'assets/branding/splash_logo_dark.png'
                  : 'assets/branding/splash_logo_light.png',
              fit: BoxFit.cover,
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 54,
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

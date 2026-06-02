import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/industrial_theme.dart';

class EmployeeBottomNav extends StatelessWidget {
  const EmployeeBottomNav({
    super.key,
    required this.currentIndex,
    this.attendanceAlert = false,
  });

  final int currentIndex;
  final bool attendanceAlert;

  static const _routes = [
    '/dashboard',
    '/attendance-details',
    '/attendance-log',
    '/salary',
    '/exit-company',
    '/profile',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: IndustrialColors.surface,
        border: Border(
          top: BorderSide(color: IndustrialColors.outlineVariant, width: 1),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => context.go(_routes[index]),
        backgroundColor: IndustrialColors.surface,
        elevation: 0,
        selectedItemColor: IndustrialColors.primary,
        unselectedItemColor: IndustrialColors.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.calendar_month),
                if (attendanceAlert)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Attendance',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Log'),
          const BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Salary',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.exit_to_app),
            label: 'Exit',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

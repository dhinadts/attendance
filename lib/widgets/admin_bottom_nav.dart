import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/industrial_theme.dart';

class AdminBottomNav extends StatelessWidget {
  const AdminBottomNav({super.key, required this.currentIndex});

  final int currentIndex;

  static const _routes = [
    '/admin-dashboard',
    '/admin-employees',
    '/admin-salary',
    '/admin-settings',
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
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Admin'),
          BottomNavigationBarItem(icon: Icon(Icons.groups), label: 'Employees'),
          BottomNavigationBarItem(icon: Icon(Icons.payments), label: 'Payroll'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_role_service.dart';
import '../services/fcm_notification_service.dart';
import '../screens/admin_attendance_logs_screen.dart';
import '../screens/admin_salary_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/employee_dashboard_screen.dart';
import '../screens/face_auth_login_screen.dart';
import '../screens/attendance_details_screen.dart';
import '../screens/attendance_gps_tracking_screen.dart';
import '../screens/attendance_log_screen.dart';
import '../screens/exit_company_screen.dart';
import '../screens/owner_dashboard_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/salary_payroll_reports_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/startup_screen.dart';
import '../screens/team_messages_screen.dart';
import '../screens/admin_employees_screen.dart';
import '../screens/admin_employee_detail_screen.dart';
import '../screens/admin_export_reports_screen.dart';
import '../screens/admin_exit_requests_screen.dart';
import '../screens/admin_leave_approval_screen.dart';
import '../screens/admin_leave_requests_screen.dart';
import '../screens/admin_mark_attendance_screen.dart';
import '../screens/admin_profile_screen.dart';

class AuthRefreshListenable extends ChangeNotifier {
  AuthRefreshListenable() {
    _subscription = FirebaseAuth.instance.authStateChanges().listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<User?> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final _authRoleService = AuthRoleService();
final _authRefreshListenable = AuthRefreshListenable();

final appRouter = GoRouter(
  navigatorKey: FcmNotificationService.navigatorKey,
  initialLocation: '/startup',
  refreshListenable: _authRefreshListenable,
  redirect: (context, state) async {
    final user = FirebaseAuth.instance.currentUser;
    final path = state.uri.path;
    final isLogin = path == '/login';
    final isStartup = path == '/startup';

    if (isStartup) {
      return null;
    }

    if (user == null) {
      return isLogin ? null : '/login';
    }

    final role = await _authRoleService.currentRole();
    final isAdminRoute = path.startsWith('/admin');
    final isEmployeeRoute = _employeeOnlyRoutes.contains(path);

    if (isLogin) {
      return role == AppUserRole.admin ? '/admin-dashboard' : '/dashboard';
    }

    if (role == AppUserRole.admin && isEmployeeRoute) {
      return '/admin-dashboard';
    }

    if (role != AppUserRole.admin && isAdminRoute) {
      return '/dashboard';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/startup',
      name: 'startup',
      builder: (context, state) => const StartupScreen(),
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const AuthScreen(),
    ),
    GoRoute(
      path: '/face-attendance',
      name: 'faceAttendance',
      builder: (context, state) => const FaceAuthLoginScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      name: 'dashboard',
      builder: (context, state) => const EmployeeDashboardScreen(),
    ),
    GoRoute(
      path: '/admin-dashboard',
      name: 'adminDashboard',
      builder: (context, state) => const OwnerDashboardScreen(),
    ),
    GoRoute(
      path: '/admin-employees',
      name: 'adminEmployees',
      builder: (context, state) => const AdminEmployeesScreen(),
    ),
    GoRoute(
      path: '/admin-employee-detail',
      name: 'adminEmployeeDetail',
      builder: (context, state) => AdminEmployeeDetailScreen(
        employeeId: state.uri.queryParameters['employeeId'] ?? '',
        initialTab: state.uri.queryParameters['initialTab'],
      ),
    ),
    GoRoute(
      path: '/admin-leave-approval',
      name: 'adminLeaveApproval',
      builder: (context, state) => AdminLeaveApprovalScreen(
        employeeId: state.uri.queryParameters['employeeId'] ?? '',
        date: state.uri.queryParameters['date'] ?? '',
      ),
    ),
    GoRoute(
      path: '/admin-leave-requests',
      name: 'adminLeaveRequests',
      builder: (context, state) => const AdminLeaveRequestsScreen(),
    ),
    GoRoute(
      path: '/admin-mark-attendance',
      name: 'adminMarkAttendance',
      builder: (context, state) => AdminMarkAttendanceScreen(
        requestId: state.uri.queryParameters['requestId'],
        employeeId: state.uri.queryParameters['employeeId'],
      ),
    ),
    GoRoute(
      path: '/admin-export-reports',
      name: 'adminExportReports',
      builder: (context, state) => const AdminExportReportsScreen(),
    ),
    GoRoute(
      path: '/admin-exit-requests',
      name: 'adminExitRequests',
      builder: (context, state) => AdminExitRequestsScreen(
        requestId: state.uri.queryParameters['requestId'],
        employeeId: state.uri.queryParameters['employeeId'],
      ),
    ),
    GoRoute(
      path: '/admin-profile',
      name: 'adminProfile',
      builder: (context, state) => const AdminProfileScreen(),
    ),
    GoRoute(
      path: '/admin-attendance',
      name: 'adminAttendance',
      builder: (context, state) => const AdminAttendanceLogsScreen(),
    ),
    GoRoute(
      path: '/admin-salary',
      name: 'adminSalary',
      builder: (context, state) => const AdminSalaryScreen(),
    ),
    GoRoute(
      path: '/attendance',
      name: 'attendance',
      builder: (context, state) => const AttendanceGpsTrackingScreen(),
    ),
    GoRoute(
      path: '/attendance-details',
      name: 'attendanceDetails',
      builder: (context, state) => const AttendanceDetailsScreen(),
    ),
    GoRoute(
      path: '/attendance-log',
      name: 'attendanceLog',
      builder: (context, state) => const AttendanceLogScreen(),
    ),
    GoRoute(
      path: '/salary',
      name: 'salary',
      builder: (context, state) => const SalaryPayrollReportsScreen(),
    ),
    GoRoute(
      path: '/profile',
      name: 'profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/admin-settings',
      name: 'adminSettings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/messages',
      name: 'messages',
      builder: (context, state) => const TeamMessagesScreen(),
    ),
    GoRoute(
      path: '/notifications',
      name: 'notifications',
      builder: (context, state) => const NotificationsScreen(),
    ),
    GoRoute(
      path: '/admin-messages',
      name: 'adminMessages',
      builder: (context, state) => const TeamMessagesScreen(),
    ),
    GoRoute(
      path: '/admin-notifications',
      name: 'adminNotifications',
      builder: (context, state) => const NotificationsScreen(),
    ),
    GoRoute(
      path: '/exit-company',
      name: 'exitCompany',
      builder: (context, state) => const ExitCompanyScreen(),
    ),
  ],
);

const _employeeOnlyRoutes = {
  '/dashboard',
  '/face-attendance',
  '/attendance',
  '/attendance-details',
  '/attendance-log',
  '/salary',
  '/profile',
  '/messages',
  '/notifications',
  '/settings',
  '/exit-company',
};

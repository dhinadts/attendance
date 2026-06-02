import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../theme/industrial_theme.dart';
import '../services/app_firestore.dart';
import '../services/auth_role_service.dart';

class AppShell extends StatefulWidget {
  final Widget child;
  final String? title;
  final Widget? bottomNavigationBar;
  final FloatingActionButton? floatingActionButton;
  final List<Widget>? appBarActions;
  final bool showAppBar;

  const AppShell({
    super.key,
    required this.child,
    this.title,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.appBarActions,
    this.showAppBar = true,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static final List<String> _routeHistory = <String>[];
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).uri.path;
    final isAdminPath = currentPath.startsWith('/admin');
    final fallbackPath = isAdminPath ? '/admin-dashboard' : '/dashboard';
    _rememberRoute(currentPath);

    final rootPaths = {
      '/admin-dashboard',
      '/admin-employees',
      '/admin-attendance',
      '/admin-mark-attendance',
      '/admin-leave-requests',
      '/admin-export-reports',
      '/admin-exit-requests',
      '/admin-salary',
      '/admin-settings',
      '/admin-profile',
      '/admin-create-user',
      '/dashboard',
      '/attendance-details',
      '/attendance-log',
      '/salary',
      '/exit-company',
      '/profile',
      '/login',
      '/startup',
    };
    final showBackButton =
        !rootPaths.contains(currentPath) || GoRouter.of(context).canPop();
    final useAdminWebShell =
        widget.showAppBar &&
        isAdminPath &&
        (kIsWeb || MediaQuery.sizeOf(context).width >= 1000);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        if (currentPath == fallbackPath ||
            currentPath == '/face-attendance' ||
            currentPath == '/login') {
          SystemNavigator.pop();
          return;
        }
        if (GoRouter.of(context).canPop()) {
          GoRouter.of(context).pop();
          return;
        }
        final previousPath = _previousRoute(currentPath);
        context.go(previousPath ?? fallbackPath);
      },
      child: useAdminWebShell
          ? _AdminWebShell(
              title: widget.title ?? 'attendance',
              currentPath: currentPath,
              appBarActions: widget.appBarActions,
              floatingActionButton: widget.floatingActionButton,
              child: widget.child,
            )
          : Scaffold(
              key: _scaffoldKey,
              appBar: widget.showAppBar
                  ? AppBar(
                      title: Text(
                        widget.title ?? 'attendance',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: IndustrialColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      leading: showBackButton
                          ? IconButton(
                              tooltip: 'Back',
                              icon: const Icon(Icons.arrow_back),
                              color: IndustrialColors.primary,
                              onPressed: () {
                                if (GoRouter.of(context).canPop()) {
                                  context.pop();
                                } else {
                                  context.go(
                                    isAdminPath
                                        ? '/admin-dashboard'
                                        : '/dashboard',
                                  );
                                }
                              },
                            )
                          : IconButton(
                              tooltip: 'Menu',
                              icon: const Icon(Icons.menu),
                              color: IndustrialColors.primary,
                              onPressed: () =>
                                  _scaffoldKey.currentState?.openDrawer(),
                            ),
                      actions: [
                        if (widget.appBarActions != null)
                          ...widget.appBarActions!,
                        _NotificationBell(isAdminPath: isAdminPath),
                        IconButton(
                          tooltip: 'Messages',
                          icon: const Icon(Icons.chat_bubble_outline),
                          onPressed: () => context.go(
                            isAdminPath ? '/admin-messages' : '/messages',
                          ),
                          color: IndustrialColors.primary,
                        ),
                        IconButton(
                          tooltip: 'Profile',
                          icon: const Icon(Icons.account_circle),
                          onPressed: () => context.go(
                            isAdminPath ? '/admin-profile' : '/profile',
                          ),
                          color: IndustrialColors.primary,
                        ),
                      ],
                      backgroundColor: IndustrialColors.surface,
                      elevation: 1,
                      shadowColor: Colors.black.withValues(alpha: 0.05),
                      surfaceTintColor: Colors.transparent,
                      centerTitle: false,
                    )
                  : null,
              drawer: widget.showAppBar
                  ? _AppDrawer(isAdmin: isAdminPath, currentPath: currentPath)
                  : null,
              body: SafeArea(child: widget.child),
              bottomNavigationBar: widget.bottomNavigationBar,
              floatingActionButton: widget.floatingActionButton,
              backgroundColor: IndustrialColors.background,
            ),
    );
  }

  void _rememberRoute(String path) {
    if (_routeHistory.isNotEmpty && _routeHistory.last == path) return;
    _routeHistory.remove(path);
    _routeHistory.add(path);
    if (_routeHistory.length > 12) {
      _routeHistory.removeAt(0);
    }
  }

  String? _previousRoute(String currentPath) {
    while (_routeHistory.isNotEmpty && _routeHistory.last == currentPath) {
      _routeHistory.removeLast();
    }
    return _routeHistory.isEmpty ? null : _routeHistory.removeLast();
  }
}

class _AdminWebShell extends StatelessWidget {
  const _AdminWebShell({
    required this.title,
    required this.currentPath,
    required this.child,
    required this.appBarActions,
    required this.floatingActionButton,
  });

  final String title;
  final String currentPath;
  final Widget child;
  final List<Widget>? appBarActions;
  final FloatingActionButton? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: floatingActionButton,
      backgroundColor: const Color(0xFFF6F8FB),
      body: Row(
        children: [
          _AdminSideMenu(currentPath: currentPath),
          Expanded(
            child: Column(
              children: [
                _AdminTopBar(
                  title: title,
                  currentPath: currentPath,
                  appBarActions: appBarActions,
                ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(color: Color(0xFFF6F8FB)),
                    child: SafeArea(
                      top: false,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1320),
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminSideMenu extends StatelessWidget {
  const _AdminSideMenu({required this.currentPath});

  final String currentPath;

  @override
  Widget build(BuildContext context) {
    const items = [
      _DrawerItem('Dashboard', Icons.dashboard, '/admin-dashboard'),
      _DrawerItem('Employees', Icons.groups, '/admin-employees'),
      _DrawerItem('Attendance', Icons.fact_check, '/admin-attendance'),
      _DrawerItem(
        'Mark Attendance',
        Icons.how_to_reg,
        '/admin-mark-attendance',
      ),
      _DrawerItem(
        'Leave Requests',
        Icons.event_available,
        '/admin-leave-requests',
      ),
      _DrawerItem('Payroll', Icons.payments, '/admin-salary'),
      _DrawerItem('Export Reports', Icons.table_view, '/admin-export-reports'),
      _DrawerItem('Exit Requests', Icons.exit_to_app, '/admin-exit-requests'),
      _DrawerItem('Messages', Icons.chat_bubble_outline, '/admin-messages'),
      _DrawerItem('Notifications', Icons.notifications, '/admin-notifications'),
      _DrawerItem('Create User', Icons.person_add, '/admin-create-user'),
      _DrawerItem('Profile', Icons.person, '/admin-profile'),
      _DrawerItem('Settings', Icons.settings, '/admin-settings'),
    ];

    return Container(
      width: 286,
      decoration: BoxDecoration(
        color: IndustrialColors.surface,
        border: Border(
          right: BorderSide(color: IndustrialColors.outlineVariant, width: 1),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: IndustrialColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.verified_user,
                      color: IndustrialColors.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'attendance',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: IndustrialColors.onSurface,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        Text(
                          'Admin workspace',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: IndustrialColors.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Divider(color: IndustrialColors.outlineVariant),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
                children: [
                  _MenuSectionLabel('Operations'),
                  for (final item in items.take(8))
                    _AdminSideMenuItem(
                      item: item,
                      selected: _isSelected(item.route),
                    ),
                  const SizedBox(height: 12),
                  _MenuSectionLabel('Communication'),
                  for (final item in items.skip(8).take(2))
                    _AdminSideMenuItem(
                      item: item,
                      selected: _isSelected(item.route),
                    ),
                  const SizedBox(height: 12),
                  _MenuSectionLabel('Account'),
                  for (final item in items.skip(10))
                    _AdminSideMenuItem(
                      item: item,
                      selected: _isSelected(item.route),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isSelected(String route) {
    if (currentPath == route) return true;
    if (route == '/admin-dashboard') return false;
    return currentPath.startsWith(route);
  }
}

class _MenuSectionLabel extends StatelessWidget {
  const _MenuSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: IndustrialColors.outline,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _AdminSideMenuItem extends StatelessWidget {
  const _AdminSideMenuItem({required this.item, required this.selected});

  final _DrawerItem item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected
            ? IndustrialColors.primary.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => context.go(item.route),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: selected
                      ? IndustrialColors.primary
                      : IndustrialColors.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: selected
                          ? IndustrialColors.primary
                          : IndustrialColors.onSurface,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
                if (selected)
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: IndustrialColors.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminTopBar extends StatelessWidget {
  const _AdminTopBar({
    required this.title,
    required this.currentPath,
    required this.appBarActions,
  });

  final String title;
  final String currentPath;
  final List<Widget>? appBarActions;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        color: IndustrialColors.surface,
        border: Border(
          bottom: BorderSide(color: IndustrialColors.outlineVariant, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _titleForRoute(title, currentPath),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: IndustrialColors.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Manage attendance, teams, approvals, payroll and requests',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: IndustrialColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (appBarActions != null) ...appBarActions!,
          _NotificationBell(isAdminPath: true),
          IconButton(
            tooltip: 'Messages',
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () => context.go('/admin-messages'),
            color: IndustrialColors.primary,
          ),
          IconButton(
            tooltip: 'Profile',
            icon: const Icon(Icons.account_circle),
            onPressed: () => context.go('/admin-profile'),
            color: IndustrialColors.primary,
          ),
        ],
      ),
    );
  }

  String _titleForRoute(String fallback, String path) {
    switch (path) {
      case '/admin-dashboard':
        return 'Admin Dashboard';
      case '/admin-employees':
        return 'Employees';
      case '/admin-attendance':
        return 'Attendance Logs';
      case '/admin-mark-attendance':
        return 'Mark Attendance';
      case '/admin-leave-requests':
        return 'Leave Requests';
      case '/admin-salary':
        return 'Payroll';
      case '/admin-export-reports':
        return 'Export Reports';
      case '/admin-exit-requests':
        return 'Exit Requests';
      case '/admin-messages':
        return 'Messages';
      case '/admin-notifications':
        return 'Notifications';
      case '/admin-profile':
        return 'Admin Profile';
      case '/admin-create-user':
        return 'Create User';
      case '/admin-settings':
        return 'Settings';
      default:
        return fallback;
    }
  }
}

class _AppDrawer extends StatelessWidget {
  const _AppDrawer({required this.isAdmin, required this.currentPath});

  final bool isAdmin;
  final String currentPath;

  @override
  Widget build(BuildContext context) {
    final items = isAdmin
        ? const [
            _DrawerItem('Admin Dashboard', Icons.dashboard, '/admin-dashboard'),
            _DrawerItem('Attendance Logs', Icons.groups, '/admin-attendance'),
            _DrawerItem('Payroll', Icons.payments, '/admin-salary'),
            _DrawerItem(
              'Exit Requests',
              Icons.exit_to_app,
              '/admin-exit-requests',
            ),
            _DrawerItem(
              'Notifications',
              Icons.notifications,
              '/admin-notifications',
            ),
            _DrawerItem(
              'Messages',
              Icons.chat_bubble_outline,
              '/admin-messages',
            ),
            _DrawerItem('Create User', Icons.person_add, '/admin-create-user'),
            _DrawerItem('Settings', Icons.settings, '/admin-settings'),
            _DrawerItem('Profile', Icons.person, '/admin-profile'),
          ]
        : const [
            _DrawerItem('Dashboard', Icons.home, '/dashboard'),
            _DrawerItem('Face Attendance', Icons.face, '/face-attendance'),
            _DrawerItem(
              'Attendance Details',
              Icons.calendar_month,
              '/attendance-details',
            ),
            _DrawerItem('Salary Download', Icons.receipt_long, '/salary'),
            _DrawerItem('Exit Company', Icons.exit_to_app, '/exit-company'),
            _DrawerItem('Notifications', Icons.notifications, '/notifications'),
            _DrawerItem('Messages', Icons.chat_bubble_outline, '/messages'),
            _DrawerItem('Profile', Icons.person, '/profile'),
            _DrawerItem('Settings', Icons.settings, '/settings'),
          ];

    return Drawer(
      backgroundColor: IndustrialColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'attendance',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: IndustrialColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (final item in items)
                    ListTile(
                      selected: currentPath == item.route,
                      leading: Icon(item.icon),
                      title: Text(item.label),
                      onTap: () {
                        Navigator.of(context).pop();
                        context.go(item.route);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.isAdminPath});

  final bool isAdminPath;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return IconButton(
        tooltip: 'Notifications',
        icon: const Icon(Icons.notifications_none),
        color: IndustrialColors.primary,
        onPressed: () => context.go('/login'),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .appCollection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, userSnapshot) {
        final userData = userSnapshot.data?.data();
        final isAdmin =
            appUserRoleFromValue(userData?['role']).isAdminLike || isAdminPath;
        final department = (userData?['department'] as String?)
            ?.trim()
            .toLowerCase();

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .appCollection('team_messages')
              .orderBy('createdAt', descending: true)
              .limit(100)
              .snapshots(),
          builder: (context, messageSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .appCollection('notification_reads')
                  .where('uid', isEqualTo: uid)
                  .snapshots(),
              builder: (context, readSnapshot) {
                final readIds = (readSnapshot.data?.docs ?? [])
                    .map((doc) => doc.data()['messageId'] as String?)
                    .whereType<String>()
                    .toSet();
                final unreadCount = (messageSnapshot.data?.docs ?? [])
                    .where(
                      (doc) => _isRelevantNotification(
                        doc.data(),
                        uid: uid,
                        isAdmin: isAdmin,
                        department: department,
                      ),
                    )
                    .where((doc) => !readIds.contains(doc.id))
                    .length;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      tooltip: 'Notifications',
                      icon: const Icon(Icons.notifications_none),
                      color: IndustrialColors.primary,
                      onPressed: () => context.go(
                        isAdminPath ? '/admin-notifications' : '/notifications',
                      ),
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: const BoxDecoration(
                            color: Color(0xFFBA1A1A),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            unreadCount > 9 ? '9+' : '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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

  bool _isRelevantNotification(
    Map<String, dynamic> data, {
    required String uid,
    required bool isAdmin,
    required String? department,
  }) {
    if (data['recipientUid'] == uid) return true;
    if ((data['recipientUids'] as List?)?.contains(uid) == true) return true;

    final targetType = data['targetType'] as String?;
    if (targetType == 'all') return true;
    if (isAdmin) {
      return targetType == 'admin' ||
          targetType == 'admins' ||
          targetType == 'team' ||
          targetType == 'teams';
    }
    if (department == null || department.isEmpty) return false;
    final targetTeam = (data['targetTeam'] as String?)?.trim().toLowerCase();
    final targetTeams = (data['targetTeams'] as List?)
        ?.whereType<String>()
        .map((team) => team.trim().toLowerCase())
        .toSet();
    return targetTeam == department ||
        targetTeams?.contains(department) == true;
  }
}

class _DrawerItem {
  const _DrawerItem(this.label, this.icon, this.route);

  final String label;
  final IconData icon;
  final String route;
}

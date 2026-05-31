import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../theme/industrial_theme.dart';

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
      child: Scaffold(
        key: _scaffoldKey,
        appBar: widget.showAppBar
            ? AppBar(
                title: Text(
                  widget.title ?? 'attendance',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
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
                              isAdminPath ? '/admin-dashboard' : '/dashboard',
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
                  if (widget.appBarActions != null) ...widget.appBarActions!,
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
                    onPressed: () =>
                        context.go(isAdminPath ? '/admin-profile' : '/profile'),
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
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, userSnapshot) {
        final userData = userSnapshot.data?.data();
        final isAdmin = userData?['role'] == 'admin' || isAdminPath;
        final department = (userData?['department'] as String?)
            ?.trim()
            .toLowerCase();

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('team_messages')
              .orderBy('createdAt', descending: true)
              .limit(100)
              .snapshots(),
          builder: (context, messageSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('notification_reads')
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

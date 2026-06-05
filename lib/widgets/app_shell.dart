import '../utils/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/industrial_theme.dart';
import '../services/app_firestore.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_role_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';

class AppShell extends StatefulWidget {
  final Widget child;
  final String? title;
  final Widget? bottomNavigationBar;
  final FloatingActionButton? floatingActionButton;
  final List<Widget>? appBarActions;
  final bool showAppBar;
  final bool showBackButton;
  final bool forceAdminShell;

  const AppShell({
    super.key,
    required this.child,
    this.title,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.appBarActions,
    this.showAppBar = true,
    this.showBackButton = false,
    this.forceAdminShell = false,
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
      '/admin-tasks',
      '/admin-settings',
      '/admin-profile',
      '/admin-create-user',
      '/dashboard',
      '/attendance-details',
      '/attendance-log',
      '/tasks',
      '/salary',
      '/exit-company',
      '/profile',
      '/login',
      '/startup',
      '/privacy',
      '/terms',
      '/support',
    };

    final isRootPath = rootPaths.contains(currentPath);
    final showBackButton =
        widget.showBackButton || (!isRootPath || GoRouter.of(context).canPop());

    final useWebShell =
        widget.showAppBar &&
        (widget.forceAdminShell ||
            (kIsWeb || Responsive.isLargeDesktop(context)));

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
      child: useWebShell
          ? _AdminWebShell(
              title: widget.title ?? 'attendance',
              currentPath: currentPath,
              isAdminPath: isAdminPath,
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
                          tooltip: 'Settings',
                          icon: const Icon(Icons.settings_outlined),
                          onPressed: () => context.go(
                            isAdminPath ? '/admin-settings' : '/settings',
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

class _AdminWebShell extends StatefulWidget {
  const _AdminWebShell({
    required this.title,
    required this.currentPath,
    required this.isAdminPath,
    required this.child,
    required this.appBarActions,
    required this.floatingActionButton,
  });

  final String title;
  final String currentPath;
  final bool isAdminPath;
  final Widget child;
  final List<Widget>? appBarActions;
  final FloatingActionButton? floatingActionButton;

  @override
  State<_AdminWebShell> createState() => _AdminWebShellState();
}

class _AdminWebShellState extends State<_AdminWebShell> {
  bool _collapsed = false;
  bool _hovering = false;

  void _toggleCollapsed() {
    setState(() {
      _collapsed = !_collapsed;
      _hovering = false;
    });
  }

  void _setHover(bool v) {
    if (!_collapsed || _hovering == v) return;
    setState(() => _hovering = v);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveCollapsed = _collapsed && !_hovering;
    return Scaffold(
      floatingActionButton: widget.floatingActionButton,
      backgroundColor: const Color(0xFFF6F8FB),
      body: Row(
        children: [
          MouseRegion(
            onEnter: (_) => _setHover(true),
            onExit: (_) => _setHover(false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              width: effectiveCollapsed ? 72 : 240,
              child: ClipRect(
                child: _AdminSideMenu(
                  currentPath: widget.currentPath,
                  collapsed: effectiveCollapsed,
                  isAdminPath: widget.isAdminPath,
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                _AdminTopBar(
                  title: widget.title,
                  currentPath: widget.currentPath,
                  isAdminPath: widget.isAdminPath,
                  appBarActions: widget.appBarActions,
                  isCollapsed: _collapsed,
                  onToggleCollapsed: _toggleCollapsed,
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
                          child: widget.child,
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
  const _AdminSideMenu({
    required this.currentPath,
    this.collapsed = false,
    this.isAdminPath = true,
  });

  final String currentPath;
  final bool collapsed;
  final bool isAdminPath;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final menuWidth = collapsed ? 72.0 : 240.0;

    final decoration = BoxDecoration(
      color: IndustrialColors.surface,
      border: Border(
        right: BorderSide(color: IndustrialColors.outlineVariant, width: 1),
      ),
    );

    if (!isAdminPath) {
      const mainItems = [
        _DrawerItem('Dashboard', Icons.home, '/dashboard'),
        _DrawerItem('Face Attendance', Icons.face, '/face-attendance'),
        _DrawerItem('Attendance Details', Icons.calendar_month, '/attendance-details'),
      ];
      const workItems = [
        _DrawerItem('Tasks', Icons.task_alt, '/tasks'),
        _DrawerItem('Salary', Icons.receipt_long, '/salary'),
        _DrawerItem('Exit Company', Icons.exit_to_app, '/exit-company'),
      ];
      const commItems = [
        _DrawerItem('Notifications', Icons.notifications, '/notifications'),
        _DrawerItem('Messages', Icons.chat_bubble_outline, '/messages'),
      ];
      const accItems = [
        _DrawerItem('Profile', Icons.person, '/profile'),
        _DrawerItem('Settings', Icons.settings, '/settings'),
      ];
      const allItems = [...mainItems, ...workItems, ...commItems, ...accItems];

      return Container(
        width: menuWidth,
        decoration: decoration,
        child: SafeArea(
          child: collapsed
              ? _buildCompact(context, uid, allItems, const [], const [])
              : _buildEmployeeExpanded(
                  context, mainItems, workItems, commItems, accItems),
        ),
      );
    }

    const operationsItems = [
      _DrawerItem('Dashboard', Icons.dashboard, '/admin-dashboard'),
      _DrawerItem('Employees', Icons.groups, '/admin-employees'),
      _DrawerItem('Attendance', Icons.fact_check, '/admin-attendance'),
      _DrawerItem('Mark Attendance', Icons.how_to_reg, '/admin-mark-attendance'),
      _DrawerItem('Leave Requests', Icons.event_available, '/admin-leave-requests'),
      _DrawerItem('Payroll', Icons.payments, '/admin-salary'),
      _DrawerItem('Export Reports', Icons.table_view, '/admin-export-reports'),
      _DrawerItem('Exit Requests', Icons.exit_to_app, '/admin-exit-requests'),
    ];
    const communicationItems = [
      _DrawerItem('Messages', Icons.chat_bubble_outline, '/admin-messages'),
      _DrawerItem('Notifications', Icons.notifications, '/admin-notifications'),
    ];
    const accountItems = [
      _DrawerItem('Profile', Icons.person, '/admin-profile'),
      _DrawerItem('Settings', Icons.settings, '/admin-settings'),
    ];
    const createUserItem = _DrawerItem('Create User', Icons.person_add, '/admin-create-user');

    return Container(
      width: menuWidth,
      decoration: decoration,
      child: SafeArea(
        child: collapsed
            ? _buildCompact(context, uid, operationsItems, communicationItems, accountItems)
            : _buildExpanded(context, uid, operationsItems, communicationItems, accountItems, createUserItem),
      ),
    );
  }

  Widget _buildCompact(
    BuildContext context,
    String? uid,
    List<_DrawerItem> ops,
    List<_DrawerItem> comms,
    List<_DrawerItem> accs,
  ) {
    final allItems = [...ops, ...comms, ...accs];
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: IndustrialColors.primary,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF34D399), width: 1.5),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: Color(0xFF34D399),
              size: 18,
            ),
          ),
        ),
        const Divider(height: 1, color: IndustrialColors.outlineVariant),
        const SizedBox(height: 8),
        for (final item in allItems)
          _CompactMenuItem(item: item, selected: _isSelected(item.route)),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _buildExpanded(
    BuildContext context,
    String? uid,
    List<_DrawerItem> ops,
    List<_DrawerItem> comms,
    List<_DrawerItem> accs,
    _DrawerItem createUserItem,
  ) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: uid == null
          ? null
          : FirebaseFirestore.instance
                .appCollection('users')
                .doc(uid)
                .snapshots(),
      builder: (context, snapshot) {
        final canCreateUsers = appUserRoleFromValue(
          snapshot.data?.data()?['role'],
        ).canAssignRoles;
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 22, 24, 18),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: IndustrialColors.primary,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF34D399),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: Color(0xFF34D399),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DhinaDTS',
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
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Divider(color: IndustrialColors.outlineVariant),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _MenuSectionLabel('Operations'),
                  for (final item in ops)
                    _AdminSideMenuItem(
                      item: item,
                      selected: _isSelected(item.route),
                    ),
                  const SizedBox(height: 12),
                  const _MenuSectionLabel('Communication'),
                  for (final item in comms)
                    _AdminSideMenuItem(
                      item: item,
                      selected: _isSelected(item.route),
                    ),
                  const SizedBox(height: 12),
                  const _MenuSectionLabel('Account'),
                  if (canCreateUsers)
                    _AdminSideMenuItem(
                      item: createUserItem,
                      selected: _isSelected(createUserItem.route),
                    ),
                  for (final item in accs)
                    _AdminSideMenuItem(
                      item: item,
                      selected: _isSelected(item.route),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmployeeExpanded(
    BuildContext context,
    List<_DrawerItem> main,
    List<_DrawerItem> work,
    List<_DrawerItem> comm,
    List<_DrawerItem> acc,
  ) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: uid == null
          ? null
          : FirebaseFirestore.instance
                .appCollection('employee_profiles')
                .where('uid', isEqualTo: uid)
                .limit(1)
                .snapshots(),
      builder: (context, snapshot) {
        final profileData = snapshot.data?.docs.firstOrNull?.data() ?? {};
        final nickName = (profileData['nickName'] as String?)?.trim() ?? '';
        final firstName = (profileData['firstName'] as String?)?.trim() ?? '';
        final lastName = (profileData['lastName'] as String?)?.trim() ?? '';
        final employeeName = (profileData['employeeName'] as String?)?.trim() ?? '';
        final displayName = nickName.isNotEmpty
            ? nickName
            : (firstName.isNotEmpty || lastName.isNotEmpty)
                ? '$firstName $lastName'.trim()
                : employeeName.isNotEmpty
                    ? employeeName
                    : (FirebaseAuth.instance.currentUser?.email ?? 'Employee');

        return ListView(
      padding: EdgeInsets.zero,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 22, 24, 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: IndustrialColors.primary,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF34D399), width: 1.5),
                ),
                child: const Icon(Icons.person_outline, color: Color(0xFF34D399), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      softWrap: true,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: IndustrialColors.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Employee portal',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
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
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Divider(color: IndustrialColors.outlineVariant),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _MenuSectionLabel('Main'),
              for (final item in main)
                _AdminSideMenuItem(item: item, selected: _isSelected(item.route)),
              const SizedBox(height: 12),
              const _MenuSectionLabel('Work'),
              for (final item in work)
                _AdminSideMenuItem(item: item, selected: _isSelected(item.route)),
              const SizedBox(height: 12),
              const _MenuSectionLabel('Communication'),
              for (final item in comm)
                _AdminSideMenuItem(item: item, selected: _isSelected(item.route)),
              const SizedBox(height: 12),
              const _MenuSectionLabel('Account'),
              for (final item in acc)
                _AdminSideMenuItem(item: item, selected: _isSelected(item.route)),
            ],
          ),
        ),
      ],
        );       // ListView
      },         // builder
    );           // StreamBuilder
  }

  bool _isSelected(String route) {
    if (currentPath == route) return true;
    if (route == '/admin-dashboard' || route == '/dashboard') return currentPath == route;
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

class _CompactMenuItem extends StatelessWidget {
  const _CompactMenuItem({required this.item, required this.selected});

  final _DrawerItem item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Tooltip(
        message: item.label,
        waitDuration: const Duration(milliseconds: 300),
        child: Material(
          color: selected
              ? IndustrialColors.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => context.go(item.route),
            child: Container(
              height: 44,
              alignment: Alignment.center,
              child: Icon(
                item.icon,
                size: 20,
                color: selected
                    ? IndustrialColors.primary
                    : IndustrialColors.onSurfaceVariant,
              ),
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
    required this.isAdminPath,
    required this.appBarActions,
    this.isCollapsed = false,
    this.onToggleCollapsed,
  });

  final String title;
  final String currentPath;
  final bool isAdminPath;
  final List<Widget>? appBarActions;
  final bool isCollapsed;
  final VoidCallback? onToggleCollapsed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: IndustrialColors.surface,
        border: Border(
          bottom: BorderSide(color: IndustrialColors.outlineVariant, width: 1),
        ),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Row(
              children: [
                IconButton(
                  tooltip: isCollapsed ? 'Open menu' : 'Collapse menu',
                  icon: Icon(isCollapsed ? Icons.menu : Icons.menu_open),
                  onPressed: onToggleCollapsed,
                  color: IndustrialColors.primary,
                ),
                const SizedBox(width: 8),
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
                        isAdminPath
                            ? 'Manage attendance, teams, approvals, payroll and requests'
                            : 'Track attendance, tasks, salary and team updates',
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
            ),
          ),
        ),
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
      case '/admin-tasks':
        return 'Tasks';
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
      case '/privacy':
        return 'Privacy Policy';
      case '/terms':
        return 'Terms & Conditions';
      case '/support':
        return 'Support Center';
      case '/tasks':
        return 'Tasks';
      case '/dashboard':
        return 'Dashboard';
      case '/attendance-details':
        return 'Attendance Details';
      case '/attendance-log':
        return 'Attendance Log';
      case '/face-attendance':
        return 'Face Attendance';
      case '/salary':
        return 'Salary';
      case '/exit-company':
        return 'Exit Company';
      case '/notifications':
        return 'Notifications';
      case '/messages':
        return 'Messages';
      case '/profile':
        return 'Profile';
      case '/settings':
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
    const adminItems = [
      _DrawerItem('Admin Dashboard', Icons.dashboard, '/admin-dashboard'),
      _DrawerItem('Attendance Logs', Icons.groups, '/admin-attendance'),
      _DrawerItem('Payroll', Icons.payments, '/admin-salary'),
      _DrawerItem('Tasks', Icons.task_alt, '/admin-tasks'),
      _DrawerItem('Exit Requests', Icons.exit_to_app, '/admin-exit-requests'),
      _DrawerItem('Notifications', Icons.notifications, '/admin-notifications'),
      _DrawerItem('Messages', Icons.chat_bubble_outline, '/admin-messages'),
      _DrawerItem('Settings', Icons.settings, '/admin-settings'),
      _DrawerItem('Profile', Icons.person, '/admin-profile'),
    ];
    const createUserItem = _DrawerItem(
      'Create User',
      Icons.person_add,
      '/admin-create-user',
    );
    const employeeItems = [
      _DrawerItem('Dashboard', Icons.home, '/dashboard'),
      _DrawerItem('Face Attendance', Icons.face, '/face-attendance'),
      _DrawerItem(
        'Attendance Details',
        Icons.calendar_month,
        '/attendance-details',
      ),
      _DrawerItem('Tasks', Icons.task_alt, '/tasks'),
      _DrawerItem('Salary Download', Icons.receipt_long, '/salary'),
      _DrawerItem('Exit Company', Icons.exit_to_app, '/exit-company'),
      _DrawerItem('Notifications', Icons.notifications, '/notifications'),
      _DrawerItem('Messages', Icons.chat_bubble_outline, '/messages'),
      _DrawerItem('Profile', Icons.person, '/profile'),
      _DrawerItem('Settings', Icons.settings, '/settings'),
    ];
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Drawer(
      backgroundColor: IndustrialColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'DhinaDTS',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: IndustrialColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: !isAdmin || uid == null
                    ? null
                    : FirebaseFirestore.instance
                          .appCollection('users')
                          .doc(uid)
                          .snapshots(),
                builder: (context, snapshot) {
                  final canCreateUsers = appUserRoleFromValue(
                    snapshot.data?.data()?['role'],
                  ).canAssignRoles;
                  final items = isAdmin
                      ? [...adminItems, if (canCreateUsers) createUserItem]
                      : employeeItems;
                  return ListView(
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
                  );
                },
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
                  .appCollection('notifications')
                  .orderBy('createdAt', descending: true)
                  .limit(100)
                  .snapshots(),
              builder: (context, backendSnapshot) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .appCollection('notification_inbox')
                      .where('uid', isEqualTo: uid)
                      .snapshots(),
                  builder: (context, inboxSnapshot) {
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
                        final unreadCount =
                            _notificationBadgeEntries(
                                  teamMessages:
                                      messageSnapshot.data?.docs ?? const [],
                                  backendNotifications:
                                      backendSnapshot.data?.docs ?? const [],
                                  inboxMessages:
                                      inboxSnapshot.data?.docs ?? const [],
                                )
                                .where(
                                  (entry) => _isRelevantNotification(
                                    entry.data,
                                    uid: uid,
                                    isAdmin: isAdmin,
                                    department: department,
                                  ),
                                )
                                .where((entry) => !readIds.contains(entry.id))
                                .length;

                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            IconButton(
                              tooltip: 'Notifications',
                              icon: const Icon(Icons.notifications_none),
                              color: IndustrialColors.primary,
                              onPressed: () => context.go(
                                isAdminPath
                                    ? '/admin-notifications'
                                    : '/notifications',
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
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
    final targetTeams = _stringSet(data['targetTeams']);
    return targetTeam == department ||
        targetTeams?.contains(department) == true;
  }

  Set<String>? _stringSet(Object? value) {
    if (value is List) {
      return value
          .whereType<String>()
          .map((item) => item.trim().toLowerCase())
          .where((item) => item.isNotEmpty)
          .toSet();
    }
    if (value is String && value.trim().isNotEmpty) {
      return value
          .split(',')
          .map((item) => item.trim().toLowerCase())
          .where((item) => item.isNotEmpty)
          .toSet();
    }
    return null;
  }

  List<_NotificationBadgeEntry> _notificationBadgeEntries({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> teamMessages,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>>
    backendNotifications,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> inboxMessages,
  }) {
    final byKey = <String, _NotificationBadgeEntry>{};

    void add(_NotificationBadgeEntry entry) {
      final key =
          (entry.data['messageId'] as String?)?.trim().isNotEmpty == true
          ? entry.data['messageId'] as String
          : entry.id;
      byKey.putIfAbsent(key, () => entry);
    }

    for (final doc in teamMessages) {
      add(
        _NotificationBadgeEntry(
          id: doc.id,
          data: {'messageId': doc.id, ...doc.data()},
        ),
      );
    }
    for (final doc in backendNotifications) {
      final data = doc.data();
      final messageId = data['messageId'] as String?;
      add(
        _NotificationBadgeEntry(
          id: messageId?.isNotEmpty == true ? messageId! : doc.id,
          data: {
            'notificationId': doc.id,
            if (messageId?.isNotEmpty == true) 'messageId': messageId,
            ...data,
          },
        ),
      );
    }
    for (final doc in inboxMessages) {
      final data = doc.data();
      final payload = Map<String, dynamic>.from(
        (data['data'] as Map?) ?? const <String, dynamic>{},
      );
      final messageId = payload['messageId'] as String?;
      add(
        _NotificationBadgeEntry(
          id: messageId?.isNotEmpty == true ? messageId! : doc.id,
          data: {
            ...payload,
            'messageId': messageId?.isNotEmpty == true ? messageId : doc.id,
            'title': data['title'] ?? payload['title'],
            'body': data['body'] ?? payload['body'],
            'source': data['source'] ?? payload['source'],
          },
        ),
      );
    }

    return byKey.values.toList();
  }
}

class _NotificationBadgeEntry {
  const _NotificationBadgeEntry({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;
}

class _DrawerItem {
  const _DrawerItem(this.label, this.icon, this.route);

  final String label;
  final IconData icon;
  final String route;
}

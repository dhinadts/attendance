import 'dart:async';
import 'dart:math' as math;
import '../utils/responsive.dart';
import '../widgets/app_shell.dart';
import '../widgets/status_chip.dart';
import 'package:flutter/material.dart';
import '../theme/industrial_theme.dart';
import '../services/app_firestore.dart';
import '../widgets/industrial_card.dart';
import 'package:go_router/go_router.dart';
import '../widgets/admin_bottom_nav.dart';
import '../constants/organization_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class AdminEmployeesScreen extends StatefulWidget {
  const AdminEmployeesScreen({super.key});

  @override
  State<AdminEmployeesScreen> createState() => _AdminEmployeesScreenState();
}

class _AdminEmployeesScreenState extends State<AdminEmployeesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<GlobalKey, OverlayEntry?> _openOverlays = {};
  final Map<GlobalKey, Timer?> _hoverTimers = {};
  final Duration _hoverOpenDelay = const Duration(milliseconds: 300);
  final Duration _hoverCloseDelay = const Duration(milliseconds: 250);

  void _openEmployeeDetail(Map<String, dynamic> emp, {int initialTab = 0}) {
  final empId = (emp['employeeId'] ?? emp['id'] ?? '').toString().trim();

  if (empId.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Employee ID missing')),
    );
    return;
  }

  final uri = Uri(
    path: '/admin-employee-detail',
    queryParameters: {
      'employeeId': empId,
      if (initialTab > 0) 'initialTab': '$initialTab',
    },
  );

  context.go(uri.toString());
}

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Employees & Teams',
      bottomNavigationBar: const AdminBottomNav(currentIndex: 1),
     showBackButton: false,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore.appCollection('employee_profiles').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading employees: ${snapshot.error}',
                style: const TextStyle(color: IndustrialColors.error),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          final grouped = <String, List<Map<String, dynamic>>>{};

          // Initialize all standard teams to guarantee they exist in the UI
          for (final team in OrganizationOptions.teams) {
            grouped[team.toUpperCase()] = [];
          }

          for (final doc in docs) {
            final data = doc.data();
            final dept = _departmentFor(data);
            if (!grouped.containsKey(dept)) {
              grouped[dept] = [];
            }
            grouped[dept]!.add({'id': doc.id, ...data});
          }

          // Filter out empty teams or show them? Show them but with a "No employees" placeholder, which is super helpful for managers!
          final sortedDepts = grouped.keys.toList()..sort();

          final isWeb = Responsive.isDesktop(context);
          final isTablet = Responsive.isTablet(context);

          if (isWeb || isTablet) {
            final cross = isWeb ? 3 : 2;
            final paddingVal = 16.0;
            final crossAxisSpacing = 12.0;
            final availableWidth = MediaQuery.of(context).size.width - paddingVal * 2 - (cross - 1) * crossAxisSpacing;
            final itemWidth = availableWidth / cross;
            final desiredItemHeight = 120.0;
            final childAspect = itemWidth / desiredItemHeight;

            return GridView.count(
              padding: EdgeInsets.all(paddingVal),
              crossAxisCount: cross,
              crossAxisSpacing: crossAxisSpacing,
              mainAxisSpacing: 12,
              childAspectRatio: childAspect,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: sortedDepts.map((dept) {
                final employees = grouped[dept]!;
                final count = employees.length;
                final cardKey = GlobalKey();
                return Container(
                  key: cardKey,
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(
                        color: IndustrialColors.outlineVariant,
                        width: 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: MouseRegion(
                          onEnter: (_) => _startHoverTimer(cardKey, employees),
                          onExit: (_) => _startCloseTimer(cardKey),
                          child: GestureDetector(
                            onTap: () => _toggleOverlayForKey(cardKey, employees),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                              child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const CircleAvatar(
                                backgroundColor: IndustrialColors.primary,
                                foregroundColor: IndustrialColors.onPrimary,
                                child: Icon(Icons.groups, size: 20),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(dept, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 4),
                                    Text('$count ${count == 1 ? "employee" : "employees"}', style: Theme.of(context).textTheme.bodySmall),
                                  ],
                                ),
                              ),
                              const Icon(Icons.keyboard_arrow_down_outlined),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ));
              }).toList(),
            );
          }
          // Mobile / small screens: original vertical list
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedDepts.length,
            itemBuilder: (context, index) {
              final dept = sortedDepts[index];
              final employees = grouped[dept]!;
              final count = employees.length;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(
                      color: IndustrialColors.outlineVariant,
                      width: 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      backgroundColor: IndustrialColors.surfaceContainerLow,
                      collapsedBackgroundColor: IndustrialColors.surfaceContainerLowest,
                      leading: const CircleAvatar(
                        backgroundColor: IndustrialColors.primary,
                        foregroundColor: IndustrialColors.onPrimary,
                        child: Icon(Icons.groups, size: 20),
                      ),
                      title: Text(
                        dept,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      subtitle: Text(
                        '$count ${count == 1 ? "employee" : "employees"}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      childrenPadding: const EdgeInsets.all(12),
                      children: [
                        if (employees.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: StatusChip(
                                label: 'No employees in this team',
                                type: StatusChipType.neutral,
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: employees.length,
                            separatorBuilder: (context, idx) => const SizedBox(height: 8),
                            itemBuilder: (context, idx) {
                              final emp = employees[idx];
                              final empId = emp['employeeId'] as String? ?? emp['id'] as String;
                              final name = emp['employeeName'] as String? ?? 'Employee';
                              final role = emp['employeeRole'] as String? ?? emp['role'] as String? ?? 'EMPLOYEE';
                              final initials = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'E';

                              return IndustrialCard(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
onTap: () => _openEmployeeDetail(emp),                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: IndustrialColors.primaryContainer,
                                      foregroundColor: IndustrialColors.onPrimary,
                                      child: Text(
                                        initials,
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                          ),
                                          Text(
                                            'ID: $empId | $role',
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'View Attendance Logs',
                                      icon: const Icon(Icons.calendar_month, color: IndustrialColors.primary),
                                      onPressed: () => context.go('/admin-employee-detail?employeeId=$empId&initialTab=1'),
                                    ),
                                    const Icon(Icons.chevron_right, color: IndustrialColors.outline),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _startHoverTimer(GlobalKey key, List<Map<String, dynamic>> employees) {
    _hoverTimers[key]?.cancel();
    _hoverTimers[key] = Timer(_hoverOpenDelay, () {
      _ensureOverlayVisible(key, employees);
    });
  }

  void _startCloseTimer(GlobalKey key) {
    _hoverTimers[key]?.cancel();
    _hoverTimers[key] = Timer(_hoverCloseDelay, () {
      _removeOverlayForKey(key);
    });
  }

  void _toggleOverlayForKey(GlobalKey key, List<Map<String, dynamic>> employees) {
    if (_openOverlays[key] != null) {
      _removeOverlayForKey(key);
    } else {
      _ensureOverlayVisible(key, employees);
    }
  }

  void _ensureOverlayVisible(GlobalKey key, List<Map<String, dynamic>> employees) {
    if (_openOverlays[key] != null) return;
    // Cancel any pending close timer for this key so the overlay stays open
    // when explicitly requested to open (e.g., hover → open).
    _hoverTimers[key]?.cancel();
    _hoverTimers.remove(key);
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final size = box.size;
    final offset = box.localToGlobal(Offset.zero);
    final screenSize = MediaQuery.of(context).size;

    final popupHeight = math.min(360.0, employees.length * 72.0 + 16.0);
    bool showAbove = offset.dy + size.height + popupHeight + 12 > screenSize.height;
    double left = offset.dx;
    double top = showAbove ? (offset.dy - popupHeight - 12) : (offset.dy + size.height + 8);
    if (left + size.width > screenSize.width - 8) {
      left = screenSize.width - size.width - 8;
    }

    final overlay = OverlayEntry(builder: (context) {
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => _removeOverlayForKey(key),
            ),
          ),
          Positioned(
            left: left,
            top: top,
            width: size.width,
            child: MouseRegion(
              onEnter: (_) {
                _hoverTimers[key]?.cancel();
                _hoverTimers.remove(key);
              },
              onExit: (_) => _startCloseTimer(key),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!showAbove) _PopupCaret(color: Colors.white),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 6))],
                      ),
                      constraints: BoxConstraints(maxHeight: popupHeight),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: employees.map((emp) {
                      final empId = emp['employeeId'] as String? ?? emp['id'] as String;
                      final name = emp['employeeName'] as String? ?? 'Employee';
                      final role = emp['employeeRole'] as String? ?? emp['role'] as String? ?? 'EMPLOYEE';
                      final email = (emp['employeeEmail'] ?? emp['email'] ?? '') as String? ?? '';
                      final phone = (emp['employeePhone'] ?? emp['phone'] ?? '') as String? ?? '';
                      final initials = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'E';
                      return InkWell(
                        onTap: () {
                          // Navigate first, then remove the overlay. Removing the
                          // overlay before navigation could interfere with
                          // go_router on web (service worker / overlay context
                          // changes). Call navigation first to ensure context
                          // is valid.
                          try {
                            _openEmployeeDetail(emp);
                          } finally {
                            _removeOverlayForKey(key);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              CircleAvatar(radius: 18, backgroundColor: IndustrialColors.primaryContainer, foregroundColor: IndustrialColors.onPrimary, child: Text(initials, style: const TextStyle(fontWeight: FontWeight.w700))),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 4),
                                    Text('ID: $empId | $role', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12)),
                                    if (email.isNotEmpty || phone.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text('${email.isNotEmpty ? email : ''}${email.isNotEmpty && phone.isNotEmpty ? ' • ' : ''}${phone.isNotEmpty ? phone : ''}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: IndustrialColors.onSurfaceVariant, fontSize: 12)),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              if (showAbove) _PopupCaret(color: Colors.white, down: true),
            ],
          ),
        ),
        ))]);
    });

    Overlay.of(context).insert(overlay);
    _openOverlays[key] = overlay;
  }

  void _removeOverlayForKey(GlobalKey key) {
    final overlay = _openOverlays.remove(key);
    overlay?.remove();
    _hoverTimers[key]?.cancel();
    _hoverTimers.remove(key);
  }

  String _departmentFor(Map<String, dynamic> data) {
    final rawDepartment = (data['department'] as String?)?.trim();
    final role =
        ((data['employeeRole'] as String?) ?? (data['role'] as String?) ?? '')
            .trim()
            .toUpperCase();
    if (rawDepartment != null && rawDepartment.isNotEmpty) {
      return rawDepartment.toUpperCase();
    }
    if (role == 'DIRECTOR' || role == 'CEO') return role;
    return 'TECH';
  }
}

class _PopupCaret extends StatelessWidget {
  final Color color;
  final bool down;
  const _PopupCaret({this.color = Colors.white, this.down = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 10,
      child: CustomPaint(
        painter: _TrianglePainter(color: color, down: down),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  final bool down;
  _TrianglePainter({required this.color, this.down = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    if (!down) {
      path.moveTo(0, size.height);
      path.lineTo(size.width / 2, 0);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, 0);
      path.lineTo(size.width / 2, size.height);
      path.lineTo(size.width, 0);
    }
    path.close();
    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.08), 4, false);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

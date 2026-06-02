import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/attendance_session_service.dart';
import '../services/fcm_notification_service.dart';
import '../theme/industrial_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/employee_bottom_nav.dart';
import '../widgets/industrial_card.dart';
import '../widgets/primary_action_button.dart';
import '../widgets/status_chip.dart';
import '../services/app_firestore.dart';

class EmployeeDashboardScreen extends StatefulWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  State<EmployeeDashboardScreen> createState() =>
      _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen> {
  final _service = AttendanceSessionService();
  EmployeeProfile? _profile;
  AttendanceSession? _session;
  String? _todayFirstLoginAtIst;
  bool _outsideOfficeSession = false;
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final profile = await _service.loadEmployeeProfile();
      final session = await _service.loadActiveSession();
      final outsideOffice = await _service.hasOutsideOfficeSession();
      final todayFirstLoginAtIst = await _loadTodayFirstLoginAtIst(profile);
      await FcmNotificationService.instance.registerCurrentUser(
        department: profile.department,
      );
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _session = session;
        _todayFirstLoginAtIst = todayFirstLoginAtIst;
        _outsideOfficeSession = outsideOffice;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<String?> _loadTodayFirstLoginAtIst(EmployeeProfile profile) async {
    try {
      final docId = _service.attendanceDocumentId(
        profile.employeeId,
        _service.todayIst,
      );
      final snapshot = await FirebaseFirestore.instance
          .appCollection('attendance')
          .doc(docId)
          .get();
      return _firstLoginAtIst(snapshot.data());
    } catch (_) {
      return null;
    }
  }

  String? _firstLoginAtIst(Map<String, dynamic>? data) {
    final loginAtIst = data?['loginAtIst'] as String?;
    if (loginAtIst != null && loginAtIst.isNotEmpty) return loginAtIst;

    final segments = data?['segments'];
    if (segments is! List) return null;
    for (final segment in segments) {
      if (segment is! Map) continue;
      final inAtIst = segment['inAtIst'] as String?;
      if (inAtIst != null && inAtIst.isNotEmpty) return inAtIst;
    }
    return null;
  }

  String _formatLoginTime(String? loginAtIst) {
    if (loginAtIst == null || loginAtIst.isEmpty) return '-';
    final parsed = DateTime.tryParse(loginAtIst);
    if (parsed == null) return loginAtIst;
    final date =
        '${parsed.year.toString().padLeft(4, "0")}-${parsed.month.toString().padLeft(2, "0")}-${parsed.day.toString().padLeft(2, "0")}';
    final time =
        '${parsed.hour.toString().padLeft(2, "0")}:${parsed.minute.toString().padLeft(2, "0")}:${parsed.second.toString().padLeft(2, "0")}';
    return '$date $time IST';
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>>? _todayAttendanceStream() {
    final profile = _profile;
    if (profile == null) return null;
    final docId = _service.attendanceDocumentId(
      profile.employeeId,
      _service.todayIst,
    );
    return FirebaseFirestore.instance
        .appCollection('attendance')
        .doc(docId)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final employeeName = profile?.employeeName.trim() ?? '';
    final welcomeName = employeeName.isNotEmpty
        ? employeeName
        : (profile?.displayName ?? 'Employee');

    return AppShell(
      title: 'dhinadts',
      bottomNavigationBar: EmployeeBottomNav(
        currentIndex: 0,
        attendanceAlert: _outsideOfficeSession,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome $welcomeName',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _buildSessionStatusChip(),
            const SizedBox(height: 20),
            _buildTodayAttendanceCard(context),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _quickCard(
                    context,
                    'Calendar',
                    Icons.calendar_month,
                    () => context.go('/attendance-details'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _quickCard(
                    context,
                    'Salary',
                    Icons.receipt_long,
                    () => context.go('/salary'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _quickCard(
                    context,
                    'Exit Request',
                    Icons.exit_to_app,
                    () => context.go('/exit-company'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _quickCard(
                    context,
                    'Profile',
                    Icons.person,
                    () => context.go('/profile'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionStatusChip() {
    if (_isLoading) {
      return const StatusChip(
        label: 'Loading today attendance...',
        type: StatusChipType.pending,
        icon: Icons.sync,
      );
    }
    if (_loadError != null) {
      return StatusChip(
        label: _loadError!,
        type: StatusChipType.alert,
        icon: Icons.error_outline,
      );
    }
    return StatusChip(
      label: _session == null ? 'Face login required today' : 'Checked in',
      type: _session == null ? StatusChipType.pending : StatusChipType.success,
      icon: _session == null ? Icons.face : Icons.check_circle,
    );
  }

  Widget _buildTodayAttendanceCard(BuildContext context) {
    final stream = _todayAttendanceStream();
    if (_isLoading || stream == null) {
      return _todayAttendanceShell(
        context,
        children: const [
          LinearProgressIndicator(),
          SizedBox(height: 12),
          Text('Fetching today attendance...'),
        ],
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final loginAtIst = _firstLoginAtIst(data) ?? _todayFirstLoginAtIst;
        final sessionStatus = data?['sessionStatus'] as String?;
        final logoutAtIst = data?['logoutAtIst'] as String?;
        final hasLoggedInToday = loginAtIst != null && loginAtIst.isNotEmpty;

        if (snapshot.connectionState == ConnectionState.waiting &&
            !hasLoggedInToday) {
          return _todayAttendanceShell(
            context,
            children: const [
              LinearProgressIndicator(),
              SizedBox(height: 12),
              Text('Fetching today attendance...'),
            ],
          );
        }

        return _todayAttendanceShell(
          context,
          children: [
            Text('Login: ${_formatLoginTime(loginAtIst)}'),
            const SizedBox(height: 6),
            Text(
              logoutAtIst == null || logoutAtIst.isEmpty
                  ? 'Final logout: 6:00 PM IST automatic'
                  : 'Logout: ${_formatLoginTime(logoutAtIst)}',
            ),
            const SizedBox(height: 6),
            const Text('Eligibility: 7 office hours required'),
            const SizedBox(height: 6),
            Text(
              hasLoggedInToday
                  ? 'Daily face authentication completed'
                  : 'Daily face authentication pending',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: IndustrialColors.onSurfaceVariant,
              ),
            ),
            if (sessionStatus != null) ...[
              const SizedBox(height: 10),
              StatusChip(
                label: sessionStatus.replaceAll('_', ' ').toUpperCase(),
                type: sessionStatus == 'active'
                    ? StatusChipType.success
                    : StatusChipType.neutral,
              ),
            ],
            const SizedBox(height: 18),
            PrimaryActionButton(
              label: hasLoggedInToday
                  ? 'FACE LOGIN DONE TODAY'
                  : 'FACE ATTENDANCE',
              icon: Icons.face,
              onPressed: hasLoggedInToday
                  ? null
                  : () => context.go('/face-attendance'),
            ),
          ],
        );
      },
    );
  }

  Widget _todayAttendanceShell(
    BuildContext context, {
    required List<Widget> children,
  }) {
    return IndustrialCard(
      highlighted: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today Attendance',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _quickCard(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    return IndustrialCard(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: IndustrialColors.primary, size: 30),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

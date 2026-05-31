import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/attendance_session_service.dart';
import '../theme/industrial_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/employee_bottom_nav.dart';
import '../widgets/industrial_card.dart';
import '../widgets/status_chip.dart';

class AttendanceLogScreen extends StatefulWidget {
  const AttendanceLogScreen({super.key});

  @override
  State<AttendanceLogScreen> createState() => _AttendanceLogScreenState();
}

class _AttendanceLogScreenState extends State<AttendanceLogScreen> {
  final _service = AttendanceSessionService();
  EmployeeProfile? _profile;
  bool _outsideOfficeSession = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await _service.loadEmployeeProfile();
    final outsideOffice = await _service.hasOutsideOfficeSession();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _outsideOfficeSession = outsideOffice;
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _attendanceStream() {
    if (_profile == null) {
      return const Stream.empty();
    }
    return FirebaseFirestore.instance
        .collection('attendance')
        .where('employeeId', isEqualTo: _profile!.employeeId)
        .snapshots();
  }

  String _formatTime(String? ist) {
    if (ist == null || ist.isEmpty) return '-';
    final parsed = DateTime.tryParse(ist);
    if (parsed == null) return ist;
    return '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Attendance Log',
      bottomNavigationBar: EmployeeBottomNav(
        currentIndex: 2,
        attendanceAlert: _outsideOfficeSession,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attendance Log',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Review your attendance history and office entry flags.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: IndustrialColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _attendanceStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text(snapshot.error.toString()));
                  }
                  final docs = List.of(snapshot.data?.docs ?? []);
                  docs.sort((a, b) {
                    final aDate =
                        DateTime.tryParse(
                          a.data()['loginAtIst'] as String? ?? '',
                        ) ??
                        DateTime.fromMillisecondsSinceEpoch(0);
                    final bDate =
                        DateTime.tryParse(
                          b.data()['loginAtIst'] as String? ?? '',
                        ) ??
                        DateTime.fromMillisecondsSinceEpoch(0);
                    return bDate.compareTo(aDate);
                  });
                  if (docs.isEmpty) {
                    return const Center(
                      child: StatusChip(
                        label: 'No attendance logs yet',
                        type: StatusChipType.neutral,
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data();
                      final status = data['attendanceStatus'] as String? ?? '-';
                      final outsideOffice = status == 'outside_office';
                      final loginAt = _formatTime(
                        data['loginAtIst'] as String?,
                      );
                      final logoutAt = _formatTime(
                        data['logoutAtIst'] as String?,
                      );
                      final distance = (data['officeDistanceMeters'] as num?)
                          ?.toDouble();
                      final grace = data['officeArrivalGraceMinutes'] as int?;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: IndustrialCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      data['loginDateIst'] as String? ?? '-',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  StatusChip(
                                    label: status
                                        .replaceAll('_', ' ')
                                        .toUpperCase(),
                                    type: outsideOffice
                                        ? StatusChipType.alert
                                        : StatusChipType.success,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('Login: $loginAt'),
                              Text('Logout: $logoutAt'),
                              if (distance != null)
                                Text(
                                  'Office distance: ${distance.toStringAsFixed(1)}m',
                                ),
                              if (grace != null)
                                Text('Arrival grace: $grace mins'),
                              if (outsideOffice) ...[
                                const SizedBox(height: 8),
                                StatusChip(
                                  label: 'RED FLAG: outside office entry',
                                  type: StatusChipType.alert,
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
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

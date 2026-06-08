import '../widgets/app_shell.dart';
import '../widgets/status_chip.dart';
import 'package:flutter/material.dart';
import '../theme/industrial_theme.dart';
import '../services/app_firestore.dart';
import '../widgets/industrial_card.dart';
import '../widgets/admin_bottom_nav.dart';
import '../widgets/primary_action_button.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminMarkAttendanceScreen extends StatefulWidget {
  const AdminMarkAttendanceScreen({super.key, this.requestId, this.employeeId});

  final String? requestId;
  final String? employeeId;

  @override
  State<AdminMarkAttendanceScreen> createState() =>
      _AdminMarkAttendanceScreenState();
}

class _AdminMarkAttendanceScreenState extends State<AdminMarkAttendanceScreen> {
  final _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> _requestStream() {
    final employeeId = widget.employeeId?.trim();
    if (employeeId != null && employeeId.isNotEmpty) {
      return _firestore
          .appCollection('attendance_mark_requests')
          .where('employeeId', isEqualTo: employeeId)
          .snapshots();
    }
    return _firestore.appCollection('attendance_mark_requests').snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _considerationStream() {
    final employeeId = widget.employeeId?.trim();
    if (employeeId != null && employeeId.isNotEmpty) {
      return _firestore
          .appCollection('attendance_consideration_requests')
          .where('employeeId', isEqualTo: employeeId)
          .snapshots();
    }
    return _firestore
        .appCollection('attendance_consideration_requests')
        .snapshots();
  }

  Future<void> _processRequest({
    required String requestId,
    required Map<String, dynamic> data,
    required bool approved,
    required String adminReason,
  }) async {
    final employeeId = data['employeeId'] as String? ?? '';
    final date =
        data['date'] as String? ?? data['loginDateIst'] as String? ?? '';
    if (employeeId.isEmpty || date.isEmpty) {
      throw StateError('Employee ID and date are required');
    }

    final attendanceId = '${_safeId(employeeId)}_$date';
    final batch = _firestore.batch();
    final requestRef = _firestore
        .appCollection('attendance_mark_requests')
        .doc(requestId);
    final attendanceRef = _firestore
        .appCollection('attendance')
        .doc(attendanceId);
    final nowIst = DateTime.now()
        .toUtc()
        .add(const Duration(hours: 5, minutes: 30))
        .toIso8601String();

    batch.set(requestRef, {
      'status': approved ? 'approved' : 'rejected',
      'adminReason': adminReason,
      'respondedAt': FieldValue.serverTimestamp(),
      'respondedAtIst': nowIst,
    }, SetOptions(merge: true));

    if (approved) {
      batch.set(attendanceRef, {
        'employeeId': employeeId,
        'employeeName': data['employeeName'] ?? 'Employee',
        'status': 'present',
        'sessionStatus': 'admin_marked',
        'attendanceStatus': 'attendance_considered',
        'dayStatus': 'present',
        'loginDateIst': date,
        'officeMinutes': 420,
        'eligibleMinutes': 420,
        'method': 'admin_approval',
        'adminReason': adminReason,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedAtIst': nowIst,
      }, SetOptions(merge: true));
    }

    batch.set(_firestore.appCollection('audit_logs').doc(), {
      'action': approved
          ? 'attendance_mark_request.approved'
          : 'attendance_mark_request.rejected',
      'entityType': 'attendance_mark_request',
      'entityId': requestId,
      'actorUid': FirebaseAuth.instance.currentUser?.uid,
      'actorEmail': FirebaseAuth.instance.currentUser?.email,
      'metadata': {
        'attendanceId': attendanceId,
        'employeeId': employeeId,
        'date': date,
        'adminReason': adminReason,
      },
      'createdAt': FieldValue.serverTimestamp(),
      'createdAtIst': nowIst,
    });

    await batch.commit();
  }

  Future<void> _processConsiderationRequest({
    required String requestId,
    required Map<String, dynamic> data,
    required bool approved,
    required String adminReason,
  }) async {
    final attendanceId = data['attendanceDocumentId'] as String? ?? '';
    final employeeId = data['employeeId'] as String? ?? '';
    final date =
        data['date'] as String? ?? data['loginDateIst'] as String? ?? '';
    if (attendanceId.isEmpty || employeeId.isEmpty || date.isEmpty) {
      throw StateError('Attendance request details are incomplete');
    }

    final nowIst = DateTime.now()
        .toUtc()
        .add(const Duration(hours: 5, minutes: 30))
        .toIso8601String();
    final batch = _firestore.batch();
    final requestRef = _firestore
        .appCollection('attendance_consideration_requests')
        .doc(requestId);
    final attendanceRef = _firestore
        .appCollection('attendance')
        .doc(attendanceId);

    batch.set(requestRef, {
      'status': approved ? 'approved' : 'rejected',
      'adminReason': adminReason,
      'respondedAt': FieldValue.serverTimestamp(),
      'respondedAtIst': nowIst,
      'respondedByUid': FirebaseAuth.instance.currentUser?.uid,
      'respondedByEmail': FirebaseAuth.instance.currentUser?.email,
    }, SetOptions(merge: true));

    batch.set(attendanceRef, {
      'breakConsiderationStatus': approved ? 'approved' : 'rejected',
      'breakConsiderationAdminReason': adminReason,
      'breakConsiderationRespondedAt': FieldValue.serverTimestamp(),
      'breakConsiderationRespondedAtIst': nowIst,
      if (approved) 'attendanceStatus': 'attendance_considered',
      if (approved) 'dayStatus': 'present',
      if (!approved) 'attendanceStatus': 'not_considered_attendance',
      if (!approved) 'dayStatus': 'not_considered',
      'logs': FieldValue.arrayUnion([
        {
          'event': approved
              ? 'break_consideration_approved'
              : 'break_consideration_rejected',
          'atIst': nowIst,
          'reason': adminReason,
        },
      ]),
    }, SetOptions(merge: true));

    batch.set(_firestore.appCollection('audit_logs').doc(), {
      'action': approved
          ? 'attendance.break_consideration_approved'
          : 'attendance.break_consideration_rejected',
      'entityType': 'attendance_consideration_request',
      'entityId': requestId,
      'actorUid': FirebaseAuth.instance.currentUser?.uid,
      'actorEmail': FirebaseAuth.instance.currentUser?.email,
      'metadata': {
        'attendanceId': attendanceId,
        'employeeId': employeeId,
        'date': date,
        'adminReason': adminReason,
      },
      'createdAt': FieldValue.serverTimestamp(),
      'createdAtIst': nowIst,
    });

    await batch.commit();
  }

  Future<void> _showDecisionDialog({
    required String requestId,
    required Map<String, dynamic> data,
    required bool approved,
    bool consideration = false,
  }) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(approved ? 'Approve Attendance' : 'Reject Attendance'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: approved ? 'Approval note' : 'Rejection reason',
            hintText: 'Enter admin reason',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              if (consideration) {
                await _processConsiderationRequest(
                  requestId: requestId,
                  data: data,
                  approved: approved,
                  adminReason: controller.text.trim(),
                );
              } else {
                await _processRequest(
                  requestId: requestId,
                  data: data,
                  approved: approved,
                  adminReason: controller.text.trim(),
                );
              }
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    approved
                        ? 'Attendance request approved'
                        : 'Attendance request rejected',
                  ),
                ),
              );
            },
            child: Text(approved ? 'APPROVE' : 'REJECT'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Mark Attendance',
      showBackButton: false,
      bottomNavigationBar: const AdminBottomNav(currentIndex: 1),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle('Manual Attendance Requests'),
          _markRequestsSection(),
          const SizedBox(height: 20),
          _sectionTitle('Break Consideration Requests'),
          _considerationRequestsSection(),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _markRequestsSection() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _requestStream(),
      builder: (context, snapshot) {
        final requests = (snapshot.data?.docs ?? []).where((doc) {
          final status = doc.data()['status'] as String? ?? 'pending';
          return status == 'pending' || status == 'requested';
        }).toList();
        requests.sort((a, b) {
          if (a.id == widget.requestId) return -1;
          if (b.id == widget.requestId) return 1;
          return 0;
        });
        if (requests.isEmpty) {
          return const StatusChip(
            label: 'No attendance mark requests',
            type: StatusChipType.neutral,
          );
        }
        return Column(
          children: [
            for (final doc in requests) ...[
              _requestCard(doc.id, doc.data()),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }

  Widget _considerationRequestsSection() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _considerationStream(),
      builder: (context, snapshot) {
        final requests = (snapshot.data?.docs ?? []).where((doc) {
          final status = doc.data()['status'] as String? ?? 'requested';
          return status == 'pending' || status == 'requested';
        }).toList();
        if (requests.isEmpty) {
          return const StatusChip(
            label: 'No break consideration requests',
            type: StatusChipType.neutral,
          );
        }
        return Column(
          children: [
            for (final doc in requests) ...[
              _requestCard(doc.id, doc.data(), consideration: true),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }

  Widget _requestCard(
    String requestId,
    Map<String, dynamic> data, {
    bool consideration = false,
  }) {
    return IndustrialCard(
      highlighted: requestId == widget.requestId,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                consideration ? Icons.timer_off : Icons.how_to_reg,
                color: IndustrialColors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  data['employeeName'] as String? ?? 'Employee',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              StatusChip(
                label: data['date'] as String? ?? '-',
                type: StatusChipType.pending,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Team: ${data['department'] ?? data['team'] ?? '-'}'),
          const SizedBox(height: 4),
          if (consideration)
            Text('Break minutes: ${data['lastBreakMinutes'] ?? '-'}'),
          const SizedBox(height: 4),
          Text('Reason: ${data['reason'] ?? 'No reason provided'}'),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: PrimaryActionButton(
                  label: 'REJECT',
                  icon: Icons.close,
                  style: ActionButtonStyle.tertiary,
                  onPressed: () => _showDecisionDialog(
                    requestId: requestId,
                    data: data,
                    approved: false,
                    consideration: consideration,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryActionButton(
                  label: 'APPROVE',
                  icon: Icons.check,
                  onPressed: () => _showDecisionDialog(
                    requestId: requestId,
                    data: data,
                    approved: true,
                    consideration: consideration,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _safeId(String value) {
    return value.trim().replaceAll(RegExp(r'[/#?\[\]]'), '_');
  }
}

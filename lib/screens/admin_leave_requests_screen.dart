import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/industrial_theme.dart';
import '../widgets/admin_bottom_nav.dart';
import '../widgets/app_shell.dart';
import '../widgets/industrial_card.dart';
import '../widgets/primary_action_button.dart';
import '../widgets/status_chip.dart';
import '../services/app_firestore.dart';

class AdminLeaveRequestsScreen extends StatefulWidget {
  const AdminLeaveRequestsScreen({super.key});

  @override
  State<AdminLeaveRequestsScreen> createState() =>
      _AdminLeaveRequestsScreenState();
}

class _AdminLeaveRequestsScreenState extends State<AdminLeaveRequestsScreen> {
  final _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> _leaveStream() {
    return _firestore.appCollection('leave_requests').snapshots();
  }

  Future<void> _processLeave({
    required String docId,
    required Map<String, dynamic> data,
    required bool approved,
    required String adminReason,
  }) async {
    final employeeId = data['employeeId'] as String? ?? '';
    final date = data['date'] as String? ?? '';
    if (employeeId.isEmpty || date.isEmpty) {
      throw StateError('Employee ID and date are required');
    }

    final attendanceRef = _firestore.appCollection('attendance').doc(docId);
    final leaveRef = _firestore.appCollection('leave_requests').doc(docId);
    final batch = _firestore.batch();
    final decisionFields = _decisionFields(
      approved: approved,
      adminReason: adminReason,
    );

    batch.set(leaveRef, {
      'status': approved ? 'approved_leave' : 'rejected_leave',
      'adminReason': adminReason,
      'respondedAt': FieldValue.serverTimestamp(),
      ...decisionFields,
    }, SetOptions(merge: true));

    batch.set(attendanceRef, {
      'employeeId': employeeId,
      'employeeName': data['employeeName'] ?? 'Employee',
      'employee': data['employee'],
      'status': approved ? 'leave' : 'absent',
      'sessionStatus': 'admin_reviewed',
      'attendanceStatus': approved
          ? 'approved_leave'
          : 'not_considered_attendance',
      'dayStatus': approved ? 'approved_leave' : 'not_considered',
      'leaveStatus': approved ? 'approved_leave' : 'rejected_leave',
      'reason': adminReason.isEmpty
          ? (approved ? 'Approved by admin' : 'Rejected by admin')
          : adminReason,
      'adminReason': adminReason,
      'loginDateIst': date,
      'updatedAt': FieldValue.serverTimestamp(),
      ...decisionFields,
    }, SetOptions(merge: true));

    await batch.commit();
  }

  Map<String, dynamic> _decisionFields({
    required bool approved,
    required String adminReason,
  }) {
    final admin = FirebaseAuth.instance.currentUser;
    final adminEmail = admin?.email ?? '';
    final displayName = admin?.displayName?.trim();
    final adminName = displayName == null || displayName.isEmpty
        ? (adminEmail.isEmpty ? 'Admin' : adminEmail)
        : displayName;
    final decisionAtIst = DateTime.now()
        .toUtc()
        .add(const Duration(hours: 5, minutes: 30))
        .toIso8601String();
    final status = approved ? 'approved_leave' : 'rejected_leave';

    return {
      'decision': approved ? 'approved' : 'rejected',
      'decisionStatus': status,
      'decisionReason': adminReason,
      'decisionByUid': admin?.uid,
      'decisionByEmail': adminEmail,
      'decisionByName': adminName,
      'decisionAt': FieldValue.serverTimestamp(),
      'decisionAtIst': decisionAtIst,
      if (approved) ...{
        'approvedByUid': admin?.uid,
        'approvedByEmail': adminEmail,
        'approvedByName': adminName,
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedAtIst': decisionAtIst,
      } else ...{
        'rejectedByUid': admin?.uid,
        'rejectedByEmail': adminEmail,
        'rejectedByName': adminName,
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedAtIst': decisionAtIst,
      },
    };
  }

  Future<void> _showReasonDialog({
    required String docId,
    required Map<String, dynamic> data,
    required bool approved,
  }) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(approved ? 'Approve Leave' : 'Reject Leave'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: approved ? 'Approval note' : 'Rejection reason',
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
              await _processLeave(
                docId: docId,
                data: data,
                approved: approved,
                adminReason: controller.text.trim(),
              );
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(approved ? 'Leave approved' : 'Leave rejected'),
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
      title: 'Approve Leaves',
      bottomNavigationBar: const AdminBottomNav(currentIndex: 1),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _leaveStream(),
        builder: (context, snapshot) {
          final allRequests = snapshot.data?.docs ?? [];
          final pendingRequests = allRequests.where((doc) {
            final status = doc.data()['status'] as String? ?? '';
            return _isPendingStatus(status);
          }).toList();
          final completedRequests = allRequests.where((doc) {
            final status = doc.data()['status'] as String? ?? '';
            return _isCompletedStatus(status);
          }).toList();

          pendingRequests.sort(_sortByRequestDateDesc);
          completedRequests.sort(_sortByDecisionDateDesc);

          if (pendingRequests.isEmpty && completedRequests.isEmpty) {
            return const Center(
              child: StatusChip(
                label: 'No leave requests',
                type: StatusChipType.neutral,
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _sectionHeader('Pending Requests', pendingRequests.length),
              if (pendingRequests.isEmpty)
                _emptySection('No pending leave requests')
              else
                ...pendingRequests.map(
                  (doc) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _pendingLeaveCard(doc.id, doc.data()),
                  ),
                ),
              const SizedBox(height: 8),
              _sectionHeader(
                'Approved / Rejected History',
                completedRequests.length,
              ),
              if (completedRequests.isEmpty)
                _emptySection('No reviewed leaves yet')
              else
                ...completedRequests.map(
                  (doc) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _completedLeaveCard(doc.data()),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          StatusChip(label: '$count', type: StatusChipType.neutral),
        ],
      ),
    );
  }

  Widget _emptySection(String message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: IndustrialCard(
        child: Center(
          child: StatusChip(label: message, type: StatusChipType.neutral),
        ),
      ),
    );
  }

  Widget _pendingLeaveCard(String docId, Map<String, dynamic> data) {
    final details = _employeeDetails(data);
    return IndustrialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _employeeHeader(
            employeeName: details.employeeName,
            team: details.team,
            trailing: StatusChip(
              label: data['date'] as String? ?? '-',
              type: StatusChipType.pending,
            ),
          ),
          const SizedBox(height: 12),
          Text('Reason: ${data['reason'] ?? 'No reason provided'}'),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: PrimaryActionButton(
                  label: 'REJECT',
                  icon: Icons.close,
                  style: ActionButtonStyle.tertiary,
                  onPressed: () => _showReasonDialog(
                    docId: docId,
                    data: data,
                    approved: false,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryActionButton(
                  label: 'APPROVE',
                  icon: Icons.check,
                  onPressed: () => _showReasonDialog(
                    docId: docId,
                    data: data,
                    approved: true,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _completedLeaveCard(Map<String, dynamic> data) {
    final details = _employeeDetails(data);
    final status = data['status'] as String? ?? '';
    final approved = status.contains('approved');
    final rejected = status.contains('rejected');
    final statusType = approved
        ? StatusChipType.success
        : (rejected ? StatusChipType.alert : StatusChipType.neutral);
    final decisionBy = _decisionBy(data, approved: approved);
    final decisionAt = _decisionAt(data, approved: approved);
    final decisionReason = _decisionReason(data);

    return IndustrialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _employeeHeader(
            employeeName: details.employeeName,
            team: details.team,
            trailing: StatusChip(
              label: status.replaceAll('_', ' '),
              type: statusType,
            ),
          ),
          const SizedBox(height: 12),
          _detailRow('Leave date', data['date'] as String? ?? '-'),
          _detailRow('Employee reason', '${data['reason'] ?? '-'}'),
          _detailRow(approved ? 'Approved by' : 'Rejected by', decisionBy),
          _detailRow(approved ? 'Approved at' : 'Rejected at', decisionAt),
          if (decisionReason.isNotEmpty)
            _detailRow(
              approved ? 'Approval note' : 'Rejection reason',
              decisionReason,
            ),
        ],
      ),
    );
  }

  Widget _employeeHeader({
    required String employeeName,
    required Object team,
    required Widget trailing,
  }) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: IndustrialColors.primary,
          foregroundColor: IndustrialColors.onPrimary,
          child: Text(
            (employeeName.isEmpty ? 'E' : employeeName)
                .substring(0, 1)
                .toUpperCase(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                employeeName.isEmpty ? 'Employee' : employeeName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text('Team: $team', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        trailing,
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  _EmployeeDetails _employeeDetails(Map<String, dynamic> data) {
    final employee = data['employee'] as Map<String, dynamic>?;
    return _EmployeeDetails(
      employeeName: data['employeeName'] as String? ?? 'Employee',
      team:
          data['department'] ?? data['team'] ?? employee?['department'] ?? '-',
    );
  }

  bool _isPendingStatus(String status) {
    return status == 'requested_leave' || status == 'pending' || status.isEmpty;
  }

  bool _isCompletedStatus(String status) {
    return status == 'approved_leave' ||
        status == 'rejected_leave' ||
        status == 'approved' ||
        status == 'rejected';
  }

  int _sortByRequestDateDesc(
    QueryDocumentSnapshot<Map<String, dynamic>> a,
    QueryDocumentSnapshot<Map<String, dynamic>> b,
  ) {
    return _sortableDate(
      b.data(),
      pending: true,
    ).compareTo(_sortableDate(a.data(), pending: true));
  }

  int _sortByDecisionDateDesc(
    QueryDocumentSnapshot<Map<String, dynamic>> a,
    QueryDocumentSnapshot<Map<String, dynamic>> b,
  ) {
    return _sortableDate(b.data()).compareTo(_sortableDate(a.data()));
  }

  String _sortableDate(Map<String, dynamic> data, {bool pending = false}) {
    final value = pending
        ? data['requestedAtIst'] ?? data['date'] ?? ''
        : data['decisionAtIst'] ??
              data['approvedAtIst'] ??
              data['rejectedAtIst'] ??
              data['respondedAtIst'] ??
              data['date'] ??
              '';
    return value.toString();
  }

  String _decisionBy(Map<String, dynamic> data, {required bool approved}) {
    final value = approved
        ? data['approvedByName'] ??
              data['approvedByEmail'] ??
              data['decisionByName'] ??
              data['decisionByEmail']
        : data['rejectedByName'] ??
              data['rejectedByEmail'] ??
              data['decisionByName'] ??
              data['decisionByEmail'];
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? 'Admin' : text;
  }

  String _decisionAt(Map<String, dynamic> data, {required bool approved}) {
    final value = approved
        ? data['approvedAtIst'] ??
              data['decisionAtIst'] ??
              data['respondedAtIst']
        : data['rejectedAtIst'] ??
              data['decisionAtIst'] ??
              data['respondedAtIst'];
    if (value is Timestamp) {
      return value.toDate().toLocal().toString().split('.').first;
    }
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? '-' : text.replaceFirst('T', ' ').split('.').first;
  }

  String _decisionReason(Map<String, dynamic> data) {
    return (data['adminReason'] ?? data['decisionReason'] ?? '')
        .toString()
        .trim();
  }
}

class _EmployeeDetails {
  const _EmployeeDetails({required this.employeeName, required this.team});

  final String employeeName;
  final Object team;
}

import 'package:cloud_firestore/cloud_firestore.dart';
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

    batch.set(leaveRef, {
      'status': approved ? 'approved_leave' : 'rejected_leave',
      'adminReason': adminReason,
      'respondedAt': FieldValue.serverTimestamp(),
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
      'loginDateIst': date,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
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
          final requests = (snapshot.data?.docs ?? []).where((doc) {
            final status = doc.data()['status'] as String? ?? '';
            return status == 'requested_leave' ||
                status == 'pending' ||
                status.isEmpty;
          }).toList();

          if (requests.isEmpty) {
            return const Center(
              child: StatusChip(
                label: 'No pending leave requests',
                type: StatusChipType.neutral,
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = requests[index];
              final data = doc.data();
              final employee = data['employee'] as Map<String, dynamic>?;
              final team =
                  data['department'] ??
                  data['team'] ??
                  employee?['department'] ??
                  '-';
              final employeeName =
                  data['employeeName'] as String? ?? 'Employee';
              return IndustrialCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                                employeeName.isEmpty
                                    ? 'Employee'
                                    : employeeName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Team: $team',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        StatusChip(
                          label: data['date'] as String? ?? '-',
                          type: StatusChipType.pending,
                        ),
                      ],
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
                              docId: doc.id,
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
                              docId: doc.id,
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
            },
          );
        },
      ),
    );
  }
}

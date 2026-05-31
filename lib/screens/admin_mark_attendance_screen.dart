import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/industrial_theme.dart';
import '../widgets/admin_bottom_nav.dart';
import '../widgets/app_shell.dart';
import '../widgets/industrial_card.dart';
import '../widgets/primary_action_button.dart';
import '../widgets/status_chip.dart';

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
          .collection('attendance_mark_requests')
          .where('employeeId', isEqualTo: employeeId)
          .snapshots();
    }
    return _firestore.collection('attendance_mark_requests').snapshots();
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
        .collection('attendance_mark_requests')
        .doc(requestId);
    final attendanceRef = _firestore.collection('attendance').doc(attendanceId);
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

    await batch.commit();
  }

  Future<void> _showDecisionDialog({
    required String requestId,
    required Map<String, dynamic> data,
    required bool approved,
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
              await _processRequest(
                requestId: requestId,
                data: data,
                approved: approved,
                adminReason: controller.text.trim(),
              );
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
      bottomNavigationBar: const AdminBottomNav(currentIndex: 1),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
            return const Center(
              child: StatusChip(
                label: 'No attendance mark requests',
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
              return IndustrialCard(
                highlighted: doc.id == widget.requestId,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.how_to_reg,
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
                              requestId: doc.id,
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
                            onPressed: () => _showDecisionDialog(
                              requestId: doc.id,
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

  String _safeId(String value) {
    return value.trim().replaceAll(RegExp(r'[/#?\[\]]'), '_');
  }
}

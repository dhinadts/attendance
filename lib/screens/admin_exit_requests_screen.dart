import '../widgets/app_shell.dart';
import '../widgets/status_chip.dart';
import 'package:flutter/material.dart';
import '../theme/industrial_theme.dart';
import '../services/app_firestore.dart';
import '../widgets/industrial_card.dart';
import '../widgets/admin_bottom_nav.dart';
import '../widgets/primary_action_button.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class AdminExitRequestsScreen extends StatefulWidget {
  const AdminExitRequestsScreen({super.key, this.requestId, this.employeeId});

  final String? requestId;
  final String? employeeId;

  @override
  State<AdminExitRequestsScreen> createState() =>
      _AdminExitRequestsScreenState();
}

class _AdminExitRequestsScreenState extends State<AdminExitRequestsScreen> {
  final _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> _requestStream() {
    var query = _firestore.appCollection('exit_requests').limit(100);
    final employeeId = widget.employeeId?.trim();
    if (employeeId != null && employeeId.isNotEmpty) {
      return _firestore
          .appCollection('exit_requests')
          .where('employeeId', isEqualTo: employeeId)
          .snapshots();
    }
    return query.snapshots();
  }

  Future<void> _processRequest({
    required String requestId,
    required bool approved,
    required String adminReason,
  }) async {
    await _firestore.appCollection('exit_requests').doc(requestId).set({
      'status': approved ? 'approved' : 'rejected',
      'adminReason': adminReason.trim(),
      'respondedAt': FieldValue.serverTimestamp(),
      'respondedAtIst': DateTime.now()
          .toUtc()
          .add(const Duration(hours: 5, minutes: 30))
          .toIso8601String(),
    }, SetOptions(merge: true));
  }

  Future<void> _showDecisionDialog({
    required String requestId,
    required bool approved,
  }) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(approved ? 'Approve Exit Request' : 'Reject Exit Request'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: approved ? 'Approval note' : 'Rejection reason',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(approved ? 'APPROVE' : 'REJECT'),
          ),
        ],
      ),
    );
    if (reason == null) return;

    await _processRequest(
      requestId: requestId,
      approved: approved,
      adminReason: reason,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          approved ? 'Exit request approved' : 'Exit request rejected',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Exit Requests',
      bottomNavigationBar: const AdminBottomNav(currentIndex: 0),
      showBackButton: false,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _requestStream(),
        builder: (context, snapshot) {
          final docs = List.of(snapshot.data?.docs ?? []);
          docs.sort((a, b) {
            if (a.id == widget.requestId) return -1;
            if (b.id == widget.requestId) return 1;
            final aDate = a.data()['requestedAtIst'] as String? ?? '';
            final bDate = b.data()['requestedAtIst'] as String? ?? '';
            return bDate.compareTo(aDate);
          });

          if (docs.isEmpty) {
            return const Center(
              child: StatusChip(
                label: 'No exit requests',
                type: StatusChipType.neutral,
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = docs[index];
              return _requestCard(doc.id, doc.data());
            },
          );
        },
      ),
    );
  }

  Widget _requestCard(String requestId, Map<String, dynamic> data) {
    final status = data['status'] as String? ?? 'pending';
    final highlighted = requestId == widget.requestId;
    final chipType = switch (status) {
      'approved' => StatusChipType.success,
      'rejected' => StatusChipType.alert,
      _ => StatusChipType.pending,
    };

    return IndustrialCard(
      highlighted: highlighted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.exit_to_app, color: IndustrialColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  data['employeeName'] as String? ?? 'Employee',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              StatusChip(label: status.toUpperCase(), type: chipType),
            ],
          ),
          const SizedBox(height: 10),
          Text('Employee ID: ${data['employeeId'] ?? '-'}'),
          Text('Leaving date: ${data['leavingDate'] ?? '-'}'),
          const SizedBox(height: 8),
          Text(
            data['subject'] as String? ?? 'Relieving request',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(data['reason'] as String? ?? '-'),
          if ((data['adminReason'] as String?)?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text('Admin reason: ${data['adminReason']}'),
          ],
          if (status == 'pending') ...[
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
                      requestId: requestId,
                      approved: true,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

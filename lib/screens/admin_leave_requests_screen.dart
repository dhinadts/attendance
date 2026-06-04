import '../utils/responsive.dart';
import '../widgets/app_shell.dart';
import '../widgets/status_chip.dart';
import 'package:flutter/material.dart';
import '../theme/industrial_theme.dart';
import '../services/app_firestore.dart';
import '../widgets/industrial_card.dart';
import '../widgets/admin_bottom_nav.dart';
import '../widgets/primary_action_button.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminLeaveRequestsScreen extends StatefulWidget {
  const AdminLeaveRequestsScreen({super.key});

  @override
  State<AdminLeaveRequestsScreen> createState() =>
      _AdminLeaveRequestsScreenState();
}

class _AdminLeaveRequestsScreenState extends State<AdminLeaveRequestsScreen> {
  final _firestore = FirebaseFirestore.instance;
  final Set<String> _processingDocIds = {};

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

  Future<void> _reviewLeave({
    required String docId,
    required Map<String, dynamic> data,
    required bool approved,
  }) async {
    if (_processingDocIds.contains(docId)) return;
    final reason = await _showDecisionSheet(approved: approved);
    if (reason == null) return;

    setState(() => _processingDocIds.add(docId));
    try {
      await _processLeave(
        docId: docId,
        data: data,
        approved: approved,
        adminReason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approved ? 'Leave approved' : 'Leave rejected')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update leave request: $error'),
          backgroundColor: IndustrialColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _processingDocIds.remove(docId));
      }
    }
  }

  Future<String?> _showDecisionSheet({required bool approved}) async {
    final controller = TextEditingController();
    String? errorText;
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: IndustrialColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: approved
                            ? IndustrialColors.secondary
                            : IndustrialColors.error,
                        foregroundColor: Colors.white,
                        child: Icon(approved ? Icons.check : Icons.close),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          approved ? 'Approve Leave' : 'Reject Leave',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    approved
                        ? 'Add an optional note for this approval.'
                        : 'A rejection reason is required and will be shared with the employee.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: IndustrialColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: !approved,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      labelText: approved
                          ? 'Approval note'
                          : 'Rejection reason *',
                      hintText: approved
                          ? 'Approved as requested'
                          : 'Example: Project deadline requires presence',
                      errorText: errorText,
                      prefixIcon: Icon(
                        approved ? Icons.edit_note : Icons.report_gmailerrorred,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          child: const Text('CANCEL'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: approved
                                ? IndustrialColors.secondary
                                : IndustrialColors.error,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            final reason = controller.text.trim();
                            if (!approved && reason.isEmpty) {
                              setSheetState(() {
                                errorText =
                                    'Please enter a reason before rejecting.';
                              });
                              return;
                            }
                            Navigator.of(sheetContext).pop(reason);
                          },
                          icon: Icon(approved ? Icons.check : Icons.close),
                          label: Text(approved ? 'APPROVE' : 'REJECT'),
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
    );
    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Approve Leaves',
      bottomNavigationBar: const AdminBottomNav(currentIndex: 1),
      showBackButton: false,
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
              if (pendingRequests.isNotEmpty) ...[
                StatusChip(
                  label: 'Swipe right to approve, left to reject',
                  type: StatusChipType.neutral,
                  icon: Icons.swipe,
                ),
                const SizedBox(height: 12),
              ],
              if (pendingRequests.isEmpty)
                _emptySection('No pending leave requests')
              else
                Builder(
                  builder: (context) {
                    final isWeb = Responsive.isDesktop(context);
                    final isTablet = Responsive.isTablet(context);
                    final cross = isWeb ? 3 : (isTablet ? 2 : 1);
                    final desiredCardHeight = 160.0;
                    return GridView.count(
                      crossAxisCount: cross,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio:
                          (MediaQuery.of(context).size.width / cross) /
                          desiredCardHeight,
                      children: pendingRequests.map((doc) {
                        return SizedBox(
                          height: desiredCardHeight,
                          child: _pendingLeaveCard(doc.id, doc.data()),
                        );
                      }).toList(),
                    );
                  },
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
    final isProcessing = _processingDocIds.contains(docId);
    return Dismissible(
      key: ValueKey('leave_$docId'),
      confirmDismiss: (direction) async {
        if (isProcessing) return false;
        await _reviewLeave(
          docId: docId,
          data: data,
          approved: direction == DismissDirection.startToEnd,
        );
        return false;
      },
      background: _swipeActionBackground(
        alignment: Alignment.centerLeft,
        color: IndustrialColors.secondary,
        icon: Icons.check_circle,
        label: 'APPROVE',
      ),
      secondaryBackground: _swipeActionBackground(
        alignment: Alignment.centerRight,
        color: IndustrialColors.error,
        icon: Icons.cancel,
        label: 'REJECT',
      ),
      child: IndustrialCard(
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
            if (isProcessing)
              const LinearProgressIndicator(minHeight: 3)
            else
              Row(
                children: [
                  Expanded(
                    child: PrimaryActionButton(
                      label: 'REJECT',
                      icon: Icons.close,
                      style: ActionButtonStyle.tertiary,
                      onPressed: () => _reviewLeave(
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
                      onPressed: () => _reviewLeave(
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
      ),
    );
  }

  Widget _swipeActionBackground({
    required Alignment alignment,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
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

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/industrial_theme.dart';
import '../widgets/admin_bottom_nav.dart';
import '../widgets/app_shell.dart';
import '../widgets/industrial_card.dart';
import '../widgets/status_chip.dart';
import '../widgets/primary_action_button.dart';
import '../services/app_firestore.dart';

class AdminLeaveApprovalScreen extends StatefulWidget {
  const AdminLeaveApprovalScreen({
    super.key,
    required this.employeeId,
    required this.date,
  });

  final String employeeId;
  final String date;

  @override
  State<AdminLeaveApprovalScreen> createState() =>
      _AdminLeaveApprovalScreenState();
}

class _AdminLeaveApprovalScreenState extends State<AdminLeaveApprovalScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _reasonController = TextEditingController();
  bool _isProcessing = false;
  String? _statusMessage;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _processLeave(bool approved) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = approved
          ? 'Approving leave request...'
          : 'Declining leave request...';
    });

    try {
      final adminReason = _reasonController.text.trim();
      final leaveDocId = '${widget.employeeId}_${widget.date}';

      // 1. Load employee profile to fetch metadata
      final profileSnap = await _firestore
          .appCollection('employee_profiles')
          .doc(widget.employeeId)
          .get();
      final profile = profileSnap.data() ?? {};
      final employeeName = profile['employeeName'] as String? ?? 'Employee';
      final email = profile['email'] as String? ?? '';
      final department = profile['department'] as String? ?? 'TECH';
      final role = profile['role'] as String? ?? 'EMPLOYEE';

      // 2. Query matching user to obtain their firebase uid for targeting the push notification
      final usersQuery = await _firestore
          .appCollection('users')
          .where('employeeId', isEqualTo: widget.employeeId)
          .limit(1)
          .get();
      String? employeeUid;
      if (usersQuery.docs.isNotEmpty) {
        employeeUid = usersQuery.docs.first.id;
      }

      final batch = _firestore.batch();

      // 3. Update leave_requests collection
      final leaveRef = _firestore
          .appCollection('leave_requests')
          .doc(leaveDocId);
      batch.set(leaveRef, {
        'status': approved ? 'approved_leave' : 'rejected_leave',
        'adminReason': adminReason,
        'respondedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 4. Merge details into attendance collection immediately
      final attendanceRef = _firestore
          .appCollection('attendance')
          .doc(leaveDocId);
      batch.set(attendanceRef, {
        'employeeId': widget.employeeId,
        'employeeName': employeeName,
        'employee': {
          'employeeId': widget.employeeId,
          'employeeName': employeeName,
          'email': email,
          'department': department,
          'role': role,
          'joiningDate': profile['joiningDate'] ?? '',
          'dateOfBirth': profile['dateOfBirth'] ?? '',
          'contactNumber': profile['contactNumber'] ?? '',
        },
        'status': approved ? 'leave' : 'absent',
        'sessionStatus': 'rejected',
        'attendanceStatus': approved
            ? 'approved_leave'
            : 'not_considered_attendance',
        'dayStatus': approved ? 'approved_leave' : 'not_considered',
        'leaveStatus': approved ? 'approved_leave' : 'rejected_leave',
        'reason': adminReason.isEmpty
            ? (approved ? 'Approved by Admin' : 'Declined by Admin')
            : adminReason,
        'loginDateIst': widget.date,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 5. Build push notification back to the employee
      if (employeeUid != null && employeeUid.isNotEmpty) {
        final nowIstStr = DateTime.now()
            .toUtc()
            .add(const Duration(hours: 5, minutes: 30))
            .toIso8601String();
        final title = approved ? 'Leave Approved' : 'Leave Declined';
        final body = approved
            ? 'Your leave request for ${widget.date} has been approved. Note: ${adminReason.isEmpty ? "None" : adminReason}'
            : 'Your leave request for ${widget.date} has been declined. Reason: ${adminReason.isEmpty ? "None" : adminReason}';

        final notifyMsg = {
          'title': title,
          'body': body,
          'senderUid': 'admin',
          'senderRole': 'admin',
          'senderName': 'Admin Portal',
          'targetType': 'employee',
          'recipientUid': employeeUid,
          'type': 'leave_response',
          'employeeId': widget.employeeId,
          'date': widget.date,
          'status': approved ? 'approved' : 'rejected',
          'createdAt': FieldValue.serverTimestamp(),
          'createdAtIst': nowIstStr,
        };

        // Add message to team_messages so it registers in their notification inbox
        final msgRef = _firestore.appCollection('team_messages').doc();
        batch.set(msgRef, notifyMsg);

        // Add to fcm_outbox to deliver the real push notification
        final outboxRef = _firestore.appCollection('fcm_outbox').doc(msgRef.id);
        batch.set(outboxRef, {
          ...notifyMsg,
          'messageId': msgRef.id,
          'status': 'pending',
          'delivery': 'cloud_function',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approved
                ? 'Leave request approved successfully.'
                : 'Leave request declined.',
          ),
          backgroundColor: approved
              ? IndustrialColors.secondary
              : IndustrialColors.error,
        ),
      );

      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Error: ${e.toString()}';
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final leaveDocId = '${widget.employeeId}_${widget.date}';

    return AppShell(
      title: 'Review Leave Request',
      bottomNavigationBar: const AdminBottomNav(currentIndex: 1),
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .appCollection('leave_requests')
            .doc(leaveDocId)
            .snapshots(),
        builder: (context, leaveSnap) {
          if (leaveSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final leaveData = leaveSnap.data?.data();
          if (leaveData == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text('Leave request details could not be loaded.'),
              ),
            );
          }

          final employeeName =
              leaveData['employeeName'] as String? ?? 'Employee';
          final requestedDate = leaveData['date'] as String? ?? widget.date;
          final empReason =
              leaveData['reason'] as String? ?? 'No reason provided';
          final currentStatus =
              leaveData['status'] as String? ?? 'requested_leave';

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _firestore
                .appCollection('employee_profiles')
                .doc(widget.employeeId)
                .snapshots(),
            builder: (context, profileSnap) {
              final profile = profileSnap.data?.data() ?? {};
              final joiningDate =
                  profile['joiningDate'] as String? ?? 'Not specified';
              final department = profile['department'] as String? ?? 'TECH';
              final role = profile['role'] as String? ?? 'EMPLOYEE';

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Employee Info Summary
                    IndustrialCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: IndustrialColors.primary,
                                foregroundColor: IndustrialColors.onPrimary,
                                child: Text(
                                  employeeName.isNotEmpty
                                      ? employeeName
                                            .substring(0, 1)
                                            .toUpperCase()
                                      : 'E',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      employeeName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      '$role | $department',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Joining Date:',
                                style: TextStyle(
                                  color: IndustrialColors.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                joiningDate,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Employee ID:',
                                style: TextStyle(
                                  color: IndustrialColors.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                widget.employeeId,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Leave Request Details
                    Text(
                      'Request Details',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    IndustrialCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Requested Date:',
                                style: TextStyle(
                                  color: IndustrialColors.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                              StatusChip(
                                label: requestedDate,
                                type: StatusChipType.pending,
                                icon: Icons.calendar_today,
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          const Text(
                            "Employee's Reason:",
                            style: TextStyle(
                              color: IndustrialColors.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            empReason,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Current Status:',
                                style: TextStyle(
                                  color: IndustrialColors.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                              StatusChip(
                                label: currentStatus.toUpperCase().replaceAll(
                                  '_',
                                  ' ',
                                ),
                                type: currentStatus.contains('approved')
                                    ? StatusChipType.success
                                    : (currentStatus.contains('rejected')
                                          ? StatusChipType.alert
                                          : StatusChipType.pending),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Action Input
                    Text(
                      'Admin Response Reason',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _reasonController,
                      maxLines: 3,
                      enabled: !_isProcessing,
                      decoration: const InputDecoration(
                        hintText: 'Enter approval note or rejection reason...',
                        labelText: 'Response Reason / Note',
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (_statusMessage != null) ...[
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Text(
                            _statusMessage!,
                            style: TextStyle(
                              color: _statusMessage!.contains('Error')
                                  ? IndustrialColors.error
                                  : IndustrialColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: PrimaryActionButton(
                            label: 'DECLINE',
                            icon: Icons.close,
                            isLoading: _isProcessing,
                            style: ActionButtonStyle.tertiary,
                            onPressed: _isProcessing
                                ? null
                                : () => _processLeave(false),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: PrimaryActionButton(
                            label: 'APPROVE',
                            icon: Icons.check,
                            isLoading: _isProcessing,
                            style: ActionButtonStyle.primary,
                            onPressed: _isProcessing
                                ? null
                                : () => _processLeave(true),
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

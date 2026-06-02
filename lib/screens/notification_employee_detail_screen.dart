import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/attendance_session_service.dart';
import '../services/auth_role_service.dart';
import '../theme/industrial_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/industrial_card.dart';
import '../widgets/status_chip.dart';
import '../services/app_firestore.dart';

class NotificationEmployeeDetailScreen extends StatefulWidget {
  const NotificationEmployeeDetailScreen({
    super.key,
    this.employeeId,
    this.initialMessageId,
    this.autoOpen = false,
  });

  final String? employeeId;
  final String? initialMessageId;
  final bool autoOpen;

  @override
  State<NotificationEmployeeDetailScreen> createState() =>
      _NotificationEmployeeDetailScreenState();
}

class _NotificationEmployeeDetailScreenState
    extends State<NotificationEmployeeDetailScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _roleService = AuthRoleService();
  final _attendanceService = AttendanceSessionService();

  AppUserRole _role = AppUserRole.employee;
  Map<String, dynamic>? _employee;
  String? _employeeUid;
  String? _openedMessageId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant NotificationEmployeeDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.employeeId != widget.employeeId ||
        oldWidget.initialMessageId != widget.initialMessageId ||
        oldWidget.autoOpen != widget.autoOpen) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final role = await _roleService.currentRole() ?? AppUserRole.employee;
    Map<String, dynamic>? employee;
    String? employeeUid;

    if (role.isAdminLike) {
      final employeeId = widget.employeeId?.trim();
      if (employeeId != null && employeeId.isNotEmpty) {
        final profile = await _firestore
            .appCollection('employee_profiles')
            .doc(employeeId)
            .get();
        employee = profile.data();
        final userQuery = await _firestore
            .appCollection('users')
            .where('employeeId', isEqualTo: employeeId)
            .limit(1)
            .get();
        if (userQuery.docs.isNotEmpty) {
          employeeUid = userQuery.docs.first.id;
        }
      }
    } else {
      final profile = await _attendanceService.loadEmployeeProfile();
      employee = profile.toMap();
      employeeUid = _auth.currentUser?.uid;
    }

    if (!mounted) return;
    setState(() {
      _role = role;
      _employee = employee;
      _employeeUid = employeeUid;
      _loading = false;
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _messagesStream() {
    return _firestore
        .appCollection('team_messages')
        .orderBy('createdAt', descending: true)
        .limit(150)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _readsStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _firestore
        .appCollection('notification_reads')
        .where('uid', isEqualTo: uid)
        .snapshots();
  }

  bool _messageBelongsToEmployee(Map<String, dynamic> data) {
    final employee = _employee;
    if (employee == null) return false;

    final employeeId = (employee['employeeId'] as String?)?.trim();
    final department = (employee['department'] as String?)
        ?.trim()
        .toLowerCase();
    if (employeeId == null || employeeId.isEmpty) return false;

    if (data['employeeId'] == employeeId ||
        data['senderEmployeeId'] == employeeId) {
      return true;
    }

    if (_employeeUid != null &&
        (data['recipientUid'] == _employeeUid ||
            (data['recipientUids'] as List?)?.contains(_employeeUid) == true)) {
      return true;
    }

    final targetType = data['targetType'] as String?;
    if (targetType == 'all') return true;
    if (department == null || department.isEmpty) return false;

    final targetTeam = (data['targetTeam'] as String?)?.trim().toLowerCase();
    final targetTeams = (data['targetTeams'] as List?)
        ?.whereType<String>()
        .map((team) => team.trim().toLowerCase())
        .toSet();
    return targetTeam == department ||
        targetTeams?.contains(department) == true;
  }

  bool _messageIsSentByEmployee(Map<String, dynamic> data) {
    final employeeId = (_employee?['employeeId'] as String?)?.trim();
    return employeeId != null &&
        employeeId.isNotEmpty &&
        data['senderEmployeeId'] == employeeId;
  }

  Future<void> _markRead(String messageId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore
        .appCollection('notification_reads')
        .doc('${uid}_$messageId')
        .set({
          'uid': uid,
          'messageId': messageId,
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  void _maybeAutoOpen(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> messages,
    Set<String> readIds,
  ) {
    final messageId = widget.initialMessageId;
    if (!widget.autoOpen ||
        messageId == null ||
        messageId.isEmpty ||
        _openedMessageId == messageId) {
      return;
    }
    QueryDocumentSnapshot<Map<String, dynamic>>? target;
    for (final doc in messages) {
      if (doc.id == messageId) {
        target = doc;
        break;
      }
    }
    if (target == null) return;
    _openedMessageId = messageId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openMessage(target!.id, target.data(), readIds.contains(target.id));
    });
  }

  Future<void> _openMessage(
    String messageId,
    Map<String, dynamic> data,
    bool isRead,
  ) async {
    if (!isRead) {
      await _markRead(messageId);
    }
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(data['title'] as String? ?? 'Notification'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('Body', data['body']),
              _detailRow('From', data['senderName'] ?? data['senderRole']),
              _detailRow('From Employee', data['senderEmployeeId']),
              _detailRow('To', _targetLabel(data)),
              _detailRow('Team', data['targetTeam']),
              _detailRow('Type', data['type']),
              _detailRow('Employee', data['employeeId']),
              _detailRow('Date', data['date']),
              _detailRow('Request', data['requestId']),
              _detailRow('Status', data['status']),
              _detailRow('Time', data['createdAtIst']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: IndustrialColors.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(text),
        ],
      ),
    );
  }

  String _targetLabel(Map<String, dynamic> data) {
    final recipient = data['recipientUid'] as String?;
    if (recipient != null && recipient.isNotEmpty) return 'direct employee';
    final targetTeam = data['targetTeam'] as String?;
    if (targetTeam != null && targetTeam.trim().isNotEmpty) return targetTeam;
    final teams = (data['targetTeams'] as List?)?.whereType<String>().toList();
    if (teams != null && teams.isNotEmpty) return teams.join(', ');
    return data['targetType'] as String? ?? 'all';
  }

  Widget _header() {
    final employee = _employee;
    final name =
        employee?['employeeName'] as String? ??
        '${employee?['firstName'] ?? ''} ${employee?['lastName'] ?? ''}'.trim();
    final employeeId = employee?['employeeId'] as String? ?? '-';
    final department = employee?['department'] as String? ?? '-';
    final role = employee?['role'] as String? ?? 'EMPLOYEE';

    return IndustrialCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: IndustrialColors.primary,
            foregroundColor: IndustrialColors.onPrimary,
            child: Text(
              name.isNotEmpty ? name.characters.first.toUpperCase() : 'E',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? employeeId : name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$role | Code: $employeeId',
                  style: const TextStyle(
                    color: IndustrialColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                StatusChip(label: department, type: StatusChipType.neutral),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _role.isAdminLike
        ? 'Employee Notifications'
        : 'My Notifications';

    return AppShell(
      title: title,
      child: Stack(
        children: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _messagesStream(),
            builder: (context, messageSnapshot) {
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _readsStream(),
                builder: (context, readSnapshot) {
                  final readIds = (readSnapshot.data?.docs ?? [])
                      .map((doc) => doc.data()['messageId'] as String?)
                      .whereType<String>()
                      .toSet();
                  final messages = (messageSnapshot.data?.docs ?? [])
                      .where((doc) => _messageBelongsToEmployee(doc.data()))
                      .toList();
                  _maybeAutoOpen(messages, readIds);

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (index == 0) return _header();
                      final doc = messages[index - 1];
                      final data = doc.data();
                      final isRead = readIds.contains(doc.id);
                      final sentByEmployee = _messageIsSentByEmployee(data);
                      return IndustrialCard(
                        highlighted:
                            !isRead || widget.initialMessageId == doc.id,
                        onTap: () => _openMessage(doc.id, data, isRead),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              sentByEmployee
                                  ? Icons.north_east
                                  : Icons.south_west,
                              color: sentByEmployee
                                  ? IndustrialColors.tertiary
                                  : IndustrialColors.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['title'] as String? ?? 'Notification',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    data['body'] as String? ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      StatusChip(
                                        label: sentByEmployee
                                            ? 'sent'
                                            : 'received',
                                        type: sentByEmployee
                                            ? StatusChipType.pending
                                            : StatusChipType.neutral,
                                      ),
                                      StatusChip(
                                        label: _targetLabel(data),
                                        type: StatusChipType.neutral,
                                      ),
                                      Text(
                                        data['createdAtIst'] as String? ?? '',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: IndustrialColors
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (!isRead)
                              const StatusChip(
                                label: 'NEW',
                                type: StatusChipType.success,
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
          if (_loading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 3),
            ),
        ],
      ),
    );
  }
}

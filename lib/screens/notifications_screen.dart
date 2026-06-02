import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/attendance_session_service.dart';
import '../services/auth_role_service.dart';
import '../services/fcm_notification_service.dart';
import '../theme/industrial_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/industrial_card.dart';
import '../widgets/status_chip.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    this.initialMessageId,
    this.autoOpen = false,
  });

  final String? initialMessageId;
  final bool autoOpen;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _attendanceService = AttendanceSessionService();
  final _authRoleService = AuthRoleService();
  AppUserRole _role = AppUserRole.employee;
  EmployeeProfile? _profile;
  String? _openedInitialMessageId;
  bool _profileLoading = true;
  bool _loadingInitialMessage = false;

  @override
  void initState() {
    super.initState();
    _initFlow();
  }

  Future<void> _initFlow() async {
    await _load();
    if (!mounted) return;
    if (widget.autoOpen && widget.initialMessageId != null) {
      await _fetchAndOpenInitialMessage(widget.initialMessageId!);
    }
  }

  @override
  void didUpdateWidget(covariant NotificationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialMessageId != oldWidget.initialMessageId ||
        widget.autoOpen != oldWidget.autoOpen) {
      if (widget.autoOpen && widget.initialMessageId != null) {
        _fetchAndOpenInitialMessage(widget.initialMessageId!);
      }
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _profileLoading = true;
    });
    final role = await _authRoleService.currentRole() ?? AppUserRole.employee;
    EmployeeProfile? profile;
    if (role == AppUserRole.employee) {
      profile = await _attendanceService.loadEmployeeProfile();
    }
    if (!mounted) return;
    setState(() {
      _role = role;
      _profile = profile;
      _profileLoading = false;
    });
  }

  Future<void> _fetchAndOpenInitialMessage(String messageId) async {
    if (_openedInitialMessageId == messageId || _loadingInitialMessage) return;
    setState(() {
      _loadingInitialMessage = true;
    });
    try {
      final doc = await FirebaseFirestore.instance
          .collection('team_messages')
          .doc(messageId)
          .get();
      if (!mounted) return;
      final data = doc.data();
      if (doc.exists && data != null) {
        if (_role == AppUserRole.employee && _profile == null) {
          await _load();
          if (!mounted) return;
        }
        if (_isRelevant(data)) {
          _openedInitialMessageId = messageId;
          final uid = FirebaseAuth.instance.currentUser?.uid;
          bool isRead = false;
          if (uid != null) {
            final readDoc = await FirebaseFirestore.instance
                .collection('notification_reads')
                .doc('${uid}_$messageId')
                .get();
            isRead = readDoc.exists && (readDoc.data()?['read'] == true);
          }
          if (!mounted) return;
          await _openNotification(doc.id, data, isRead);
        }
      }
    } catch (e) {
      debugPrint('Error fetching initial message: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loadingInitialMessage = false;
        });
      }
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _messagesStream() {
    return FirebaseFirestore.instance
        .collection('team_messages')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _readsStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('notification_reads')
        .where('uid', isEqualTo: uid)
        .snapshots();
  }

  bool _isRelevant(Map<String, dynamic> data) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    if (_role == AppUserRole.admin) {
      final targetType = data['targetType'] as String?;
      return targetType == 'all' ||
          targetType == 'admin' ||
          targetType == 'admins' ||
          targetType == 'teams' ||
          targetType == 'team' ||
          data['recipientUid'] == user.uid ||
          (data['recipientUids'] as List?)?.contains(user.uid) == true;
    }

    final department = _profile?.department.trim().toLowerCase();
    final targetType = data['targetType'] as String?;
    if (targetType == 'all') return true;
    if (data['recipientUid'] == user.uid) return true;
    if ((data['recipientUids'] as List?)?.contains(user.uid) == true) {
      return true;
    }
    if (department == null || department.isEmpty) return false;

    final targetTeam = (data['targetTeam'] as String?)?.trim().toLowerCase();
    final targetTeams = (data['targetTeams'] as List?)
        ?.whereType<String>()
        .map((team) => team.trim().toLowerCase())
        .toSet();
    return targetTeam == department ||
        targetTeams?.contains(department) == true;
  }

  Future<void> _markRead(String messageId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('notification_reads')
        .doc('${uid}_$messageId')
        .set({
          'uid': uid,
          'messageId': messageId,
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> _openNotification(
    String messageId,
    Map<String, dynamic> data,
    bool isRead,
  ) async {
    if (!isRead) {
      _markRead(messageId);
    }
    final actionRoute = await FcmNotificationService.instance
        .actionRouteForNotificationData({...data, 'messageId': messageId});
    if (!mounted) return;

    final targetLabel = _targetLabel(data);
    final createdAt = data['createdAtIst'] as String? ?? '';
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: IndustrialColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data['title'] as String? ?? 'Notification',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: IndustrialColors.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusChip(label: targetLabel, type: StatusChipType.neutral),
                if (!isRead)
                  const StatusChip(label: 'NEW', type: StatusChipType.success),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              data['body'] as String? ?? '',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: IndustrialColors.onSurface,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Divider(color: IndustrialColors.outlineVariant, height: 1),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 16,
                  color: IndustrialColors.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  '${data['senderName'] ?? data['senderRole'] ?? '-'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: IndustrialColors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: IndustrialColors.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  createdAt,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: IndustrialColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (actionRoute != null) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.go(actionRoute);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: IndustrialColors.primary,
                    foregroundColor: IndustrialColors.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text(
                    _actionLabel(data),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (mounted) {
      final state = GoRouterState.of(context);
      final currentPath = state.uri.path;
      if (currentPath == '/notifications' ||
          currentPath == '/admin-notifications') {
        if (state.uri.queryParameters.containsKey('messageId')) {
          context.go(currentPath);
        }
      }
    }
  }

  String _targetLabel(Map<String, dynamic> data) {
    final targetTeam = data['targetTeam'] as String?;
    if (targetTeam != null && targetTeam.trim().isNotEmpty) return targetTeam;
    final targetTeams = (data['targetTeams'] as List?)?.whereType<String>();
    if (targetTeams != null && targetTeams.isNotEmpty) {
      return targetTeams.join(', ');
    }
    return data['targetType'] as String? ?? 'all';
  }

  String _actionLabel(Map<String, dynamic> data) {
    return switch (data['type'] as String?) {
      'leave_request' => 'Open Leave Request',
      'attendance_mark_request' => 'Open Attendance Request',
      'exit_request' => 'Open Exit Request',
      _ => 'Open Message',
    };
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = _profileLoading || _loadingInitialMessage;

    return AppShell(
      title: _role == AppUserRole.admin
          ? 'Admin Notifications'
          : 'Notifications',
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
                  final notifications = (messageSnapshot.data?.docs ?? [])
                      .where((doc) => _isRelevant(doc.data()))
                      .toList();

                  if (notifications.isEmpty && !isLoading) {
                    return const Center(
                      child: StatusChip(
                        label: 'No notifications yet',
                        type: StatusChipType.neutral,
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: notifications.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final doc = notifications[index];
                      final data = doc.data();
                      final isRead = readIds.contains(doc.id);
                      final isSelected = widget.initialMessageId == doc.id;
                      return IndustrialCard(
                        highlighted: !isRead || isSelected,
                        onTap: () => _openNotification(doc.id, data, isRead),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              isRead
                                  ? Icons.notifications_none
                                  : Icons.notifications_active,
                              color: isRead
                                  ? IndustrialColors.onSurfaceVariant
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
                                      fontWeight: FontWeight.w700,
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
                                      StatusChip(
                                        label: _targetLabel(data),
                                        type: StatusChipType.neutral,
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
          if (isLoading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                minHeight: 3,
                backgroundColor: Colors.transparent,
              ),
            ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../constants/organization_options.dart';
import '../services/attendance_session_service.dart';
import '../services/auth_role_service.dart';
import '../services/fcm_notification_service.dart';
import '../theme/industrial_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/industrial_card.dart';
import '../widgets/primary_action_button.dart';
import '../widgets/status_chip.dart';
import '../services/app_firestore.dart';

class TeamMessagesScreen extends StatefulWidget {
  const TeamMessagesScreen({super.key});

  @override
  State<TeamMessagesScreen> createState() => _TeamMessagesScreenState();
}

class _TeamMessagesScreenState extends State<TeamMessagesScreen> {
  final _attendanceService = AttendanceSessionService();
  final _authRoleService = AuthRoleService();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();

  EmployeeProfile? _profile;
  AppUserRole _role = AppUserRole.employee;
  bool _sendToAllTeams = false;
  bool _isSending = false;
  String _teamToAdd = OrganizationOptions.teams.first;
  final Set<String> _selectedTeams = <String>{};
  String? _status;
  StatusChipType _statusType = StatusChipType.neutral;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _deliverySubscription;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _deliverySubscription?.cancel();
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final role = await _authRoleService.currentRole() ?? AppUserRole.employee;
    EmployeeProfile? profile;
    if (role == AppUserRole.employee) {
      profile = await _attendanceService.loadEmployeeProfile();
      await FcmNotificationService.instance.registerCurrentUser(
        department: profile.department,
      );
    } else {
      await FcmNotificationService.instance.registerCurrentUser();
    }

    if (!mounted) return;
    setState(() {
      _role = role;
      _profile = profile;
      if (role == AppUserRole.employee && profile != null) {
        _selectedTeams
          ..clear()
          ..add(profile.department);
      }
    });
    debugPrint(
      'TeamMessages: loaded role=$_role department=${_profile?.department}',
    );
  }

  Future<void> _sendMessage() async {
    final title = _titleController.text.trim();
    final body = _messageController.text.trim();
    final teams = _selectedTeams.toList();
    if (title.isEmpty || body.isEmpty) {
      setState(() {
        _status = 'Title and message are required';
        _statusType = StatusChipType.alert;
      });
      return;
    }
    if (!_sendToAllTeams && teams.isEmpty) {
      setState(() {
        _status = 'Team is required for selected-team messages';
        _statusType = StatusChipType.alert;
      });
      return;
    }

    setState(() {
      _isSending = true;
      _status = null;
      _statusType = StatusChipType.neutral;
    });

    try {
      final outboxId = await FcmNotificationService.instance.sendTeamMessage(
        title: title,
        body: body,
        senderRole: _role,
        senderName:
            _profile?.displayName ??
            FirebaseAuth.instance.currentUser?.email ??
            'Admin',
        senderEmployeeId: _profile?.employeeId,
        sendToAllTeams: _sendToAllTeams,
        selectedTeams: teams,
      );

      if (!mounted) return;
      _messageController.clear();
      setState(() {
        _status = 'Message saved. Waiting for push delivery...';
        _statusType = StatusChipType.pending;
      });
      _watchDeliveryStatus(outboxId);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _status = error.toString();
        _statusType = StatusChipType.alert;
      });
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _messageStream() {
    return FirebaseFirestore.instance
        .appCollection('team_messages')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  void _watchDeliveryStatus(String outboxId) {
    _deliverySubscription?.cancel();
    _deliverySubscription = FirebaseFirestore.instance
        .appCollection('fcm_outbox')
        .doc(outboxId)
        .snapshots()
        .listen(
          (snapshot) {
            final data = snapshot.data();
            if (data == null || !mounted) return;
            final deliveryStatus = data['status'] as String? ?? 'pending';
            final error = data['error'] as String?;
            switch (deliveryStatus) {
              case 'sent':
                setState(() {
                  _status = 'Message saved. Push delivered.';
                  _statusType = StatusChipType.success;
                });
                _deliverySubscription?.cancel();
                _deliverySubscription = null;
              case 'failed':
                setState(() {
                  _status = error == null || error.isEmpty
                      ? 'Message saved, but push delivery failed.'
                      : 'Push delivery failed: $error';
                  _statusType = StatusChipType.alert;
                });
                _deliverySubscription?.cancel();
                _deliverySubscription = null;
              case 'retry':
                setState(() {
                  _status = error == null || error.isEmpty
                      ? 'Message saved. Push delivery is retrying.'
                      : 'Push delivery retrying: $error';
                  _statusType = StatusChipType.pending;
                });
              case 'processing':
                setState(() {
                  _status = 'Message saved. Push delivery processing...';
                  _statusType = StatusChipType.pending;
                });
              default:
                setState(() {
                  _status = 'Message saved. Push delivery queued.';
                  _statusType = StatusChipType.pending;
                });
            }
          },
          onError: (Object error) {
            if (!mounted) return;
            setState(() {
              _status = 'Message saved. Unable to read push delivery status.';
              _statusType = StatusChipType.pending;
            });
          },
        );
  }

  bool _canReadMessage(Map<String, dynamic> data) {
    if (_role == AppUserRole.admin) return true;
    final targetType = data['targetType'] as String?;
    if (targetType == 'all') return true;
    final targetTeams = (data['targetTeams'] as List?)
        ?.whereType<String>()
        .map((team) => team.trim().toLowerCase())
        .toSet();
    final targetTeam = (data['targetTeam'] as String?)?.trim().toLowerCase();
    final department = _profile?.department.trim().toLowerCase();
    if (department == null || department.isEmpty) return false;
    if (targetTeams != null && targetTeams.contains(department)) return true;
    return targetTeam != null &&
        targetTeam.isNotEmpty &&
        targetTeam == department;
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _role == AppUserRole.admin;
    return AppShell(
      title: 'Messages',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Team Messages',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isAdmin
                  ? 'Send admin messages to all teams or selected teams'
                  : 'Send and receive messages for your team',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: IndustrialColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            IndustrialCard(
              child: Column(
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      prefixIcon: Icon(Icons.title),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _messageController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                      prefixIcon: Icon(Icons.message),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: _sendToAllTeams,
                    onChanged: (value) {
                      debugPrint(
                        'TeamMessages: switch onChanged -> $value (isAdmin=$isAdmin)',
                      );
                      _setSendToAllTeams(value);
                    },
                    title: const Text('Send to all teams'),
                    subtitle: const Text('Broadcast to every configured team'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (_role != AppUserRole.admin)
                    Padding(
                      padding: const EdgeInsets.only(top: 6.0, bottom: 6.0),
                      child: Text(
                        'As an employee you can broadcast to all teams or select specific teams.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: IndustrialColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (!_sendToAllTeams) _buildTeamSelector(isAdmin),
                  const SizedBox(height: 12),
                  PrimaryActionButton(
                    label: _isSending ? 'SENDING...' : 'SEND MESSAGE',
                    icon: Icons.send,
                    isLoading: _isSending,
                    onPressed: _isSending ? null : _sendMessage,
                  ),
                  if (_status != null) ...[
                    const SizedBox(height: 12),
                    StatusChip(label: _status!, type: _statusType),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _messageStream(),
              builder: (context, snapshot) {
                final messages = (snapshot.data?.docs ?? [])
                    .map((doc) => doc.data())
                    .where(_canReadMessage)
                    .toList();
                if (messages.isEmpty) {
                  return const StatusChip(
                    label: 'No team messages yet',
                    type: StatusChipType.neutral,
                  );
                }
                return Column(
                  children: messages
                      .map(
                        (data) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: IndustrialCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        data['title'] as String? ?? 'Message',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    StatusChip(
                                      label:
                                          data['targetTeam'] as String? ??
                                          'all',
                                      type: StatusChipType.neutral,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(data['body'] as String? ?? ''),
                                const SizedBox(height: 8),
                                Text(
                                  '${data['senderRole'] ?? '-'} | ${data['createdAtIst'] ?? '-'}',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color:
                                            IndustrialColors.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _setSendToAllTeams(bool value) {
    setState(() {
      _sendToAllTeams = value;
      if (value) {
        _selectedTeams
          ..clear()
          ..addAll(OrganizationOptions.teams);
      } else {
        _selectedTeams.clear();
      }
    });
  }

  Widget _buildTeamSelector(bool isAdmin) {
    // Allow both admins and employees to select teams and send-to-all.
    final alreadySelected = _selectedTeams.contains(_teamToAdd);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _teamToAdd,
                decoration: const InputDecoration(
                  labelText: 'Select Team',
                  prefixIcon: Icon(Icons.groups),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                items: OrganizationOptions.teams
                    .map(
                      (team) =>
                          DropdownMenuItem(value: team, child: Text(team)),
                    )
                    .toList(),
                // debugPrint('Dropdown items: ${OrganizationOptions.teams}'),
                onChanged: (value) {
                  if (value == null) return;
                  debugPrint('TeamMessages: dropdown onChanged -> $value');
                  setState(() => _teamToAdd = value);
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              tooltip: alreadySelected ? 'Team already selected' : 'Add team',
              onPressed: alreadySelected
                  ? null
                  : () {
                      debugPrint(
                        'TeamMessages: add team button pressed -> $_teamToAdd',
                      );
                      setState(() {
                        _selectedTeams.add(_teamToAdd);
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Added $_teamToAdd')),
                      );
                    },
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: Container()),
            const SizedBox(width: 10),
            IconButton(
              tooltip: 'Clear teams',
              onPressed: () {
                debugPrint('TeamMessages: clear teams pressed');
                setState(() => _selectedTeams.clear());
              },
              icon: const Icon(Icons.clear),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _selectedTeams.isEmpty
              ? [
                  const StatusChip(
                    label: 'No teams selected',
                    type: StatusChipType.pending,
                  ),
                ]
              : _selectedTeams
                    .map(
                      (team) => InputChip(
                        label: Text(
                          team,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        backgroundColor: Colors.grey.shade100,
                        onPressed: () =>
                            setState(() => _selectedTeams.remove(team)),
                        onDeleted: () =>
                            setState(() => _selectedTeams.remove(team)),
                        deleteIconColor: Colors.black54,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    )
                    .toList(),
        ),
      ],
    );
  }
}

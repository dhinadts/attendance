import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as xlsx;
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:attendance/widgets/app_shell.dart';
import 'package:attendance/widgets/status_chip.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendance/services/app_firestore.dart';
import 'package:attendance/theme/industrial_theme.dart';
import 'package:attendance/widgets/industrial_card.dart';
import 'package:attendance/widgets/admin_bottom_nav.dart';
import 'package:attendance/services/auth_role_service.dart';
import 'package:attendance/widgets/employee_bottom_nav.dart';
import 'package:attendance/widgets/primary_action_button.dart';
import 'package:attendance/services/attendance_session_service.dart';
import 'package:attendance/widgets/fade_in_slide.dart';


class TaskBoardScreen extends StatefulWidget {
  const TaskBoardScreen({super.key, required this.adminMode});

  final bool adminMode;

  @override
  State<TaskBoardScreen> createState() => _TaskBoardScreenState();
}

class _TaskBoardScreenState extends State<TaskBoardScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _attendanceService = AttendanceSessionService();
  final _roleService = AuthRoleService();
  EmployeeProfile? _profile;
  AppUserAccess? _access;
  bool _isLoading = true;

  bool get _canAssign => widget.adminMode && _access?.isAdminLike == true;

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  Future<void> _loadContext() async {
    try {
      final access = await _roleService.currentAccess();
      EmployeeProfile? profile;
      try {
        profile = await _attendanceService.loadEmployeeProfile();
      } catch (_) {
        profile = null;
      }
      if (!mounted) return;
      setState(() {
        _access = access;
        _profile = profile;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _taskStream() {
    final profile = _profile;
    final ref = _firestore.appCollection('tasks');
    if (_canAssign) {
      return ref.snapshots();
    }
    if (profile == null) {
      return const Stream.empty();
    }
    return ref
        .where('assignedToEmployeeId', isEqualTo: profile.employeeId)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _employeeStream() {
    return _firestore.appCollection('employee_profiles').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: widget.adminMode ? 'Team Tasks' : 'My Tasks',
      bottomNavigationBar: widget.adminMode
          ? const AdminBottomNav(currentIndex: 3)
          : const EmployeeBottomNav(currentIndex: 3),
      floatingActionButton: _canAssign
          ? FloatingActionButton(
              backgroundColor: IndustrialColors.primary,
              onPressed: _showCreateTaskDialog,
              child: const Icon(Icons.add, color: IndustrialColors.onPrimary),
            )
          : null,
      showBackButton: false,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _taskStream(),
              builder: (context, snapshot) {
                final tasks = snapshot.data?.docs ?? [];
                tasks.sort((a, b) {
                  final av =
                      (a.data()['updatedAtIst'] ??
                              a.data()['createdAtIst'] ??
                              '')
                          .toString();
                  final bv =
                      (b.data()['updatedAtIst'] ??
                              b.data()['createdAtIst'] ??
                              '')
                          .toString();
                  return bv.compareTo(av);
                });

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      widget.adminMode
                          ? 'Agile Task Board'
                          : 'Daily Scrum & Timesheet',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontSize: 24, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.adminMode
                          ? 'Create Jira-style tickets, assign work, and track feedback, achievements, improvements, and team performance.'
                          : 'Update your daily scrum report, timesheet hours, blockers, and delivery status for assigned work.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: IndustrialColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_canAssign) ...[
                      Row(
                        children: [
                          Expanded(
                            child: PrimaryActionButton(
                              label: 'ADD SINGLE',
                              icon: Icons.add_task,
                              height: 42,
                              onPressed: _showCreateTaskDialog,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: PrimaryActionButton(
                              label: 'IMPORT CSV/XLSX',
                              icon: Icons.upload_file,
                              height: 42,
                              style: ActionButtonStyle.secondary,
                              onPressed: _importTasks,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    _buildTaskSummary(tasks),
                    const SizedBox(height: 16),
                    if (tasks.isEmpty)
                      const Center(
                        child: StatusChip(
                          label: 'No tasks yet',
                          type: StatusChipType.neutral,
                        ),
                      )
                    else
                      ...tasks.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final doc = entry.value;
                        return FadeInSlide(
                          delay: Duration(milliseconds: idx * 80),
                          child: _taskCard(doc.id, doc.data()),
                        );
                      }),
                    const SizedBox(height: 80),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildTaskSummary(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> tasks,
  ) {
    final open = tasks.where((doc) {
      final status = (doc.data()['status'] ?? '').toString();
      return status != 'done' && status != 'closed';
    }).length;
    final done = tasks.length - open;
    final blockers = tasks.where((doc) {
      final blocker = (doc.data()['latestBlocker'] ?? '').toString().trim();
      return blocker.isNotEmpty;
    }).length;

    return Row(
      children: [
        Expanded(child: _summaryPill('Open', '$open', StatusChipType.pending)),
        const SizedBox(width: 8),
        Expanded(child: _summaryPill('Done', '$done', StatusChipType.success)),
        const SizedBox(width: 8),
        Expanded(
          child: _summaryPill('Blockers', '$blockers', StatusChipType.alert),
        ),
      ],
    );
  }

  Widget _summaryPill(String label, String value, StatusChipType type) {
    return IndustrialCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: type == StatusChipType.alert
                  ? IndustrialColors.error
                  : IndustrialColors.primary,
            ),
          ),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }

  Widget _taskCard(String taskId, Map<String, dynamic> data) {
    final status = (data['status'] ?? 'todo').toString();
    final priority = (data['priority'] ?? 'medium').toString();
    final statusType = switch (status) {
      'done' || 'closed' => StatusChipType.success,
      'blocked' => StatusChipType.alert,
      'in_progress' => StatusChipType.pending,
      _ => StatusChipType.neutral,
    };
    final updates = data['scrumReports'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: IndustrialCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (data['ticketKey'] ?? 'TASK').toString(),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: IndustrialColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (data['title'] ?? 'Untitled task').toString(),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                StatusChip(
                  label: status.replaceAll('_', ' '),
                  type: statusType,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text((data['description'] ?? 'No description').toString()),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusChip(label: priority, type: StatusChipType.neutral),
                StatusChip(
                  label: (data['team'] ?? 'TEAM').toString(),
                  type: StatusChipType.neutral,
                ),
                StatusChip(
                  label: (data['assignedToName'] ?? 'Unassigned').toString(),
                  type: StatusChipType.pending,
                ),
              ],
            ),
            if ((data['latestFeedback'] ?? '')
                .toString()
                .trim()
                .isNotEmpty) ...[
              const SizedBox(height: 10),
              _line('Manager feedback', data['latestFeedback']),
            ],
            if ((data['latestAchievement'] ?? '').toString().trim().isNotEmpty)
              _line('Achievement', data['latestAchievement']),
            if ((data['latestImprovement'] ?? '').toString().trim().isNotEmpty)
              _line('Improvement', data['latestImprovement']),
            if (updates is List && updates.isNotEmpty) ...[
              const Divider(height: 20),
              Text(
                'Latest scrum',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(
                (updates.last as Map?)?['summary']?.toString() ?? '-',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: PrimaryActionButton(
                    label: 'SCRUM',
                    icon: Icons.edit_note,
                    height: 42,
                    style: ActionButtonStyle.outline,
                    onPressed: () => _showScrumDialog(taskId, data),
                  ),
                ),
                if (_canAssign) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: PrimaryActionButton(
                      label: 'FEEDBACK',
                      icon: Icons.rate_review,
                      height: 42,
                      style: ActionButtonStyle.secondary,
                      onPressed: () => _showFeedbackDialog(taskId),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(String label, Object? value) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            TextSpan(text: value?.toString() ?? '-'),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateTaskDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) =>
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _employeeStream(),
            builder: (context, snapshot) {
              final employees = snapshot.data?.docs ?? [];
              return _CreateTaskDialog(
                employees: employees,
                onCreate: (payload) async {
                  await _createTask(payload);
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                },
              );
            },
          ),
    );
  }

  Future<void> _createTask(_TaskPayload payload) async {
    final nowIst = DateTime.now()
        .toUtc()
        .add(const Duration(hours: 5, minutes: 30))
        .toIso8601String();
    final user = _auth.currentUser;
    final assigner = _profile?.displayName.trim().isNotEmpty == true
        ? _profile!.displayName
        : (user?.email ?? 'Admin');
    final docRef = _firestore.appCollection('tasks').doc();
    final ticketKey = payload.ticketKey.trim().isEmpty
        ? 'DTS-${docRef.id.substring(0, 5).toUpperCase()}'
        : payload.ticketKey.trim();
    final record = {
      'id': docRef.id,
      'ticketKey': ticketKey,
      'title': payload.title.trim(),
      'description': payload.description.trim(),
      'team': payload.team.trim(),
      'teamId': payload.team.trim(),
      'priority': payload.priority,
      'status': 'todo',
      'assignedToEmployeeId': payload.employeeId.trim(),
      'assignedToName': payload.employeeName.trim(),
      'assignedByUid': user?.uid,
      'assignedByEmail': user?.email,
      'assignedByName': assigner,
      'assignedByRole': _profile?.role ?? _access?.role.label ?? 'ADMIN',
      'scrumReports': [],
      'createdAt': FieldValue.serverTimestamp(),
      'createdAtIst': nowIst,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedAtIst': nowIst,
    };
    final recipientUid = await _uidForEmployeeId(payload.employeeId);
    final batch = _firestore.batch();
    batch.set(docRef, record);
    _queueTaskAssignmentPush(
      batch,
      taskId: docRef.id,
      ticketKey: ticketKey,
      title: payload.title,
      employeeId: payload.employeeId,
      employeeName: payload.employeeName,
      team: payload.team,
      recipientUid: recipientUid,
      assignedByName: assigner,
      assignedByRole: _profile?.role ?? _access?.role.label ?? 'ADMIN',
      createdAtIst: nowIst,
    );
    await batch.commit();
  }

  Future<String?> _uidForEmployeeId(String employeeId) async {
    final snapshot = await _firestore
        .appCollection('users')
        .where('employeeId', isEqualTo: employeeId.trim())
        .limit(1)
        .get();
    return snapshot.docs.isEmpty ? null : snapshot.docs.first.id;
  }

  void _queueTaskAssignmentPush(
    WriteBatch batch, {
    required String taskId,
    required String ticketKey,
    required String title,
    required String employeeId,
    required String employeeName,
    required String team,
    required String? recipientUid,
    required String assignedByName,
    required String assignedByRole,
    required String createdAtIst,
  }) {
    final user = _auth.currentUser;
    final messageRef = _firestore.appCollection('team_messages').doc();
    final message = {
      'title': 'New Task Assigned',
      'body': '$ticketKey - ${title.trim()}',
      'senderUid': user?.uid,
      'senderEmail': user?.email,
      'senderRole': assignedByRole,
      'senderName': assignedByName,
      'targetType': 'employee',
      'recipientUid': recipientUid,
      'recipientUids': recipientUid == null ? <String>[] : [recipientUid],
      'employeeId': employeeId.trim(),
      'employeeName': employeeName.trim(),
      'department': team.trim(),
      'targetTeam': team.trim(),
      'type': 'task_assigned',
      'taskId': taskId,
      'ticketKey': ticketKey,
      'route': '/tasks',
      'createdAt': FieldValue.serverTimestamp(),
      'createdAtIst': createdAtIst,
    };
    batch.set(messageRef, message);
    batch.set(_firestore.appCollection('fcm_outbox').doc(messageRef.id), {
      ...message,
      'messageId': messageRef.id,
      'status': 'pending',
      'delivery': 'cloud_function',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Map<String, dynamic> _taskRecord({
    required String taskId,
    required _TaskPayload payload,
    required String ticketKey,
    required String assignedByName,
    required String assignedByRole,
    required String createdAtIst,
  }) {
    final user = _auth.currentUser;
    return {
      'id': taskId,
      'ticketKey': payload.ticketKey.trim().isEmpty
          ? ticketKey
          : payload.ticketKey.trim(),
      'title': payload.title.trim(),
      'description': payload.description.trim(),
      'team': payload.team.trim(),
      'teamId': payload.team.trim(),
      'priority': payload.priority,
      'status': 'todo',
      'assignedToEmployeeId': payload.employeeId.trim(),
      'assignedToName': payload.employeeName.trim(),
      'assignedByUid': user?.uid,
      'assignedByEmail': user?.email,
      'assignedByName': assignedByName,
      'assignedByRole': assignedByRole,
      'scrumReports': [],
      'createdAt': FieldValue.serverTimestamp(),
      'createdAtIst': createdAtIst,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedAtIst': createdAtIst,
    };
  }

  Future<void> _importTasks() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx'],
        withData: true,
      );
      final file = result?.files.single;
      final bytes = file?.bytes;
      if (file == null || bytes == null) return;

      final lowerName = file.name.toLowerCase();
      final payloads = lowerName.endsWith('.xlsx')
          ? _payloadsFromExcel(bytes)
          : _payloadsFromCsv(String.fromCharCodes(bytes));
      if (payloads.isEmpty) {
        throw StateError('No valid task rows found');
      }

      final employees = await _firestore
          .appCollection('employee_profiles')
          .get();
      final employeesById = {
        for (final doc in employees.docs)
          (doc.data()['employeeId'] ?? doc.id).toString().trim(): doc.data(),
      };
      final batch = _firestore.batch();
      for (final payload in payloads) {
        final employee = employeesById[payload.employeeId];
        final enriched = payload.copyWith(
          employeeName: payload.employeeName.trim().isNotEmpty
              ? payload.employeeName
              : (employee?['employeeName'] ?? payload.employeeId).toString(),
          team: payload.team.trim().isNotEmpty
              ? payload.team
              : (employee?['department'] ?? 'TECH').toString(),
        );
        final recipientUid = await _uidForEmployeeId(enriched.employeeId);
        _setTaskInBatch(batch, enriched, recipientUid: recipientUid);
      }
      await batch.commit();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported ${payloads.length} tasks')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Import failed: $error')));
    }
  }

  List<_TaskPayload> _payloadsFromExcel(List<int> bytes) {
    final book = xlsx.Excel.decodeBytes(bytes);
    if (book.tables.isEmpty) return const [];
    final sheet = book.tables.values.first;
    final rows = sheet.rows
        .map((row) => row.map((cell) => cell?.value?.toString() ?? '').toList())
        .toList();
    return _payloadsFromRows(rows);
  }

  List<_TaskPayload> _payloadsFromCsv(String content) {
    final rows = _parseCsv(content);
    return _payloadsFromRows(rows);
  }

  List<List<String>> _parseCsv(String content) {
    final rows = <List<String>>[];
    var current = StringBuffer();
    var row = <String>[];
    var inQuotes = false;
    for (var i = 0; i < content.length; i++) {
      final char = content[i];
      if (char == '"') {
        final escaped =
            inQuotes && i + 1 < content.length && content[i + 1] == '"';
        if (escaped) {
          current.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        row.add(current.toString().trim());
        current = StringBuffer();
      } else if ((char == '\n' || char == '\r') && !inQuotes) {
        if (char == '\r' && i + 1 < content.length && content[i + 1] == '\n') {
          i++;
        }
        row.add(current.toString().trim());
        if (row.any((value) => value.isNotEmpty)) rows.add(row);
        row = <String>[];
        current = StringBuffer();
      } else {
        current.write(char);
      }
    }
    row.add(current.toString().trim());
    if (row.any((value) => value.isNotEmpty)) rows.add(row);
    return rows;
  }

  List<_TaskPayload> _payloadsFromRows(List<List<String>> rows) {
    if (rows.isEmpty) return const [];
    final headers = rows.first.map(_normalizeHeader).toList();
    String cell(List<String> row, String key) {
      final index = headers.indexOf(key);
      if (index < 0 || index >= row.length) return '';
      return row[index].trim();
    }

    return rows
        .skip(1)
        .map((row) {
          return _TaskPayload(
            ticketKey: cell(row, 'ticketkey'),
            title: cell(row, 'title'),
            description: cell(row, 'description'),
            priority: _priorityOrDefault(cell(row, 'priority')),
            employeeId: cell(row, 'employeeid'),
            employeeName: cell(row, 'employeename'),
            team: cell(row, 'team'),
          );
        })
        .where((payload) {
          return payload.title.trim().isNotEmpty &&
              payload.employeeId.trim().isNotEmpty;
        })
        .toList();
  }

  String _normalizeHeader(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String _priorityOrDefault(String value) {
    final normalized = value.trim().toLowerCase();
    if (['low', 'medium', 'high', 'urgent'].contains(normalized)) {
      return normalized;
    }
    return 'medium';
  }

  void _setTaskInBatch(
    WriteBatch batch,
    _TaskPayload payload, {
    required String? recipientUid,
  }) {
    final nowIst = DateTime.now()
        .toUtc()
        .add(const Duration(hours: 5, minutes: 30))
        .toIso8601String();
    final user = _auth.currentUser;
    final assigner = _profile?.displayName.trim().isNotEmpty == true
        ? _profile!.displayName
        : (user?.email ?? 'Admin');
    final assignedByRole = _profile?.role ?? _access?.role.label ?? 'ADMIN';
    final docRef = _firestore.appCollection('tasks').doc();
    final ticketKey = payload.ticketKey.trim().isEmpty
        ? 'DTS-${docRef.id.substring(0, 5).toUpperCase()}'
        : payload.ticketKey.trim();
    batch.set(
      docRef,
      _taskRecord(
        taskId: docRef.id,
        payload: payload,
        ticketKey: ticketKey,
        assignedByName: assigner,
        assignedByRole: assignedByRole,
        createdAtIst: nowIst,
      ),
    );
    _queueTaskAssignmentPush(
      batch,
      taskId: docRef.id,
      ticketKey: ticketKey,
      title: payload.title,
      employeeId: payload.employeeId,
      employeeName: payload.employeeName,
      team: payload.team,
      recipientUid: recipientUid,
      assignedByName: assigner,
      assignedByRole: assignedByRole,
      createdAtIst: nowIst,
    );
  }

  Future<void> _showScrumDialog(
    String taskId,
    Map<String, dynamic> data,
  ) async {
    final summary = TextEditingController();
    final blocker = TextEditingController(
      text: data['latestBlocker'] as String? ?? '',
    );
    final hours = TextEditingController();
    var status = (data['status'] ?? 'in_progress').toString();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Daily Scrum Update'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: status,
                items: const [
                  DropdownMenuItem(value: 'todo', child: Text('To do')),
                  DropdownMenuItem(
                    value: 'in_progress',
                    child: Text('In progress'),
                  ),
                  DropdownMenuItem(value: 'blocked', child: Text('Blocked')),
                  DropdownMenuItem(value: 'done', child: Text('Done')),
                ],
                onChanged: (value) => status = value ?? status,
                decoration: const InputDecoration(labelText: 'Status'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: summary,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'What did you deliver today?',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: blocker,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Blockers'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: hours,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Timesheet hours'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () async {
              await _saveScrumUpdate(
                taskId: taskId,
                status: status,
                summary: summary.text,
                blocker: blocker.text,
                hours: hours.text,
              );
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveScrumUpdate({
    required String taskId,
    required String status,
    required String summary,
    required String blocker,
    required String hours,
  }) async {
    final nowIst = DateTime.now()
        .toUtc()
        .add(const Duration(hours: 5, minutes: 30))
        .toIso8601String();
    final reporter = _profile?.displayName.trim().isNotEmpty == true
        ? _profile!.displayName
        : (_auth.currentUser?.email ?? 'Employee');
    await _firestore.appCollection('tasks').doc(taskId).set({
      'status': status,
      'latestScrumSummary': summary.trim(),
      'latestBlocker': blocker.trim(),
      'latestHours': hours.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedAtIst': nowIst,
      'scrumReports': FieldValue.arrayUnion([
        {
          'summary': summary.trim(),
          'blocker': blocker.trim(),
          'hours': hours.trim(),
          'status': status,
          'reporterUid': _auth.currentUser?.uid,
          'reporterName': reporter,
          'reportedAtIst': nowIst,
        },
      ]),
    }, SetOptions(merge: true));
  }

  Future<void> _showFeedbackDialog(String taskId) async {
    final feedback = TextEditingController();
    final achievement = TextEditingController();
    final improvement = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Manager Feedback'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: feedback,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Feedback'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: achievement,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Achievement'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: improvement,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Improvement'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () async {
              await _saveFeedback(
                taskId: taskId,
                feedback: feedback.text,
                achievement: achievement.text,
                improvement: improvement.text,
              );
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveFeedback({
    required String taskId,
    required String feedback,
    required String achievement,
    required String improvement,
  }) async {
    final nowIst = DateTime.now()
        .toUtc()
        .add(const Duration(hours: 5, minutes: 30))
        .toIso8601String();
    final reviewer = _profile?.displayName.trim().isNotEmpty == true
        ? _profile!.displayName
        : (_auth.currentUser?.email ?? 'Manager');
    await _firestore.appCollection('tasks').doc(taskId).set({
      'latestFeedback': feedback.trim(),
      'latestAchievement': achievement.trim(),
      'latestImprovement': improvement.trim(),
      'feedbackByUid': _auth.currentUser?.uid,
      'feedbackByName': reviewer,
      'feedbackAt': FieldValue.serverTimestamp(),
      'feedbackAtIst': nowIst,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedAtIst': nowIst,
    }, SetOptions(merge: true));
  }
}

class _CreateTaskDialog extends StatefulWidget {
  const _CreateTaskDialog({required this.employees, required this.onCreate});

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> employees;
  final Future<void> Function(_TaskPayload payload) onCreate;

  @override
  State<_CreateTaskDialog> createState() => _CreateTaskDialogState();
}

class _CreateTaskDialogState extends State<_CreateTaskDialog> {
  final _ticket = TextEditingController();
  final _title = TextEditingController();
  final _description = TextEditingController();
  String _priority = 'medium';
  String? _selectedEmployeeId;
  bool _saving = false;

  @override
  void dispose() {
    _ticket.dispose();
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final employeeItems = widget.employees.map((doc) {
      final data = doc.data();
      final employeeId = (data['employeeId'] ?? doc.id).toString();
      final name = (data['employeeName'] ?? employeeId).toString();
      final team = (data['department'] ?? 'TEAM').toString();
      return DropdownMenuItem(value: employeeId, child: Text('$name - $team'));
    }).toList();

    return AlertDialog(
      title: const Text('Create Task'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _ticket,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Jira ticket / code',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _title,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Task title'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _description,
              onChanged: (_) => setState(() {}),
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Task details'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _selectedEmployeeId,
              items: employeeItems,
              onChanged: (value) => setState(() => _selectedEmployeeId = value),
              decoration: const InputDecoration(labelText: 'Assign to'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _priority,
              items: const [
                DropdownMenuItem(value: 'low', child: Text('Low')),
                DropdownMenuItem(value: 'medium', child: Text('Medium')),
                DropdownMenuItem(value: 'high', child: Text('High')),
                DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
              ],
              onChanged: (value) =>
                  setState(() => _priority = value ?? 'medium'),
              decoration: const InputDecoration(labelText: 'Priority'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          onPressed:
              _saving ||
                  _title.text.trim().isEmpty ||
                  _selectedEmployeeId == null
              ? null
              : _create,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('CREATE'),
        ),
      ],
    );
  }

  Future<void> _create() async {
    final selected = widget.employees.firstWhere(
      (doc) =>
          ((doc.data()['employeeId'] ?? doc.id).toString()) ==
          _selectedEmployeeId,
    );
    final data = selected.data();
    setState(() => _saving = true);
    await widget.onCreate(
      _TaskPayload(
        ticketKey: _ticket.text,
        title: _title.text,
        description: _description.text,
        priority: _priority,
        employeeId: _selectedEmployeeId!,
        employeeName: (data['employeeName'] ?? _selectedEmployeeId).toString(),
        team: (data['department'] ?? 'TECH').toString(),
      ),
    );
  }
}

class _TaskPayload {
  const _TaskPayload({
    required this.ticketKey,
    required this.title,
    required this.description,
    required this.priority,
    required this.employeeId,
    required this.employeeName,
    required this.team,
  });

  final String ticketKey;
  final String title;
  final String description;
  final String priority;
  final String employeeId;
  final String employeeName;
  final String team;

  _TaskPayload copyWith({
    String? ticketKey,
    String? title,
    String? description,
    String? priority,
    String? employeeId,
    String? employeeName,
    String? team,
  }) {
    return _TaskPayload(
      ticketKey: ticketKey ?? this.ticketKey,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      team: team ?? this.team,
    );
  }
}

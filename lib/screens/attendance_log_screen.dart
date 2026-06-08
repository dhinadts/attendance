import '../widgets/app_shell.dart';
import '../widgets/status_chip.dart';
import 'package:flutter/material.dart';
import '../theme/industrial_theme.dart';
import '../services/app_firestore.dart';
import '../widgets/industrial_card.dart';
import '../widgets/employee_bottom_nav.dart';
import '../services/attendance_session_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum _LogRange { today, week, month, year }

class AttendanceLogScreen extends StatefulWidget {
  const AttendanceLogScreen({super.key});

  @override
  State<AttendanceLogScreen> createState() => _AttendanceLogScreenState();
}

class _AttendanceLogScreenState extends State<AttendanceLogScreen> {
  final _service = AttendanceSessionService();
  EmployeeProfile? _profile;
  bool _outsideOfficeSession = false;
  bool _isSubmittingReason = false;
  _LogRange _selectedRange = _LogRange.today;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await _service.loadEmployeeProfile();
    final outsideOffice = await _service.hasOutsideOfficeSession();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _outsideOfficeSession = outsideOffice;
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _attendanceStream() {
    if (_profile == null) {
      return const Stream.empty();
    }
    return FirebaseFirestore.instance
        .appCollection('attendance')
        .where('employeeId', isEqualTo: _profile!.employeeId)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Attendance Log',
      showBackButton: false,
      bottomNavigationBar: EmployeeBottomNav(
        currentIndex: 2,
        attendanceAlert: _outsideOfficeSession,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attendance Log',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Office circle time, breaks, delay requests, and logout timings.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: IndustrialColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            _policyCard(),
            const SizedBox(height: 14),
            _buildRangeSelector(),
            const SizedBox(height: 14),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _attendanceStream(),
                builder: (context, snapshot) {
                  if (_profile == null ||
                      snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text(snapshot.error.toString()));
                  }

                  final docs =
                      List.of(snapshot.data?.docs ?? [])
                          .where((doc) => _isInSelectedRange(doc.data()))
                          .toList()
                        ..sort((a, b) {
                          final aDate = _dateFromRecord(a.data());
                          final bDate = _dateFromRecord(b.data());
                          return bDate.compareTo(aDate);
                        });

                  if (docs.isEmpty) {
                    return Center(
                      child: StatusChip(
                        label: 'No logs for ${_rangeLabel(_selectedRange)}',
                        type: StatusChipType.neutral,
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _dayLogCard(docs[index]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRangeSelector() {
    return SegmentedButton<_LogRange>(
      selected: {_selectedRange},
      showSelectedIcon: false,
      onSelectionChanged: (selection) {
        setState(() => _selectedRange = selection.first);
      },
      segments: const [
        ButtonSegment(value: _LogRange.today, label: Text('Today')),
        ButtonSegment(value: _LogRange.week, label: Text('Week')),
        ButtonSegment(value: _LogRange.month, label: Text('Month')),
        ButtonSegment(value: _LogRange.year, label: Text('Year')),
      ],
    );
  }

  Widget _policyCard() {
    return IndustrialCard(
      backgroundColor: IndustrialColors.surfaceContainerLow,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          StatusChip(
            label:
                'OFFICE ${AttendanceSessionService.defaultOfficeLatitude.toStringAsFixed(7)}, ${AttendanceSessionService.defaultOfficeLongitude.toStringAsFixed(7)}',
            type: StatusChipType.neutral,
            icon: Icons.location_on,
          ),
          StatusChip(
            label:
                '${AttendanceSessionService.defaultRadiusMeters.toInt()}M RANGE',
            type: StatusChipType.success,
            icon: Icons.radio_button_checked,
          ),
          StatusChip(
            label:
                '${AttendanceSessionService.officeArrivalGrace.inMinutes}M BREAK GRACE',
            type: StatusChipType.pending,
            icon: Icons.timer,
          ),
          StatusChip(
            label:
                '${AttendanceSessionService.eligibleMinutes ~/ 60}H OFFICE TIME REQUIRED',
            type: StatusChipType.success,
            icon: Icons.verified,
          ),
        ],
      ),
    );
  }

  Widget _dayLogCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final date = data['loginDateIst'] as String? ?? '-';
    final status = data['attendanceStatus'] as String? ?? '-';
    final officeMinutes = (data['officeMinutes'] as num?)?.toInt();
    final breakMinutes = (data['breakMinutes'] as num?)?.toInt();
    final segments = _segmentsFrom(data);
    final logs = _logsFrom(data);
    final outsideAttempts = logs
        .where((log) => log['event'] == 'out_of_office_login_attempt')
        .length;
    final breakCount = _breakCount(segments, data);
    final needsReason =
        data['breakConsiderationRequired'] == true ||
        data['breakConsiderationStatus'] == 'reason_required';
    final requestStatus =
        (data['breakConsiderationStatus'] as String?) ?? 'not_required';
    final currentOfficeMinutes = officeMinutes ?? _liveOfficeMinutes(segments);
    final progress =
        (currentOfficeMinutes / AttendanceSessionService.eligibleMinutes)
            .clamp(0.0, 1.0)
            .toDouble();
    final chipType = status == 'attendance_considered'
        ? StatusChipType.success
        : status == 'outside_office_break'
        ? StatusChipType.alert
        : StatusChipType.pending;

    return IndustrialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  date,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              StatusChip(
                label: status.replaceAll('_', ' ').toUpperCase(),
                type: chipType,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusChip(
                label: 'OFFICE ${_minutesLabel(currentOfficeMinutes)}',
                type: StatusChipType.success,
                icon: Icons.work,
              ),
              StatusChip(
                label:
                    'BREAK ${breakMinutes == null ? _liveBreakMinutesLabel(segments) : _minutesLabel(breakMinutes)}',
                type: StatusChipType.neutral,
                icon: Icons.free_breakfast,
              ),
              StatusChip(
                label: 'BREAKS $breakCount',
                type: breakCount == 0
                    ? StatusChipType.neutral
                    : StatusChipType.pending,
                icon: Icons.directions_walk,
              ),
              if (outsideAttempts > 0)
                StatusChip(
                  label: 'OUTSIDE LOGIN $outsideAttempts',
                  type: StatusChipType.alert,
                  icon: Icons.location_off,
                ),
              if (requestStatus != 'not_required')
                StatusChip(
                  label: requestStatus.replaceAll('_', ' '),
                  type: requestStatus == 'requested'
                      ? StatusChipType.pending
                      : StatusChipType.alert,
                  icon: Icons.assignment_late,
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              color: IndustrialColors.secondary,
              backgroundColor: IndustrialColors.outlineVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_minutesLabel(currentOfficeMinutes)} of ${_minutesLabel(AttendanceSessionService.eligibleMinutes)} office time counted for attendance.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: IndustrialColors.onSurfaceVariant,
            ),
          ),
          if (needsReason) ...[
            const SizedBox(height: 12),
            _reasonRequiredPanel(doc.id, data),
          ],
          const SizedBox(height: 14),
          if (segments.isEmpty)
            _emptySegmentMessage(data)
          else
            ..._timelineRows(segments, data),
          if (logs.isNotEmpty) ...[
            const SizedBox(height: 8),
            ..._eventRows(logs),
          ],
        ],
      ),
    );
  }

  Widget _reasonRequiredPanel(String docId, Map<String, dynamic> data) {
    final lastBreakMinutes = (data['lastBreakMinutes'] as num?)?.toInt();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: IndustrialColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: IndustrialColors.error.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lastBreakMinutes == null
                ? 'Break delay reason required'
                : 'Break was ${_minutesLabel(lastBreakMinutes)}. Reason required.',
            style: TextStyle(
              color: IndustrialColors.error,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Submit the reason to ask admin to consider this attendance day.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: IndustrialColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _isSubmittingReason
                  ? null
                  : () => _showReasonSheet(docId),
              icon: const Icon(Icons.edit_note),
              label: const Text('Request consideration'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptySegmentMessage(Map<String, dynamic> data) {
    final outsideLogin = data['outsideLoginAttempt'] == true;
    return Text(
      outsideLogin
          ? 'Login attempt was outside the office circle. Office time will start when the employee enters the 50m range.'
          : 'No in/out segment captured for this day.',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: outsideLogin
            ? IndustrialColors.error
            : IndustrialColors.onSurfaceVariant,
      ),
    );
  }

  Future<void> _showReasonSheet(String docId) async {
    final controller = TextEditingController();
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Delay reason',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 4,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Reason for delayed return',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () =>
                          Navigator.pop(context, controller.text.trim()),
                      icon: const Icon(Icons.send),
                      label: const Text('Submit'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
    if (reason == null || reason.isEmpty) return;
    await _submitReason(docId, reason);
  }

  Future<void> _submitReason(String docId, String reason) async {
    setState(() => _isSubmittingReason = true);
    try {
      await _service.submitBreakConsiderationRequest(
        attendanceDocumentId: docId,
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Consideration request submitted')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isSubmittingReason = false);
    }
  }

  List<Widget> _timelineRows(
    List<Map<String, dynamic>> segments,
    Map<String, dynamic> data,
  ) {
    final rows = <Widget>[];
    for (var index = 0; index < segments.length; index++) {
      final segment = segments[index];
      final inAt = segment['inAtIst'] as String?;
      final outAt = segment['outAtIst'] as String?;
      final outReason = segment['outReason'] as String?;
      rows.add(
        _timelineRow(
          icon: Icons.login,
          title: index == 0 ? 'Login / entered office' : 'Re-entered office',
          value: _formatTime(inAt),
          type: StatusChipType.success,
        ),
      );
      rows.add(
        _timelineRow(
          icon: outAt == null ? Icons.work_history : Icons.logout,
          title: outAt == null
              ? 'Working inside office'
              : outReason == 'left_geofence_break'
              ? 'Left office for break'
              : 'Logged out',
          value: outAt == null ? 'Active now' : _formatTime(outAt),
          type: outAt == null ? StatusChipType.pending : StatusChipType.alert,
        ),
      );

      final nextSegment = index + 1 < segments.length
          ? segments[index + 1]
          : null;
      if (outAt != null && nextSegment != null) {
        rows.add(
          _timelineRow(
            icon: Icons.timer_off,
            title: 'Out-of-office break',
            value: _durationBetween(outAt, nextSegment['inAtIst'] as String?),
            type: StatusChipType.neutral,
          ),
        );
      }
    }

    final logoutAt = data['logoutAtIst'] as String?;
    if (logoutAt != null && logoutAt.isNotEmpty) {
      rows.add(
        _timelineRow(
          icon: Icons.flag,
          title: 'Final logout',
          value: _formatTime(logoutAt),
          type: StatusChipType.neutral,
        ),
      );
    }

    return rows;
  }

  List<Widget> _eventRows(List<Map<String, dynamic>> logs) {
    final visibleLogs = logs
        .where(
          (log) =>
              log['event'] == 'out_of_office_login_attempt' ||
              log['event'] == 'break_delay_reason_required' ||
              log['event'] == 'break_consideration_requested',
        )
        .toList();
    if (visibleLogs.isEmpty) return const [];
    return visibleLogs.map((log) {
      final event = (log['event'] as String? ?? '').replaceAll('_', ' ');
      final distance = (log['distanceMeters'] as num?)?.toDouble();
      final message = log['message'] as String? ?? event;
      return _timelineRow(
        icon: log['event'] == 'break_consideration_requested'
            ? Icons.assignment_turned_in
            : Icons.warning_amber,
        title: message,
        value: [
          _formatTime(log['atIst'] as String?),
          if (distance != null) '${distance.toStringAsFixed(1)}m from office',
        ].join('  '),
        type: log['event'] == 'break_consideration_requested'
            ? StatusChipType.pending
            : StatusChipType.alert,
      );
    }).toList();
  }

  Widget _timelineRow({
    required IconData icon,
    required String title,
    required String value,
    required StatusChipType type,
  }) {
    final color = switch (type) {
      StatusChipType.success => IndustrialColors.secondary,
      StatusChipType.alert => IndustrialColors.error,
      _ => IndustrialColors.onSurfaceVariant,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: IndustrialColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isInSelectedRange(Map<String, dynamic> data) {
    final recordDate = _dateFromRecord(data);
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final dateStart = DateTime(
      recordDate.year,
      recordDate.month,
      recordDate.day,
    );

    return switch (_selectedRange) {
      _LogRange.today => dateStart == todayStart,
      _LogRange.week => _isSameWeek(dateStart, todayStart),
      _LogRange.month =>
        dateStart.year == todayStart.year &&
            dateStart.month == todayStart.month,
      _LogRange.year => dateStart.year == todayStart.year,
    };
  }

  bool _isSameWeek(DateTime value, DateTime today) {
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));
    return !value.isBefore(weekStart) && value.isBefore(weekEnd);
  }

  DateTime _dateFromRecord(Map<String, dynamic> data) {
    final dateKey = data['loginDateIst'] as String?;
    final parsedDate = DateTime.tryParse(dateKey ?? '');
    if (parsedDate != null) return parsedDate;
    final loginAt = DateTime.tryParse(data['loginAtIst'] as String? ?? '');
    return loginAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  List<Map<String, dynamic>> _segmentsFrom(Map<String, dynamic> data) {
    final rawSegments = data['segments'];
    if (rawSegments is! List) return <Map<String, dynamic>>[];
    return rawSegments
        .whereType<Map>()
        .map((segment) => Map<String, dynamic>.from(segment))
        .toList();
  }

  List<Map<String, dynamic>> _logsFrom(Map<String, dynamic> data) {
    final rawLogs = data['logs'];
    if (rawLogs is! List) return <Map<String, dynamic>>[];
    return rawLogs
        .whereType<Map>()
        .map((log) => Map<String, dynamic>.from(log))
        .toList();
  }

  int _breakCount(
    List<Map<String, dynamic>> segments,
    Map<String, dynamic> data,
  ) {
    var count = 0;
    for (final segment in segments) {
      if (segment['outReason'] == 'left_geofence_break') count++;
    }
    if (data['outsideLoginAttempt'] == true && segments.isNotEmpty) {
      count++;
    }
    return count;
  }

  String _formatTime(String? ist) {
    if (ist == null || ist.isEmpty) return '-';
    final parsed = DateTime.tryParse(ist);
    if (parsed == null) return ist;
    return '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}:${parsed.second.toString().padLeft(2, '0')} IST';
  }

  String _durationBetween(String? startIst, String? endIst) {
    final start = DateTime.tryParse(startIst ?? '');
    final end = DateTime.tryParse(endIst ?? '');
    if (start == null || end == null || end.isBefore(start)) return '-';
    return _minutesLabel(end.difference(start).inMinutes);
  }

  int _liveOfficeMinutes(List<Map<String, dynamic>> segments) {
    var minutes = 0;
    final now = DateTime.now();
    for (final segment in segments) {
      final inAt = DateTime.tryParse(segment['inAtIst'] as String? ?? '');
      final outAt =
          DateTime.tryParse(segment['outAtIst'] as String? ?? '') ?? now;
      if (inAt == null || outAt.isBefore(inAt)) continue;
      minutes += outAt.difference(inAt).inMinutes;
    }
    return minutes;
  }

  String _liveBreakMinutesLabel(List<Map<String, dynamic>> segments) {
    var minutes = 0;
    for (var index = 0; index < segments.length - 1; index++) {
      final outAt = DateTime.tryParse(
        segments[index]['outAtIst'] as String? ?? '',
      );
      final nextInAt = DateTime.tryParse(
        segments[index + 1]['inAtIst'] as String? ?? '',
      );
      if (outAt == null || nextInAt == null || nextInAt.isBefore(outAt)) {
        continue;
      }
      minutes += nextInAt.difference(outAt).inMinutes;
    }
    return _minutesLabel(minutes);
  }

  String _minutesLabel(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours == 0) return '${mins}m';
    return '${hours}h ${mins}m';
  }

  String _rangeLabel(_LogRange range) {
    return switch (range) {
      _LogRange.today => 'today',
      _LogRange.week => 'this week',
      _LogRange.month => 'this month',
      _LogRange.year => 'this year',
    };
  }
}

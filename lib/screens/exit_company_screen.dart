import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/attendance_session_service.dart';
import '../theme/industrial_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/employee_bottom_nav.dart';
import '../widgets/industrial_card.dart';
import '../widgets/primary_action_button.dart';
import '../widgets/status_chip.dart';

class ExitCompanyScreen extends StatefulWidget {
  const ExitCompanyScreen({super.key});

  @override
  State<ExitCompanyScreen> createState() => _ExitCompanyScreenState();
}

class _ExitCompanyScreenState extends State<ExitCompanyScreen> {
  final _service = AttendanceSessionService();
  final _subjectController = TextEditingController();
  final _reasonController = TextEditingController();
  final _leavingDateController = TextEditingController();
  EmployeeProfile? _profile;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _subjectController.text = 'Relieving request';
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _reasonController.dispose();
    _leavingDateController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await _service.loadEmployeeProfile();
    if (!mounted) return;
    setState(() => _profile = profile);
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      await _service.submitExitRequest(
        subject: _subjectController.text,
        reason: _reasonController.text,
        leavingDate: _leavingDateController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Exit request submitted')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _requestStream() {
    final profile = _profile;
    if (profile == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('exit_requests')
        .where('employeeId', isEqualTo: profile.employeeId)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Exit Company',
      bottomNavigationBar: const EmployeeBottomNav(currentIndex: 4),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Relieving Request',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Request will be logged for CEO and Manager review',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: IndustrialColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            IndustrialCard(
              child: Column(
                children: [
                  TextField(
                    controller: _subjectController,
                    decoration: const InputDecoration(
                      labelText: 'Email Subject',
                      prefixIcon: Icon(Icons.subject),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _leavingDateController,
                    keyboardType: TextInputType.datetime,
                    decoration: const InputDecoration(
                      labelText: 'Leaving Date (YYYY-MM-DD)',
                      prefixIcon: Icon(Icons.event_busy),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _reasonController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Reason',
                      prefixIcon: Icon(Icons.notes),
                    ),
                  ),
                  const SizedBox(height: 20),
                  PrimaryActionButton(
                    label: _isSubmitting ? 'SUBMITTING...' : 'SUBMIT REQUEST',
                    icon: Icons.send,
                    isLoading: _isSubmitting,
                    onPressed: _isSubmitting ? null : _submit,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Request Status',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _requestStream(),
              builder: (context, snapshot) {
                final requests = snapshot.data?.docs ?? [];
                if (requests.isEmpty) {
                  return const StatusChip(
                    label: 'No request yet',
                    type: StatusChipType.neutral,
                  );
                }
                return Column(
                  children: requests.map((doc) {
                    final data = doc.data();
                    final status = (data['status'] as String?) ?? 'pending';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: IndustrialCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(data['subject'] as String? ?? '-'),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Leaving: ${data['leavingDate'] ?? '-'}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            StatusChip(
                              label: status,
                              type: status == 'approved'
                                  ? StatusChipType.success
                                  : status == 'rejected'
                                  ? StatusChipType.alert
                                  : StatusChipType.pending,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

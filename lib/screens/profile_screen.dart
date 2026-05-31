import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../constants/organization_options.dart';
import '../services/attendance_session_service.dart';
import '../services/fcm_notification_service.dart';
import '../theme/industrial_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/employee_bottom_nav.dart';
import '../widgets/industrial_card.dart';
import '../widgets/primary_action_button.dart';
import '../widgets/status_chip.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _service = AttendanceSessionService();
  final _employeeIdController = TextEditingController();
  final _nickNameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _dobController = TextEditingController();
  final _contactController = TextEditingController();
  final _emailController = TextEditingController();
  final _joiningDateController = TextEditingController();

  bool _isSaving = false;
  bool _isLoaded = false;
  String _status = 'Editable employee profile';
  String _selectedDepartment = OrganizationOptions.teams.first;
  String _selectedRole = OrganizationOptions.employeeRoles.last;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _employeeIdController.dispose();
    _nickNameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _dobController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    _joiningDateController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await _service.loadEmployeeProfile();
    if (!mounted) return;
    setState(() {
      _employeeIdController.text = profile.employeeId;
      _nickNameController.text = profile.nickName;
      _firstNameController.text = profile.firstName;
      _lastNameController.text = profile.lastName;
      _dobController.text = profile.dateOfBirth;
      _contactController.text = profile.contactNumber;
      _emailController.text = profile.email;
      _joiningDateController.text = profile.joiningDate;
      _selectedDepartment =
          OrganizationOptions.teams.contains(profile.department)
          ? profile.department
          : OrganizationOptions.teams.first;
      _selectedRole = OrganizationOptions.employeeRoles.contains(profile.role)
          ? profile.role
          : OrganizationOptions.employeeRoles.last;
      _isLoaded = true;
    });
  }

  Future<void> _saveProfile() async {
    setState(() {
      _isSaving = true;
      _status = 'Saving to Firebase...';
    });

    try {
      await _service.saveEmployeeProfile(
        EmployeeProfile(
          employeeId: _employeeIdController.text,
          nickName: _nickNameController.text,
          firstName: _firstNameController.text,
          lastName: _lastNameController.text,
          dateOfBirth: _dobController.text,
          contactNumber: _contactController.text,
          email: _emailController.text,
          joiningDate: _joiningDateController.text,
          department: _selectedDepartment,
          role: _selectedRole,
        ),
      );
      await FcmNotificationService.instance.registerCurrentUser(
        department: _selectedDepartment,
      );

      if (!mounted) return;
      setState(() => _status = 'Profile updated');
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _leaveRequestsStream() {
    final employeeId = _employeeIdController.text.trim();
    if (!_isLoaded || employeeId.isEmpty) {
      return const Stream.empty();
    }
    return FirebaseFirestore.instance
        .collection('leave_requests')
        .where('employeeId', isEqualTo: employeeId)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Profile',
      bottomNavigationBar: const EmployeeBottomNav(currentIndex: 5),
      child: DefaultTabController(
        length: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Profile',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  StatusChip(
                    label: _status,
                    type: _isSaving
                        ? StatusChipType.pending
                        : StatusChipType.success,
                    icon: _isSaving ? Icons.sync : Icons.person,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.badge), text: 'Details'),
                Tab(icon: Icon(Icons.event_busy), text: 'Leaves'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [_buildDetailsTab(), _buildLeaveRequestsTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: IndustrialCard(
        child: _isLoaded
            ? Column(
                children: [
                  _field(_employeeIdController, 'Employee ID', Icons.badge),
                  const SizedBox(height: 12),
                  _field(_nickNameController, 'Nick Name', Icons.tag_faces),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          _firstNameController,
                          'First Name',
                          Icons.person,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          _lastNameController,
                          'Last Name',
                          Icons.person_outline,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _field(
                    _dobController,
                    'DOB (YYYY-MM-DD)',
                    Icons.cake,
                    keyboardType: TextInputType.datetime,
                  ),
                  const SizedBox(height: 12),
                  _field(
                    _contactController,
                    'Contact Number',
                    Icons.phone,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  _field(
                    _emailController,
                    'Email',
                    Icons.email,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  _field(
                    _joiningDateController,
                    'Joining Date (YYYY-MM-DD)',
                    Icons.event_available,
                    keyboardType: TextInputType.datetime,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedDepartment,
                    decoration: const InputDecoration(
                      labelText: 'Department / Team',
                      prefixIcon: Icon(Icons.factory),
                    ),
                    items: OrganizationOptions.teams
                        .map(
                          (team) =>
                              DropdownMenuItem(value: team, child: Text(team)),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedDepartment = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      prefixIcon: Icon(Icons.engineering),
                    ),
                    items: OrganizationOptions.employeeRoles
                        .map(
                          (role) =>
                              DropdownMenuItem(value: role, child: Text(role)),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedRole = value);
                    },
                  ),
                  const SizedBox(height: 20),
                  PrimaryActionButton(
                    label: _isSaving ? 'SAVING...' : 'SAVE PROFILE',
                    icon: Icons.save,
                    isLoading: _isSaving,
                    onPressed: _isSaving ? null : _saveProfile,
                  ),
                ],
              )
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildLeaveRequestsTab() {
    if (!_isLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _leaveRequestsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }

        final docs = List.of(snapshot.data?.docs ?? []);
        docs.sort((a, b) {
          final aDate = a.data()['date'] as String? ?? '';
          final bDate = b.data()['date'] as String? ?? '';
          return bDate.compareTo(aDate);
        });

        final requested = docs
            .where((doc) => doc.data()['status'] == 'requested_leave')
            .length;
        final approved = docs
            .where((doc) => doc.data()['status'] == 'approved_leave')
            .length;
        final rejected = docs
            .where((doc) => doc.data()['status'] == 'rejected_leave')
            .length;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            IndustrialCard(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  StatusChip(
                    label: 'TOTAL ${docs.length}',
                    type: StatusChipType.neutral,
                  ),
                  StatusChip(
                    label: 'REQUESTED $requested',
                    type: StatusChipType.pending,
                  ),
                  StatusChip(
                    label: 'APPROVED $approved',
                    type: StatusChipType.success,
                  ),
                  StatusChip(
                    label: 'REJECTED $rejected',
                    type: StatusChipType.alert,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (docs.isEmpty)
              const Center(
                child: StatusChip(
                  label: 'No leave requests yet',
                  type: StatusChipType.neutral,
                ),
              )
            else
              for (final doc in docs) _leaveRequestTile(doc.data()),
          ],
        );
      },
    );
  }

  Widget _leaveRequestTile(Map<String, dynamic> data) {
    final status = data['status'] as String? ?? 'requested_leave';
    final statusType = switch (status) {
      'approved_leave' => StatusChipType.success,
      'rejected_leave' => StatusChipType.alert,
      _ => StatusChipType.pending,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: IndustrialCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    data['date'] as String? ?? '-',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                StatusChip(
                  label: status.replaceAll('_', ' ').toUpperCase(),
                  type: statusType,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Reason: ${data['reason'] as String? ?? '-'}'),
            if ((data['adminReason'] as String?)?.trim().isNotEmpty == true)
              Text('Admin reason: ${data['adminReason']}'),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: IndustrialColors.primary),
      ),
    );
  }
}

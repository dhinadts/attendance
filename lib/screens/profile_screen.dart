import '../widgets/app_shell.dart';
import '../widgets/status_chip.dart';
import 'package:flutter/material.dart';
import '../theme/industrial_theme.dart';
import '../services/app_firestore.dart';
import '../widgets/industrial_card.dart';
import '../widgets/primary_action_button.dart';
import '../constants/organization_options.dart';
import '../services/fcm_notification_service.dart';
import '../services/attendance_session_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  final _fatherController = TextEditingController();
  final _motherController = TextEditingController();
  final _spouseController = TextEditingController();
  final _childrenController = TextEditingController();
  final _experienceController = TextEditingController();
  final _strengthsController = TextEditingController();
  final _weaknessesController = TextEditingController();
  final _teamActivitiesController = TextEditingController();
  final _performanceController = TextEditingController();

  bool _isSaving = false;
  bool _isLoaded = false;
  String _status = 'Editable employee profile';
  String _selectedDepartment = OrganizationOptions.teams.first;
  String _selectedRole = OrganizationOptions.employeeRoles.last;
  String _selectedMaritalStatus = _maritalStatuses.first;

  static const _maritalStatuses = ['Single', 'Married', 'Separated', 'Widowed'];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    for (final controller in [
      _employeeIdController,
      _nickNameController,
      _firstNameController,
      _lastNameController,
      _dobController,
      _contactController,
      _emailController,
      _joiningDateController,
      _fatherController,
      _motherController,
      _spouseController,
      _childrenController,
      _experienceController,
      _strengthsController,
      _weaknessesController,
      _teamActivitiesController,
      _performanceController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await _service.loadEmployeeProfile();
    final doc = await FirebaseFirestore.instance
        .appCollection('employee_profiles')
        .doc(profile.employeeId)
        .get();
    final data = doc.data() ?? {};

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
      _fatherController.text = _text(data['fatherName']);
      _motherController.text = _text(data['motherName']);
      _spouseController.text = _text(data['spouseName']);
      _childrenController.text = _text(data['children']);
      _experienceController.text = _text(data['professionalExperience']);
      _strengthsController.text = _text(data['strengths']);
      _weaknessesController.text = _text(data['weaknesses']);
      _teamActivitiesController.text = _text(data['teamActivities']);
      _performanceController.text = _text(data['performanceLevel']);
      _selectedMaritalStatus = _maritalStatuses.contains(data['maritalStatus'])
          ? data['maritalStatus'] as String
          : _maritalStatuses.first;
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
      final profile = EmployeeProfile(
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
      );
      await _service.saveEmployeeProfile(profile);

      final extraFields = {
        'fatherName': _fatherController.text.trim(),
        'motherName': _motherController.text.trim(),
        'spouseName': _spouseController.text.trim(),
        'children': _childrenController.text.trim(),
        'maritalStatus': _selectedMaritalStatus,
        'professionalExperience': _experienceController.text.trim(),
        'strengths': _strengthsController.text.trim(),
        'weaknesses': _weaknessesController.text.trim(),
        'teamActivities': _teamActivitiesController.text.trim(),
        'performanceLevel': _performanceController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .appCollection('employee_profiles')
          .doc(profile.employeeId.trim())
          .set(extraFields, SetOptions(merge: true));

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .appCollection('users')
            .doc(user.uid)
            .set(extraFields, SetOptions(merge: true));
      }

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
        .appCollection('leave_requests')
        .where('employeeId', isEqualTo: employeeId)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Profile',
      showBackButton: false,
      bottomNavigationBar: null,
      child: !_isLoaded
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _profileOverview(),
                  const SizedBox(height: 16),
                  _sectionTitle('Professional Profile', Icons.work_history),
                  const SizedBox(height: 8),
                  _professionalCard(),
                  const SizedBox(height: 16),
                  PrimaryActionButton(
                    label: _isSaving ? 'SAVING...' : 'SAVE PROFILE',
                    icon: Icons.save,
                    isLoading: _isSaving,
                    onPressed: _isSaving ? null : _saveProfile,
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle('Leave Requests', Icons.event_busy),
                  const SizedBox(height: 8),
                  _leaveRequestsSection(),
                ],
              ),
            ),
    );
  }

  Widget _profileOverview() {
    final name = _employeeName;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _identityCard(name),
              const SizedBox(height: 12),
              _personalDetailsCard(),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: _identityCard(name)),
            const SizedBox(width: 12),
            Expanded(flex: 3, child: _personalDetailsCard()),
          ],
        );
      },
    );
  }

  Widget _identityCard(String name) {
    return IndustrialCard(
      highlighted: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: IndustrialColors.primary,
                foregroundColor: Colors.white,
                child: Text(
                  _initials(name, _emailController.text),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'Employee' : name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_selectedDepartment | $_selectedRole',
                      style: Theme.of(context).textTheme.bodySmall,
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
            ],
          ),
          const SizedBox(height: 16),
          _field(_firstNameController, 'First Name', Icons.person),
          const SizedBox(height: 10),
          _field(_lastNameController, 'Last Name', Icons.person_outline),
          const SizedBox(height: 10),
          _field(_employeeIdController, 'Employee ID / Code', Icons.badge),
          const SizedBox(height: 10),
          _field(
            _emailController,
            'Employee Email',
            Icons.email,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 10),
          _field(
            _contactController,
            'Employee Phone',
            Icons.phone,
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
    );
  }

  Widget _personalDetailsCard() {
    return IndustrialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Personal Details', Icons.family_restroom),
          const SizedBox(height: 12),
          _field(_nickNameController, 'Nick Name', Icons.tag_faces),
          const SizedBox(height: 10),
          _field(
            _dobController,
            'DOB (YYYY-MM-DD)',
            Icons.cake,
            keyboardType: TextInputType.datetime,
          ),
          const SizedBox(height: 10),
          _field(_fatherController, 'Father Name', Icons.man),
          const SizedBox(height: 10),
          _field(_motherController, 'Mother Name', Icons.woman),
          const SizedBox(height: 10),
          _field(_spouseController, 'Spouse Name', Icons.favorite),
          const SizedBox(height: 10),
          _field(_childrenController, 'Children', Icons.child_care),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _selectedMaritalStatus,
            decoration: const InputDecoration(
              labelText: 'Marital Status',
              prefixIcon: Icon(Icons.diversity_1),
            ),
            items: _maritalStatuses
                .map(
                  (status) =>
                      DropdownMenuItem(value: status, child: Text(status)),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedMaritalStatus = value);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _professionalCard() {
    return IndustrialCard(
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedDepartment,
            decoration: const InputDecoration(
              labelText: 'Department / Team',
              prefixIcon: Icon(Icons.factory),
            ),
            items: OrganizationOptions.teams
                .map((team) => DropdownMenuItem(value: team, child: Text(team)))
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _selectedDepartment = value);
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _selectedRole,
            decoration: const InputDecoration(
              labelText: 'Employee Role',
              prefixIcon: Icon(Icons.engineering),
            ),
            items: OrganizationOptions.employeeRoles
                .map((role) => DropdownMenuItem(value: role, child: Text(role)))
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _selectedRole = value);
            },
          ),
          const SizedBox(height: 10),
          _field(
            _joiningDateController,
            'Joining Date (YYYY-MM-DD)',
            Icons.event_available,
            keyboardType: TextInputType.datetime,
          ),
          const SizedBox(height: 10),
          _field(
            _experienceController,
            'Professional Experience',
            Icons.history_edu,
            maxLines: 3,
          ),
          const SizedBox(height: 10),
          _field(_strengthsController, 'Strengths', Icons.trending_up),
          const SizedBox(height: 10),
          _field(_weaknessesController, 'Weaknesses', Icons.psychology),
          const SizedBox(height: 10),
          _field(
            _teamActivitiesController,
            'Team Activities',
            Icons.groups,
            maxLines: 3,
          ),
          const SizedBox(height: 10),
          _field(_performanceController, 'Performance Level', Icons.speed),
        ],
      ),
    );
  }

  Widget _leaveRequestsSection() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _leaveRequestsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const IndustrialCard(
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return IndustrialCard(child: Text(snapshot.error.toString()));
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const IndustrialCard(
                child: Center(
                  child: StatusChip(
                    label: 'No leave requests yet',
                    type: StatusChipType.neutral,
                  ),
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

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: IndustrialColors.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: IndustrialColors.primary),
      ),
    );
  }

  String get _employeeName =>
      '${_firstNameController.text} ${_lastNameController.text}'.trim();

  String _initials(String name, String fallback) {
    final source = name.trim().isEmpty ? fallback : name;
    final parts = source
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'E';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  String _text(Object? value) => value?.toString().trim() ?? '';
}

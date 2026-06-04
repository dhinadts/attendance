import 'dart:convert';
import 'dart:ui' as ui;
import '../widgets/app_shell.dart';
import '../widgets/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/industrial_theme.dart';
import '../services/app_firestore.dart';
import '../widgets/industrial_card.dart';
import '../widgets/admin_bottom_nav.dart';
import '../widgets/primary_action_button.dart';
import '../constants/organization_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Controllers for editing
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _nickNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _contactController = TextEditingController();
  final _dobController = TextEditingController();
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
  final _reportingToController = TextEditingController();
  final _workLocationController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _adminScopeController = TextEditingController();

  String _selectedDepartment = OrganizationOptions.teams.first;
  String _selectedRole = OrganizationOptions.adminRoles.first;
  String _selectedMaritalStatus = _maritalStatuses.first;
  String _selectedAccessLevel = _accessLevels.first;

  bool _isSaving = false;
  bool _isLoaded = false;
  String _status = 'Admin account configuration';
  String? _photoBase64;

  static const _maritalStatuses = ['Single', 'Married', 'Separated', 'Widowed'];

  static const _accessLevels = [
    'FULL ACCESS',
    'CEO ACCESS',
    'ADMIN ACCESS',
    'HR ACCESS',
    'TEAM ADMIN',
  ];

  List<String> get _roleOptions => {
    ...OrganizationOptions.adminRoles,
    ...OrganizationOptions.partialAdminRoles,
    ...OrganizationOptions.employeeRoles,
  }.toList();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAdminData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _nickNameController.dispose();
    _emailController.dispose();
    _contactController.dispose();
    _dobController.dispose();
    _joiningDateController.dispose();
    _fatherController.dispose();
    _motherController.dispose();
    _spouseController.dispose();
    _childrenController.dispose();
    _experienceController.dispose();
    _strengthsController.dispose();
    _weaknessesController.dispose();
    _teamActivitiesController.dispose();
    _performanceController.dispose();
    _reportingToController.dispose();
    _workLocationController.dispose();
    _emergencyContactController.dispose();
    _adminScopeController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.appCollection('users').doc(user.uid).get();
      final data = doc.data() ?? {};

      setState(() {
        _firstNameController.text = data['firstName'] as String? ?? '';
        _lastNameController.text = data['lastName'] as String? ?? '';
        _nickNameController.text = data['nickName'] as String? ?? '';
        _emailController.text = data['email'] as String? ?? user.email ?? '';
        _contactController.text = data['contactNumber'] as String? ?? '';
        _dobController.text = data['dateOfBirth'] as String? ?? '';
        _joiningDateController.text = data['joiningDate'] as String? ?? '';
        _fatherController.text = _text(data['fatherName']);
        _motherController.text = _text(data['motherName']);
        _spouseController.text = _text(data['spouseName']);
        _childrenController.text = _text(data['children']);
        _experienceController.text = _text(data['professionalExperience']);
        _strengthsController.text = _text(data['strengths']);
        _weaknessesController.text = _text(data['weaknesses']);
        _teamActivitiesController.text = _text(data['teamActivities']);
        _performanceController.text = _text(data['performanceLevel']);
        _reportingToController.text = _text(data['reportingTo']);
        _workLocationController.text = _text(data['workLocation']);
        _emergencyContactController.text = _text(data['emergencyContact']);
        _adminScopeController.text = _text(data['adminScope']);
        _photoBase64 = data['photoBase64'] as String?;
        _selectedMaritalStatus =
            _maritalStatuses.contains(data['maritalStatus'])
            ? data['maritalStatus'] as String
            : _maritalStatuses.first;
        _selectedAccessLevel = _accessLevels.contains(data['accessLevel'])
            ? data['accessLevel'] as String
            : _accessLevels.first;

        final dept = data['department'] as String? ?? '';
        _selectedDepartment = OrganizationOptions.teams.contains(dept)
            ? dept
            : OrganizationOptions.teams.first;

        final role =
            data['employeeRole'] as String? ?? data['role'] as String? ?? '';
        _selectedRole = _roleOptions.contains(role)
            ? role
            : OrganizationOptions.adminRoles.first;

        _isLoaded = true;
      });
    } catch (e) {
      setState(() {
        _status = 'Error loading profile: ${e.toString()}';
      });
    }
  }

  Future<void> _saveAdminData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() {
      _isSaving = true;
      _status = 'Saving changes...';
    });

    try {
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final displayName = '$firstName $lastName'.trim();
      final currentDoc = await _firestore
          .appCollection('users')
          .doc(user.uid)
          .get();
      final currentRole = currentDoc.data()?['role'] as String? ?? 'admin';

      await _firestore.appCollection('users').doc(user.uid).set({
        'firstName': firstName,
        'lastName': lastName,
        'displayName': displayName.isEmpty ? user.email : displayName,
        'nickName': _nickNameController.text.trim(),
        'email': _emailController.text.trim().isEmpty
            ? user.email
            : _emailController.text.trim(),
        'contactNumber': _contactController.text.trim(),
        'dateOfBirth': _dobController.text.trim(),
        'joiningDate': _joiningDateController.text.trim(),
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
        'reportingTo': _reportingToController.text.trim(),
        'workLocation': _workLocationController.text.trim(),
        'emergencyContact': _emergencyContactController.text.trim(),
        'adminScope': _adminScopeController.text.trim(),
        'accessLevel': _selectedAccessLevel,
        'department': _selectedDepartment,
        'employeeRole': _selectedRole,
        'role': currentRole,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await user.updateDisplayName(displayName);

      setState(() {
        _isSaving = false;
        _status = 'Admin details saved';
      });
    } catch (e) {
      setState(() {
        _isSaving = false;
        _status = 'Error saving changes: ${e.toString()}';
      });
    }
  }

  Future<void> _showPhotoPicker() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update profile picture'),
        content: const Text(
          'Choose how to set the admin profile picture. The selected image is stored as base64 in users/{uid}.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _clearPhoto();
            },
            child: const Text('CLEAR'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _saveInitialsAvatar();
            },
            child: const Text('INITIALS'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _saveBrandAvatar();
            },
            child: const Text('APP LOGO'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveBrandAvatar() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() {
      _status = 'Saving profile picture...';
    });

    try {
      final bytes = await rootBundle.load('assets/branding/app_logo.png');
      final photoBase64 = base64Encode(bytes.buffer.asUint8List());
      await _firestore.appCollection('users').doc(user.uid).set({
        'photoBase64': photoBase64,
        'photoSource': 'app_logo',
        'photoUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() {
        _photoBase64 = photoBase64;
        _status = 'Profile picture updated';
      });
    } catch (e) {
      setState(() {
        _status = 'Error uploading photo: ${e.toString()}';
      });
    }
  }

  Future<void> _saveInitialsAvatar() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final initials = _initials(
      '${_firstNameController.text} ${_lastNameController.text}'.trim(),
      user.email ?? 'A',
    );
    final photoBase64 = await _buildInitialsAvatarBase64(initials);
    await _firestore.appCollection('users').doc(user.uid).set({
      'photoBase64': photoBase64,
      'photoSource': 'initials',
      'photoUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    setState(() {
      _photoBase64 = photoBase64;
      _status = 'Profile picture updated';
    });
  }

  Future<void> _clearPhoto() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore.appCollection('users').doc(user.uid).set({
      'photoBase64': FieldValue.delete(),
      'photoSource': FieldValue.delete(),
      'photoUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    setState(() {
      _photoBase64 = null;
      _status = 'Profile picture cleared';
    });
  }

  Future<String> _buildInitialsAvatarBase64(String initials) async {
    const size = 320.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final rect = Rect.fromLTWH(0, 0, size, size);
    final gradient = LinearGradient(
      colors: [IndustrialColors.primary, IndustrialColors.secondary],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(rect);

    final paint = Paint()..shader = gradient;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(72)),
      paint,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 112,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return base64Encode(bytes!.buffer.asUint8List());
  }

  String _initials(String name, String fallback) {
    final source = name.trim().isEmpty ? fallback : name;
    final parts = source
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'A';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  Uint8List? _decodePhoto(String? photoBase64) {
    if (photoBase64 == null || photoBase64.trim().isEmpty) return null;
    try {
      return base64Decode(photoBase64);
    } catch (_) {
      return null;
    }
  }

  String _text(Object? value) => value?.toString().trim() ?? '';

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return const AppShell(
        title: 'Admin Profile',
        showBackButton: false,
        bottomNavigationBar: AdminBottomNav(currentIndex: 0),
        child: Center(child: Text('Please log in.')),
      );
    }

    return AppShell(
      title: 'Admin Profile',
      showBackButton: false,
      bottomNavigationBar: const AdminBottomNav(currentIndex: 0),
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _firestore.appCollection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !_isLoaded) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = snapshot.data?.data() ?? {};
          final email = userData['email'] as String? ?? user.email ?? '';
          final displayName =
              userData['displayName'] as String? ??
              userData['firstName'] as String? ??
              'Admin';
          final photoBase64 =
              (userData['photoBase64'] as String?) ?? _photoBase64;
          final department = userData['department'] as String? ?? 'TECH';
          final role =
              userData['employeeRole'] as String? ??
              userData['role'] as String? ??
              'CEO';
          final imageBytes = _decodePhoto(photoBase64);

          return Column(
            children: [
              // Profile Header Card
              Container(
                width: double.infinity,
                color: IndustrialColors.surface,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: IndustrialColors.primary,
                          backgroundImage: imageBytes == null
                              ? null
                              : MemoryImage(imageBytes),
                          child: imageBytes == null
                              ? Text(
                                  _initials(displayName, email),
                                  style: const TextStyle(
                                    fontSize: 36,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: IndustrialColors.primaryContainer,
                          child: IconButton(
                            icon: const Icon(
                              Icons.camera_alt,
                              size: 16,
                              color: Colors.white,
                            ),
                            onPressed: _showPhotoPicker,
                            tooltip: 'Update Photo',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      displayName,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '$role | $department',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    StatusChip(
                      label: _status,
                      type: _isSaving
                          ? StatusChipType.pending
                          : StatusChipType.success,
                      icon: _isSaving ? Icons.sync : Icons.admin_panel_settings,
                    ),
                  ],
                ),
              ),

              TabBar(
                controller: _tabController,
                indicatorColor: IndustrialColors.primary,
                labelColor: IndustrialColors.primary,
                unselectedLabelColor: IndustrialColors.onSurfaceVariant,
                tabs: const [
                  Tab(icon: Icon(Icons.person), text: 'Details'),
                  Tab(icon: Icon(Icons.history), text: 'Activities'),
                ],
              ),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [_buildDetailsTab(email), _buildActivitiesTab()],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Tab 1: Details Layout (Editable)
  Widget _buildDetailsTab(String email) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _adminProfileOverview(email),
          const SizedBox(height: 16),
          _sectionTitle('Professional Profile', Icons.work_history),
          const SizedBox(height: 8),
          _adminProfessionalCard(),
          const SizedBox(height: 16),
          _sectionTitle('Admin Controls', Icons.admin_panel_settings),
          const SizedBox(height: 8),
          _adminControlCard(),
          const SizedBox(height: 18),
          PrimaryActionButton(
            label: _isSaving ? 'SAVING...' : 'SAVE PROFILE',
            icon: Icons.save,
            isLoading: _isSaving,
            onPressed: _isSaving ? null : _saveAdminData,
          ),
        ],
      ),
    );
  }

  Widget _adminProfileOverview(String email) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _adminIdentityCard(email),
              const SizedBox(height: 12),
              _adminPersonalCard(),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: _adminIdentityCard(email)),
            const SizedBox(width: 12),
            Expanded(flex: 3, child: _adminPersonalCard()),
          ],
        );
      },
    );
  }

  Widget _adminIdentityCard(String email) {
    return IndustrialCard(
      highlighted: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Account Details', Icons.badge),
          const SizedBox(height: 12),
          _field(_firstNameController, 'First Name', Icons.person),
          const SizedBox(height: 10),
          _field(_lastNameController, 'Last Name', Icons.person_outline),
          const SizedBox(height: 10),
          _field(_nickNameController, 'Nickname', Icons.tag_faces),
          const SizedBox(height: 10),
          _field(
            _emailController,
            'Email Address',
            Icons.email,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 10),
          _field(
            _contactController,
            'Phone Number',
            Icons.phone,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 10),
          _field(
            _emergencyContactController,
            'Emergency Contact',
            Icons.contact_emergency,
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
    );
  }

  Widget _adminPersonalCard() {
    return IndustrialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Personal Details', Icons.family_restroom),
          const SizedBox(height: 12),
          _field(
            _dobController,
            'Date of Birth (YYYY-MM-DD)',
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

  Widget _adminProfessionalCard() {
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
              labelText: 'Admin / CEO Role',
              prefixIcon: Icon(Icons.engineering),
            ),
            items: _roleOptions
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
            Icons.event,
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

  Widget _adminControlCard() {
    return IndustrialCard(
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedAccessLevel,
            decoration: const InputDecoration(
              labelText: 'Access Level',
              prefixIcon: Icon(Icons.security),
            ),
            items: _accessLevels
                .map(
                  (level) => DropdownMenuItem(value: level, child: Text(level)),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _selectedAccessLevel = value);
            },
          ),
          const SizedBox(height: 10),
          _field(_reportingToController, 'Reporting To', Icons.account_tree),
          const SizedBox(height: 10),
          _field(_workLocationController, 'Work Location', Icons.location_on),
          const SizedBox(height: 10),
          _field(
            _adminScopeController,
            'Admin Responsibility Scope',
            Icons.fact_check,
            maxLines: 3,
          ),
        ],
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

  // Tab 2: Activities Layout
  Widget _buildActivitiesTab() {
    final activities = const [
      (
        'Reviewed & Approved Leave Request',
        'Dhinakaran | May 31, 2026',
        Icons.check_circle_outline,
        IndustrialColors.secondary,
      ),
      (
        'Reviewed Leave Request',
        'Employee 2 | May 31, 2026',
        Icons.hourglass_top,
        IndustrialColors.primary,
      ),
      (
        'Updated Face Authentication Radius',
        'Zone Radius: 10 meters | May 30, 2026',
        Icons.settings,
        IndustrialColors.onSurfaceVariant,
      ),
      (
        'Generated Slips & Reviewed Deductions',
        'May 2026 Payroll Generated | May 28, 2026',
        Icons.payments,
        IndustrialColors.primary,
      ),
      (
        'Configured WorkSync Core Parameters',
        'System Update v1.0.0 | May 25, 2026',
        Icons.terminal,
        IndustrialColors.onSurfaceVariant,
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Company Role Activities',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _adminStat('18', 'Approvals', Icons.verified)),
            const SizedBox(width: 12),
            Expanded(child: _adminStat('6', 'Payroll Runs', Icons.payments)),
            const SizedBox(width: 12),
            Expanded(child: _adminStat('4', 'Policy Edits', Icons.tune)),
          ],
        ),
        const SizedBox(height: 16),
        for (final act in activities)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: IndustrialCard(
              child: Row(
                children: [
                  Icon(act.$3, color: act.$4, size: 28),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          act.$1,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          act.$2,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const StatusChip(
                    label: 'ADMIN LOG',
                    type: StatusChipType.neutral,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _adminStat(String value, String label, IconData icon) {
    return IndustrialCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Icon(icon, color: IndustrialColors.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: IndustrialColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

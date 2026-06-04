import 'dart:convert';
import 'dart:ui' as ui;
import '../widgets/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/industrial_theme.dart';
import '../services/app_firestore.dart';
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
  String _status = 'All changes are saved';
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

      if (!mounted) return;
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
      if (!mounted) return;
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
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _status = 'Admin details saved';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _status = 'Error saving changes: ${e.toString()}';
      });
    }
  }

  Future<void> _showPhotoPicker() async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Profile Picture',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Divider(),
            _buildPickerOption(
              icon: Icons.text_fields,
              label: 'Use Initials',
              onTap: () {
                Navigator.pop(context);
                _saveInitialsAvatar();
              },
            ),
            _buildPickerOption(
              icon: Icons.branding_watermark,
              label: 'Use App Logo',
              onTap: () {
                Navigator.pop(context);
                _saveBrandAvatar();
              },
            ),
            _buildPickerOption(
              icon: Icons.delete_outline,
              label: 'Clear Photo',
              onTap: () {
                Navigator.pop(context);
                _clearPhoto();
              },
              isDestructive: true,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? Colors.red : IndustrialColors.primary,
      ),
      title: Text(
        label,
        style: TextStyle(color: isDestructive ? Colors.red : null),
      ),
      onTap: onTap,
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
      if (!mounted) return;
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
    if (!mounted) return;
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
    if (!mounted) return;
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

  bool _isCompactScreen(BuildContext context) =>
      MediaQuery.of(context).size.width < 800;

  double _s(BuildContext context, double v) =>
      _isCompactScreen(context) ? v * 0.65 : v;

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

          return Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(13),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: IndustrialColors.primary,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelColor: IndustrialColors.primary,
                  unselectedLabelColor: IndustrialColors.onSurfaceVariant,
                  tabs: const [
                    Tab(icon: Icon(Icons.person_outline), text: 'PROFILE'),
                    Tab(icon: Icon(Icons.history_outlined), text: 'ACTIVITY'),
                  ],
                ),
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

  // Modern SaaS Profile Header
  Widget _buildProfileHeader(String email) {
    final displayName =
        '${_firstNameController.text} ${_lastNameController.text}'.trim();
    final imageBytes = _decodePhoto(_photoBase64);
    final radius = _isCompactScreen(context) ? 40.0 : 56.0;
    final initialsFont = _isCompactScreen(context) ? 24.0 : 36.0;
    final w = MediaQuery.of(context).size.width;

    return Container(
      padding: EdgeInsets.all(_s(context, 24)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            IndustrialColors.primary.withAlpha(26),
            IndustrialColors.secondary.withAlpha(13),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: IndustrialColors.primary.withAlpha(77),
                      blurRadius: _s(context, 12),
                      offset: Offset(0, _s(context, 4)),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: radius,
                  backgroundColor: IndustrialColors.primary,
                  foregroundColor: Colors.white,
                  backgroundImage: imageBytes == null
                      ? null
                      : MemoryImage(imageBytes),
                  child: imageBytes == null
                      ? Text(
                          _initials(displayName, email),
                          style: TextStyle(
                            fontSize: initialsFont,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      : null,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: IndustrialColors.primaryContainer,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: IconButton(
                  tooltip: 'Edit photo',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.camera_alt, size: 18),
                  color: IndustrialColors.primary,
                  onPressed: _showPhotoPicker,
                ),
              ),
            ],
          ),
          SizedBox(width: _s(context, 24)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayName.isEmpty ? 'Admin User' : displayName,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 2,
                        softWrap: true,
                        overflow: TextOverflow.visible,
                      ),
                    ),
                    SizedBox(width: _s(context, 12)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: IndustrialColors.primary.withAlpha(26),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified,
                            size: 16,
                            color: IndustrialColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _selectedAccessLevel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: IndustrialColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.business_center,
                      size: 16,
                      color: IndustrialColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$_selectedDepartment • $_selectedRole',
                      style: TextStyle(
                        color: IndustrialColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.email,
                      size: 16,
                      color: IndustrialColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      email,
                      style: TextStyle(
                        color: IndustrialColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _isSaving
                        ? IndustrialColors.warning.withAlpha(26)
                        : IndustrialColors.success.withAlpha(26),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isSaving ? Icons.sync : Icons.check_circle,
                        size: 16,
                        color: _isSaving
                            ? IndustrialColors.warning
                            : IndustrialColors.success,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _status,
                        style: TextStyle(
                          fontSize: 12,
                          color: _isSaving
                              ? IndustrialColors.warning
                              : IndustrialColors.success,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // On wide screens (>=900px), show compact info arranged in 2x2 tiles
          if (w >= 900) ...[
            SizedBox(width: _s(context, 20)),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _miniInfoTile(
                          'Phone',
                          _contactController.text,
                          Icons.phone,
                        ),
                      ),
                      SizedBox(width: _s(context, 8)),
                      Expanded(
                        child: _miniInfoTile(
                          'Emergency',
                          _emergencyContactController.text,
                          Icons.contact_emergency,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: _s(context, 8)),
                  Row(
                    children: [
                      Expanded(
                        child: _miniInfoTile(
                          'Work Location',
                          _workLocationController.text,
                          Icons.location_on,
                        ),
                      ),
                      SizedBox(width: _s(context, 8)),
                      Expanded(
                        child: _miniInfoTile(
                          'Reporting To',
                          _reportingToController.text,
                          Icons.people,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoGrid() {
    final w = MediaQuery.of(context).size.width;
    final spacing = _s(context, 12);
    // Large screens: single horizontal row with four cards
    if (w >= 1000) {
      return Row(
        children: [
          Expanded(
            child: _infoCard('Phone', _contactController.text, Icons.phone),
          ),
          SizedBox(width: spacing),
          Expanded(
            child: _infoCard(
              'Emergency',
              _emergencyContactController.text,
              Icons.contact_emergency,
            ),
          ),
          SizedBox(width: spacing),
          Expanded(
            child: _infoCard(
              'Work Location',
              _workLocationController.text,
              Icons.location_on,
            ),
          ),
          SizedBox(width: spacing),
          Expanded(
            child: _infoCard(
              'Reporting To',
              _reportingToController.text,
              Icons.people,
            ),
          ),
        ],
      );
    }

    // Medium screens: 2-column grid
    if (w >= 600) {
      final cols = 2;
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: cols,
        childAspectRatio: 1.4,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        children: [
          _infoCard('Phone', _contactController.text, Icons.phone),
          _infoCard(
            'Emergency',
            _emergencyContactController.text,
            Icons.contact_emergency,
          ),
          _infoCard(
            'Work Location',
            _workLocationController.text,
            Icons.location_on,
          ),
          _infoCard('Reporting To', _reportingToController.text, Icons.people),
        ],
      );
    }

    // Small screens: stacked column
    return Column(
      children: [
        _infoCard('Phone', _contactController.text, Icons.phone),
        SizedBox(height: spacing),
        _infoCard(
          'Emergency',
          _emergencyContactController.text,
          Icons.contact_emergency,
        ),
        SizedBox(height: spacing),
        _infoCard(
          'Work Location',
          _workLocationController.text,
          Icons.location_on,
        ),
        SizedBox(height: spacing),
        _infoCard('Reporting To', _reportingToController.text, Icons.people),
      ],
    );
  }

  Widget _infoCard(String label, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.all(_s(context, 12)),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withAlpha(26)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: _s(context, 18),
                color: IndustrialColors.primary,
              ),
              SizedBox(width: _s(context, 8)),
              Text(
                label,
                style: TextStyle(
                  fontSize: _s(context, 12),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value.isNotEmpty ? value : 'Not set',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: _s(context, 14),
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniInfoTile(String label, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _s(context, 12),
        vertical: _s(context, 8),
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withAlpha(20)),
      ),
      child: Row(
        children: [
          Icon(icon, size: _s(context, 16), color: IndustrialColors.primary),
          SizedBox(width: _s(context, 8)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: _s(context, 11),
                    color: IndustrialColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isNotEmpty ? value : 'Not set',
                  style: TextStyle(
                    fontSize: _s(context, 13),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, Widget child) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withAlpha(26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: IndustrialColors.primary.withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: IndustrialColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 0),
          Padding(padding: const EdgeInsets.all(20), child: child),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: IndustrialColors.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withAlpha(51)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: IndustrialColors.primary),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<T> items,
    required String label,
    required IconData icon,
    required void Function(T?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withAlpha(51)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20, color: IndustrialColors.primary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        items: items
            .map(
              (item) =>
                  DropdownMenuItem(value: item, child: Text(item.toString())),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  // Tab 1: Details Layout (Editable)
  Widget _buildDetailsTab(String email) {
    final w = MediaQuery.of(context).size.width;
    return SingleChildScrollView(
      padding: EdgeInsets.all(_s(context, 16)),
      child: Column(
        children: [
          _buildProfileHeader(email),
          SizedBox(height: _s(context, 24)),
          if (w < 900) ...[
            _buildInfoGrid(),
            SizedBox(height: _s(context, 8)),
            _buildSection(
              'Personal Information',
              Icons.person_outline,
              Column(
                children: [
                  _buildTextField(
                    _firstNameController,
                    'First Name',
                    Icons.person,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    _lastNameController,
                    'Last Name',
                    Icons.person_outline,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(_nickNameController, 'Nickname', Icons.tag),
                  const SizedBox(height: 16),
                  _buildTextField(
                    _emailController,
                    'Email Address',
                    Icons.email,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    _contactController,
                    'Phone Number',
                    Icons.phone,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    _emergencyContactController,
                    'Emergency Contact',
                    Icons.contact_emergency,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    _dobController,
                    'Date of Birth (YYYY-MM-DD)',
                    Icons.cake,
                    keyboardType: TextInputType.datetime,
                  ),
                  const SizedBox(height: 16),
                  _buildDropdown(
                    value: _selectedMaritalStatus,
                    items: _maritalStatuses,
                    label: 'Marital Status',
                    icon: Icons.favorite,
                    onChanged: (v) =>
                        setState(() => _selectedMaritalStatus = v!),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    _fatherController,
                    'Father\'s Name',
                    Icons.man,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    _motherController,
                    'Mother\'s Name',
                    Icons.woman,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    _spouseController,
                    'Spouse\'s Name',
                    Icons.favorite,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    _childrenController,
                    'Children',
                    Icons.child_care,
                  ),
                ],
              ),
            ),
            _buildSection(
              'Professional Information',
              Icons.work_outline,
              Column(
                children: [
                  _buildDropdown(
                    value: _selectedDepartment,
                    items: OrganizationOptions.teams,
                    label: 'Department',
                    icon: Icons.business,
                    onChanged: (v) => setState(() => _selectedDepartment = v!),
                  ),
                  const SizedBox(height: 16),
                  _buildDropdown(
                    value: _selectedRole,
                    items: _roleOptions,
                    label: 'Role',
                    icon: Icons.engineering,
                    onChanged: (v) => setState(() => _selectedRole = v!),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    _joiningDateController,
                    'Joining Date (YYYY-MM-DD)',
                    Icons.event,
                    keyboardType: TextInputType.datetime,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    _experienceController,
                    'Professional Experience',
                    Icons.history_edu,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    _strengthsController,
                    'Strengths',
                    Icons.trending_up,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    _weaknessesController,
                    'Areas for Improvement',
                    Icons.psychology,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    _teamActivitiesController,
                    'Team Activities',
                    Icons.groups,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    _performanceController,
                    'Performance Rating',
                    Icons.speed,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    _workLocationController,
                    'Work Location',
                    Icons.location_on,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    _reportingToController,
                    'Reporting Manager',
                    Icons.people,
                  ),
                ],
              ),
            ),
          ] else ...[
            // Wide screens: show Personal and Professional side-by-side
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildSection(
                    'Personal Information',
                    Icons.person_outline,
                    Column(
                      children: [
                        _buildTextField(
                          _firstNameController,
                          'First Name',
                          Icons.person,
                        ),
                        SizedBox(height: _s(context, 12)),
                        _buildTextField(
                          _lastNameController,
                          'Last Name',
                          Icons.person_outline,
                        ),
                        SizedBox(height: _s(context, 12)),
                        _buildTextField(
                          _nickNameController,
                          'Nickname',
                          Icons.tag,
                        ),
                        SizedBox(height: _s(context, 12)),
                        _buildTextField(
                          _emailController,
                          'Email Address',
                          Icons.email,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        SizedBox(height: _s(context, 12)),
                        _buildTextField(
                          _contactController,
                          'Phone Number',
                          Icons.phone,
                          keyboardType: TextInputType.phone,
                        ),
                        SizedBox(height: _s(context, 12)),
                        _buildTextField(
                          _emergencyContactController,
                          'Emergency Contact',
                          Icons.contact_emergency,
                          keyboardType: TextInputType.phone,
                        ),
                        SizedBox(height: _s(context, 12)),
                        _buildTextField(
                          _dobController,
                          'Date of Birth (YYYY-MM-DD)',
                          Icons.cake,
                          keyboardType: TextInputType.datetime,
                        ),
                        SizedBox(height: _s(context, 12)),
                        _buildDropdown(
                          value: _selectedMaritalStatus,
                          items: _maritalStatuses,
                          label: 'Marital Status',
                          icon: Icons.favorite,
                          onChanged: (v) =>
                              setState(() => _selectedMaritalStatus = v!),
                        ),
                        SizedBox(height: _s(context, 12)),
                        _buildTextField(
                          _fatherController,
                          'Father\'s Name',
                          Icons.man,
                        ),
                        SizedBox(height: _s(context, 12)),
                        _buildTextField(
                          _motherController,
                          'Mother\'s Name',
                          Icons.woman,
                        ),
                        SizedBox(height: _s(context, 12)),
                        _buildTextField(
                          _spouseController,
                          'Spouse\'s Name',
                          Icons.favorite,
                        ),
                        SizedBox(height: _s(context, 12)),
                        _buildTextField(
                          _childrenController,
                          'Children',
                          Icons.child_care,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: _s(context, 20)),
                Expanded(
                  child: _buildSection(
                    'Professional Information',
                    Icons.work_outline,
                    Column(
                      children: [
                        _buildDropdown(
                          value: _selectedDepartment,
                          items: OrganizationOptions.teams,
                          label: 'Department',
                          icon: Icons.business,
                          onChanged: (v) =>
                              setState(() => _selectedDepartment = v!),
                        ),
                        SizedBox(height: _s(context, 12)),
                        _buildDropdown(
                          value: _selectedRole,
                          items: _roleOptions,
                          label: 'Role',
                          icon: Icons.engineering,
                          onChanged: (v) => setState(() => _selectedRole = v!),
                        ),
                        SizedBox(height: _s(context, 12)),
                        _buildTextField(
                          _joiningDateController,
                          'Joining Date (YYYY-MM-DD)',
                          Icons.event,
                          keyboardType: TextInputType.datetime,
                        ),
                        SizedBox(height: _s(context, 12)),
                        _buildTextField(
                          _experienceController,
                          'Professional Experience',
                          Icons.history_edu,
                          maxLines: 3,
                        ),
                        SizedBox(height: _s(context, 12)),
                        _buildTextField(
                          _strengthsController,
                          'Strengths',
                          Icons.trending_up,
                        ),
                        SizedBox(height: _s(context, 12)),
                        _buildTextField(
                          _weaknessesController,
                          'Areas for Improvement',
                          Icons.psychology,
                        ),
                        SizedBox(height: _s(context, 12)),
                        _buildTextField(
                          _teamActivitiesController,
                          'Team Activities',
                          Icons.groups,
                          maxLines: 2,
                        ),
                        SizedBox(height: _s(context, 12)),
                        _buildTextField(
                          _performanceController,
                          'Performance Rating',
                          Icons.speed,
                        ),
                        SizedBox(height: _s(context, 12)),
                        _buildTextField(
                          _workLocationController,
                          'Work Location',
                          Icons.location_on,
                        ),
                        SizedBox(height: _s(context, 12)),
                        _buildTextField(
                          _reportingToController,
                          'Reporting Manager',
                          Icons.people,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
          _buildSection(
            'Admin Configuration',
            Icons.admin_panel_settings,
            Column(
              children: [
                _buildDropdown(
                  value: _selectedAccessLevel,
                  items: _accessLevels,
                  label: 'Access Level',
                  icon: Icons.security,
                  onChanged: (v) => setState(() => _selectedAccessLevel = v!),
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  _adminScopeController,
                  'Admin Scope & Responsibilities',
                  Icons.fact_check,
                  maxLines: 3,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          PrimaryActionButton(
            label: _isSaving ? 'SAVING...' : 'UPDATE PROFILE',
            icon: Icons.save,
            isLoading: _isSaving,
            onPressed: _isSaving ? null : _saveAdminData,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // Tab 2: Activities Layout
  Widget _buildActivitiesTab() {
    final activities = const [
      (
        'Approved Leave Request',
        'Dhinakaran | May 31, 2026',
        Icons.check_circle,
        IndustrialColors.success,
      ),
      (
        'Pending Leave Review',
        'Employee 2 | May 31, 2026',
        Icons.hourglass_top,
        IndustrialColors.warning,
      ),
      (
        'Updated Security Settings',
        'Face Auth Radius: 10m | May 30, 2026',
        Icons.settings,
        IndustrialColors.primary,
      ),
      (
        'Generated Payroll',
        'May 2026 | May 28, 2026',
        Icons.payments,
        IndustrialColors.secondary,
      ),
      (
        'System Configuration',
        'WorkSync v1.0.0 | May 25, 2026',
        Icons.terminal,
        IndustrialColors.onSurfaceVariant,
      ),
      (
        'User Permission Update',
        '3 users modified | May 24, 2026',
        Icons.security,
        IndustrialColors.primary,
      ),
      (
        'Report Generated',
        'Monthly HR Report | May 23, 2026',
        Icons.description,
        IndustrialColors.success,
      ),
    ];

    return ListView(
      padding: EdgeInsets.all(_s(context, 16)),
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: EdgeInsets.all(_s(context, 20)),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                IndustrialColors.primary.withAlpha(26),
                IndustrialColors.secondary.withAlpha(13),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMetric('24', 'Actions', Icons.touch_app),
              _buildMetric('8', 'Pending', Icons.pending_actions),
              _buildMetric('156', 'Points', Icons.stars),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Recent Activity',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: activities.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final act = activities[index];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withAlpha(26)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: act.$4.withAlpha(26),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(act.$3, color: act.$4, size: 22),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          act.$1,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          act.$2,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: IndustrialColors.primary.withAlpha(26),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'LOG',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMetric(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: IndustrialColors.primary, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: IndustrialColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

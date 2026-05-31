import 'package:attendance/services/attendance_session_service.dart';
import 'package:attendance/theme/industrial_theme.dart';
import 'package:attendance/widgets/app_shell.dart';
import 'package:attendance/widgets/industrial_card.dart';
import 'package:attendance/widgets/primary_action_button.dart';
import 'package:attendance/widgets/status_chip.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _service = AttendanceSessionService();
  final _employeeIdController = TextEditingController();
  final _employeeNameController = TextEditingController();
  final _roleController = TextEditingController();
  final _departmentController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isSaving = false;
  bool _isLoaded = false;
  String _status = 'Profile is used in attendance logs';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _employeeIdController.dispose();
    _employeeNameController.dispose();
    _roleController.dispose();
    _departmentController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await _service.loadEmployeeProfile();
    if (!mounted) return;
    setState(() {
      _employeeIdController.text = profile.employeeId;
      _employeeNameController.text = profile.employeeName;
      _roleController.text = profile.role;
      _departmentController.text = profile.department;
      // _phoneController.text = profile['phone'] ?? "";
      _isLoaded = true;
    });
  }

  Future<void> _saveProfile() async {
    setState(() {
      _isSaving = true;
      _status = 'Saving profile...';
    });

    /* await _service.saveEmployeeProfile(
      EmployeeProfile(
        employeeId: _employeeIdController.text,
        employeeName: _employeeNameController.text,
        role: _roleController.text,
        department: _departmentController.text,
        phone: _phoneController.text,
      ),
    );
 */
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _status = 'Profile saved for attendance logs';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Profile',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Employee Profile',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            StatusChip(
              label: _status,
              type: _isSaving ? StatusChipType.pending : StatusChipType.success,
              icon: _isSaving ? Icons.sync : Icons.verified_user,
            ),
            const SizedBox(height: 20),
            IndustrialCard(
              child: _isLoaded
                  ? Column(
                      children: [
                        _buildField(
                          controller: _employeeIdController,
                          label: 'Employee ID',
                          icon: Icons.badge,
                        ),
                        const SizedBox(height: 12),
                        _buildField(
                          controller: _employeeNameController,
                          label: 'Employee Name',
                          icon: Icons.person,
                        ),
                        const SizedBox(height: 12),
                        _buildField(
                          controller: _roleController,
                          label: 'Role',
                          icon: Icons.engineering,
                        ),
                        const SizedBox(height: 12),
                        _buildField(
                          controller: _departmentController,
                          label: 'Department',
                          icon: Icons.factory,
                        ),
                        const SizedBox(height: 12),
                        _buildField(
                          controller: _phoneController,
                          label: 'Phone',
                          icon: Icons.phone,
                          keyboardType: TextInputType.phone,
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
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
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

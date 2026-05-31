import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/organization_options.dart';
import '../services/auth_role_service.dart';
import '../services/fcm_notification_service.dart';
import '../theme/industrial_theme.dart';
import '../widgets/primary_action_button.dart';
import '../widgets/status_chip.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _auth = AuthRoleService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _employeeIdController = TextEditingController();

  bool _isSignup = false;
  bool _isLoading = false;
  AppUserRole _selectedRole = AppUserRole.employee;
  String _selectedTeam = OrganizationOptions.teams.first;
  String _selectedEmployeeRole = OrganizationOptions.employeeRoles.last;
  String? _error;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _employeeIdController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final role = _isSignup
          ? await _auth.signUp(
              email: _emailController.text,
              password: _passwordController.text,
              role: _selectedRole,
              firstName: _firstNameController.text,
              lastName: _lastNameController.text,
              employeeId: _employeeIdController.text,
              department: _selectedTeam,
              employeeRole: _selectedEmployeeRole,
            )
          : await _auth.signIn(
              email: _emailController.text,
              password: _passwordController.text,
            );

      if (!mounted) return;
      final pendingRoute = FcmNotificationService.instance
          .consumePendingRouteFor(role);
      context.go(
        pendingRoute ??
            (role == AppUserRole.admin ? '/admin-dashboard' : '/dashboard'),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IndustrialColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildLogo(context),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                  ),
                  if (_isSignup) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _firstNameController,
                            decoration: const InputDecoration(
                              labelText: 'First Name',
                              prefixIcon: Icon(Icons.person),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _lastNameController,
                            decoration: const InputDecoration(
                              labelText: 'Last Name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _employeeIdController,
                      decoration: const InputDecoration(
                        labelText: 'Employee ID',
                        prefixIcon: Icon(Icons.badge),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedTeam,
                      decoration: const InputDecoration(
                        labelText: 'Team',
                        prefixIcon: Icon(Icons.groups),
                      ),
                      items: OrganizationOptions.teams
                          .map(
                            (team) => DropdownMenuItem(
                              value: team,
                              child: Text(team),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedTeam = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedEmployeeRole,
                      decoration: const InputDecoration(
                        labelText: 'Employee Role',
                        prefixIcon: Icon(Icons.engineering),
                      ),
                      items: OrganizationOptions.employeeRoles
                          .map(
                            (role) => DropdownMenuItem(
                              value: role,
                              child: Text(role),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedEmployeeRole = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<AppUserRole>(
                      segments: const [
                        ButtonSegment(
                          value: AppUserRole.employee,
                          label: Text('Employee'),
                          icon: Icon(Icons.person),
                        ),
                        ButtonSegment(
                          value: AppUserRole.admin,
                          label: Text('Admin'),
                          icon: Icon(Icons.admin_panel_settings),
                        ),
                      ],
                      selected: {_selectedRole},
                      onSelectionChanged: (selection) {
                        setState(() => _selectedRole = selection.first);
                      },
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    StatusChip(
                      label: _error!,
                      type: StatusChipType.alert,
                      icon: Icons.error_outline,
                    ),
                  ],
                  const SizedBox(height: 20),
                  PrimaryActionButton(
                    label: _isSignup ? 'CREATE ACCOUNT' : 'LOGIN',
                    icon: _isSignup ? Icons.person_add : Icons.login,
                    isLoading: _isLoading,
                    onPressed: _isLoading ? null : _submit,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _isSignup = !_isSignup;
                              _error = null;
                            });
                          },
                    child: Text(
                      _isSignup
                          ? 'Already have an account? Login'
                          : 'New user? Create employee/admin account',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: const BoxDecoration(
            color: IndustrialColors.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              'd',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: IndustrialColors.onPrimary,
                fontSize: 56,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'dhinadts',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            color: IndustrialColors.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _isSignup
              ? 'Create your workspace access'
              : 'Employee attendance login',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: IndustrialColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

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
  bool _rememberMe = true;

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
      backgroundColor: const Color(0xFFF7F9F3),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWebLayout = constraints.maxWidth >= 920;
            if (!isWebLayout) {
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: _buildAuthForm(context, compact: true),
                  ),
                ),
              );
            }

            return Row(
              children: [
                Expanded(child: _buildBrandPanel(context)),
                Container(width: 1, color: IndustrialColors.outlineVariant),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 56,
                        vertical: 40,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: _buildAuthForm(context),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAuthForm(BuildContext context, {bool compact = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (compact) ...[_buildMobileLogo(context), const SizedBox(height: 28)],
        if (!compact) ...[
          Row(
            children: [
              _buildLogoMark(size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DHINADTS ATTENDANCE',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: IndustrialColors.onSurface,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'FACE CHECK-IN • TEAMS • PAYROLL',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: IndustrialColors.primary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.dark_mode, size: 22, color: IndustrialColors.primary),
            ],
          ),
          const SizedBox(height: 52),
        ],
        Text(
          _isSignup ? 'Create Account' : 'Welcome Back',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: IndustrialColors.onSurface,
            fontSize: compact ? 26 : 30,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isSignup
              ? 'Create employee or admin workspace access'
              : 'Sign in to access attendance workspace',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: IndustrialColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 30),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: _inputDecoration('Email', Icons.email_outlined),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: _inputDecoration(
            'Password',
            Icons.lock_outline,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
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
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _firstNameController,
                  decoration: _inputDecoration('First Name', Icons.person),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _lastNameController,
                  decoration: _inputDecoration(
                    'Last Name',
                    Icons.person_outline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _employeeIdController,
            decoration: _inputDecoration('Employee ID', Icons.badge_outlined),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedTeam,
            decoration: _inputDecoration('Team', Icons.groups_outlined),
            items: OrganizationOptions.teams
                .map((team) => DropdownMenuItem(value: team, child: Text(team)))
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selectedTeam = value);
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedEmployeeRole,
            decoration: _inputDecoration(
              'Employee Role',
              Icons.engineering_outlined,
            ),
            items: OrganizationOptions.employeeRoles
                .map((role) => DropdownMenuItem(value: role, child: Text(role)))
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selectedEmployeeRole = value);
            },
          ),
          const SizedBox(height: 16),
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
        if (!_isSignup) ...[
          const SizedBox(height: 18),
          Row(
            children: [
              Checkbox(
                value: _rememberMe,
                onChanged: (value) {
                  setState(() => _rememberMe = value ?? true);
                },
              ),
              Text(
                'Remember me',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: IndustrialColors.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {},
                child: const Text('Forgot password?'),
              ),
            ],
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
        const SizedBox(height: 24),
        SizedBox(
          height: 56,
          child: compact
              ? PrimaryActionButton(
                  label: _isSignup ? 'CREATE ACCOUNT' : 'LOGIN',
                  icon: _isSignup ? Icons.person_add : Icons.login,
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _submit,
                )
              : FilledButton(
                  onPressed: _isLoading ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: IndustrialColors.primary,
                    foregroundColor: IndustrialColors.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _isSignup ? 'CREATE ACCOUNT' : 'LOGIN',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                        ),
                ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _isSignup ? 'Already registered?' : 'New user?',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: IndustrialColors.onSurfaceVariant,
              ),
            ),
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      setState(() {
                        _isSignup = !_isSignup;
                        _error = null;
                      });
                    },
              child: Text(_isSignup ? 'Login' : 'Create account'),
            ),
          ],
        ),
        if (!compact) ...[
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: IndustrialColors.surface.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: IndustrialColors.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(Icons.security, color: IndustrialColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Attendance data is protected with Firebase Auth and role based access.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: IndustrialColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBrandPanel(BuildContext context) {
    return Container(
      color: const Color(0xFFF0F4ED),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final shortScreen = constraints.maxHeight < 720;
          final logoSize = shortScreen ? 104.0 : 128.0;
          final heroGap = shortScreen ? 38.0 : 64.0;
          final badgeGap = shortScreen ? 22.0 : 32.0;
          final footerGap = shortScreen ? 24.0 : 48.0;

          return Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: 56,
                vertical: shortScreen ? 28 : 56,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLogoMark(size: logoSize),
                  const SizedBox(height: 22),
                  Text(
                    'DHINADTS ATTENDANCE',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: IndustrialColors.onSurface,
                      fontSize: shortScreen ? 30 : 34,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'FACE CHECK-IN • GEO ZONE • PAYROLL',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: IndustrialColors.primary,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  SizedBox(height: heroGap),
                  Text(
                    'Secure Attendance',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: IndustrialColors.onSurface,
                      fontSize: shortScreen ? 22 : null,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Manage face authentication, teams, leave requests and salary records from one workspace.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: IndustrialColors.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: badgeGap),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: const [
                      _SecurityBadge(
                        icon: Icons.verified_user,
                        label: 'Role Safe',
                      ),
                      _SecurityBadge(icon: Icons.pin_drop, label: 'Geo Zone'),
                      _SecurityBadge(icon: Icons.face, label: 'Face Auth'),
                    ],
                  ),
                  SizedBox(height: footerGap),
                  Text(
                    'Made by',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: IndustrialColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 26,
                      vertical: shortScreen ? 10 : 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5BA77D),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'DHINADTS',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: const Color(0xFFFFD88A),
                            fontSize: shortScreen ? 22 : null,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMobileLogo(BuildContext context) {
    return Column(
      children: [
        _buildLogoMark(size: 96),
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

  Widget _buildLogoMark({required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: IndustrialColors.primary,
        borderRadius: BorderRadius.circular(size * 0.14),
        border: Border.all(color: const Color(0xFFE3B633), width: 2),
        boxShadow: [
          BoxShadow(
            color: IndustrialColors.primary.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.shield_outlined,
            color: const Color(0xFFE3B633),
            size: size * 0.68,
          ),
          Icon(
            Icons.view_module,
            color: IndustrialColors.onPrimary,
            size: size * 0.22,
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(
    String label,
    IconData icon, {
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.82),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: IndustrialColors.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: IndustrialColors.primary, width: 1.4),
      ),
    );
  }
}

class _SecurityBadge extends StatelessWidget {
  const _SecurityBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: IndustrialColors.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: IndustrialColors.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: IndustrialColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

import '../widgets/app_shell.dart';
import '../widgets/stat_card.dart';
import '../widgets/status_chip.dart';
import 'package:flutter/material.dart';
import '../theme/industrial_theme.dart';
import '../widgets/industrial_card.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../widgets/primary_action_button.dart';
import '../services/attendance_session_service.dart';

class AttendanceGpsTrackingScreen extends StatefulWidget {
  const AttendanceGpsTrackingScreen({super.key});

  @override
  State<AttendanceGpsTrackingScreen> createState() =>
      _AttendanceGpsTrackingScreenState();
}

class _AttendanceGpsTrackingScreenState
    extends State<AttendanceGpsTrackingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  final _attendanceService = AttendanceSessionService();
  bool _isCheckingOut = false;
  String? _statusMessage;
  StatusChipType _statusType = StatusChipType.neutral;
  AttendanceSession? _activeSession;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _refreshActiveSession();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String get _currentTime {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';
  }

  String get _currentDate {
    final now = DateTime.now();
    final days = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];
    final months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return '${days[now.weekday % 7]}, ${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  String get _sessionStatusLabel {
    if (_activeSession == null) return 'No active session';
    return _activeSession!.attendanceStatus == 'outside_office'
        ? 'Reach office zone'
        : 'Active';
  }

  String get _hoursWorked {
    final loginAt = DateTime.tryParse(_activeSession?.loginAtIst ?? '');
    if (loginAt == null) return '--:--';
    final minutes = DateTime.now()
        .toUtc()
        .add(const Duration(hours: 5, minutes: 30))
        .difference(loginAt)
        .inMinutes
        .clamp(0, AttendanceSessionService.maxOfficeSession.inMinutes);
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
  }

  String get _officeLocationLabel {
    final session = _activeSession;
    if (session == null) return 'Open face check-in to start a session';
    return '${session.officeLatitude.toStringAsFixed(6)}, ${session.officeLongitude.toStringAsFixed(6)}';
  }

  Future<void> _refreshActiveSession() async {
    try {
      final session = await _attendanceService.loadActiveSession();
      if (!mounted) return;
      setState(() => _activeSession = session);
    } catch (_) {
      if (!mounted) return;
      setState(() => _activeSession = null);
    }
  }

  Future<void> _checkOut() async {
    if (_isCheckingOut) return;
    setState(() {
      _isCheckingOut = true;
      _statusMessage = null;
    });

    try {
      final session = await _attendanceService.loadActiveSession();
      if (session == null) {
        setState(() {
          _statusMessage = 'No active attendance session found';
          _statusType = StatusChipType.pending;
        });
        return;
      }

      Position? position;
      double? distanceMeters;
      try {
        position = await _currentPosition();
        distanceMeters = _attendanceService.distanceFromZone(position, session);
      } catch (_) {
        position = null;
        distanceMeters = null;
      }

      await _attendanceService.closeSession(
        session: session,
        reason: 'manual_logout',
        logoutPosition: position,
        distanceMeters: distanceMeters,
      );
      if (!mounted) return;
      setState(() {
        _activeSession = null;
        _statusMessage = 'Checked out successfully';
        _statusType = StatusChipType.success;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _statusMessage = error.toString();
        _statusType = StatusChipType.alert;
      });
    } finally {
      if (mounted) {
        setState(() => _isCheckingOut = false);
      }
    }
  }

  Future<Position> _currentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw StateError('Location service is disabled');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError('Location permission denied');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      showAppBar: true,
      showBackButton: false,
      title: 'WorkSync Pro',
      bottomNavigationBar: _buildBottomNav(),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Time Section
              Text(
                _currentDate.toUpperCase(),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: 12,
                  color: IndustrialColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _currentTime,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                  color: IndustrialColors.onSurface,
                ),
              ),
              const SizedBox(height: 24),

              // Map & GPS Card
              IndustrialCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    // Map placeholder
                    Container(
                      width: double.infinity,
                      height: 160,
                      decoration: BoxDecoration(
                        color: IndustrialColors.surfaceDim,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.map,
                            size: 64,
                            color: IndustrialColors.primary.withValues(
                              alpha: 0.3,
                            ),
                          ),
                          // GPS Pulse
                          ScaleTransition(
                            scale: Tween<double>(
                              begin: 1.0,
                              end: 1.3,
                            ).animate(_pulseController),
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: IndustrialColors.primary.withValues(
                                    alpha: 0.5,
                                  ),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: IndustrialColors.primary,
                              boxShadow: [
                                BoxShadow(
                                  color: IndustrialColors.primary.withValues(
                                    alpha: 0.4,
                                  ),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      size: 18,
                                      color: IndustrialColors.secondary,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        _activeSession == null
                                            ? 'Attendance zone'
                                            : 'Office geofence',
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge
                                            ?.copyWith(
                                              fontSize: 13,
                                              color: IndustrialColors.onSurface,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _officeLocationLabel,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        fontSize: 12,
                                        color:
                                            IndustrialColors.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusChip(
                            label: _activeSession == null
                                ? 'Inactive'
                                : 'Verified',
                            type: _activeSession == null
                                ? StatusChipType.neutral
                                : StatusChipType.success,
                            icon: _activeSession == null
                                ? Icons.info_outline
                                : Icons.check_circle,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Check In / Out Buttons
              PrimaryActionButton(
                label: 'FACE CHECK IN',
                icon: Icons.face,
                style: ActionButtonStyle.secondary,
                onPressed: () => context.go('/face-attendance'),
              ),
              const SizedBox(height: 12),
              PrimaryActionButton(
                label: _isCheckingOut ? 'CHECKING OUT...' : 'CHECK OUT',
                icon: Icons.logout,
                style: ActionButtonStyle.outline,
                isLoading: _isCheckingOut,
                onPressed: _isCheckingOut ? null : _checkOut,
              ),
              if (_statusMessage != null) ...[
                const SizedBox(height: 12),
                StatusChip(
                  label: _statusMessage!,
                  type: _statusType,
                  icon: _statusType == StatusChipType.success
                      ? Icons.check_circle
                      : Icons.info_outline,
                ),
              ],
              const SizedBox(height: 20),

              // Shift Summary Card
              IndustrialCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.assessment,
                              color: IndustrialColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Shift Summary',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                        Icon(
                          Icons.info_outline,
                          color: IndustrialColors.onSurfaceVariant,
                          size: 18,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            label: 'Hours Worked',
                            value: _hoursWorked,
                            icon: Icons.schedule,
                            valueColor: IndustrialColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatCard(
                            label: 'Est. Overtime',
                            value: '00:00',
                            icon: Icons.access_time,
                            valueColor: IndustrialColors.secondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(color: IndustrialColors.outlineVariant, height: 16),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: IndustrialColors.secondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Shift Status: ',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: IndustrialColors.onSurfaceVariant,
                                  ),
                            ),
                            Text(
                              _sessionStatusLabel,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: IndustrialColors.onSurface,
                                  ),
                            ),
                          ],
                        ),
                        Text(
                          'Target: 08:00',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: IndustrialColors.primary,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: IndustrialColors.surface,
        border: Border(
          top: BorderSide(color: IndustrialColors.outlineVariant, width: 1),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: 1,
        onTap: (index) {
          switch (index) {
            case 0:
              context.go('/dashboard');
              break;
            case 1:
              context.go('/attendance-details');
              break;
            case 2:
              context.go('/salary');
              break;
            case 3:
              context.go('/settings');
              break;
          }
        },
        backgroundColor: IndustrialColors.surface,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: Icon(
              Icons.dashboard,
              color: IndustrialColors.onSurfaceVariant,
            ),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: IndustrialColors.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.location_on,
                color: IndustrialColors.onSecondaryContainer,
                size: 20,
              ),
            ),
            label: 'Attendance',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.payments,
              color: IndustrialColors.onSurfaceVariant,
            ),
            label: 'Salary',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.settings,
              color: IndustrialColors.onSurfaceVariant,
            ),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

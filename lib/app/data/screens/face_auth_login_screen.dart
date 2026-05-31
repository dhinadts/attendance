import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:attendance/services/attendance_session_service.dart';
import 'package:attendance/theme/industrial_theme.dart';
import 'package:attendance/widgets/app_shell.dart';
import 'package:attendance/widgets/primary_action_button.dart';
import 'package:attendance/widgets/status_chip.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceAuthLoginScreen extends StatefulWidget {
  const FaceAuthLoginScreen({super.key});

  @override
  State<FaceAuthLoginScreen> createState() => _FaceAuthLoginScreenState();
}

class _FaceAuthLoginScreenState extends State<FaceAuthLoginScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _scanAnimationController;
  late final Animation<double> _scanLineAnimation;
  late final Animation<double> _pulseAnimation;
  late final FaceDetector _faceDetector;
  late final AttendanceSessionService _attendanceService;

  CameraController? _cameraController;
  Future<void>? _cameraInitFuture;
  StreamSubscription<Position>? _positionSubscription;
  AttendanceSession? _activeSession;
  bool _isProcessing = false;
  String _statusText = 'Camera starting...';
  StatusChipType _statusType = StatusChipType.alert;
  Position? _lastPosition;
  double? _lastDistanceMeters;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _scanAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat();

    _scanLineAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(_scanAnimationController);
    _pulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(_scanAnimationController);
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );
    _attendanceService = AttendanceSessionService();

    _cameraInitFuture = _initializeCamera();
    _restoreActiveSession();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _positionSubscription?.cancel();
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _cameraInitFuture = _initializeCamera();
      _restoreActiveSession();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionSubscription?.cancel();
    _cameraController?.dispose();
    _faceDetector.close();
    _scanAnimationController.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _setStatus('No camera found on this device.', StatusChipType.alert);
        return;
      }

      final camera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.low,
        enableAudio: false,
      );

      await _cameraController?.dispose();
      _cameraController = controller;
      await controller.initialize();

      if (!mounted) return;
      setState(() {
        _statusText = 'Ready to scan';
        _statusType = StatusChipType.success;
      });
    } on CameraException catch (error) {
      _setStatus(_cameraErrorMessage(error), StatusChipType.alert);
    } catch (error) {
      _setStatus('Camera failed to start: $error', StatusChipType.alert);
    }
  }

  Future<void> _captureAndMarkAttendance() async {
    final controller = _cameraController;
    if (_isProcessing ||
        controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusText = 'Capturing face...';
      _statusType = StatusChipType.success;
    });

    try {
      final image = await controller.takePicture();
      _setStatus('Checking face...', StatusChipType.success);

      final faces = await _faceDetector.processImage(
        InputImage.fromFilePath(image.path),
      );

      if (faces.isEmpty) {
        await _markLeave(reason: 'No face detected', imagePath: image.path);
        return;
      }

      _setStatus('Checking location...', StatusChipType.success);
      final position = await _getCurrentPosition();
      _lastPosition = position;
      _lastDistanceMeters = 0;

      _setStatus('Saving attendance...', StatusChipType.success);
      final faceImageBase64 = await _readFaceImageBase64(image.path);

      final session = await _attendanceService.createLogin(
        loginPosition: position,
        faceImageBase64: faceImageBase64,
        faceCount: faces.length,
      );
      _activeSession = session;
      _startLocationMonitoring(session);

      _setStatus('Attendance marked present', StatusChipType.success);

      if (!mounted) return;
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (mounted) context.go('/attendance');
    } catch (error) {
      await _markLeave(reason: 'Attendance failed: $error');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _markLeave({
    required String reason,
    String? imagePath,
    Position? position,
    double? distanceMeters,
  }) async {
    try {
      await _attendanceService.recordLeave(
        reason: reason,
        position: position,
        distanceMeters: distanceMeters,
      );
    } catch (_) {
      // Keep the UI focused on the original failure reason.
    }

    if (imagePath != null) {
      try {
        await File(imagePath).delete();
      } catch (_) {
        // The attendance state is already saved; temp cleanup is best effort.
      }
    }

    _setStatus('Attendance marked leave: $reason', StatusChipType.alert);
  }

  Future<String> _readFaceImageBase64(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    return base64Encode(bytes);
  }

  Future<Position> _getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location service is disabled');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('Location permission denied');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission permanently denied');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
    );
  }

  Future<void> _restoreActiveSession() async {
    final session = await _attendanceService.loadActiveSession();
    if (!mounted || session == null) return;

    _activeSession = session;
    if (_attendanceService.shouldAutoLogout(session)) {
      await _attendanceService.closeSession(
        session: session,
        reason: 'auto_logout_after_9_hours',
      );
      _activeSession = null;
      _setStatus('Auto logged out after 9 hours', StatusChipType.alert);
      return;
    }

    _startLocationMonitoring(session);
    _setStatus('Active attendance session', StatusChipType.success);
  }

  void _startLocationMonitoring(AttendanceSession session) {
    _positionSubscription?.cancel();
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 3,
          ),
        ).listen(
          (position) async {
            final distance = _attendanceService.distanceFromZone(
              position,
              session,
            );
            if (!mounted) return;

            setState(() {
              _lastPosition = position;
              _lastDistanceMeters = distance;
            });

            if (_attendanceService.shouldAutoLogout(session)) {
              await _closeActiveSession(
                reason: 'auto_logout_after_9_hours',
                position: position,
                distanceMeters: distance,
              );
              return;
            }

            if (distance > session.allowedRadiusMeters) {
              await _closeActiveSession(
                reason: 'left_geofence',
                position: position,
                distanceMeters: distance,
              );
            }
          },
          onError: (Object error) {
            _setStatus(
              'Location tracking paused: $error',
              StatusChipType.alert,
            );
          },
        );
  }

  Future<void> _closeActiveSession({
    required String reason,
    Position? position,
    double? distanceMeters,
  }) async {
    final session = _activeSession;
    if (session == null) return;

    await _positionSubscription?.cancel();
    await _attendanceService.closeSession(
      session: session,
      reason: reason,
      logoutPosition: position,
      distanceMeters: distanceMeters,
    );

    _activeSession = null;
    _setStatus('Logged out: $reason', StatusChipType.alert);
  }

  void _setStatus(String text, StatusChipType type) {
    if (!mounted) return;
    setState(() {
      _statusText = text;
      _statusType = type;
    });
  }

  String _cameraErrorMessage(CameraException error) {
    switch (error.code) {
      case 'CameraAccessDenied':
      case 'CameraAccessDeniedWithoutPrompt':
        return 'Camera permission denied';
      case 'CameraAccessRestricted':
        return 'Camera access restricted';
      default:
        return 'Camera error: ${error.description ?? error.code}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      showAppBar: true,
      title: 'WorkSync Pro',
      child: SingleChildScrollView(
        child: Container(
          constraints: BoxConstraints(
            minHeight:
                MediaQuery.of(context).size.height -
                kToolbarHeight -
                MediaQuery.of(context).padding.top,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Face Attendance',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: IndustrialColors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Face auth sets this device location as today\'s 10 meter zone',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: IndustrialColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 40),
              _buildScanner(),
              const SizedBox(height: 24),
              StatusChip(
                label: _statusText,
                type: _statusType,
                icon: _statusType == StatusChipType.success
                    ? Icons.check_circle
                    : Icons.info_outline,
              ),
              if (_lastDistanceMeters != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Distance: ${_lastDistanceMeters!.toStringAsFixed(1)}m from office',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: IndustrialColors.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              PrimaryActionButton(
                label: _isProcessing ? 'PROCESSING...' : 'CAPTURE ATTENDANCE',
                icon: Icons.camera_alt,
                onPressed: _isProcessing ? null : _captureAndMarkAttendance,
              ),
              const SizedBox(height: 12),
              if (_activeSession != null) ...[
                PrimaryActionButton(
                  label: 'MANUAL CHECK OUT',
                  icon: Icons.logout,
                  style: ActionButtonStyle.secondary,
                  onPressed: _isProcessing
                      ? null
                      : () => _closeActiveSession(reason: 'manual_logout'),
                ),
                const SizedBox(height: 12),
              ],
              PrimaryActionButton(
                label: 'OPEN LOCATION SCREEN',
                icon: Icons.location_on,
                style: ActionButtonStyle.outline,
                onPressed: _isProcessing
                    ? null
                    : () => context.go('/attendance'),
              ),
              const SizedBox(height: 40),
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanner() {
    return Stack(
      alignment: Alignment.center,
      children: [
        ScaleTransition(
          scale: _pulseAnimation,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: IndustrialColors.primary.withValues(alpha: 0.3),
                width: 3,
              ),
            ),
          ),
        ),
        Container(
          width: 260,
          height: 260,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: IndustrialColors.primary, width: 3),
            color: IndustrialColors.surfaceContainerHigh,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipOval(
            child: FutureBuilder<void>(
              future: _cameraInitFuture,
              builder: (context, snapshot) {
                final controller = _cameraController;
                if (snapshot.connectionState != ConnectionState.done ||
                    controller == null ||
                    !controller.value.isInitialized) {
                  return const Center(child: CircularProgressIndicator());
                }

                return FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller.value.previewSize?.height ?? 260,
                    height: controller.value.previewSize?.width ?? 260,
                    child: CameraPreview(controller),
                  ),
                );
              },
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: ClipOval(
              child: AnimatedBuilder(
                animation: _scanLineAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _scanLineAnimation.value * 254),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        height: 2,
                        width: 254,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              IndustrialColors.primary.withValues(alpha: 0),
                              IndustrialColors.primary,
                              IndustrialColors.primary.withValues(alpha: 0),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: IndustrialColors.primary.withValues(
                                alpha: 0.6,
                              ),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        _cornerBracket(top: 10, left: 10),
        _cornerBracket(top: 10, right: 10),
        _cornerBracket(bottom: 10, left: 10),
        _cornerBracket(bottom: 10, right: 10),
      ],
    );
  }

  Widget _cornerBracket({
    double? top,
    double? right,
    double? bottom,
    double? left,
  }) {
    return Positioned(
      top: top,
      right: right,
      bottom: bottom,
      left: left,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          border: Border(
            top: top == null
                ? BorderSide.none
                : const BorderSide(color: IndustrialColors.primary, width: 3),
            right: right == null
                ? BorderSide.none
                : const BorderSide(color: IndustrialColors.primary, width: 3),
            bottom: bottom == null
                ? BorderSide.none
                : const BorderSide(color: IndustrialColors.primary, width: 3),
            left: left == null
                ? BorderSide.none
                : const BorderSide(color: IndustrialColors.primary, width: 3),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final location = _lastPosition;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.my_location,
              size: 16,
              color: IndustrialColors.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              location == null
                  ? 'Today\'s zone: 10m from login GPS'
                  : '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: 12,
                color: IndustrialColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'DhinaDTS IT Solutions and Support (OPC) Private Limited. - V1.2.0',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 11,
            color: IndustrialColors.outline,
          ),
        ),
      ],
    );
  }
}

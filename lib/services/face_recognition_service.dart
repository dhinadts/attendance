import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'attendance_session_service.dart';
import 'app_firestore.dart';

class FaceRecognitionResult {
  const FaceRecognitionResult({
    required this.matched,
    required this.score,
    required this.templateCount,
  });

  final bool matched;
  final double score;
  final int templateCount;
}

class FaceRecognitionService {
  FaceRecognitionService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    AttendanceSessionService? attendanceService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _attendanceService = attendanceService ?? AttendanceSessionService();

  static const int requiredTemplateCount = 5;
  static const double matchThreshold = 0.22;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final AttendanceSessionService _attendanceService;

  Future<int> templateCount() async {
    final profile = await _attendanceService.loadEmployeeProfile();
    final doc = await _firestore
        .appCollection('employee_profiles')
        .doc(profile.employeeId)
        .get();
    return _readTemplates(doc.data()).length;
  }

  Future<void> enrollTemplates(List<Face> faces) async {
    if (faces.length < requiredTemplateCount) {
      throw StateError('Capture $requiredTemplateCount face samples to enroll');
    }

    final profile = await _attendanceService.loadEmployeeProfile();
    final templates = faces
        .take(requiredTemplateCount)
        .map((face) => templateFromFace(face))
        .toList();
    await _firestore
        .appCollection('employee_profiles')
        .doc(profile.employeeId)
        .set({
          'faceRecognition': {
            'version': 'landmark_v1',
            'sampleCount': templates.length,
            'templates': templates,
            'enrolledAt': FieldValue.serverTimestamp(),
            'enrolledAtIst': _attendanceService.nowIst.toIso8601String(),
            'updatedByUid': _auth.currentUser?.uid,
          },
        }, SetOptions(merge: true));
  }

  Future<FaceRecognitionResult> verify(Face face) async {
    final profile = await _attendanceService.loadEmployeeProfile();
    final doc = await _firestore
        .appCollection('employee_profiles')
        .doc(profile.employeeId)
        .get();
    final templates = _readTemplates(doc.data());
    if (templates.length < requiredTemplateCount) {
      return FaceRecognitionResult(
        matched: false,
        score: double.infinity,
        templateCount: templates.length,
      );
    }

    final current = templateFromFace(face);
    final scores = templates.map((template) => _distance(current, template));
    final bestScore = scores.reduce(math.min);
    return FaceRecognitionResult(
      matched: bestScore <= matchThreshold,
      score: bestScore,
      templateCount: templates.length,
    );
  }

  Map<String, dynamic> templateFromFace(Face face) {
    final leftEye = _landmark(face, FaceLandmarkType.leftEye);
    final rightEye = _landmark(face, FaceLandmarkType.rightEye);
    final nose = _landmark(face, FaceLandmarkType.noseBase);
    final leftMouth = _landmark(face, FaceLandmarkType.leftMouth);
    final rightMouth = _landmark(face, FaceLandmarkType.rightMouth);
    final bottomMouth = _landmark(face, FaceLandmarkType.bottomMouth);
    final leftCheek = _landmark(face, FaceLandmarkType.leftCheek);
    final rightCheek = _landmark(face, FaceLandmarkType.rightCheek);

    final eyeDistance = math.max(_pointDistance(leftEye, rightEye), 1.0);
    final center = _Point(
      (leftEye.x + rightEye.x) / 2,
      (leftEye.y + rightEye.y) / 2,
    );

    return {
      'leftEye': _normalized(leftEye, center, eyeDistance),
      'rightEye': _normalized(rightEye, center, eyeDistance),
      'noseBase': _normalized(nose, center, eyeDistance),
      'leftMouth': _normalized(leftMouth, center, eyeDistance),
      'rightMouth': _normalized(rightMouth, center, eyeDistance),
      'bottomMouth': _normalized(bottomMouth, center, eyeDistance),
      'leftCheek': _normalized(leftCheek, center, eyeDistance),
      'rightCheek': _normalized(rightCheek, center, eyeDistance),
      'headEulerAngleY': face.headEulerAngleY ?? 0,
      'headEulerAngleZ': face.headEulerAngleZ ?? 0,
    };
  }

  List<Map<String, dynamic>> _readTemplates(Map<String, dynamic>? data) {
    final rawTemplates = data?['faceRecognition']?['templates'];
    if (rawTemplates is! List) return <Map<String, dynamic>>[];
    return rawTemplates
        .whereType<Map>()
        .map((template) => Map<String, dynamic>.from(template))
        .toList();
  }

  _Point _landmark(Face face, FaceLandmarkType type) {
    final landmark = face.landmarks[type];
    if (landmark == null) {
      throw StateError(
        'Face landmark missing. Keep eyes, nose, mouth, and cheeks visible.',
      );
    }
    return _Point(
      landmark.position.x.toDouble(),
      landmark.position.y.toDouble(),
    );
  }

  List<double> _normalized(_Point point, _Point center, double scale) {
    return [(point.x - center.x) / scale, (point.y - center.y) / scale];
  }

  double _distance(Map<String, dynamic> current, Map<String, dynamic> stored) {
    const keys = [
      'leftEye',
      'rightEye',
      'noseBase',
      'leftMouth',
      'rightMouth',
      'bottomMouth',
      'leftCheek',
      'rightCheek',
    ];
    var total = 0.0;
    var count = 0;
    for (final key in keys) {
      final a = _list(current[key]);
      final b = _list(stored[key]);
      if (a.length < 2 || b.length < 2) continue;
      total += math.sqrt(math.pow(a[0] - b[0], 2) + math.pow(a[1] - b[1], 2));
      count++;
    }
    if (count == 0) return double.infinity;
    final landmarkScore = total / count;
    final posePenalty =
        (((current['headEulerAngleY'] as num?)?.toDouble() ?? 0) -
                ((stored['headEulerAngleY'] as num?)?.toDouble() ?? 0))
            .abs() /
        100;
    return landmarkScore + posePenalty;
  }

  List<double> _list(Object? value) {
    if (value is! List) return const [];
    return value.whereType<num>().map((item) => item.toDouble()).toList();
  }

  double _pointDistance(_Point a, _Point b) {
    return math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));
  }
}

class _Point {
  const _Point(this.x, this.y);

  final double x;
  final double y;
}

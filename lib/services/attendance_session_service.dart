import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_firestore.dart';

class EmployeeProfile {
  const EmployeeProfile({
    required this.employeeId,
    required this.nickName,
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.contactNumber,
    required this.email,
    required this.joiningDate,
    required this.role,
    required this.department,
  });

  final String employeeId;
  final String nickName;
  final String firstName;
  final String lastName;
  final String dateOfBirth;
  final String contactNumber;
  final String email;
  final String joiningDate;
  final String role;
  final String department;

  String get employeeName => '$firstName $lastName'.trim();
  String get displayName {
    final nick = nickName.trim();
    if (nick.isNotEmpty) return nick;
    final name = employeeName;
    return name.isNotEmpty ? name : employeeId;
  }

  Map<String, dynamic> toMap() {
    return {
      'employeeId': employeeId,
      'nickName': nickName,
      'employeeName': employeeName,
      'firstName': firstName,
      'lastName': lastName,
      'dateOfBirth': dateOfBirth,
      'contactNumber': contactNumber,
      'email': email,
      'joiningDate': joiningDate,
      'role': role,
      'department': department,
    };
  }
}

class DeviceIdentity {
  const DeviceIdentity({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
  });

  final String deviceId;
  final String deviceName;
  final String platform;

  Map<String, dynamic> toMap() {
    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'platform': platform,
    };
  }
}

class AttendanceSession {
  const AttendanceSession({
    required this.documentId,
    required this.employeeId,
    required this.loginAtIst,
    required this.loginDateIst,
    required this.officeLatitude,
    required this.officeLongitude,
    required this.allowedRadiusMeters,
    this.attendanceStatus,
  });

  final String documentId;
  final String employeeId;
  final String loginAtIst;
  final String loginDateIst;
  final double officeLatitude;
  final double officeLongitude;
  final double allowedRadiusMeters;
  final String? attendanceStatus;

  Map<String, dynamic> toJson() {
    return {
      'documentId': documentId,
      'employeeId': employeeId,
      'loginAtIst': loginAtIst,
      'loginDateIst': loginDateIst,
      'officeLatitude': officeLatitude,
      'officeLongitude': officeLongitude,
      'allowedRadiusMeters': allowedRadiusMeters,
      if (attendanceStatus != null) 'attendanceStatus': attendanceStatus,
    };
  }

  static AttendanceSession? fromJson(Map<String, dynamic> json) {
    final documentId = json['documentId'] as String?;
    final employeeId = json['employeeId'] as String?;
    final loginAtIst = json['loginAtIst'] as String?;
    final loginDateIst = json['loginDateIst'] as String?;
    final officeLatitude = (json['officeLatitude'] as num?)?.toDouble();
    final officeLongitude = (json['officeLongitude'] as num?)?.toDouble();
    final allowedRadiusMeters = (json['allowedRadiusMeters'] as num?)
        ?.toDouble();

    if (documentId == null ||
        employeeId == null ||
        loginAtIst == null ||
        loginDateIst == null ||
        officeLatitude == null ||
        officeLongitude == null ||
        allowedRadiusMeters == null) {
      return null;
    }

    return AttendanceSession(
      documentId: documentId,
      employeeId: employeeId,
      loginAtIst: loginAtIst,
      loginDateIst: loginDateIst,
      officeLatitude: officeLatitude,
      officeLongitude: officeLongitude,
      allowedRadiusMeters: allowedRadiusMeters,
      attendanceStatus: json['attendanceStatus'] as String?,
    );
  }
}

class AttendanceSessionService {
  static const double defaultOfficeLatitude = 11.3968207;
  static const double defaultOfficeLongitude = 77.8881173;
  static const double defaultRadiusMeters = 50;
  static const Duration officeArrivalGrace = Duration(minutes: 30);
  static const int finalLogoutHourIst = 18;
  static const int finalLogoutMinuteIst = 0;
  static const Duration maxOfficeSession = Duration(hours: 9);
  static const int eligibleMinutes = 420;
  static const int monthlyBaseSalary = 24500;
  static const int monthlyWorkingDays = 26;

  static const String _sessionKey = 'active_attendance_session';
  static const String _employeeIdKey = 'employee_id';
  static const String _employeeNickNameKey = 'employee_nick_name';
  static const String _employeeFirstNameKey = 'employee_first_name';
  static const String _employeeLastNameKey = 'employee_last_name';
  static const String _employeeDobKey = 'employee_dob';
  static const String _employeeContactKey = 'employee_contact';
  static const String _employeeEmailKey = 'employee_email';
  static const String _employeeJoiningDateKey = 'employee_joining_date';
  static const String _employeeRoleKey = 'employee_role';
  static const String _employeeDepartmentKey = 'employee_department';

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final DeviceInfoPlugin _deviceInfo;

  AttendanceSessionService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    DeviceInfoPlugin? deviceInfo,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _deviceInfo = deviceInfo ?? DeviceInfoPlugin();

  DateTime get nowIst =>
      DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));

  String get todayIst => _dateKey(nowIst);

  String attendanceDocumentId(String employeeId, String dateKey) {
    return '${_safeId(employeeId)}_$dateKey';
  }

  String leaveRequestDocumentId(String employeeId, String dateKey) {
    return '${_safeId(employeeId)}_$dateKey';
  }

  String salaryRecordDocumentId(String employeeId, int year, int month) {
    return '${_safeId(employeeId)}_${year.toString().padLeft(4, '0')}${month.toString().padLeft(2, '0')}';
  }

  String exitRequestDocumentId(String employeeId) {
    return '${_safeId(employeeId)}_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<EmployeeProfile> loadEmployeeProfile() async {
    await ensureSignedIn();
    final prefs = await SharedPreferences.getInstance();
    final user = _auth.currentUser;
    final fallbackId = user?.uid ?? 'EMP-DEMO-001';
    final fallbackName = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!.trim()
        : '';
    final parts = fallbackName.split(RegExp(r'\s+'));

    final userDoc = user == null
        ? null
        : await _firestore.appCollection('users').doc(user.uid).get();
    final userData = userDoc?.data();
    final mappedEmployeeId = (userData?['employeeId'] as String?)?.trim();
    final cachedEmployeeId = prefs.getString(_employeeIdKey)?.trim();
    var employeeId = mappedEmployeeId?.isNotEmpty == true
        ? mappedEmployeeId!
        : '';
    Map<String, dynamic>? profileData;

    if (employeeId.isNotEmpty) {
      final profileDoc = await _firestore
          .appCollection('employee_profiles')
          .doc(employeeId)
          .get();
      profileData = profileDoc.data();
    }

    if (profileData == null && user != null) {
      final byUid = await _firestore
          .appCollection('employee_profiles')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();
      if (byUid.docs.isNotEmpty) {
        employeeId = byUid.docs.first.id;
        profileData = byUid.docs.first.data();
      }
    }

    if (profileData == null && user?.email?.isNotEmpty == true) {
      final byEmail = await _firestore
          .appCollection('employee_profiles')
          .where('email', isEqualTo: user!.email)
          .limit(1)
          .get();
      if (byEmail.docs.isNotEmpty) {
        employeeId = byEmail.docs.first.id;
        profileData = byEmail.docs.first.data();
      }
    }

    if (employeeId.isEmpty) {
      employeeId = cachedEmployeeId?.isNotEmpty == true
          ? cachedEmployeeId!
          : fallbackId;
    }

    return EmployeeProfile(
      employeeId: employeeId,
      nickName:
          (profileData?['nickName'] as String?) ??
          (userData?['nickName'] as String?) ??
          prefs.getString(_employeeNickNameKey) ??
          '',
      firstName:
          (profileData?['firstName'] as String?) ??
          (userData?['firstName'] as String?) ??
          prefs.getString(_employeeFirstNameKey) ??
          (parts.first.isEmpty ? '' : parts.first),
      lastName:
          (profileData?['lastName'] as String?) ??
          (userData?['lastName'] as String?) ??
          prefs.getString(_employeeLastNameKey) ??
          (parts.length > 1 ? parts.sublist(1).join(' ') : ''),
      dateOfBirth:
          (profileData?['dateOfBirth'] as String?) ??
          (userData?['dateOfBirth'] as String?) ??
          prefs.getString(_employeeDobKey) ??
          '',
      contactNumber:
          (profileData?['contactNumber'] as String?) ??
          (userData?['contactNumber'] as String?) ??
          prefs.getString(_employeeContactKey) ??
          '',
      email:
          (userData?['email'] as String?) ??
          user?.email ??
          (profileData?['email'] as String?) ??
          prefs.getString(_employeeEmailKey) ??
          '',
      joiningDate:
          (profileData?['joiningDate'] as String?) ??
          (userData?['joiningDate'] as String?) ??
          prefs.getString(_employeeJoiningDateKey) ??
          '',
      role:
          (profileData?['role'] as String?) ??
          (profileData?['employeeRole'] as String?) ??
          (userData?['employeeRole'] as String?) ??
          (userData?['role'] as String?) ??
          prefs.getString(_employeeRoleKey) ??
          'Employee',
      department:
          (profileData?['department'] as String?) ??
          (userData?['department'] as String?) ??
          prefs.getString(_employeeDepartmentKey) ??
          '',
    );
  }

  Future<void> saveEmployeeProfile(EmployeeProfile profile) async {
    await ensureSignedIn();
    _validateProfile(profile);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_employeeIdKey, profile.employeeId.trim());
    await prefs.setString(_employeeNickNameKey, profile.nickName.trim());
    await prefs.setString(_employeeFirstNameKey, profile.firstName.trim());
    await prefs.setString(_employeeLastNameKey, profile.lastName.trim());
    await prefs.setString(_employeeDobKey, profile.dateOfBirth.trim());
    await prefs.setString(_employeeContactKey, profile.contactNumber.trim());
    await prefs.setString(_employeeEmailKey, profile.email.trim());
    await prefs.setString(_employeeJoiningDateKey, profile.joiningDate.trim());
    await prefs.setString(_employeeRoleKey, profile.role.trim());
    await prefs.setString(_employeeDepartmentKey, profile.department.trim());

    await _firestore
        .appCollection('employee_profiles')
        .doc(profile.employeeId.trim())
        .set({
          ...profile.toMap(),
          'uid': _auth.currentUser?.uid,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedAtIst': nowIst.toIso8601String(),
        }, SetOptions(merge: true));

    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.appCollection('users').doc(user.uid).set({
        'uid': user.uid,
        'employeeId': profile.employeeId.trim(),
        'firstName': profile.firstName.trim(),
        'lastName': profile.lastName.trim(),
        'displayName': profile.employeeName,
        'nickName': profile.nickName.trim(),
        'email': profile.email.trim(),
        'contactNumber': profile.contactNumber.trim(),
        'joiningDate': profile.joiningDate.trim(),
        'department': profile.department.trim(),
        'employeeRole': profile.role.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<DeviceIdentity> loadDeviceIdentity() async {
    await ensureSignedIn();
    final android = await _deviceInfo.androidInfo;
    final stableUser = _auth.currentUser?.uid ?? 'anonymous-device';
    return DeviceIdentity(
      deviceId: '${android.id}-${android.model}-$stableUser',
      deviceName: '${android.manufacturer} ${android.model}',
      platform: 'android',
    );
  }

  Future<AttendanceSession?> loadActiveSession() async {
    final prefs = await SharedPreferences.getInstance();
    final rawSession = prefs.getString(_sessionKey);
    if (rawSession != null) {
      final decoded = jsonDecode(rawSession);
      if (decoded is Map<String, dynamic>) {
        final session = AttendanceSession.fromJson(decoded);
        if (session != null) {
          if (session.loginDateIst != todayIst) {
            await closeSession(session: session, reason: 'day_changed');
            return null;
          }
          if (shouldAutoLogout(session)) {
            await closeSession(session: session, reason: 'auto_logout_6pm');
            return null;
          }
          return session;
        }
      }
    }

    final firestoreSession = await _loadActiveSessionFromFirestore();
    if (firestoreSession != null) {
      if (shouldAutoLogout(firestoreSession)) {
        await closeSession(
          session: firestoreSession,
          reason: 'auto_logout_6pm',
        );
        return null;
      }
      await _saveSession(firestoreSession);
    }
    return firestoreSession;
  }

  Future<AttendanceSession?> _loadActiveSessionFromFirestore() async {
    try {
      final employee = await loadEmployeeProfile();
      final docId = attendanceDocumentId(employee.employeeId, todayIst);
      final docSnapshot = await _firestore
          .appCollection('attendance')
          .doc(docId)
          .get();
      final docData = docSnapshot.data();
      if (docData != null) {
        final session = _attendanceSessionFromFirestoreData(
          docId: docId,
          employeeId: employee.employeeId,
          data: docData,
        );
        if (session != null) return session;
      }

      final querySnapshot = await _firestore
          .appCollection('attendance')
          .where('employeeId', isEqualTo: employee.employeeId)
          .get();
      for (final record in querySnapshot.docs) {
        final data = record.data();
        final session = _attendanceSessionFromFirestoreData(
          docId: record.id,
          employeeId: employee.employeeId,
          data: data,
        );
        if (session != null && session.loginDateIst == todayIst) {
          return session;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  AttendanceSession? _attendanceSessionFromFirestoreData({
    required String docId,
    required String employeeId,
    required Map<String, dynamic> data,
  }) {
    final sessionStatus = data['sessionStatus'] as String?;
    if (sessionStatus != 'active') return null;
    final loginAtIst = data['loginAtIst'] as String?;
    final loginDateIst = data['loginDateIst'] as String?;
    if (loginAtIst == null || loginDateIst == null) return null;

    final officeGeofence = data['officeGeofence'] as Map<String, dynamic>?;
    final officeLatitude =
        (officeGeofence?['latitude'] as num?)?.toDouble() ??
        defaultOfficeLatitude;
    final officeLongitude =
        (officeGeofence?['longitude'] as num?)?.toDouble() ??
        defaultOfficeLongitude;
    final allowedRadiusMeters =
        (officeGeofence?['allowedRadiusMeters'] as num?)?.toDouble() ??
        defaultRadiusMeters;

    return AttendanceSession(
      documentId: docId,
      employeeId: employeeId,
      loginAtIst: loginAtIst,
      loginDateIst: loginDateIst,
      officeLatitude: officeLatitude,
      officeLongitude: officeLongitude,
      allowedRadiusMeters: allowedRadiusMeters,
      attendanceStatus: data['attendanceStatus'] as String?,
    );
  }

  Future<bool> hasOutsideOfficeSession() async {
    final session = await loadActiveSession();
    return session?.attendanceStatus == 'outside_office';
  }

  Future<AttendanceSession> createLogin({
    required Position loginPosition,
    required String faceImageBase64,
    required int faceCount,
    Map<String, dynamic>? faceRecognition,
  }) async {
    await ensureSignedIn();
    final employee = await loadEmployeeProfile();
    final device = await loadDeviceIdentity();
    final loginAt = nowIst;
    if (!loginAt.isBefore(_finalLogoutAtFor(loginAt))) {
      throw StateError('Face login is closed after 6 PM for today');
    }
    final loginAtIso = loginAt.toIso8601String();
    final loginDate = _dateKey(loginAt);
    final docId = attendanceDocumentId(employee.employeeId, loginDate);
    final docRef = _firestore.appCollection('attendance').doc(docId);

    final officeDistanceMeters = Geolocator.distanceBetween(
      loginPosition.latitude,
      loginPosition.longitude,
      defaultOfficeLatitude,
      defaultOfficeLongitude,
    );
    final outsideOffice = officeDistanceMeters > defaultRadiusMeters;

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final currentData = snapshot.data();
      final currentStatus = currentData?['sessionStatus'] as String?;
      if (currentStatus == 'active') {
        throw StateError('Attendance already active for today');
      }
      if (currentData?['loginAtIst'] != null) {
        throw StateError('Face login already completed for today');
      }

      final segment = {
        'inAtIst': loginAtIso,
        'inAt': Timestamp.fromDate(loginAt.toUtc()),
        'inLocation': {
          'latitude': loginPosition.latitude,
          'longitude': loginPosition.longitude,
          'accuracy': loginPosition.accuracy,
        },
        'outAtIst': null,
        'outReason': null,
      };

      transaction.set(docRef, {
        'employeeId': employee.employeeId,
        'employeeName': employee.employeeName,
        'employee': employee.toMap(),
        'device': device.toMap(),
        'status': 'present',
        'sessionStatus': 'active',
        'attendanceStatus': outsideOffice ? 'outside_office' : 'pending',
        'attendanceDecision': outsideOffice
            ? 'requires_office_entry'
            : 'eligible_after_7_hours',
        'eligibleMinutes': eligibleMinutes,
        'method': 'face_geofence',
        'requiresDailyFaceAuth': true,
        'faceImageBase64': faceImageBase64,
        'faceImageContentType': 'image/jpeg',
        'faceCount': faceCount,
        if (faceRecognition != null) 'faceRecognition': faceRecognition,
        'loginAt': FieldValue.serverTimestamp(),
        'loginAtIst': loginAtIso,
        'loginDateIst': loginDate,
        'officeGeofence': {
          'source': 'fixed_office_location',
          'latitude': defaultOfficeLatitude,
          'longitude': defaultOfficeLongitude,
          'allowedRadiusMeters': defaultRadiusMeters,
        },
        'officeDistanceMeters': officeDistanceMeters,
        'officeArrivalGraceMinutes': officeArrivalGrace.inMinutes,
        'loginLocation': {
          'latitude': loginPosition.latitude,
          'longitude': loginPosition.longitude,
          'accuracy': loginPosition.accuracy,
        },
        'segments': [segment],
        'logs': [
          {
            'event': 'login',
            'atIst': loginAtIso,
            'message': outsideOffice
                ? 'Logged in outside office circle; 30 mins to reach office'
                : 'Logged in inside office circle',
          },
        ],
      });
    });

    final session = AttendanceSession(
      documentId: docId,
      employeeId: employee.employeeId,
      loginAtIst: loginAtIso,
      loginDateIst: loginDate,
      officeLatitude: defaultOfficeLatitude,
      officeLongitude: defaultOfficeLongitude,
      allowedRadiusMeters: defaultRadiusMeters,
      attendanceStatus: outsideOffice ? 'outside_office' : 'pending',
    );

    await _saveSession(session);
    await purgeOldDailyFaceImages(employee.employeeId, keepDateKey: loginDate);
    return session;
  }

  Future<void> purgeOldDailyFaceImages(
    String employeeId, {
    required String keepDateKey,
  }) async {
    final snapshot = await _firestore
        .appCollection('attendance')
        .where('employeeId', isEqualTo: employeeId)
        .get();
    final batch = _firestore.batch();
    var hasUpdates = false;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['loginDateIst'] == keepDateKey) continue;
      if (!data.containsKey('faceImageBase64')) continue;
      batch.set(doc.reference, {
        'faceImageBase64': FieldValue.delete(),
        'faceImageContentType': FieldValue.delete(),
        'faceImagePurgedAt': FieldValue.serverTimestamp(),
        'faceImagePurgedAtIst': nowIst.toIso8601String(),
      }, SetOptions(merge: true));
      hasUpdates = true;
    }
    if (hasUpdates) {
      await batch.commit();
    }
  }

  Future<void> closeSession({
    required AttendanceSession session,
    String reason = 'manual_logout',
    Position? logoutPosition,
    double? distanceMeters,
  }) async {
    final requestedLogoutAt = nowIst;
    final docRef = _firestore
        .appCollection('attendance')
        .doc(session.documentId);
    final snapshot = await docRef.get();
    final data = snapshot.data();
    final loginAt = DateTime.tryParse(
      (data?['loginAtIst'] as String?) ?? session.loginAtIst,
    );
    final logoutAt = _effectiveLogoutAt(
      loginAt: loginAt,
      requestedLogoutAt: requestedLogoutAt,
    );
    final segments = _readSegments(data);
    if (segments.isNotEmpty) {
      final lastIndex = segments.length - 1;
      final lastSegment = Map<String, dynamic>.from(segments[lastIndex]);
      if (lastSegment['outAtIst'] == null) {
        lastSegment['outAtIst'] = logoutAt.toIso8601String();
        lastSegment['outAt'] = Timestamp.fromDate(logoutAt.toUtc());
        lastSegment['outReason'] = reason;
        lastSegment['outLocation'] = logoutPosition == null
            ? null
            : {
                'latitude': logoutPosition.latitude,
                'longitude': logoutPosition.longitude,
                'accuracy': logoutPosition.accuracy,
                'distanceMeters': distanceMeters,
              };
        segments[lastIndex] = lastSegment;
      }
    }

    final totalMinutes = loginAt == null
        ? null
        : logoutAt
              .difference(loginAt)
              .inMinutes
              .clamp(0, maxOfficeSession.inMinutes);
    final officeMinutes = _officeMinutesFromSegments(
      segments,
      logoutAt,
    ).clamp(0, maxOfficeSession.inMinutes);
    final attendanceStatus = officeMinutes >= eligibleMinutes
        ? 'attendance_considered'
        : 'not_considered_attendance';
    final dayStatus = officeMinutes >= eligibleMinutes
        ? 'pending'
        : 'not_considered';

    await docRef.update({
      'sessionStatus': 'closed',
      'attendanceStatus': attendanceStatus,
      'dayStatus': dayStatus,
      'logoutReason': reason,
      'logoutAt': FieldValue.serverTimestamp(),
      'logoutAtIst': logoutAt.toIso8601String(),
      'totalMinutes': totalMinutes,
      'officeMinutes': officeMinutes,
      'breakMinutes': totalMinutes == null
          ? null
          : (totalMinutes - officeMinutes).clamp(0, totalMinutes),
      'segments': segments,
      'logoutLocation': logoutPosition == null
          ? null
          : {
              'latitude': logoutPosition.latitude,
              'longitude': logoutPosition.longitude,
              'accuracy': logoutPosition.accuracy,
              'distanceMeters': distanceMeters,
            },
      'logs': FieldValue.arrayUnion([
        {
          'event': 'logout',
          'reason': reason,
          'atIst': logoutAt.toIso8601String(),
          'distanceMeters': distanceMeters,
        },
      ]),
    });

    await clearActiveSession();
  }

  Future<void> recordOfficeExit({
    required AttendanceSession session,
    required Position position,
    required double distanceMeters,
  }) async {
    final at = nowIst;
    final docRef = _firestore
        .appCollection('attendance')
        .doc(session.documentId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final data = snapshot.data();
      if (data == null || data['sessionStatus'] != 'active') return;

      final segments = _readSegments(data);
      if (segments.isEmpty) return;

      final lastIndex = segments.length - 1;
      final lastSegment = Map<String, dynamic>.from(segments[lastIndex]);
      if (lastSegment['outAtIst'] != null) return;

      lastSegment['outAtIst'] = at.toIso8601String();
      lastSegment['outAt'] = Timestamp.fromDate(at.toUtc());
      lastSegment['outReason'] = 'left_geofence_break';
      lastSegment['outLocation'] = {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'distanceMeters': distanceMeters,
      };
      segments[lastIndex] = lastSegment;

      transaction.set(docRef, {
        'attendanceStatus': 'outside_office_break',
        'lastOfficeExitAtIst': at.toIso8601String(),
        'lastOfficeDistanceMeters': distanceMeters,
        'segments': segments,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedAtIst': at.toIso8601String(),
        'logs': FieldValue.arrayUnion([
          {
            'event': 'office_exit',
            'reason': 'left_geofence_break',
            'atIst': at.toIso8601String(),
            'distanceMeters': distanceMeters,
          },
        ]),
      }, SetOptions(merge: true));
    });
  }

  Future<void> recordOfficeEntry({
    required AttendanceSession session,
    required Position position,
    required double distanceMeters,
  }) async {
    final at = nowIst;
    final docRef = _firestore
        .appCollection('attendance')
        .doc(session.documentId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final data = snapshot.data();
      if (data == null || data['sessionStatus'] != 'active') return;

      final segments = _readSegments(data);
      if (segments.isNotEmpty) {
        final lastSegment = segments.last;
        if (lastSegment['outAtIst'] == null) return;
      }

      segments.add({
        'inAtIst': at.toIso8601String(),
        'inAt': Timestamp.fromDate(at.toUtc()),
        'inLocation': {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
          'distanceMeters': distanceMeters,
        },
        'outAtIst': null,
        'outReason': null,
      });

      transaction.set(docRef, {
        'attendanceStatus': 'pending',
        'lastOfficeEntryAtIst': at.toIso8601String(),
        'lastOfficeDistanceMeters': distanceMeters,
        'segments': segments,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedAtIst': at.toIso8601String(),
        'logs': FieldValue.arrayUnion([
          {
            'event': 'office_entry',
            'atIst': at.toIso8601String(),
            'distanceMeters': distanceMeters,
          },
        ]),
      }, SetOptions(merge: true));
    });
  }

  Future<void> recordLeave({
    required String reason,
    Position? position,
    double? distanceMeters,
  }) async {
    await ensureSignedIn();
    final employee = await loadEmployeeProfile();
    final device = await loadDeviceIdentity();
    final at = nowIst;
    final dateKey = _dateKey(at);
    final docId = attendanceDocumentId(employee.employeeId, dateKey);

    await _firestore.appCollection('attendance').doc(docId).set({
      'employeeId': employee.employeeId,
      'employeeName': employee.employeeName,
      'employee': employee.toMap(),
      'device': device.toMap(),
      'status': 'leave',
      'sessionStatus': 'rejected',
      'attendanceStatus': 'leave',
      'dayStatus': 'leave',
      'method': 'face_geofence',
      'reason': reason,
      'capturedAt': FieldValue.serverTimestamp(),
      'capturedAtIst': at.toIso8601String(),
      'loginDateIst': dateKey,
      'location': position == null
          ? null
          : {
              'latitude': position.latitude,
              'longitude': position.longitude,
              'accuracy': position.accuracy,
              'distanceMeters': distanceMeters,
            },
    }, SetOptions(merge: true));
  }

  Future<void> requestLeave({
    required String dateKey,
    String reason = '',
  }) async {
    await ensureSignedIn();
    final date = _parseDateKey(dateKey, 'Leave date');
    final today = DateTime(nowIst.year, nowIst.month, nowIst.day);
    if (date.isBefore(DateTime(today.year, today.month - 1, today.day))) {
      throw ArgumentError('Leave request is too old');
    }

    final employee = await loadEmployeeProfile();
    final user = _auth.currentUser;
    final attendanceDoc = await _firestore
        .appCollection('attendance')
        .doc(attendanceDocumentId(employee.employeeId, dateKey))
        .get();
    final attendanceStatus = attendanceDoc.data()?['attendanceStatus'];
    if (attendanceStatus == 'attendance_considered') {
      throw StateError('Cannot request leave for a completed attendance day');
    }

    final docRef = _firestore
        .appCollection('leave_requests')
        .doc(leaveRequestDocumentId(employee.employeeId, dateKey));
    final existing = await docRef.get();
    final existingStatus = existing.data()?['status'] as String?;
    if (existing.exists &&
        existingStatus != 'rejected_leave' &&
        existingStatus != 'rejected' &&
        existingStatus != 'cancelled') {
      throw StateError('Leave request already exists for this date');
    }

    await docRef.set({
      'employeeId': employee.employeeId,
      'employeeName': employee.employeeName,
      'employee': employee.toMap(),
      'date': dateKey,
      'status': 'requested_leave',
      'reason': reason.trim(),
      'requestedAt': FieldValue.serverTimestamp(),
      'requestedAtIst': nowIst.toIso8601String(),
    }, SetOptions(merge: true));

    // Send push notification to Admin
    final nowIstStr = nowIst.toIso8601String();
    final message = {
      'title': 'New Leave Request',
      'body':
          '${employee.employeeName} requests leave on $dateKey. Reason: ${reason.trim().isEmpty ? "None" : reason.trim()}',
      'senderUid': user?.uid,
      'senderEmail': user?.email,
      'senderRole': 'employee',
      'senderName': employee.employeeName,
      'targetType': 'admin',
      'topics': ['admin_all'],
      'type': 'leave_request',
      'employeeId': employee.employeeId,
      'date': dateKey,
      'createdAt': FieldValue.serverTimestamp(),
      'createdAtIst': nowIstStr,
    };

    final msgRef = await _firestore.appCollection('team_messages').add(message);
    await _firestore.appCollection('fcm_outbox').doc(msgRef.id).set({
      ...message,
      'messageId': msgRef.id,
      'status': 'pending',
      'delivery': 'cloud_function',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> submitExitRequest({
    required String subject,
    required String reason,
    required String leavingDate,
  }) async {
    await ensureSignedIn();
    _validateExitRequest(
      subject: subject,
      reason: reason,
      leavingDate: leavingDate,
    );
    final employee = await loadEmployeeProfile();
    final at = nowIst;
    final user = _auth.currentUser;
    final pending = await _firestore
        .appCollection('exit_requests')
        .where('employeeId', isEqualTo: employee.employeeId)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    if (pending.docs.isNotEmpty) {
      throw StateError('A pending exit request already exists');
    }

    final requestId = exitRequestDocumentId(employee.employeeId);
    await _firestore.appCollection('exit_requests').doc(requestId).set({
      'employeeId': employee.employeeId,
      'employeeName': employee.employeeName,
      'employee': employee.toMap(),
      'subject': subject.trim(),
      'reason': reason.trim(),
      'leavingDate': leavingDate.trim(),
      'status': 'pending',
      'approvers': ['CEO', 'MANAGER'],
      'recipientEmails': {
        'ceo': 'ceo@dhinadts.com',
        'manager': 'manager@dhinadts.com',
      },
      'requestedAt': FieldValue.serverTimestamp(),
      'requestedAtIst': at.toIso8601String(),
    });

    final message = {
      'title': 'New Exit Request',
      'body':
          '${employee.employeeName} requested relieving on ${leavingDate.trim()}',
      'senderUid': user?.uid,
      'senderEmail': user?.email,
      'senderRole': 'employee',
      'senderName': employee.employeeName,
      'targetType': 'admin',
      'topics': ['admin_all'],
      'type': 'exit_request',
      'employeeId': employee.employeeId,
      'requestId': requestId,
      'createdAt': FieldValue.serverTimestamp(),
      'createdAtIst': at.toIso8601String(),
    };
    final msgRef = await _firestore.appCollection('team_messages').add(message);
    await _firestore.appCollection('fcm_outbox').doc(msgRef.id).set({
      ...message,
      'messageId': msgRef.id,
      'status': 'pending',
      'delivery': 'cloud_function',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>> generateSalaryRecord({
    required int year,
    required int month,
  }) async {
    await ensureSignedIn();
    if (month < 1 || month > 12) {
      throw ArgumentError('Invalid salary month');
    }

    final employee = await loadEmployeeProfile();
    final monthKey =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
    final records = await _firestore
        .appCollection('attendance')
        .where('employeeId', isEqualTo: employee.employeeId)
        .get();

    var payableDays = 0;
    var notConsideredDays = 0;
    var leaveDays = 0;
    var officeMinutes = 0;
    for (final doc in records.docs) {
      final data = doc.data();
      final date = data['loginDateIst'] as String?;
      if (date == null || !date.startsWith(monthKey)) continue;
      final minutes = (data['officeMinutes'] as num?)?.toInt() ?? 0;
      officeMinutes += minutes;
      final status = data['attendanceStatus'] as String?;
      final dayStatus = data['dayStatus'] as String?;
      if (status == 'attendance_considered') {
        payableDays++;
      } else if (dayStatus == 'approved_leave' || status == 'approved_leave') {
        payableDays++;
        leaveDays++;
      } else if (status == 'leave' || dayStatus == 'leave') {
        leaveDays++;
      } else if (status == 'not_considered_attendance') {
        notConsideredDays++;
      }
    }

    final perDay = monthlyBaseSalary / monthlyWorkingDays;
    final gross = (payableDays * perDay).round();
    final deductions = monthlyBaseSalary - gross;
    final net = gross;
    final record = {
      'employeeId': employee.employeeId,
      'employeeName': employee.employeeName,
      'employee': employee.toMap(),
      'year': year,
      'month': month,
      'monthKey': monthKey,
      'baseSalary': monthlyBaseSalary,
      'workingDays': monthlyWorkingDays,
      'payableDays': payableDays,
      'notConsideredDays': notConsideredDays,
      'leaveDays': leaveDays,
      'officeMinutes': officeMinutes,
      'grossSalary': gross,
      'deductions': deductions,
      'netSalary': net,
      'generatedAt': FieldValue.serverTimestamp(),
      'generatedAtIst': nowIst.toIso8601String(),
    };

    await _firestore
        .appCollection('salary_records')
        .doc(salaryRecordDocumentId(employee.employeeId, year, month))
        .set(record, SetOptions(merge: true));
    return record;
  }

  Future<void> clearLocalCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Future<User?> ensureSignedIn() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) return currentUser;
    throw StateError('Login required');
  }

  bool shouldAutoLogout(AttendanceSession session) {
    final loginAt = DateTime.tryParse(session.loginAtIst);
    if (loginAt == null) return false;
    if (session.loginDateIst != todayIst) return true;
    return !nowIst.isBefore(_finalLogoutAtFor(loginAt));
  }

  double distanceFromZone(Position position, AttendanceSession session) {
    return Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      session.officeLatitude,
      session.officeLongitude,
    );
  }

  Future<void> clearActiveSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  Future<void> _saveSession(AttendanceSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(session.toJson()));
  }

  String _dateKey(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  DateTime _finalLogoutAtFor(DateTime loginAt) {
    return DateTime(
      loginAt.year,
      loginAt.month,
      loginAt.day,
      finalLogoutHourIst,
      finalLogoutMinuteIst,
    );
  }

  DateTime _effectiveLogoutAt({
    required DateTime? loginAt,
    required DateTime requestedLogoutAt,
  }) {
    if (loginAt == null) return requestedLogoutAt;
    final finalLogoutAt = _finalLogoutAtFor(loginAt);
    return requestedLogoutAt.isAfter(finalLogoutAt)
        ? finalLogoutAt
        : requestedLogoutAt;
  }

  List<Map<String, dynamic>> _readSegments(Map<String, dynamic>? data) {
    final rawSegments = data?['segments'];
    if (rawSegments is! List) return <Map<String, dynamic>>[];
    return rawSegments
        .whereType<Map>()
        .map((segment) => Map<String, dynamic>.from(segment))
        .toList();
  }

  int _officeMinutesFromSegments(
    List<Map<String, dynamic>> segments,
    DateTime fallbackOutAt,
  ) {
    var minutes = 0;
    for (final segment in segments) {
      final inAt = DateTime.tryParse(segment['inAtIst'] as String? ?? '');
      final outAt =
          DateTime.tryParse(segment['outAtIst'] as String? ?? '') ??
          fallbackOutAt;
      if (inAt == null || outAt.isBefore(inAt)) continue;
      minutes += outAt.difference(inAt).inMinutes;
    }
    return minutes;
  }

  DateTime _parseDateKey(String value, String label) {
    final parsed = DateTime.tryParse(value.trim());
    if (parsed == null ||
        value.trim().length != 10 ||
        value.trim()[4] != '-' ||
        value.trim()[7] != '-') {
      throw ArgumentError('$label must be in YYYY-MM-DD format');
    }
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  void _validateProfile(EmployeeProfile profile) {
    if (profile.employeeId.trim().isEmpty) {
      throw ArgumentError('Employee ID is required');
    }
    if (profile.firstName.trim().isEmpty) {
      throw ArgumentError('First name is required');
    }
    if (profile.email.trim().isEmpty || !profile.email.contains('@')) {
      throw ArgumentError('Valid email is required');
    }
    if (profile.dateOfBirth.trim().isNotEmpty) {
      _parseDateKey(profile.dateOfBirth, 'DOB');
    }
    if (profile.joiningDate.trim().isNotEmpty) {
      _parseDateKey(profile.joiningDate, 'Joining date');
    }
    if (profile.contactNumber.trim().isNotEmpty &&
        profile.contactNumber.trim().length < 10) {
      throw ArgumentError('Contact number must be at least 10 digits');
    }
  }

  void _validateExitRequest({
    required String subject,
    required String reason,
    required String leavingDate,
  }) {
    if (subject.trim().isEmpty) {
      throw ArgumentError('Subject is required');
    }
    if (reason.trim().length < 10) {
      throw ArgumentError('Reason must be at least 10 characters');
    }
    final date = _parseDateKey(leavingDate, 'Leaving date');
    final today = DateTime(nowIst.year, nowIst.month, nowIst.day);
    if (date.isBefore(today)) {
      throw ArgumentError('Leaving date cannot be in the past');
    }
  }

  String _safeId(String value) {
    return value.trim().replaceAll(RegExp(r'[/#?\[\]]'), '_');
  }
}

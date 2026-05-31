import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum AppUserRole { employee, admin }

class AuthRoleService {
  AuthRoleService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  User? get currentUser => _auth.currentUser;

  Future<AppUserRole?> currentRole() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return roleForUser(user.uid);
  }

  Future<AppUserRole> roleForUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    final rawRole = doc.data()?['role'] as String?;
    return rawRole == 'admin' ? AppUserRole.admin : AppUserRole.employee;
  }

  Future<AppUserRole> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final uid = credential.user!.uid;
    return roleForUser(uid);
  }

  Future<AppUserRole> signUp({
    required String email,
    required String password,
    required AppUserRole role,
    required String firstName,
    required String lastName,
    required String employeeId,
    String department = '',
    String employeeRole = 'EMPLOYEE',
  }) async {
    if (email.trim().isEmpty || !email.trim().contains('@')) {
      throw ArgumentError('Valid email is required');
    }
    if (password.length < 6) {
      throw ArgumentError('Password must be at least 6 characters');
    }
    if (firstName.trim().isEmpty) {
      throw ArgumentError('First name is required');
    }
    final normalizedEmployeeId = employeeId.trim();
    if (role == AppUserRole.employee && normalizedEmployeeId.isEmpty) {
      throw ArgumentError('Employee ID is required');
    }
    if (normalizedEmployeeId.isNotEmpty) {
      final existingProfile = await _firestore
          .collection('employee_profiles')
          .doc(normalizedEmployeeId)
          .get();
      if (existingProfile.exists) {
        throw StateError('Employee ID already exists');
      }
    }

    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user!;
    final roleName = role.name;
    final displayName = '$firstName $lastName'.trim();
    await user.updateDisplayName(displayName);

    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': email.trim(),
      'role': roleName,
      'employeeId': normalizedEmployeeId.isEmpty
          ? user.uid
          : normalizedEmployeeId,
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'nickName': firstName.trim(),
      'displayName': displayName,
      'department': department.trim(),
      'employeeRole': employeeRole.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (role == AppUserRole.employee) {
      await _firestore
          .collection('employee_profiles')
          .doc(normalizedEmployeeId.isEmpty ? user.uid : normalizedEmployeeId)
          .set({
            'employeeId': normalizedEmployeeId.isEmpty
                ? user.uid
                : normalizedEmployeeId,
            'firstName': firstName.trim(),
            'lastName': lastName.trim(),
            'nickName': firstName.trim(),
            'employeeName': displayName,
            'email': email.trim(),
            'role': employeeRole.trim().isEmpty
                ? 'EMPLOYEE'
                : employeeRole.trim(),
            'department': department.trim(),
            'employeeRole': employeeRole.trim().isEmpty
                ? 'EMPLOYEE'
                : employeeRole.trim(),
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    }

    return role;
  }

  Future<void> signOut() => _auth.signOut();
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../constants/organization_options.dart';
import 'app_firestore.dart';

enum AppUserRole { employee, partialAdmin, admin }

extension SignupRoleAuthX on SignupRole {
  AppUserRole get appUserRole {
    switch (this) {
      case SignupRole.admin:
        return AppUserRole.admin;
      case SignupRole.employee:
        return AppUserRole.employee;
      case SignupRole.partialAdmin:
        return AppUserRole.partialAdmin;
    }
  }
}

extension AppUserRoleX on AppUserRole {
  bool get isAdminLike =>
      this == AppUserRole.admin || this == AppUserRole.partialAdmin;

  bool get canAssignRoles => this == AppUserRole.admin;

  String get storageValue {
    switch (this) {
      case AppUserRole.employee:
        return 'employee';
      case AppUserRole.partialAdmin:
        return 'partialAdmin';
      case AppUserRole.admin:
        return 'admin';
    }
  }

  String get label {
    switch (this) {
      case AppUserRole.employee:
        return 'EMPLOYEE';
      case AppUserRole.partialAdmin:
        return 'PARTIAL ADMIN';
      case AppUserRole.admin:
        return 'ADMIN';
    }
  }
}

AppUserRole appUserRoleFromValue(Object? value) {
  final normalized = value
      ?.toString()
      .trim()
      .replaceAll('-', '_')
      .replaceAll(' ', '_')
      .toLowerCase();
  switch (normalized) {
    case 'admin':
      return AppUserRole.admin;
    case 'partialadmin':
    case 'partial_admin':
      return AppUserRole.partialAdmin;
    default:
      return AppUserRole.employee;
  }
}

class AppUserAccess {
  const AppUserAccess({
    required this.role,
    required this.canApproveLeave,
    required this.canManageSalary,
  });

  final AppUserRole role;
  final bool canApproveLeave;
  final bool canManageSalary;

  bool get isAdminLike => role.isAdminLike;
}

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
    final doc = await _firestore.appCollection('users').doc(uid).get();
    return appUserRoleFromValue(doc.data()?['role']);
  }

  Future<AppUserAccess> accessForUser(String uid) async {
    final doc = await _firestore.appCollection('users').doc(uid).get();
    final data = doc.data() ?? {};
    final role = appUserRoleFromValue(data['role']);
    final permissions = data['permissions'] as Map<String, dynamic>? ?? {};
    final canApproveLeave =
        role == AppUserRole.admin ||
        data['canApproveLeave'] == true ||
        permissions['approveLeave'] == true;
    final canManageSalary =
        role == AppUserRole.admin ||
        data['canManageSalary'] == true ||
        permissions['manageSalary'] == true;
    return AppUserAccess(
      role: role,
      canApproveLeave: canApproveLeave,
      canManageSalary: canManageSalary,
    );
  }

  Future<AppUserAccess?> currentAccess() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return accessForUser(user.uid);
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
    String organizationRole = 'EMPLOYEE',
    bool canApproveLeave = false,
    bool canManageSalary = false,
    bool allowPrivilegedSignup = false,
  }) async {
    final creator = _auth.currentUser;
    final creatorRole = creator == null ? null : await currentRole();
    final isAdminCreatedAccount = creatorRole?.canAssignRoles == true;

    if (role.isAdminLike && !isAdminCreatedAccount && !allowPrivilegedSignup) {
      throw StateError(
        'Admin and partial admin accounts must be created by an authorized admin',
      );
    }
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
    if (role != AppUserRole.admin && normalizedEmployeeId.isEmpty) {
      throw ArgumentError('Employee ID is required');
    }
    if (role == AppUserRole.partialAdmin &&
        !OrganizationOptions.partialAdminRoles.contains(employeeRole.trim()) &&
        !OrganizationOptions.partialAdminRoles.contains(
          organizationRole.trim(),
        )) {
      throw ArgumentError(
        'Partial admin access is available only for lead roles',
      );
    }
    if (normalizedEmployeeId.isNotEmpty) {
      final existingProfile = await _firestore
          .appCollection('employee_profiles')
          .doc(normalizedEmployeeId)
          .get();
      if (existingProfile.exists) {
        throw StateError('Employee ID already exists');
      }
    }

    FirebaseApp? secondaryApp;
    FirebaseAuth accountAuth = _auth;
    if (isAdminCreatedAccount) {
      secondaryApp = await Firebase.initializeApp(
        name: 'account_creator_${DateTime.now().microsecondsSinceEpoch}',
        options: Firebase.app().options,
      );
      accountAuth = FirebaseAuth.instanceFor(app: secondaryApp);
    }

    try {
      final credential = await accountAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user!;
      final roleName = role.storageValue;
      final displayName = '$firstName $lastName'.trim();
      final allowLeaveApproval = role == AppUserRole.admin || canApproveLeave;
      final allowSalaryManagement =
          role == AppUserRole.admin || canManageSalary;
      await user.updateDisplayName(displayName);

      await _firestore.appCollection('users').doc(user.uid).set({
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
        'organizationRole': organizationRole.trim(),
        'accessRoleName': organizationRole.trim(),
        'canApproveLeave': allowLeaveApproval,
        'canManageSalary': allowSalaryManagement,
        'permissions': {
          'approveLeave': allowLeaveApproval,
          'manageSalary': allowSalaryManagement,
        },
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (role != AppUserRole.admin) {
        await _firestore
            .appCollection('employee_profiles')
            .doc(normalizedEmployeeId.isEmpty ? user.uid : normalizedEmployeeId)
            .set({
              'uid': user.uid,
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
              'organizationRole': organizationRole.trim(),
              'accessRoleName': organizationRole.trim(),
              'employeeRole': employeeRole.trim().isEmpty
                  ? 'EMPLOYEE'
                  : employeeRole.trim(),
              'createdAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      }
    } finally {
      if (isAdminCreatedAccount) {
        await accountAuth.signOut();
        await secondaryApp?.delete();
      }
    }

    return role;
  }

  Future<void> sendPasswordResetEmail(String email) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty || !trimmedEmail.contains('@')) {
      throw ArgumentError('Enter a valid email address');
    }
    await _auth.sendPasswordResetEmail(email: trimmedEmail);
  }

  Future<void> signOut() => _auth.signOut();
}

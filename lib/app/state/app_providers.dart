import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/attendance_session_service.dart';
import '../../services/auth_role_service.dart';
import '../../services/payroll_api_service.dart';

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final attendanceSessionServiceProvider = Provider<AttendanceSessionService>((
  ref,
) {
  return AttendanceSessionService(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});

final authRoleServiceProvider = Provider<AuthRoleService>((ref) {
  return AuthRoleService(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});

final payrollApiServiceProvider = Provider<PayrollApiService>((ref) {
  return PayrollApiService();
});

final payrollUploadDraftProvider =
    NotifierProvider<PayrollUploadDraftController, PayrollUploadDraft>(
      PayrollUploadDraftController.new,
    );

final payrollUploadBusyProvider =
    NotifierProvider<PayrollUploadBusyController, bool>(
      PayrollUploadBusyController.new,
    );

final payrollUploadStatusProvider =
    NotifierProvider<PayrollUploadStatusController, String?>(
      PayrollUploadStatusController.new,
    );

final salarySlipSelectionProvider =
    NotifierProvider<SalarySlipSelectionController, SalarySlipSelection>(
      SalarySlipSelectionController.new,
    );

final salarySlipSavedPathProvider =
    NotifierProvider<SalarySlipSavedPathController, String?>(
      SalarySlipSavedPathController.new,
    );

final currentEmployeeProfileProvider = FutureProvider<EmployeeProfile>((
  ref,
) async {
  return ref.watch(attendanceSessionServiceProvider).loadEmployeeProfile();
});

final currentUserRoleProvider = FutureProvider<AppUserRole?>((ref) async {
  return ref.watch(authRoleServiceProvider).currentRole();
});

final employeeProfilesStreamProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
      return ref
          .watch(firestoreProvider)
          .collection('employee_profiles')
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => {'id': doc.id, ...doc.data()})
                .toList(),
          );
    });

final salaryRecordsStreamProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String?>((
      ref,
      employeeId,
    ) {
      Query<Map<String, dynamic>> query = ref
          .watch(firestoreProvider)
          .collection('salary_records')
          .orderBy('monthKey', descending: true);
      final trimmedEmployeeId = employeeId?.trim();
      if (trimmedEmployeeId != null && trimmedEmployeeId.isNotEmpty) {
        query = query.where('employeeId', isEqualTo: trimmedEmployeeId);
      }
      return query.snapshots().map(
        (snapshot) =>
            snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList(),
      );
    });

class PayrollUploadDraft {
  const PayrollUploadDraft({this.employeeId = '', this.year, this.month});

  final String employeeId;
  final int? year;
  final int? month;

  PayrollUploadDraft copyWith({String? employeeId, int? year, int? month}) {
    return PayrollUploadDraft(
      employeeId: employeeId ?? this.employeeId,
      year: year ?? this.year,
      month: month ?? this.month,
    );
  }
}

class PayrollUploadDraftController extends Notifier<PayrollUploadDraft> {
  @override
  PayrollUploadDraft build() => const PayrollUploadDraft();

  void update(PayrollUploadDraft value) => state = value;
}

class PayrollUploadBusyController extends Notifier<bool> {
  @override
  bool build() => false;

  void setValue(bool value) => state = value;
}

class PayrollUploadStatusController extends Notifier<String?> {
  @override
  String? build() => null;

  void setMessage(String? value) => state = value;
}

class SalarySlipSelection {
  const SalarySlipSelection({required this.month, required this.year});

  final int month;
  final int year;

  String get monthKey =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';

  SalarySlipSelection copyWith({int? month, int? year}) {
    return SalarySlipSelection(
      month: month ?? this.month,
      year: year ?? this.year,
    );
  }
}

class SalarySlipSelectionController extends Notifier<SalarySlipSelection> {
  @override
  SalarySlipSelection build() {
    final now = DateTime.now();
    return SalarySlipSelection(month: now.month, year: now.year);
  }

  void update(SalarySlipSelection value) => state = value;
}

class SalarySlipSavedPathController extends Notifier<String?> {
  @override
  String? build() => null;

  void setPath(String? value) => state = value;
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'app_firestore.dart';

class AuditLogService {
  AuditLogService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<void> write({
    required String action,
    required String entityType,
    required String entityId,
    String result = 'success',
    Map<String, dynamic>? metadata,
  }) async {
    final user = _auth.currentUser;
    final nowIst = DateTime.now()
        .toUtc()
        .add(const Duration(hours: 5, minutes: 30))
        .toIso8601String();

    await _firestore.appCollection('audit_logs').add({
      'action': action,
      'entityType': entityType,
      'entityId': entityId,
      'result': result,
      'actorUid': user?.uid,
      'actorEmail': user?.email,
      'metadata': metadata ?? const <String, dynamic>{},
      'createdAt': FieldValue.serverTimestamp(),
      'createdAtIst': nowIst,
    });
  }

  Future<void> writeBestEffort({
    required String action,
    required String entityType,
    required String entityId,
    String result = 'success',
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await write(
        action: action,
        entityType: entityType,
        entityId: entityId,
        result: result,
        metadata: metadata,
      );
    } catch (_) {
      // Audit writes must not strand the user's foreground attendance action.
    }
  }
}

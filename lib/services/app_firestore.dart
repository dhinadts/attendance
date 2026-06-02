import 'package:cloud_firestore/cloud_firestore.dart';

class AppFirestore {
  AppFirestore._();

  static const rootCollection = 'Attendance';
  static const rootDocument = 'main';

  static DocumentReference<Map<String, dynamic>> root(
    FirebaseFirestore firestore,
  ) {
    return firestore.collection(rootCollection).doc(rootDocument);
  }

  static CollectionReference<Map<String, dynamic>> collection(
    FirebaseFirestore firestore,
    String collectionPath,
  ) {
    return root(firestore).collection(collectionPath);
  }
}

extension AttendanceFirestoreNamespace on FirebaseFirestore {
  CollectionReference<Map<String, dynamic>> appCollection(
    String collectionPath,
  ) {
    return AppFirestore.collection(this, collectionPath);
  }
}

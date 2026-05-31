import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'app.dart';
import 'firebase_options.dart';
import 'services/fcm_notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  try {
    await FirebaseFirestore.instance.collection('fcm_background_events').add({
      'messageId': message.messageId,
      'title': message.notification?.title ?? message.data['title'],
      'body': message.notification?.body ?? message.data['body'],
      'data': message.data,
      'receivedAt': FieldValue.serverTimestamp(),
      'source': 'background',
    });
  } catch (_) {
    // Background handlers must stay best-effort; notification delivery should
    // not crash because an audit write was blocked or unavailable.
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await FcmNotificationService.instance.initialize();

  runApp(const WorkSyncApp());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    FcmNotificationService.instance.handlePendingInitialMessage();
  });
}

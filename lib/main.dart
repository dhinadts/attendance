import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'firebase_options.dart';
import 'services/fcm_notification_service.dart';
import 'services/app_firestore.dart';
import 'services/app_resilience_service.dart';
import 'services/app_telemetry_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  try {
    await FirebaseFirestore.instance
        .appCollection('fcm_background_events')
        .add({
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
  final telemetryDsn = const String.fromEnvironment('SENTRY_DSN', defaultValue: '');
  final appEnvironment = const String.fromEnvironment(
    'APP_ENV',
    defaultValue: kReleaseMode ? 'production' : 'debug',
  );
  final appRelease = const String.fromEnvironment(
    'APP_RELEASE',
    defaultValue: 'attendance@1.0.0+1',
  );

  FlutterError.onError = (details) {
    AppResilienceService.instance.recordError(
      details.exceptionAsString(),
      context: 'flutter_error',
      details: {
        'library': details.library,
        'stackTrace': details.stack?.toString(),
      },
    );
    AppTelemetryService.instance.captureException(
      details.exception,
      stackTrace: details.stack,
      context: 'flutter_error',
      extra: {'library': details.library},
    );
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    AppResilienceService.instance.recordError(
      error.toString(),
      context: 'platform_dispatcher',
      details: {'stackTrace': stack.toString()},
    );
    AppTelemetryService.instance.captureException(
      error,
      stackTrace: stack,
      context: 'platform_dispatcher',
    );
    return true;
  };

  await AppResilienceService.instance.initialize();
  await AppTelemetryService.instance.initialize(
    dsn: telemetryDsn,
    environment: appEnvironment,
    release: appRelease,
  );
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }
  await FcmNotificationService.instance.initialize();

  runApp(const ProviderScope(child: WorkSyncApp()));
  WidgetsBinding.instance.addPostFrameCallback((_) {
    FcmNotificationService.instance.handlePendingInitialMessage();
  });
}

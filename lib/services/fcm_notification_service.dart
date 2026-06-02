import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as fln;
import 'package:go_router/go_router.dart';

import 'auth_role_service.dart';

class FcmNotificationService {
  FcmNotificationService._();

  static final FcmNotificationService instance = FcmNotificationService._();
  static final navigatorKey = GlobalKey<NavigatorState>();
  static const androidNotificationChannelId = 'team_messages_heads_up';

  final _messaging = FirebaseMessaging.instance;
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _localNotifications = fln.FlutterLocalNotificationsPlugin();
  final _authRoleService = AuthRoleService();
  bool _foregroundDialogOpen = false;
  RemoteMessage? _pendingInitialMessage;
  String? _pendingRouteAfterLogin;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _adminRequestSubscription;
  bool _adminRequestListenerPrimed = false;
  final Set<String> _shownForegroundMessageIds = <String>{};

  static const _channel = fln.AndroidNotificationChannel(
    androidNotificationChannelId,
    'Team messages',
    description: 'Team and admin message notifications',
    importance: fln.Importance.high,
    playSound: true,
    enableVibration: true,
  );

  Future<void> initialize() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    if (!kIsWeb) {
      await _localNotifications.initialize(
        settings: const fln.InitializationSettings(
          android: fln.AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: (response) {
          _handleLocalNotificationTap(response.payload);
        },
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            fln.AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_channel);
    }

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedFromBackground);
    _pendingInitialMessage = await _messaging.getInitialMessage();

    _auth.authStateChanges().listen((user) {
      if (user != null) {
        registerCurrentUser();
      } else {
        _stopAdminRequestForegroundListener();
      }
    });
    _messaging.onTokenRefresh.listen((_) => registerCurrentUser());
  }

  Future<void> handlePendingInitialMessage() async {
    final message = _pendingInitialMessage;
    if (message == null) return;
    _pendingInitialMessage = null;
    await _handleRemoteMessageTap(message);
    unawaited(
      _saveIncomingMessageBestEffort(
        title: _titleFor(message),
        body: _bodyFor(message),
        data: message.data,
        source: 'terminated',
      ),
    );
  }

  Future<void> registerCurrentUser({String? department}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final role = await _authRoleService.currentRole();
    if (role == AppUserRole.admin) {
      _startAdminRequestForegroundListener();
    }

    String? token;
    try {
      const webVapidKey = String.fromEnvironment(
        'FIREBASE_WEB_VAPID_KEY',
        defaultValue: '',
      );
      token = kIsWeb
          ? await _messaging.getToken(
              vapidKey: webVapidKey.isEmpty ? null : webVapidKey,
            )
          : await _messaging.getToken();
    } catch (_) {
      token = null;
    }
    if (token == null || token.isEmpty) return;

    if (!kIsWeb) {
      await _messaging.subscribeToTopic('team_all');
      if (role == AppUserRole.admin) {
        await _messaging.subscribeToTopic('admin_all');
      }
    }
    final normalizedDepartment = department?.trim();
    if (normalizedDepartment != null && normalizedDepartment.isNotEmpty) {
      if (!kIsWeb) {
        await _messaging.subscribeToTopic(_topicForTeam(normalizedDepartment));
      }
    }

    final data = {
      'uid': user.uid,
      'email': user.email,
      'token': token,
      'platform': kIsWeb ? 'web' : 'android',
      'department': normalizedDepartment,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final userRef = _firestore.collection('users').doc(user.uid);
    final userDoc = await userRef.get();
    if (userDoc.exists) {
      await userRef.set({
        'fcmToken': token,
        'fcmUpdatedAt': FieldValue.serverTimestamp(),
        if (normalizedDepartment != null) 'department': normalizedDepartment,
      }, SetOptions(merge: true));
    }
    await _firestore
        .collection('fcm_tokens')
        .doc('${user.uid}_${kIsWeb ? 'web' : 'android'}')
        .set(data, SetOptions(merge: true));
  }

  Future<void> _handleLocalNotificationTap(String? payload) async {
    if (payload == null || payload.isEmpty) return;

    try {
      final decoded = Map<String, dynamic>.from(jsonDecode(payload));
      final notificationRoute = await routeForNotificationData(decoded);
      if (notificationRoute != null) {
        _openRouteOrStore(notificationRoute);
        return;
      }

      final messageId = decoded['messageId'] as String?;
      final role = await _authRoleService.currentRole();
      final messageRoute = role == AppUserRole.admin
          ? '/admin-notifications'
          : '/notifications';
      _openRouteOrStore(
        messageId == null || messageId.isEmpty
            ? messageRoute
            : '$messageRoute?messageId=${Uri.encodeComponent(messageId)}&open=1',
      );
    } catch (_) {
      // fallback
      final role = await _authRoleService.currentRole();
      final route = role == AppUserRole.admin
          ? '/admin-notifications'
          : '/notifications';
      _openRouteOrStore(
        payload.contains('/')
            ? payload
            : '$route?messageId=${Uri.encodeComponent(payload)}&open=1',
      );
    }
  }

  Future<void> _handleRemoteMessageTap(RemoteMessage message) async {
    final notificationRoute = await routeForNotificationData(message.data);
    if (notificationRoute != null) {
      _openRouteOrStore(notificationRoute);
      return;
    }

    final role = await _authRoleService.currentRole();
    final messageRoute = role == AppUserRole.admin
        ? '/admin-notifications'
        : '/notifications';
    final messageId = message.data['messageId'] as String?;
    _openRouteOrStore(
      messageId == null || messageId.isEmpty
          ? messageRoute
          : '$messageRoute?messageId=${Uri.encodeComponent(messageId)}&open=1',
    );
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final title = _titleFor(message);
    final body = _bodyFor(message);
    final messageId = message.data['messageId'] as String?;
    await _saveIncomingMessageBestEffort(
      title: title,
      body: body,
      data: message.data,
      source: 'foreground',
    );

    await _handleRemoteMessageTap(message);

    if (messageId != null &&
        messageId.isNotEmpty &&
        _shownForegroundMessageIds.contains(messageId)) {
      return;
    }
    if (messageId != null && messageId.isNotEmpty) {
      _shownForegroundMessageIds.add(messageId);
    }

    await _showForegroundNotificationAndDialog(
      notificationId: message.hashCode,
      title: title,
      body: body,
      data: message.data,
      onOpen: () => _handleRemoteMessageTap(message),
      showInAppDialog: false,
    );
  }

  Future<void> _showForegroundNotificationAndDialog({
    required int notificationId,
    required String title,
    required String body,
    required Map<String, dynamic> data,
    required VoidCallback onOpen,
    bool showInAppDialog = true,
  }) async {
    if (!kIsWeb) {
      await _localNotifications.show(
        id: notificationId,
        title: title,
        body: body,
        payload: jsonEncode({
          'messageId': data['messageId'] ?? '',
          'type': data['type'] ?? '',
          'employeeId': data['employeeId'] ?? '',
          'date': data['date'] ?? '',
          'requestId': data['requestId'] ?? '',
        }),
        notificationDetails: fln.NotificationDetails(
          android: fln.AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: fln.Importance.high,
            priority: fln.Priority.high,
            playSound: true,
            enableVibration: true,
          ),
        ),
      );
    }

    if (!showInAppDialog) return;

    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    if (_foregroundDialogOpen) return;
    _foregroundDialogOpen = true;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body.isEmpty ? 'You have a new team message.' : body),
        actions: [
          TextButton(
            onPressed: () {
              if (!kIsWeb) {
                _localNotifications.cancel(id: notificationId);
              }
              Navigator.of(context).pop();
            },
            child: const Text('CLEAR'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              onOpen();
            },
            child: const Text('OPEN'),
          ),
        ],
      ),
    ).whenComplete(() => _foregroundDialogOpen = false);
  }

  void _startAdminRequestForegroundListener() {
    if (_adminRequestSubscription != null) return;
    _adminRequestListenerPrimed = false;
    _adminRequestSubscription = _firestore
        .collection('team_messages')
        .orderBy('createdAt', descending: true)
        .limit(25)
        .snapshots()
        .listen((snapshot) {
          final addedDocs = snapshot.docChanges
              .where((change) => change.type == DocumentChangeType.added)
              .map((change) => change.doc)
              .toList();

          if (!_adminRequestListenerPrimed) {
            _shownForegroundMessageIds.addAll(addedDocs.map((doc) => doc.id));
            _adminRequestListenerPrimed = true;
            return;
          }

          for (final doc in addedDocs.reversed) {
            final data = doc.data();
            if (data == null || !_isAdminRequestMessage(data)) continue;
            if (_shownForegroundMessageIds.contains(doc.id)) continue;
            _shownForegroundMessageIds.add(doc.id);

            final payload = {...data, 'messageId': doc.id};
            final title = data['title'] as String? ?? 'New Employee Request';
            final body =
                data['body'] as String? ?? 'An employee request needs review.';

            _saveIncomingMessage(
              title: title,
              body: body,
              data: payload,
              source: 'foreground_firestore',
            );
            _showForegroundNotificationAndDialog(
              notificationId: doc.id.hashCode,
              title: title,
              body: body,
              data: payload,
              onOpen: () async {
                final context = navigatorKey.currentContext;
                if (context == null || !context.mounted) return;
                final route = await routeForNotificationData(payload);
                if (!context.mounted || route == null) return;
                context.go(route);
              },
            );
          }
        });
  }

  void _stopAdminRequestForegroundListener() {
    _adminRequestSubscription?.cancel();
    _adminRequestSubscription = null;
    _adminRequestListenerPrimed = false;
  }

  bool _isAdminRequestMessage(Map<String, dynamic> data) {
    final targetType = data['targetType'] as String?;
    final type = data['type'] as String?;
    return targetType == 'admin' &&
        (type == 'leave_request' ||
            type == 'attendance_mark_request' ||
            type == 'exit_request');
  }

  Future<void> _handleOpenedFromBackground(RemoteMessage message) async {
    await _handleRemoteMessageTap(message);
    unawaited(
      _saveIncomingMessageBestEffort(
        title: _titleFor(message),
        body: _bodyFor(message),
        data: message.data,
        source: 'background_tap',
      ),
    );
  }

  Future<String> sendTeamMessage({
    required String title,
    required String body,
    required AppUserRole senderRole,
    required String senderName,
    required String? senderEmployeeId,
    required bool sendToAllTeams,
    required List<String> selectedTeams,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Login required');
    }
    if (title.trim().isEmpty || body.trim().isEmpty) {
      throw ArgumentError('Title and message are required');
    }
    if (!sendToAllTeams && selectedTeams.isEmpty) {
      throw ArgumentError('Select at least one team');
    }

    final normalizedTeams = selectedTeams
        .map((team) => team.trim())
        .where((team) => team.isNotEmpty)
        .toSet()
        .toList();
    final topics = sendToAllTeams
        ? ['team_all']
        : normalizedTeams.map(topicForTeam).toList();
    if (senderRole == AppUserRole.employee && !topics.contains('admin_all')) {
      topics.add('admin_all');
    }
    final nowIst = DateTime.now()
        .toUtc()
        .add(const Duration(hours: 5, minutes: 30))
        .toIso8601String();
    final message = {
      'title': title.trim(),
      'body': body.trim(),
      'senderUid': user.uid,
      'senderEmail': user.email,
      'senderRole': senderRole.name,
      'senderName': senderName,
      'senderEmployeeId': senderEmployeeId,
      'targetType': sendToAllTeams ? 'all' : 'teams',
      'targetTeam': sendToAllTeams ? 'all' : normalizedTeams.join(', '),
      'targetTeams': sendToAllTeams ? <String>[] : normalizedTeams,
      'topics': topics,
      'type': senderRole == AppUserRole.employee
          ? 'employee_message'
          : 'team_message',
      'createdAt': FieldValue.serverTimestamp(),
      'createdAtIst': nowIst,
    };

    final messageRef = await _firestore
        .collection('team_messages')
        .add(message);
    await _firestore.collection('fcm_outbox').doc(messageRef.id).set({
      ...message,
      'messageId': messageRef.id,
      'status': 'pending',
      'delivery': 'cloud_function',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return messageRef.id;
  }

  static String topicForTeam(String team) => _topicForTeam(team);

  Future<String?> routeForNotificationData(Map<String, dynamic> data) async {
    final role = await _authRoleService.currentRole();
    final isAdmin = role == AppUserRole.admin;
    final messageId = data['messageId'] as String?;
    final route = isAdmin ? '/admin-notifications' : '/notifications';
    return messageId == null || messageId.isEmpty
        ? route
        : '$route?messageId=${Uri.encodeComponent(messageId)}&open=1';
  }

  Future<String?> actionRouteForNotificationData(
    Map<String, dynamic> data,
  ) async {
    final user = _auth.currentUser;
    final role = await _authRoleService.currentRole();
    final isAdmin = role == AppUserRole.admin;
    final type = data['type'] as String?;

    if ((isAdmin || user == null) && type == 'leave_request') {
      final employeeId = data['employeeId'] as String?;
      final date = data['date'] as String?;
      if (employeeId != null &&
          employeeId.isNotEmpty &&
          date != null &&
          date.isNotEmpty) {
        final route =
            '/admin-leave-approval?employeeId=${Uri.encodeComponent(employeeId)}&date=${Uri.encodeComponent(date)}';
        if (user == null) _pendingRouteAfterLogin = route;
        return route;
      }
      if (user == null) _pendingRouteAfterLogin = '/admin-leave-requests';
      return '/admin-leave-requests';
    }

    if ((isAdmin || user == null) && type == 'attendance_mark_request') {
      final requestId = data['requestId'] as String?;
      final employeeId = data['employeeId'] as String?;
      final query = <String, String>{
        if (requestId != null && requestId.isNotEmpty) 'requestId': requestId,
        if (employeeId != null && employeeId.isNotEmpty)
          'employeeId': employeeId,
      };
      final route = _routeWithQuery('/admin-mark-attendance', query);
      if (user == null) _pendingRouteAfterLogin = route;
      return route;
    }

    if ((isAdmin || user == null) && type == 'exit_request') {
      final requestId = data['requestId'] as String?;
      final employeeId = data['employeeId'] as String?;
      final query = <String, String>{
        if (requestId != null && requestId.isNotEmpty) 'requestId': requestId,
        if (employeeId != null && employeeId.isNotEmpty)
          'employeeId': employeeId,
      };
      final route = _routeWithQuery('/admin-exit-requests', query);
      if (user == null) _pendingRouteAfterLogin = route;
      return route;
    }

    if (!isAdmin && type == 'leave_response') {
      return '/profile';
    }

    final messageId = data['messageId'] as String?;
    final route = isAdmin ? '/admin-messages' : '/messages';
    return messageId == null || messageId.isEmpty
        ? route
        : '$route?messageId=${Uri.encodeComponent(messageId)}';
  }

  String? consumePendingRouteFor(AppUserRole role) {
    final route = _pendingRouteAfterLogin;
    if (route == null) return null;
    if (route.startsWith('/admin') && role != AppUserRole.admin) {
      _pendingRouteAfterLogin = null;
      return null;
    }
    _pendingRouteAfterLogin = null;
    return route;
  }

  void _openRouteOrStore(String route) {
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) {
      _pendingRouteAfterLogin = route;
      return;
    }

    final currentPath = _currentPath(context);
    if (currentPath == '/startup' || currentPath == '/login') {
      _pendingRouteAfterLogin = route;
      return;
    }

    context.go(route);
  }

  String? _currentPath(BuildContext context) {
    try {
      return GoRouterState.of(context).uri.path;
    } catch (_) {
      return null;
    }
  }

  String _routeWithQuery(String path, Map<String, String> query) {
    if (query.isEmpty) return path;
    final encoded = query.entries
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
        )
        .join('&');
    return '$path?$encoded';
  }

  static String _topicForTeam(String team) {
    final normalized = team
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return normalized.isEmpty ? 'team_all' : 'team_$normalized';
  }

  Future<void> _saveIncomingMessage({
    required String title,
    required String body,
    required Map<String, dynamic> data,
    required String source,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final messageId = data['messageId'] as String?;
    final docRef = messageId == null || messageId.isEmpty
        ? _firestore.collection('notification_inbox').doc()
        : _firestore
              .collection('notification_inbox')
              .doc('${user.uid}_$messageId');
    await docRef.set({
      'uid': user.uid,
      'title': title,
      'body': body,
      'data': data,
      'read': false,
      'source': source,
      'receivedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _saveIncomingMessageBestEffort({
    required String title,
    required String body,
    required Map<String, dynamic> data,
    required String source,
  }) async {
    try {
      await _saveIncomingMessage(
        title: title,
        body: body,
        data: data,
        source: source,
      );
    } catch (_) {
      // Notification taps should still navigate when the optional inbox write
      // is unavailable during app startup.
    }
  }

  String _titleFor(RemoteMessage message) {
    return message.notification?.title ??
        message.data['title'] as String? ??
        'attendance';
  }

  String _bodyFor(RemoteMessage message) {
    return message.notification?.body ?? message.data['body'] as String? ?? '';
  }
}

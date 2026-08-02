import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_telemetry_service.dart';

class OfflineQueueOutcome {
  const OfflineQueueOutcome({required this.queued, required this.message});

  final bool queued;
  final String message;
}

class AppResilienceService {
  AppResilienceService._();

  static final AppResilienceService instance = AppResilienceService._();

  static const _pendingWritesKey = 'app_resilience_pending_writes';
  static const _errorLogKey = 'app_resilience_error_log';
  static const _maxErrorLogEntries = 25;

  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<List<Map<String, dynamic>>> pendingWrites() async {
    await initialize();
    final raw = _prefs!.getStringList(_pendingWritesKey) ?? <String>[];
    return raw
        .map((entry) => jsonDecode(entry) as Map<String, dynamic>)
        .toList();
  }

  Future<void> enqueuePendingWrite(
    String operation,
    Map<String, dynamic> payload,
  ) async {
    await initialize();
    final current = await pendingWrites();
    final normalized = <String, dynamic>{
      ...payload,
      'operation': operation,
      'enqueuedAt': DateTime.now().toUtc().toIso8601String(),
    };

    final existingIndex = current.indexWhere((item) {
      final itemOperation = item['operation'];
      final itemUid = item['uid'];
      return itemOperation == operation &&
          itemUid != null &&
          itemUid == normalized['uid'];
    });

    if (existingIndex >= 0) {
      current[existingIndex] = normalized;
    } else {
      current.add(normalized);
    }

    await _prefs!.setStringList(
      _pendingWritesKey,
      current.map((entry) => jsonEncode(entry)).toList(),
    );
  }

  Future<List<Map<String, dynamic>>> dequeuePendingWrites() async {
    await initialize();
    final pending = await pendingWrites();
    await _prefs!.remove(_pendingWritesKey);
    return pending;
  }

  Future<void> clear() async {
    await initialize();
    await _prefs!.remove(_pendingWritesKey);
    await _prefs!.remove(_errorLogKey);
  }

  Future<OfflineQueueOutcome> executeWithOfflineQueue({
    required String operation,
    required Map<String, dynamic> payload,
    required Future<void> Function() action,
    Future<bool> Function()? onlineCheck,
  }) async {
    await initialize();
    final isReachable = await (onlineCheck != null
        ? onlineCheck.call()
        : isOnlineStatus());
    if (!isReachable) {
      await enqueuePendingWrite(operation, payload);
      return const OfflineQueueOutcome(
        queued: true,
        message: 'Saved locally and will sync once you are back online.',
      );
    }

    try {
      await action();
      return const OfflineQueueOutcome(queued: false, message: 'Saved');
    } catch (error, stackTrace) {
      if (_shouldQueueWrite(error)) {
        await enqueuePendingWrite(operation, payload);
        await recordError(
          error.toString(),
          context: operation,
          details: {
            'payload': payload,
            'stackTrace': stackTrace.toString(),
          },
        );
        await AppTelemetryService.instance.captureException(
          error,
          stackTrace: stackTrace,
          context: operation,
          extra: {'queued': true, 'operation': operation},
        );
        return const OfflineQueueOutcome(
          queued: true,
          message: 'Saved locally and will sync once you are back online.',
        );
      }
      rethrow;
    }
  }

  Future<T> executeWithRetry<T>({
    required Future<T> Function() action,
    int attempts = 3,
    Duration delay = const Duration(milliseconds: 400),
  }) async {
    var attempt = 0;
    while (true) {
      try {
        return await action();
      } catch (error) {
        attempt += 1;
        if (attempt >= attempts || !_shouldRetry(error)) {
          rethrow;
        }
        await Future<void>.delayed(delay * attempt);
      }
    }
  }

  Future<bool> isOnlineStatus() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return !connectivityResult.contains(ConnectivityResult.none);
    } catch (_) {
      return true;
    }
  }

  bool _shouldQueueWrite(Object error) {
    if (error is SocketException) return true;
    if (error is TimeoutException) return true;
    final message = error.toString().toLowerCase();
    return message.contains('network') ||
        message.contains('offline') ||
        message.contains('socket') ||
        message.contains('timed out') ||
        message.contains('connection');
  }

  bool _shouldRetry(Object error) {
    if (error is SocketException) return true;
    if (error is TimeoutException) return true;
    final message = error.toString().toLowerCase();
    return message.contains('network') ||
        message.contains('offline') ||
        message.contains('timed out') ||
        message.contains('connection');
  }

  Future<void> recordError(
    String message, {
    String? context,
    Map<String, dynamic>? details,
  }) async {
    await initialize();
    final logEntries = await _errorLogEntries();
    logEntries.add({
      'message': message,
      'context': context ?? 'app',
      'details': details ?? <String, dynamic>{},
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    });

    if (logEntries.length > _maxErrorLogEntries) {
      logEntries.removeRange(0, logEntries.length - _maxErrorLogEntries);
    }

    await _prefs!.setStringList(
      _errorLogKey,
      logEntries.map((entry) => jsonEncode(entry)).toList(),
    );
  }

  Future<List<Map<String, dynamic>>> errorLogEntries() async {
    await initialize();
    return _errorLogEntries();
  }

  Future<List<Map<String, dynamic>>> _errorLogEntries() async {
    final raw = _prefs!.getStringList(_errorLogKey) ?? <String>[];
    return raw
        .map((entry) => jsonDecode(entry) as Map<String, dynamic>)
        .toList();
  }
}

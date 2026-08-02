import 'dart:io';

import 'package:attendance/services/app_resilience_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _resetState() async {
  SharedPreferences.setMockInitialValues({});
  await AppResilienceService.instance.initialize();
  await AppResilienceService.instance.clear();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('persists pending writes across service instances', () async {
    await _resetState();
    SharedPreferences.setMockInitialValues({});

    final first = AppResilienceService.instance;
    await first.initialize();
    await first.enqueuePendingWrite('fcm_registration', {
      'uid': 'user-1',
      'token': 'token-abc',
    });

    final second = AppResilienceService.instance;
    await second.initialize();
    final pending = await second.pendingWrites();

    expect(pending, hasLength(1));
    expect(pending.first['operation'], 'fcm_registration');
    expect(pending.first['uid'], 'user-1');
    expect(pending.first['token'], 'token-abc');
  });

  test('records and returns application error log entries', () async {
    await _resetState();
    SharedPreferences.setMockInitialValues({});

    final service = AppResilienceService.instance;
    await service.initialize();
    await service.recordError(
      'registration failed',
      context: 'fcm_registration',
      details: {'uid': 'user-2'},
    );

    final errors = await service.errorLogEntries();

    expect(errors, hasLength(1));
    expect(errors.first['message'], 'registration failed');
    expect(errors.first['context'], 'fcm_registration');
  });

  test('queues write when offline check fails', () async {
    await _resetState();
    SharedPreferences.setMockInitialValues({});

    final service = AppResilienceService.instance;
    await service.initialize();
    var actionRuns = 0;

    final result = await service.executeWithOfflineQueue(
      operation: 'leave_request',
      payload: {'uid': 'user-3', 'status': 'pending'},
      action: () async {
        actionRuns += 1;
      },
      onlineCheck: () async => false,
    );

    expect(result.queued, isTrue);
    expect(actionRuns, 0);
    expect(await service.pendingWrites(), hasLength(1));
  });

  test('queues write when a transient network exception occurs', () async {
    await _resetState();
    SharedPreferences.setMockInitialValues({});

    final service = AppResilienceService.instance;
    await service.initialize();
    var actionRuns = 0;

    final result = await service.executeWithOfflineQueue(
      operation: 'task_update',
      payload: {'uid': 'user-4', 'status': 'in_progress'},
      action: () async {
        actionRuns += 1;
        throw const SocketException('network down');
      },
      onlineCheck: () async => true,
    );

    expect(result.queued, isTrue);
    expect(actionRuns, 1);
    expect(await service.pendingWrites(), hasLength(1));
  });
}

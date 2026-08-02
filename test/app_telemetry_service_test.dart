import 'package:attendance/services/app_telemetry_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTelemetrySink extends AppTelemetrySink {
  bool initialized = false;
  int exceptionCount = 0;
  int messageCount = 0;

  @override
  Future<void> initialize({required String? dsn, required String environment, required String release}) async {
    initialized = true;
  }

  @override
  Future<void> captureException(
    Object exception, {
    StackTrace? stackTrace,
    String? context,
    Map<String, dynamic>? extra,
  }) async {
    exceptionCount += 1;
  }

  @override
  Future<void> captureMessage(
    String message, {
    String? context,
    Map<String, dynamic>? extra,
  }) async {
    messageCount += 1;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('initializes and reports errors through the configured sink', () async {
    final sink = _FakeTelemetrySink();
    final service = AppTelemetryService(sink: sink);

    await service.initialize(dsn: 'https://test@example.com', environment: 'test', release: 'test-release');
    await service.captureException(StateError('boom'), context: 'auth');
    await service.captureMessage('queueing write', context: 'resilience');

    expect(sink.initialized, isTrue);
    expect(sink.exceptionCount, 1);
    expect(sink.messageCount, 1);
  });

  test('skips initialization when no DSN is supplied', () async {
    final sink = _FakeTelemetrySink();
    final service = AppTelemetryService(sink: sink);

    await service.initialize(dsn: null, environment: 'test', release: 'test-release');

    expect(sink.initialized, isFalse);
  });
}

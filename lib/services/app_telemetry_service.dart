import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

abstract class AppTelemetrySink {
  Future<void> initialize({required String? dsn, required String environment, required String release});

  Future<void> captureException(
    Object exception, {
    StackTrace? stackTrace,
    String? context,
    Map<String, dynamic>? extra,
  });

  Future<void> captureMessage(
    String message, {
    String? context,
    Map<String, dynamic>? extra,
  });
}

class SentryTelemetrySink implements AppTelemetrySink {
  @override
  Future<void> initialize({required String? dsn, required String environment, required String release}) async {
    if ((dsn ?? '').trim().isEmpty) {
      return;
    }

    await SentryFlutter.init(
      (options) {
        options.dsn = dsn;
        options.environment = environment;
        options.release = release;
        options.enableAutoSessionTracking = false;
        options.enableAppLifecycleBreadcrumbs = true;
      },
      appRunner: () {},
    );
  }

  @override
  Future<void> captureException(
    Object exception, {
    StackTrace? stackTrace,
    String? context,
    Map<String, dynamic>? extra,
  }) async {
    await Sentry.captureException(
      exception,
      stackTrace: stackTrace,
      withScope: (scope) {
        if (context != null && context.isNotEmpty) {
          scope.setExtra('app_flow', {'context': context});
        }
        if (extra != null && extra.isNotEmpty) {
          for (final entry in extra.entries) {
            scope.setTag(entry.key, entry.value?.toString() ?? '');
          }
        }
      },
    );
  }

  @override
  Future<void> captureMessage(
    String message, {
    String? context,
    Map<String, dynamic>? extra,
  }) async {
    await Sentry.captureMessage(
      message,
      withScope: (scope) {
        if (context != null && context.isNotEmpty) {
          scope.setExtra('app_flow', {'context': context});
        }
        if (extra != null && extra.isNotEmpty) {
          for (final entry in extra.entries) {
            scope.setTag(entry.key, entry.value?.toString() ?? '');
          }
        }
      },
    );
  }
}

class AppTelemetryService {
  AppTelemetryService({AppTelemetrySink? sink}) : _sink = sink ?? SentryTelemetrySink();

  static final AppTelemetryService instance = AppTelemetryService();

  final AppTelemetrySink _sink;
  bool _initialized = false;

  Future<void> initialize({required String? dsn, required String environment, required String release}) async {
    if (_initialized) {
      return;
    }
    if ((dsn ?? '').trim().isEmpty) {
      return;
    }

    await _sink.initialize(dsn: dsn, environment: environment, release: release);
    _initialized = true;
  }

  Future<void> captureException(
    Object exception, {
    StackTrace? stackTrace,
    String? context,
    Map<String, dynamic>? extra,
  }) async {
    if (!_initialized) {
      await initialize(
        dsn: const String.fromEnvironment('SENTRY_DSN', defaultValue: ''),
        environment: const String.fromEnvironment('APP_ENV', defaultValue: kReleaseMode ? 'production' : 'debug'),
        release: const String.fromEnvironment('APP_RELEASE', defaultValue: 'attendance@1.0.0+1'),
      );
    }
    if (!_initialized) {
      return;
    }
    await _sink.captureException(exception, stackTrace: stackTrace, context: context, extra: extra);
  }

  Future<void> captureMessage(
    String message, {
    String? context,
    Map<String, dynamic>? extra,
  }) async {
    if (!_initialized) {
      await initialize(
        dsn: const String.fromEnvironment('SENTRY_DSN', defaultValue: ''),
        environment: const String.fromEnvironment('APP_ENV', defaultValue: kReleaseMode ? 'production' : 'debug'),
        release: const String.fromEnvironment('APP_RELEASE', defaultValue: 'attendance@1.0.0+1'),
      );
    }
    if (!_initialized) {
      return;
    }
    await _sink.captureMessage(message, context: context, extra: extra);
  }
}

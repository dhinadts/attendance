import 'dart:convert';

import 'package:http/http.dart' as http;

class AttendanceFinalizeApiService {
  AttendanceFinalizeApiService({
    String? baseUrl,
    String? apiKey,
    http.Client? client,
  }) : baseUrl =
           (baseUrl ??
                   const String.fromEnvironment(
                     'ATTENDANCE_API_BASE_URL',
                     defaultValue: 'https://attendance-gk31.onrender.com',
                   ))
               .replaceAll(RegExp(r'/$'), ''),
       apiKey =
           apiKey ??
           const String.fromEnvironment('ATTENDANCE_API_KEY', defaultValue: ''),
       _client = client ?? http.Client();

  final String baseUrl;
  final String apiKey;
  final http.Client _client;

  bool get isConfigured => apiKey.trim().isNotEmpty;

  Future<void> finalizeSession({
    required String attendanceId,
    required String logoutAtIst,
    required String reason,
  }) async {
    if (!isConfigured) return;
    final response = await _client.post(
      Uri.parse('$baseUrl/api/attendance/finalize-session'),
      headers: {'content-type': 'application/json', 'x-api-key': apiKey},
      body: jsonEncode({
        'attendanceId': attendanceId,
        'logoutAtIst': logoutAtIst,
        'reason': reason,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = response.body.isEmpty
          ? 'Attendance finalization failed'
          : response.body;
      throw StateError(body);
    }
  }
}

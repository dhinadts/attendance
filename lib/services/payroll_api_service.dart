import 'dart:convert';

import 'package:http/http.dart' as http;

class PayrollApiService {
  PayrollApiService({String? baseUrl, String? apiKey, http.Client? client})
    : baseUrl =
          (baseUrl ??
                  const String.fromEnvironment(
                    'PAYROLL_API_BASE_URL',
                    defaultValue: 'https://workforce.dhinadts.com/p1',
                  ))
              .replaceAll(RegExp(r'/$'), ''),
      apiKey =
          apiKey ??
          const String.fromEnvironment('PAYROLL_API_KEY', defaultValue: ''),
      _client = client ?? http.Client();

  final String baseUrl;
  final String apiKey;
  final http.Client _client;

  Future<void> uploadSalaryRecord(Map<String, dynamic> record) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/payroll/upload'),
      headers: {
        'content-type': 'application/json',
        if (apiKey.isNotEmpty) 'x-api-key': apiKey,
      },
      body: jsonEncode(record),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = response.body.isEmpty ? 'Upload failed' : response.body;
      throw StateError(body);
    }
  }
}

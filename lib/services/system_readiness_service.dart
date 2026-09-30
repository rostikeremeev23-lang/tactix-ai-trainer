import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class TactixBuildInfo {
  TactixBuildInfo._();

  static const releaseId = String.fromEnvironment(
    'TACTIX_RELEASE_ID',
    defaultValue: 'dev',
  );
  static const buildChannel = String.fromEnvironment(
    'TACTIX_BUILD_CHANNEL',
    defaultValue: 'development',
  );
}

class SystemReadinessSnapshot {
  final bool ready;
  final DateTime? checkedAt;
  final String release;
  final String environment;
  final Map<String, String> components;
  final Map<String, bool> capabilities;

  const SystemReadinessSnapshot({
    required this.ready,
    required this.checkedAt,
    required this.release,
    required this.environment,
    required this.components,
    required this.capabilities,
  });

  factory SystemReadinessSnapshot.fromJson(Map<String, dynamic> json) {
    final rawComponents = json['components'];
    final rawCapabilities = json['capabilities'];

    final components = <String, String>{};
    if (rawComponents is Map) {
      for (final entry in rawComponents.entries) {
        components[entry.key.toString()] = entry.value.toString();
      }
    }

    final capabilities = <String, bool>{};
    if (rawCapabilities is Map) {
      for (final entry in rawCapabilities.entries) {
        capabilities[entry.key.toString()] = entry.value == true;
      }
    }

    return SystemReadinessSnapshot(
      ready: json['status'] == 'ready',
      checkedAt: DateTime.tryParse(json['checked_at']?.toString() ?? ''),
      release: json['release']?.toString() ?? 'unknown',
      environment: json['environment']?.toString() ?? 'unknown',
      components: components,
      capabilities: capabilities,
    );
  }
}

class SystemReadinessService {
  SystemReadinessService._();

  static Future<SystemReadinessSnapshot> fetch({
    http.Client? client,
    String? baseUrl,
  }) async {
    final httpClient = client ?? http.Client();
    final ownsClient = client == null;
    final root = (baseUrl ?? AuthApiConfig.baseUrl).replaceAll(RegExp(r'/+$'), '');

    try {
      final response = await httpClient
          .get(Uri.parse('$root/ready'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200 && response.statusCode != 503) {
        throw StateError('Backend readiness HTTP ${response.statusCode}');
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Некорректный ответ диагностики TACTIX.');
      }
      return SystemReadinessSnapshot.fromJson(decoded);
    } finally {
      if (ownsClient) httpClient.close();
    }
  }
}

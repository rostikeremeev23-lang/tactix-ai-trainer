import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../models/app_user.dart';

enum AuthFailureKind { network, rejected, invalidInput, server, unknown }

class AuthFailure implements Exception {
  final AuthFailureKind kind;
  final String message;
  const AuthFailure(this.kind, this.message);

  bool get invalidSession => kind == AuthFailureKind.rejected;

  @override
  String toString() => message;
}

class AuthTokens {
  final String accessToken;
  final String refreshToken;
  final AppUser user;

  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });
}

class InviteResult {
  final String code;
  final String role;
  final String organizationId;
  final DateTime? expiresAt;
  final int maxUses;

  const InviteResult({
    required this.code,
    required this.role,
    required this.organizationId,
    required this.expiresAt,
    required this.maxUses,
  });
}

abstract interface class AuthClient {
  Future<String?> readRefreshToken();
  Future<void> writeRefreshToken(String token);
  Future<void> clearRefreshToken();
  Future<AuthTokens> login(String email, String password);
  Future<AuthTokens> register({
    required String email,
    required String password,
    required String firstName,
    required String callsign,
    required String inviteCode,
  });
  Future<AuthTokens> refresh(String refreshToken);
  Future<AppUser> me(String accessToken);
  Future<void> logout(String refreshToken);

  Future<InviteResult> createInvite({
    required String accessToken,
    required String role,
    int maxUses = 1,
    int? expiresInDays = 30,
  });
}

abstract interface class RefreshTokenStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}

class SecureRefreshTokenStore implements RefreshTokenStore {
  static const _key = 'tactix_refresh_token';
  final FlutterSecureStorage _storage;

  SecureRefreshTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);

  @override
  Future<void> delete() => _storage.delete(key: _key);
}

class AuthApiConfig {
  AuthApiConfig._();

  static const _configuredUrl = String.fromEnvironment('TACTIX_API_URL');

  static String get baseUrl {
    final configured = _configuredUrl.trim();
    if (configured.isNotEmpty) return _trim(configured);

    if (kIsWeb) return 'http://127.0.0.1:8000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  static String _trim(String value) {
    var result = value.trim();
    while (result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }
}

class AuthService implements AuthClient {
  final http.Client _client;
  final RefreshTokenStore _tokens;
  final String _baseUrl;
  static const _timeout = Duration(seconds: 12);

  AuthService({
    http.Client? client,
    RefreshTokenStore? tokenStore,
    String? baseUrl,
  }) : _client = client ?? http.Client(),
       _tokens = tokenStore ?? SecureRefreshTokenStore(),
       _baseUrl = AuthApiConfig._trim(baseUrl ?? AuthApiConfig.baseUrl);

  @override
  Future<String?> readRefreshToken() => _tokens.read();

  @override
  Future<void> writeRefreshToken(String token) => _tokens.write(token);

  @override
  Future<void> clearRefreshToken() => _tokens.delete();

  @override
  Future<AuthTokens> login(String email, String password) async {
    final json = await _post('/v1/auth/login', {
      'email': email,
      'password': password,
    });
    return _parseTokens(json);
  }

  @override
  Future<AuthTokens> register({
    required String email,
    required String password,
    required String firstName,
    required String callsign,
    required String inviteCode,
  }) async {
    final json = await _post('/v1/auth/register', {
      'email': email,
      'password': password,
      'first_name': firstName,
      'callsign': callsign,
      'invite_code': inviteCode,
    });
    return _parseTokens(json);
  }

  @override
  Future<AuthTokens> refresh(String refreshToken) async {
    final json = await _post('/v1/auth/refresh', {
      'refresh_token': refreshToken,
    });
    return _parseTokens(json);
  }

  @override
  Future<AppUser> me(String accessToken) async {
    final json = await _request(
      'GET',
      '/v1/auth/me',
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    return _serverUser(json);
  }

  @override
  Future<void> logout(String refreshToken) async {
    await _request(
      'POST',
      '/v1/auth/logout',
      body: {'refresh_token': refreshToken},
      accepted: const {200, 204},
    );
  }

  @override
  Future<InviteResult> createInvite({
    required String accessToken,
    required String role,
    int maxUses = 1,
    int? expiresInDays = 30,
  }) async {
    final json = await _request(
      'POST',
      '/v1/invites',
      headers: {'Authorization': 'Bearer $accessToken'},
      body: {
        'role': role,
        'max_uses': maxUses,
        'expires_in_days': expiresInDays,
      },
    );

    final code = json['code'];
    final inviteRole = json['role'];
    final organizationId = json['organization_id'];
    final maxUsesValue = json['max_uses'];
    final expiresAtValue = json['expires_at'];

    if (code is! String ||
        inviteRole is! String ||
        organizationId is! String ||
        maxUsesValue is! int) {
      throw const AuthFailure(
        AuthFailureKind.server,
        'Сервер вернул некорректные данные приглашения.',
      );
    }

    DateTime? expiresAt;
    if (expiresAtValue is String && expiresAtValue.isNotEmpty) {
      expiresAt = DateTime.tryParse(expiresAtValue);
    }

    return InviteResult(
      code: code,
      role: inviteRole,
      organizationId: organizationId,
      expiresAt: expiresAt,
      maxUses: maxUsesValue,
    );
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) =>
      _request('POST', path, body: body);

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, String> headers = const {},
    Map<String, dynamic>? body,
    Set<int> accepted = const {200, 201},
  }) async {
    http.Response response;
    try {
      final uri = Uri.parse('$_baseUrl$path');
      final requestHeaders = {
        'Accept': 'application/json',
        'Content-Type': 'application/json; charset=utf-8',
        ...headers,
      };
      final future = switch (method) {
        'GET' => _client.get(uri, headers: requestHeaders),
        'POST' => _client.post(
          uri,
          headers: requestHeaders,
          body: jsonEncode(body),
        ),
        _ => throw StateError('Unsupported auth method'),
      };
      response = await future.timeout(_timeout);
    } on TimeoutException {
      throw const AuthFailure(
        AuthFailureKind.network,
        'Сервер недоступен. Проверьте подключение.',
      );
    } on SocketException {
      throw const AuthFailure(
        AuthFailureKind.network,
        'Сервер недоступен. Проверьте подключение.',
      );
    } on http.ClientException {
      throw const AuthFailure(
        AuthFailureKind.network,
        'Сервер недоступен. Проверьте подключение.',
      );
    } on FormatException {
      throw const AuthFailure(
        AuthFailureKind.server,
        'Сервер вернул некорректный ответ.',
      );
    }

    if (!accepted.contains(response.statusCode)) {
      throw _failure(response);
    }
    if (response.statusCode == 204 || response.bodyBytes.isEmpty) {
      return const {};
    }
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // Converted below to a concise user-facing error.
    }
    throw const AuthFailure(
      AuthFailureKind.server,
      'Сервер вернул некорректный ответ.',
    );
  }

  AuthFailure _failure(http.Response response) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      return const AuthFailure(
        AuthFailureKind.rejected,
        'Неверные учётные данные',
      );
    }
    if (response.statusCode == 400 ||
        response.statusCode == 409 ||
        response.statusCode == 422) {
      String message = 'Проверьте данные регистрации.';
      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map && decoded['detail'] is String) {
          final detail = (decoded['detail'] as String).trim();
          if (detail.isNotEmpty && detail.length < 200) message = detail;
        }
      } catch (_) {
        // Do not expose raw response content.
      }
      return AuthFailure(AuthFailureKind.invalidInput, message);
    }
    if (response.statusCode >= 500) {
      return const AuthFailure(
        AuthFailureKind.network,
        'Сервер временно недоступен.',
      );
    }
    return const AuthFailure(
      AuthFailureKind.unknown,
      'Не удалось выполнить запрос.',
    );
  }

  AuthTokens _parseTokens(Map<String, dynamic> json) {
    final access = json['access_token'];
    final refresh = json['refresh_token'];
    if (access is! String || refresh is! String || json['user'] is! Map) {
      throw const AuthFailure(
        AuthFailureKind.server,
        'Сервер вернул неполные данные авторизации.',
      );
    }
    return AuthTokens(
      accessToken: access,
      refreshToken: refresh,
      user: _serverUser(Map<String, dynamic>.from(json['user'] as Map)),
    );
  }

  AppUser _serverUser(Map<String, dynamic> json) {
    try {
      return AppUser.fromServer(json);
    } on Object {
      throw const AuthFailure(
        AuthFailureKind.server,
        'Сервер вернул некорректный профиль.',
      );
    }
  }

  void dispose() => _client.close();
}

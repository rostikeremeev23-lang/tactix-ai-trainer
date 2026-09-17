import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class EnvironmentData {
  final double temperature;
  final int humidity;
  final double windKmh;
  final int visibilityMeters;
  final int weatherCode;
  final bool isDay;
  final DateTime updatedAt;

  const EnvironmentData({
    required this.temperature,
    required this.humidity,
    required this.windKmh,
    required this.visibilityMeters,
    required this.weatherCode,
    required this.isDay,
    required this.updatedAt,
  });

  String get weatherLabel {
    if (weatherCode == 0) {
      return isDay ? 'ЯСНО' : 'ЯСНАЯ НОЧЬ';
    }

    if ([1, 2, 3].contains(weatherCode)) {
      return 'ОБЛАЧНО';
    }

    if ([45, 48].contains(weatherCode)) {
      return 'ТУМАН';
    }

    if ([51, 53, 55, 56, 57].contains(weatherCode)) {
      return 'МОРОСЬ';
    }

    if ([61, 63, 65, 66, 67, 80, 81, 82].contains(weatherCode)) {
      return 'ОСАДКИ';
    }

    if ([71, 73, 75, 77, 85, 86].contains(weatherCode)) {
      return 'СНЕГ';
    }

    if ([95, 96, 99].contains(weatherCode)) {
      return 'ГРОЗА';
    }

    return 'ПЕРЕМЕННАЯ ОБЛАЧНОСТЬ';
  }

  String get visibilityLabel {
    if (visibilityMeters >= 10000) {
      return 'HIGH';
    }

    if (visibilityMeters >= 5000) {
      return 'GOOD';
    }

    if (visibilityMeters >= 2000) {
      return 'LIMITED';
    }

    return 'LOW';
  }

  Map<String, dynamic> toJson() {
    return {
      'temperature': temperature,
      'humidity': humidity,
      'windKmh': windKmh,
      'visibilityMeters': visibilityMeters,
      'weatherCode': weatherCode,
      'isDay': isDay,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory EnvironmentData.fromJson(Map<String, dynamic> json) {
    return EnvironmentData(
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0,
      humidity: (json['humidity'] as num?)?.round() ?? 0,
      windKmh: (json['windKmh'] as num?)?.toDouble() ?? 0,
      visibilityMeters: (json['visibilityMeters'] as num?)?.round() ?? 10000,
      weatherCode: (json['weatherCode'] as num?)?.round() ?? 0,
      isDay: json['isDay'] as bool? ?? true,
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class EnvironmentService {
  EnvironmentService._();

  static const double latitude = 51.1694;
  static const double longitude = 71.4491;

  static const String zoneName = 'TRAINING ZONE / ASTANA';

  static const String _storageKey = 'tactix_environment_cache';

  static EnvironmentData? lastData;

  /// Основной метод для интерфейса.
  ///
  /// Никогда не требует интернет.
  /// Сначала возвращает последние сохранённые данные.
  /// Если их нет — локальный безопасный профиль среды.
  static Future<EnvironmentData> fetch() async {
    if (lastData != null) {
      return lastData!;
    }

    final cached = await loadCached();

    if (cached != null) {
      lastData = cached;
      return cached;
    }

    final fallback = offlineFallback();

    lastData = fallback;

    return fallback;
  }

  /// Вызывается только когда пользователь сам нажал SYNC.
  ///
  /// Если интернет есть — обновляет данные и сохраняет их.
  /// Если сети нет — возвращает имеющиеся локальные данные.
  static Future<EnvironmentData> syncRemote() async {
    try {
      final remote = await _fetchRemote();

      lastData = remote;

      await _saveCached(remote);

      return remote;
    } catch (_) {
      return fetch();
    }
  }

  static Future<EnvironmentData?> loadCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final raw = prefs.getString(_storageKey);

      if (raw == null || raw.isEmpty) {
        return null;
      }

      final decoded = jsonDecode(raw);

      if (decoded is! Map) {
        return null;
      }

      return EnvironmentData.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  static Future<void> _saveCached(EnvironmentData value) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(_storageKey, jsonEncode(value.toJson()));
    } catch (_) {
      // Работа приложения не должна зависеть от кэша погоды.
    }
  }

  static EnvironmentData offlineFallback() {
    final now = DateTime.now();

    final hour = now.hour;

    final isDay = hour >= 7 && hour < 20;

    return EnvironmentData(
      temperature: 0,
      humidity: 50,
      windKmh: 0,
      visibilityMeters: 10000,
      weatherCode: 0,
      isDay: isDay,
      updatedAt: now,
    );
  }

  static Future<EnvironmentData> _fetchRemote() async {
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$latitude'
      '&longitude=$longitude'
      '&current=temperature_2m,relative_humidity_2m,wind_speed_10m,visibility,weather_code,is_day'
      '&temperature_unit=celsius'
      '&wind_speed_unit=kmh'
      '&timezone=auto',
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      throw Exception('Environment HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid environment response');
    }

    final current = decoded['current'];

    if (current is! Map<String, dynamic>) {
      throw Exception('Current environment data missing');
    }

    final timeValue = current['time']?.toString();

    final updated = DateTime.tryParse(timeValue ?? '') ?? DateTime.now();

    return EnvironmentData(
      temperature: (current['temperature_2m'] as num?)?.toDouble() ?? 0,
      humidity: (current['relative_humidity_2m'] as num?)?.round() ?? 0,
      windKmh: (current['wind_speed_10m'] as num?)?.toDouble() ?? 0,
      visibilityMeters: (current['visibility'] as num?)?.round() ?? 10000,
      weatherCode: (current['weather_code'] as num?)?.round() ?? 0,
      isDay: ((current['is_day'] as num?)?.round() ?? 1) == 1,
      updatedAt: updated,
    );
  }
}

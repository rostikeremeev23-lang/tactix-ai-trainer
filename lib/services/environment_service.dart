import 'dart:convert';

import 'package:http/http.dart' as http;

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
      return 'МОРСЯНЬ';
    }

    if ([61, 63, 65, 66, 67, 80, 81, 82]
        .contains(weatherCode)) {
      return 'ОСАДКИ';
    }

    if ([71, 73, 75, 77, 85, 86]
        .contains(weatherCode)) {
      return 'СНЕГ';
    }

    if ([95, 96, 99].contains(weatherCode)) {
      return 'ГРОЗА';
    }

    return 'ПЕРЕМЕННАЯ';
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
}

class EnvironmentService {
  EnvironmentService._();

  static const double latitude = 51.1694;
  static const double longitude = 71.4491;
  static const String zoneName =
      'TRAINING ZONE / ASTANA';

  static EnvironmentData? lastData;

  static Future<EnvironmentData> fetch() async {
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$latitude'
      '&longitude=$longitude'
      '&current=temperature_2m,relative_humidity_2m,wind_speed_10m,visibility,weather_code,is_day'
      '&temperature_unit=celsius'
      '&wind_speed_unit=kmh'
      '&timezone=auto',
    );

    final response = await http
        .get(uri)
        .timeout(
          const Duration(
            seconds: 10,
          ),
        );

    if (response.statusCode != 200) {
      throw Exception(
        'Environment HTTP ${response.statusCode}',
      );
    }

    final decoded =
        jsonDecode(response.body);

    if (decoded
        is! Map<String, dynamic>) {
      throw Exception(
        'Invalid environment response',
      );
    }

    final current =
        decoded['current'];

    if (current
        is! Map<String, dynamic>) {
      throw Exception(
        'Current environment data missing',
      );
    }

    final timeValue =
        current['time']?.toString();

    final updated =
        DateTime.tryParse(
              timeValue ?? '',
            ) ??
            DateTime.now();

    final value =
        EnvironmentData(
      temperature:
          (current['temperature_2m'] as num?)
                  ?.toDouble() ??
              0,
      humidity:
          (current['relative_humidity_2m']
                      as num?)
                  ?.round() ??
              0,
      windKmh:
          (current['wind_speed_10m'] as num?)
                  ?.toDouble() ??
              0,
      visibilityMeters:
          (current['visibility'] as num?)
                  ?.round() ??
              0,
      weatherCode:
          (current['weather_code'] as num?)
                  ?.round() ??
              -1,
      isDay:
          ((current['is_day'] as num?)
                      ?.round() ??
                  1) ==
              1,
      updatedAt: updated,
    );

    lastData = value;

    return value;
  }
}


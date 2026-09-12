import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';

class UserStorageService {
  UserStorageService._();

  static const String _currentUserKey =
      'tactix_current_user';

  static const String _usersKey =
      'tactix_users';

  static Future<AppUser?> loadCurrentUser() async {
    final prefs =
        await SharedPreferences.getInstance();

    final raw =
        prefs.getString(_currentUserKey);

    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      return AppUser.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveCurrentUser(
    AppUser user,
  ) async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setString(
      _currentUserKey,
      jsonEncode(user.toJson()),
    );
  }

  static Future<void> clearCurrentUser() async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.remove(_currentUserKey);
  }

  static Future<List<AppUser>> loadUsers() async {
    final prefs =
        await SharedPreferences.getInstance();

    final raw =
        prefs.getString(_usersKey);

    if (raw == null || raw.isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is! List) {
        return const [];
      }

      return decoded
          .whereType<Map>()
          .map(
            (item) => AppUser.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> saveUsers(
    List<AppUser> users,
  ) async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setString(
      _usersKey,
      jsonEncode(
        users
            .map((user) => user.toJson())
            .toList(),
      ),
    );
  }

  static Future<void> upsertUser(
    AppUser user,
  ) async {
    final users =
        (await loadUsers()).toList();

    final index = users.indexWhere(
      (item) => item.id == user.id,
    );

    if (index == -1) {
      users.add(user);
    } else {
      users[index] = user;
    }

    await saveUsers(users);
  }

  static Future<void> deleteUser(
    String userId,
  ) async {
    final users =
        (await loadUsers()).toList();

    users.removeWhere(
      (user) => user.id == userId,
    );

    await saveUsers(users);
  }
}


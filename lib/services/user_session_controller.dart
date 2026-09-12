import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import 'user_storage_service.dart';

class UserSessionController
    extends ChangeNotifier {
  AppUser? _currentUser;
  bool _loading = false;

  AppUser? get currentUser => _currentUser;

  bool get loading => _loading;

  bool get isAuthenticated =>
      _currentUser != null;

  bool get isInstructor =>
      _currentUser?.role ==
      UserRole.instructor;

  bool get isAdmin =>
      _currentUser?.role ==
      UserRole.admin;

  bool get canManageTraining =>
      isInstructor || isAdmin;

  Future<void> load() async {
    _loading = true;
    notifyListeners();

    try {
      _currentUser =
          await UserStorageService
              .loadCurrentUser();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> signIn(
    AppUser user,
  ) async {
    _currentUser = user;

    await UserStorageService
        .upsertUser(user);

    await UserStorageService
        .saveCurrentUser(user);

    notifyListeners();
  }

  Future<void> updateProfile(
    AppUser user,
  ) async {
    _currentUser = user;

    await UserStorageService
        .upsertUser(user);

    await UserStorageService
        .saveCurrentUser(user);

    notifyListeners();
  }

  Future<void> signOut() async {
    _currentUser = null;

    await UserStorageService
        .clearCurrentUser();

    notifyListeners();
  }
}


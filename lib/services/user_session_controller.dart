import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import 'auth_service.dart';
import 'user_storage_service.dart';

enum AuthSessionState {
  unauthenticated,
  authenticatedOnline,
  cachedOffline,
  localDemo,
}

abstract interface class CurrentUserStore {
  Future<AppUser?> loadCurrentUser();
  Future<void> saveCurrentUser(AppUser user);
  Future<void> clearCurrentUser();
  Future<void> upsertUser(AppUser user);
}

class LocalCurrentUserStore implements CurrentUserStore {
  const LocalCurrentUserStore();

  @override
  Future<AppUser?> loadCurrentUser() => UserStorageService.loadCurrentUser();

  @override
  Future<void> saveCurrentUser(AppUser user) =>
      UserStorageService.saveCurrentUser(user);

  @override
  Future<void> clearCurrentUser() => UserStorageService.clearCurrentUser();

  @override
  Future<void> upsertUser(AppUser user) => UserStorageService.upsertUser(user);
}

class UserSessionController extends ChangeNotifier {
  final AuthClient _auth;
  final CurrentUserStore _users;

  AppUser? _currentUser;
  String? _accessToken;
  AuthSessionState _state = AuthSessionState.unauthenticated;
  bool _loading = false;

  UserSessionController({AuthClient? authClient, CurrentUserStore? userStore})
    : _auth = authClient ?? AuthService(),
      _users = userStore ?? const LocalCurrentUserStore();

  AppUser? get currentUser => _currentUser;
  String? get accessToken => _accessToken;
  AuthSessionState get state => _state;
  bool get loading => _loading;
  bool get isAuthenticated => _state != AuthSessionState.unauthenticated;
  bool get isOnline => _state == AuthSessionState.authenticatedOnline;
  bool get isOffline => _state == AuthSessionState.cachedOffline;
  bool get isServerUser => _currentUser?.serverId != null;
  bool get isInstructor => _currentUser?.role == UserRole.instructor;
  bool get isAdmin => _currentUser?.role == UserRole.admin;
  bool get canManageTraining => isInstructor || isAdmin;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    AppUser? cached;
    try {
      cached = await _users.loadCurrentUser();
      final refreshToken = await _auth.readRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        if (_isConfirmedServerProfile(cached)) {
          _setUser(cached!, AuthSessionState.cachedOffline);
        } else if (cached != null && cached.serverId == null) {
          _setUser(cached, AuthSessionState.localDemo);
        } else {
          _setUser(null, AuthSessionState.unauthenticated);
        }
        return;
      }

      final tokens = await _auth.refresh(refreshToken);
      await _auth.writeRefreshToken(tokens.refreshToken);
      _accessToken = tokens.accessToken;

      AppUser profile;
      try {
        profile = await _auth.me(tokens.accessToken);
      } on AuthFailure catch (error) {
        if (error.invalidSession) rethrow;
        profile = tokens.user;
      }

      await _persistServerUser(profile, AuthSessionState.authenticatedOnline);
    } on AuthFailure catch (error) {
      if (error.invalidSession) {
        await _invalidateServerSession();
      } else if (_isConfirmedServerProfile(cached)) {
        _accessToken = null;
        _setUser(cached!, AuthSessionState.cachedOffline);
      } else if (cached != null && cached.serverId == null) {
        _setUser(cached, AuthSessionState.localDemo);
      } else {
        _setUser(null, AuthSessionState.unauthenticated);
      }
    } catch (_) {
      if (_isConfirmedServerProfile(cached)) {
        _accessToken = null;
        _setUser(cached!, AuthSessionState.cachedOffline);
      } else if (cached != null && cached.serverId == null) {
        _setUser(cached, AuthSessionState.localDemo);
      } else {
        _setUser(null, AuthSessionState.unauthenticated);
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    _loading = true;
    notifyListeners();
    try {
      final tokens = await _auth.login(email.trim(), password);
      await _auth.writeRefreshToken(tokens.refreshToken);
      _accessToken = tokens.accessToken;
      var profile = tokens.user;
      try {
        profile = await _auth.me(tokens.accessToken);
      } on AuthFailure catch (error) {
        if (error.invalidSession) rethrow;
      }
      await _persistServerUser(profile, AuthSessionState.authenticatedOnline);
    } catch (_) {
      await _discardAuthTokens();
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String firstName,
    required String callsign,
    required String inviteCode,
  }) async {
    _loading = true;
    notifyListeners();
    try {
      final tokens = await _auth.register(
        email: email.trim(),
        password: password,
        firstName: firstName.trim(),
        callsign: callsign.trim(),
        inviteCode: inviteCode.trim(),
      );
      await _auth.writeRefreshToken(tokens.refreshToken);
      _accessToken = tokens.accessToken;
      var profile = tokens.user;
      try {
        profile = await _auth.me(tokens.accessToken);
      } on AuthFailure catch (error) {
        if (error.invalidSession) rethrow;
      }
      await _persistServerUser(profile, AuthSessionState.authenticatedOnline);
    } catch (_) {
      await _discardAuthTokens();
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<InviteResult> createInvite({
    required String role,
    int maxUses = 1,
    int? expiresInDays = 30,
  }) async {
    if (!canManageTraining) {
      throw const AuthFailure(
        AuthFailureKind.rejected,
        'Недостаточно прав для создания приглашений.',
      );
    }

    if (role != 'trainee' && role != 'instructor') {
      throw const AuthFailure(
        AuthFailureKind.invalidInput,
        'Некорректная роль приглашения.',
      );
    }

    if (isInstructor && role != 'trainee') {
      throw const AuthFailure(
        AuthFailureKind.rejected,
        'Инструктор может приглашать только обучаемых.',
      );
    }

    final token = _accessToken;
    if (token == null ||
        token.isEmpty ||
        _state != AuthSessionState.authenticatedOnline) {
      throw const AuthFailure(
        AuthFailureKind.network,
        'Для создания приглашения требуется подключение к серверу.',
      );
    }

    return _auth.createInvite(
      accessToken: token,
      role: role,
      maxUses: maxUses,
      expiresInDays: expiresInDays,
    );
  }

  Future<void> _persistServerUser(
    AppUser profile,
    AuthSessionState state,
  ) async {
    if (profile.serverId == null || profile.serverRole == null) {
      throw const AuthFailure(
        AuthFailureKind.server,
        'Данные профиля с сервера неполны.',
      );
    }
    await _users.upsertUser(profile);
    await _users.saveCurrentUser(profile);
    _setUser(profile, state);
  }

  bool _isConfirmedServerProfile(AppUser? user) =>
      user?.serverId != null && user?.serverRole != null;

  void _setUser(AppUser? user, AuthSessionState state) {
    _currentUser = user;
    _state = state;
    if (user == null) _accessToken = null;
    notifyListeners();
  }

  Future<void> _discardAuthTokens() async {
    _accessToken = null;
    try {
      await _auth.clearRefreshToken();
    } catch (_) {}
  }

  Future<void> _invalidateServerSession() async {
    await _discardAuthTokens();
    try {
      await _users.clearCurrentUser();
    } catch (_) {}
    _setUser(null, AuthSessionState.unauthenticated);
  }

  Future<void> signIn(AppUser user) async {
    if (user.serverId != null ||
        _state == AuthSessionState.authenticatedOnline ||
        _state == AuthSessionState.cachedOffline) {
      throw StateError('Sign out before switching to a local profile.');
    }
    await _users.upsertUser(user);
    await _users.saveCurrentUser(user);
    _setUser(user, AuthSessionState.localDemo);
  }

  Future<void> updateProfile(AppUser user) async {
    if (isServerUser && user.serverId != _currentUser?.serverId) {
      throw StateError(
        'A server profile cannot be replaced by a local profile.',
      );
    }
    await _users.upsertUser(user);
    await _users.saveCurrentUser(user);
    _setUser(user, _state);
  }

  Future<void> signOut() async {
    String? refreshToken;
    try {
      refreshToken = await _auth.readRefreshToken();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _auth.logout(refreshToken);
      }
    } catch (_) {
      // Local credentials must still be removed when the backend is offline.
    } finally {
      _accessToken = null;
      try {
        await _auth.clearRefreshToken();
      } catch (_) {}
      try {
        await _users.clearCurrentUser();
      } catch (_) {}
      _setUser(null, AuthSessionState.unauthenticated);
    }
  }
}

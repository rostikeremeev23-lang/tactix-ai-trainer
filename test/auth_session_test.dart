import 'package:flutter_test/flutter_test.dart';
import 'package:ai_trainer_mobile/models/app_user.dart';
import 'package:ai_trainer_mobile/services/auth_service.dart';
import 'package:ai_trainer_mobile/services/user_session_controller.dart';

void main() {
  final serverUser = AppUser.fromServer({
    'id': 'server-user-1',
    'email': 'instructor@example.test',
    'first_name': 'Alex',
    'callsign': 'ECHO',
    'role': 'instructor',
  });

  test('legacy AppUser JSON remains readable', () {
    final user = AppUser.fromJson({
      'id': 'local-1',
      'callsign': 'ALPHA',
      'fullName': 'Alex',
      'role': 'trainee',
      'createdAt': '2025-01-01T00:00:00.000',
    });
    expect(user.serverId, isNull);
    expect(user.serverRole, isNull);
    expect(user.role, UserRole.trainee);
  });

  test('saved local profile remains available as local demo', () async {
    final local = AppUser(
      id: 'local-demo',
      callsign: 'ALPHA',
      fullName: 'Alex',
      role: UserRole.instructor,
      createdAt: DateTime(2025),
    );
    final controller = UserSessionController(
      authClient: _FakeAuth(user: serverUser),
      userStore: _FakeUsers()..current = local,
    );

    await controller.load();

    expect(controller.state, AuthSessionState.localDemo);
    expect(controller.currentUser?.role, UserRole.instructor);
    controller.dispose();
  });

  test('confirmed server role overrides saved manual role', () {
    final user = AppUser.fromJson({
      ...serverUser.toJson(),
      'role': 'trainee',
      'serverRole': 'instructor',
    });
    expect(user.role, UserRole.instructor);
  });

  test('registration persists tokens and server identity', () async {
    final auth = _FakeAuth(user: serverUser);
    final users = _FakeUsers();
    final controller = UserSessionController(
      authClient: auth,
      userStore: users,
    );

    await controller.register(
      email: 'instructor@example.test',
      password: 'long-enough-password',
      firstName: 'Alex',
      callsign: 'ECHO',
      inviteCode: 'TACTIX-INS-TEST',
    );

    expect(auth.registerCalled, isTrue);
    expect(auth.meCalled, isTrue);
    expect(auth.savedRefreshToken, 'refresh-rotated');
    expect(controller.state, AuthSessionState.authenticatedOnline);
    expect(controller.currentUser?.role, UserRole.instructor);
    controller.dispose();
  });

  test('restart rotates refresh token and restores server profile', () async {
    final auth = _FakeAuth(user: serverUser)
      ..storedRefreshToken = 'refresh-old';
    final users = _FakeUsers()..current = serverUser;
    final controller = UserSessionController(
      authClient: auth,
      userStore: users,
    );

    await controller.load();

    expect(auth.refreshCalled, isTrue);
    expect(auth.meCalled, isTrue);
    expect(auth.storedRefreshToken, 'refresh-rotated');
    expect(controller.state, AuthSessionState.authenticatedOnline);
    expect(controller.currentUser?.role, UserRole.instructor);
    controller.dispose();
  });

  test('failed server profile validation removes newly stored token', () async {
    final auth = _FakeAuth(user: serverUser)
      ..meFailure = const AuthFailure(AuthFailureKind.rejected, 'revoked');
    final controller = UserSessionController(
      authClient: auth,
      userStore: _FakeUsers(),
    );

    await expectLater(
      controller.login('instructor@example.test', 'secret'),
      throwsA(isA<AuthFailure>()),
    );

    expect(auth.storedRefreshToken, isNull);
    expect(controller.accessToken, isNull);
    expect(controller.state, AuthSessionState.unauthenticated);
    controller.dispose();
  });

  test(
    'login transitions to authenticated online using server identity',
    () async {
      final auth = _FakeAuth(user: serverUser);
      final users = _FakeUsers();
      final controller = UserSessionController(
        authClient: auth,
        userStore: users,
      );

      await controller.login('instructor@example.test', 'secret');

      expect(controller.state, AuthSessionState.authenticatedOnline);
      expect(controller.currentUser?.role, UserRole.instructor);
      expect(controller.accessToken, 'access');
      expect(auth.savedRefreshToken, 'refresh-rotated');
      controller.dispose();
    },
  );

  test('cached server profile allows offline session when refresh cannot reach server', () async {
    final auth = _FakeAuth(user: serverUser)
      ..storedRefreshToken = 'refresh-old'
      ..refreshFailure = const AuthFailure(AuthFailureKind.network, 'offline');
    final users = _FakeUsers()..current = serverUser;
    final controller = UserSessionController(
      authClient: auth,
      userStore: users,
    );

    await controller.load();

    expect(controller.state, AuthSessionState.cachedOffline);
    expect(controller.currentUser?.serverId, 'server-user-1');
    expect(controller.accessToken, isNull);
    controller.dispose();
  });

  test('rejected refresh clears server session and cached profile', () async {
    final auth = _FakeAuth(user: serverUser)
      ..storedRefreshToken = 'revoked'
      ..refreshFailure = const AuthFailure(AuthFailureKind.rejected, 'denied');
    final users = _FakeUsers()..current = serverUser;
    final controller = UserSessionController(
      authClient: auth,
      userStore: users,
    );

    await controller.load();

    expect(controller.state, AuthSessionState.unauthenticated);
    expect(controller.currentUser, isNull);
    expect(auth.storedRefreshToken, isNull);
    expect(users.current, isNull);
    controller.dispose();
  });

  test(
    'instructor invite permissions and offline guard are enforced',
    () async {
      final auth = _FakeAuth(user: serverUser);
      final controller = UserSessionController(
        authClient: auth,
        userStore: _FakeUsers(),
      );
      await controller.login('instructor@example.test', 'secret');

      final invite = await controller.createInvite(role: 'trainee');
      expect(invite.role, 'trainee');
      expect(auth.inviteCalled, isTrue);
      await expectLater(
        controller.createInvite(role: 'instructor'),
        throwsA(isA<AuthFailure>()),
      );

      final offlineAuth = _FakeAuth(user: serverUser)
        ..storedRefreshToken = 'refresh-old'
        ..refreshFailure = const AuthFailure(
          AuthFailureKind.network,
          'offline',
        );
      final offlineController = UserSessionController(
        authClient: offlineAuth,
        userStore: _FakeUsers()..current = serverUser,
      );
      await offlineController.load();
      await expectLater(
        offlineController.createInvite(role: 'trainee'),
        throwsA(
          isA<AuthFailure>().having(
            (error) => error.kind,
            'kind',
            AuthFailureKind.network,
          ),
        ),
      );

      controller.dispose();
      offlineController.dispose();
    },
  );

  test('logout revokes where possible and clears local auth session', () async {
    final auth = _FakeAuth(user: serverUser)
      ..storedRefreshToken = 'refresh-old';
    final users = _FakeUsers()..current = serverUser;
    final controller = UserSessionController(
      authClient: auth,
      userStore: users,
    );
    await controller.login('instructor@example.test', 'secret');

    await controller.signOut();

    expect(auth.logoutCalled, isTrue);
    expect(auth.storedRefreshToken, isNull);
    expect(controller.accessToken, isNull);
    expect(controller.state, AuthSessionState.unauthenticated);
    expect(users.current, isNull);
    controller.dispose();
  });
}

class _FakeAuth implements AuthClient {
  _FakeAuth({required this.user});
  final AppUser user;
  String? storedRefreshToken;
  String? savedRefreshToken;
  AuthFailure? refreshFailure;
  AuthFailure? meFailure;
  bool registerCalled = false;
  bool refreshCalled = false;
  bool meCalled = false;
  bool inviteCalled = false;
  bool logoutCalled = false;

  @override
  Future<String?> readRefreshToken() async => storedRefreshToken;
  @override
  Future<void> writeRefreshToken(String token) async {
    savedRefreshToken = token;
    storedRefreshToken = token;
  }

  @override
  Future<void> clearRefreshToken() async => storedRefreshToken = null;
  @override
  Future<AuthTokens> login(String email, String password) async => _tokens();
  @override
  Future<AuthTokens> register({
    required String email,
    required String password,
    required String firstName,
    required String callsign,
    required String inviteCode,
  }) async {
    registerCalled = true;
    return _tokens();
  }

  @override
  Future<AuthTokens> refresh(String refreshToken) async {
    refreshCalled = true;
    if (refreshFailure case final failure?) throw failure;
    return _tokens();
  }

  @override
  Future<AppUser> me(String accessToken) async {
    meCalled = true;
    if (meFailure case final failure?) throw failure;
    return user;
  }

  @override
  Future<void> logout(String refreshToken) async => logoutCalled = true;

  @override
  Future<InviteResult> createInvite({
    required String accessToken,
    required String role,
    int maxUses = 1,
    int? expiresInDays = 30,
  }) async {
    inviteCalled = true;
    return InviteResult(
      code: 'TACTIX-TEST-CODE',
      role: role,
      organizationId: 'test-org',
      expiresAt: null,
      maxUses: maxUses,
    );
  }

  AuthTokens _tokens() => AuthTokens(
    accessToken: 'access',
    refreshToken: 'refresh-rotated',
    user: user,
  );
}

class _FakeUsers implements CurrentUserStore {
  AppUser? current;
  final List<AppUser> users = [];
  @override
  Future<AppUser?> loadCurrentUser() async => current;
  @override
  Future<void> saveCurrentUser(AppUser user) async => current = user;
  @override
  Future<void> clearCurrentUser() async => current = null;
  @override
  Future<void> upsertUser(AppUser user) async {
    final index = users.indexWhere((item) => item.id == user.id);
    if (index < 0) {
      users.add(user);
    } else {
      users[index] = user;
    }
  }
}

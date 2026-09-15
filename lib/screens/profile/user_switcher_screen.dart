import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../app/user_session_scope.dart';
import '../../models/app_user.dart';
import '../../services/user_storage_service.dart';

class UserSwitcherScreen extends StatefulWidget {
  const UserSwitcherScreen({
    super.key,
  });

  @override
  State<UserSwitcherScreen> createState() =>
      _UserSwitcherScreenState();
}

class _UserSwitcherScreenState
    extends State<UserSwitcherScreen> {
  List<AppUser> _users = const [];
  bool _loading = true;
  String? _switchingUserId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final storedUsers =
        await UserStorageService.loadUsers();
    final users = storedUsers
        .where((user) => user.serverId == null)
        .toList();

    users.sort(
      (a, b) {
        final roleCompare =
            a.role.index.compareTo(
          b.role.index,
        );

        if (roleCompare != 0) {
          return roleCompare;
        }

        return a.callsign
            .toLowerCase()
            .compareTo(
              b.callsign.toLowerCase(),
            );
      },
    );

    if (!mounted) return;

    setState(() {
      _users = users;
      _loading = false;
    });
  }

  Future<void> _switchTo(
    AppUser user,
  ) async {
    setState(() {
      _switchingUserId = user.id;
    });

    try {
      await UserSessionScope.read(context)
          .signIn(user);

      if (!mounted) return;

      Navigator.of(context)
          .popUntil(
        (route) => route.isFirst,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _switchingUserId = null;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Не удалось переключить пользователя: $e',
          ),
        ),
      );
    }
  }

  Color _roleColor(
    UserRole role,
  ) {
    switch (role) {
      case UserRole.trainee:
        return TactixTheme.cyan;
      case UserRole.instructor:
        return TactixTheme.gold;
      case UserRole.admin:
        return const Color(0xFFB18CFF);
    }
  }

  IconData _roleIcon(
    UserRole role,
  ) {
    switch (role) {
      case UserRole.trainee:
        return Icons.person_outline;
      case UserRole.instructor:
        return Icons.school_outlined;
      case UserRole.admin:
        return Icons.admin_panel_settings_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final current =
        UserSessionScope.of(context)
            .currentUser;

    return Scaffold(
      backgroundColor: TactixTheme.bg,
      appBar: AppBar(
        title: const Text(
          'ПЕРЕКЛЮЧИТЬ ПРОФИЛЬ',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed:
                _loading ? null : _load,
            icon: const Icon(
              Icons.sync_rounded,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : _users.isEmpty
              ? const _EmptyState()
              : ListView.separated(
                  padding:
                      const EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    40,
                  ),
                  itemCount: _users.length,
                  separatorBuilder:
                      (_, _) =>
                          const SizedBox(
                    height: 10,
                  ),
                  itemBuilder:
                      (context, index) {
                    final user =
                        _users[index];

                    final isCurrent =
                        current?.id ==
                            user.id;

                    final roleColor =
                        _roleColor(
                      user.role,
                    );

                    final switching =
                        _switchingUserId ==
                            user.id;

                    return Container(
                      padding:
                          const EdgeInsets
                              .all(16),
                      decoration:
                          BoxDecoration(
                        color:
                            TactixTheme.panel,
                        borderRadius:
                            BorderRadius
                                .circular(
                          14,
                        ),
                        border: Border.all(
                          color: isCurrent
                              ? roleColor
                              : TactixTheme
                                  .line,
                          width:
                              isCurrent
                                  ? 1.4
                                  : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration:
                                BoxDecoration(
                              color: roleColor
                                  .withValues(
                                alpha: .1,
                              ),
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                12,
                              ),
                              border:
                                  Border.all(
                                color: roleColor
                                    .withValues(
                                  alpha: .28,
                                ),
                              ),
                            ),
                            child: Icon(
                              _roleIcon(
                                user.role,
                              ),
                              color:
                                  roleColor,
                            ),
                          ),
                          const SizedBox(
                            width: 14,
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child:
                                          Text(
                                        user.callsign,
                                        overflow:
                                            TextOverflow
                                                .ellipsis,
                                        style:
                                            const TextStyle(
                                          fontSize:
                                              16,
                                          fontWeight:
                                              FontWeight
                                                  .w900,
                                        ),
                                      ),
                                    ),
                                    if (isCurrent) ...[
                                      const SizedBox(
                                        width: 8,
                                      ),
                                      Container(
                                        padding:
                                            const EdgeInsets
                                                .symmetric(
                                          horizontal:
                                              7,
                                          vertical:
                                              4,
                                        ),
                                        decoration:
                                            BoxDecoration(
                                          color:
                                              roleColor
                                                  .withValues(
                                            alpha:
                                                .1,
                                          ),
                                          borderRadius:
                                              BorderRadius
                                                  .circular(
                                            7,
                                          ),
                                        ),
                                        child:
                                            Text(
                                          'ТЕКУЩИЙ',
                                          style:
                                              TextStyle(
                                            color:
                                                roleColor,
                                            fontSize:
                                                8,
                                            fontWeight:
                                                FontWeight
                                                    .w900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(
                                  height: 4,
                                ),
                                Text(
                                  user.fullName,
                                  style:
                                      const TextStyle(
                                    color:
                                        Colors.white70,
                                  ),
                                ),
                                const SizedBox(
                                  height: 4,
                                ),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 4,
                                  children: [
                                    Text(
                                      user.role.label,
                                      style:
                                          TextStyle(
                                        color:
                                            roleColor,
                                        fontSize:
                                            10,
                                        fontWeight:
                                            FontWeight
                                                .w900,
                                      ),
                                    ),
                                    if (user.unitName
                                        .isNotEmpty)
                                      Text(
                                        user.unitName,
                                        style:
                                            const TextStyle(
                                          color:
                                              TactixTheme
                                                  .textMuted,
                                          fontSize:
                                              10,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(
                            width: 12,
                          ),
                          FilledButton(
                            onPressed:
                                isCurrent ||
                                        switching
                                    ? null
                                    : () =>
                                        _switchTo(
                                          user,
                                        ),
                            child: switching
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth:
                                          2,
                                    ),
                                  )
                                : Text(
                                    isCurrent
                                        ? 'АКТИВЕН'
                                        : 'ВОЙТИ',
                                    style:
                                        const TextStyle(
                                      fontWeight:
                                          FontWeight
                                              .w900,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

class _EmptyState
    extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline,
              size: 52,
              color:
                  TactixTheme.textMuted,
            ),
            SizedBox(height: 14),
            Text(
              'ПРОФИЛЕЙ ПОКА НЕТ',
              style: TextStyle(
                fontWeight:
                    FontWeight.w900,
                letterSpacing: .8,
              ),
            ),
            SizedBox(height: 7),
            Text(
              'Создайте пользователей в системе, после чего между ними можно будет переключаться для демонстрации полного учебного цикла.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color:
                    TactixTheme.textMuted,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


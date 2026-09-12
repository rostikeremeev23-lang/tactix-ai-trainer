import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../app/user_session_scope.dart';
import '../../models/app_user.dart';
import '../../services/user_storage_service.dart';

class TraineeRosterScreen
    extends StatefulWidget {
  const TraineeRosterScreen({
    super.key,
  });

  @override
  State<TraineeRosterScreen> createState() =>
      _TraineeRosterScreenState();
}

class _TraineeRosterScreenState
    extends State<TraineeRosterScreen> {
  List<AppUser> _users = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final currentUser =
        UserSessionScope.read(context)
            .currentUser;

    final users =
        await UserStorageService.loadUsers();

    if (!mounted) return;

    final filtered = users
        .where(
          (user) =>
              user.id != currentUser?.id &&
              user.role == UserRole.trainee,
        )
        .toList()
      ..sort(
        (a, b) => a.callsign
            .toLowerCase()
            .compareTo(
              b.callsign.toLowerCase(),
            ),
      );

    setState(() {
      _users = filtered;
      _loading = false;
    });
  }

  Future<void> _addTrainee() async {
    final formKey =
        GlobalKey<FormState>();

    String callsign = '';
    String fullName = '';
    String unitName = '';

    final result = await showDialog<AppUser>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'ДОБАВИТЬ ОБУЧАЕМОГО',
          ),
          content: SizedBox(
            width: 440,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  TextFormField(
                    decoration:
                        const InputDecoration(
                      labelText: 'Позывной',
                      prefixIcon: Icon(
                        Icons.badge_outlined,
                      ),
                    ),
                    onChanged: (value) {
                      callsign = value;
                    },
                    validator: (value) {
                      if (value == null ||
                          value.trim().isEmpty) {
                        return 'Введите позывной';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration:
                        const InputDecoration(
                      labelText: 'ФИО',
                      prefixIcon: Icon(
                        Icons.person_outline,
                      ),
                    ),
                    onChanged: (value) {
                      fullName = value;
                    },
                    validator: (value) {
                      if (value == null ||
                          value.trim().isEmpty) {
                        return 'Введите ФИО';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration:
                        const InputDecoration(
                      labelText:
                          'Подразделение',
                      prefixIcon: Icon(
                        Icons.groups_outlined,
                      ),
                    ),
                    onChanged: (value) {
                      unitName = value;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
              ),
              child:
                  const Text('ОТМЕНА'),
            ),
            FilledButton.icon(
              onPressed: () {
                if (!formKey.currentState!
                    .validate()) {
                  return;
                }

                final user = AppUser(
                  id: DateTime.now()
                      .microsecondsSinceEpoch
                      .toString(),
                  callsign:
                      callsign.trim(),
                  fullName:
                      fullName.trim(),
                  unitName:
                      unitName.trim(),
                  role: UserRole.trainee,
                  createdAt:
                      DateTime.now(),
                );

                Navigator.pop(
                  dialogContext,
                  user,
                );
              },
              icon: const Icon(
                Icons.person_add_alt_1,
              ),
              label:
                  const Text('ДОБАВИТЬ'),
            ),
          ],
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    await UserStorageService.upsertUser(
      result,
    );

    if (!mounted) {
      return;
    }

    await _load();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          'Добавлен обучаемый ${result.callsign}',
        ),
      ),
    );
  }

  Future<void> _deleteUser(
    AppUser user,
  ) async {
    final answer =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) =>
          AlertDialog(
        title: const Text(
          'Удалить обучаемого?',
        ),
        content: Text(
          'Удалить ${user.callsign} из локального списка?',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(
              dialogContext,
              false,
            ),
            child:
                const Text('ОТМЕНА'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(
              dialogContext,
              true,
            ),
            child:
                const Text('УДАЛИТЬ'),
          ),
        ],
      ),
    );

    if (answer != true) return;

    await UserStorageService.deleteUser(
      user.id,
    );

    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TactixTheme.bg,
      appBar: AppBar(
        title: const Text(
          'ОБУЧАЕМЫЕ',
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
      floatingActionButton:
          FloatingActionButton.extended(
        onPressed: _addTrainee,
        icon: const Icon(
          Icons.person_add_alt_1,
        ),
        label: const Text(
          'ДОБАВИТЬ',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : _users.isEmpty
              ? const _EmptyRoster()
              : ListView.separated(
                  padding:
                      const EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    100,
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

                    return _TraineeCard(
                      user: user,
                      onDelete: () =>
                          _deleteUser(user),
                    );
                  },
                ),
    );
  }
}

class _TraineeCard
    extends StatelessWidget {
  final AppUser user;
  final VoidCallback onDelete;

  const _TraineeCard({
    required this.user,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TactixTheme.panel,
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color: TactixTheme.line,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: TactixTheme.gold
                  .withValues(
                alpha: .1,
              ),
              borderRadius:
                  BorderRadius.circular(12),
              border: Border.all(
                color: TactixTheme.gold
                    .withValues(
                  alpha: .28,
                ),
              ),
            ),
            child: const Icon(
              Icons.person_outline,
              color: TactixTheme.gold,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  user.callsign,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.fullName,
                  style: const TextStyle(
                    color:
                        Colors.white70,
                  ),
                ),
                if (user.unitName
                    .isNotEmpty) ...[
                  const SizedBox(
                    height: 4,
                  ),
                  Text(
                    user.unitName,
                    style: const TextStyle(
                      color: TactixTheme
                          .textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: TactixTheme.cyan
                  .withValues(
                alpha: .08,
              ),
              borderRadius:
                  BorderRadius.circular(8),
              border: Border.all(
                color: TactixTheme.cyan
                    .withValues(
                  alpha: .25,
                ),
              ),
            ),
            child: const Text(
              'ОБУЧАЕМЫЙ',
              style: TextStyle(
                color: TactixTheme.cyan,
                fontSize: 9,
                fontWeight:
                    FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Удалить',
            onPressed: onDelete,
            icon: const Icon(
              Icons.delete_outline,
              color: Colors.white38,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRoster
    extends StatelessWidget {
  const _EmptyRoster();

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
              Icons.groups_outlined,
              size: 54,
              color:
                  TactixTheme.textMuted,
            ),
            SizedBox(height: 14),
            Text(
              'СПИСОК ПОКА ПУСТ',
              style: TextStyle(
                fontWeight:
                    FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            SizedBox(height: 7),
            Text(
              'Добавьте обучаемого, чтобы инструктор мог назначать ему тренировки.',
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


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
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: .3),
        ),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.sync_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: !_loading && _users.isEmpty
          ? null
          : FloatingActionButton.extended(
        onPressed: _addTrainee,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text(
          'ДОБАВИТЬ',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
          ? _EmptyRoster(onAdd: _addTrainee)
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              itemCount: _users.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final user = _users[index];

                return _TraineeCard(
                  user: user,
                  onDelete: () => _deleteUser(user),
                );
              },
            ),
    );
  }
}

class _TraineeCard extends StatelessWidget {
  final AppUser user;
  final VoidCallback onDelete;

  const _TraineeCard({required this.user, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TactixTheme.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TactixTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            user.callsign,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            user.fullName,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            user.unitName.isEmpty
                ? 'Подразделение не указано'
                : 'Подразделение: ${user.unitName}',
            style: const TextStyle(
              fontSize: 12,
              color: TactixTheme.textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                user.role.label,
                style: const TextStyle(
                  fontSize: 12,
                  color: TactixTheme.cyan,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: TactixTheme.panel2,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: TactixTheme.line),
                ),
                child: Text(
                  user.isActive ? 'Активен' : 'Неактивен',
                  style: TextStyle(
                    fontSize: 12,
                    color: user.isActive
                        ? TactixTheme.cyan
                        : TactixTheme.textMuted,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Удалить'),
                style: TextButton.styleFrom(
                  foregroundColor: TactixTheme.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Последние результаты — в контроле назначений',
            style: TextStyle(
              fontSize: 12,
              color: TactixTheme.textMuted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRoster extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyRoster({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.groups_outlined, size: 64, color: TactixTheme.gold),
              const SizedBox(height: 16),
              const Text(
                'СПИСОК ПОКА ПУСТ',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: .3),
              ),
              const SizedBox(height: 8),
              const Text(
                'Добавьте обучаемого, чтобы инструктор мог назначать ему тренировки.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: TactixTheme.textMuted, height: 1.5),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('ДОБАВИТЬ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../app/user_session_scope.dart';
import '../../services/auth_service.dart';

class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key});

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  final _maxUsesController = TextEditingController(text: '1');
  final _expiresController = TextEditingController(text: '30');

  String _role = 'trainee';
  bool _creating = false;
  InviteResult? _result;
  String? _error;

  @override
  void dispose() {
    _maxUsesController.dispose();
    _expiresController.dispose();
    super.dispose();
  }

  Future<void> _createInvite() async {
    final session = UserSessionScope.of(context);

    final maxUses = int.tryParse(_maxUsesController.text.trim());
    final expiresInDays = int.tryParse(_expiresController.text.trim());

    if (maxUses == null || maxUses < 1 || maxUses > 1000) {
      setState(() {
        _error = 'Количество использований должно быть от 1 до 1000.';
        _result = null;
      });
      return;
    }

    if (expiresInDays == null || expiresInDays < 1 || expiresInDays > 365) {
      setState(() {
        _error = 'Срок действия должен быть от 1 до 365 дней.';
        _result = null;
      });
      return;
    }

    setState(() {
      _creating = true;
      _error = null;
      _result = null;
    });

    try {
      final result = await session.createInvite(
        role: _role,
        maxUses: maxUses,
        expiresInDays: expiresInDays,
      );

      if (!mounted) return;
      setState(() => _result = result);
    } on AuthFailure catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Не удалось создать приглашение.');
    } finally {
      if (mounted) {
        setState(() => _creating = false);
      }
    }
  }

  Future<void> _copyCode() async {
    final code = _result?.code;
    if (code == null || code.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Код приглашения скопирован')));
  }

  String _roleLabel(String role) {
    return switch (role) {
      'instructor' => 'Инструктор',
      _ => 'Обучаемый',
    };
  }

  @override
  Widget build(BuildContext context) {
    final session = UserSessionScope.of(context);
    final canCreateInstructor = session.isAdmin;
    final online = session.isOnline;

    if (!canCreateInstructor && _role == 'instructor') {
      _role = 'trainee';
    }

    return Scaffold(
      backgroundColor: TactixTheme.bg,
      appBar: AppBar(
        backgroundColor: TactixTheme.bg,
        elevation: 0,
        title: const Text(
          'ПРИГЛАШЕНИЯ',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: TactixTheme.panel,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: TactixTheme.line),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        online
                            ? Icons.cloud_done_rounded
                            : Icons.cloud_off_rounded,
                        color: online ? TactixTheme.gold : Colors.white54,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          online
                              ? 'Сервер доступен. Можно создавать новые коды.'
                              : 'Создание приглашений доступно только при подключении к серверу.',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'НОВОЕ ПРИГЛАШЕНИЕ',
                  style: TextStyle(
                    color: TactixTheme.gold,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: TactixTheme.panel,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: TactixTheme.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Роль',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _role,
                        dropdownColor: TactixTheme.panel,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: 'trainee',
                            child: Text('Обучаемый'),
                          ),
                          if (canCreateInstructor)
                            const DropdownMenuItem(
                              value: 'instructor',
                              child: Text('Инструктор'),
                            ),
                        ],
                        onChanged: _creating
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() => _role = value);
                                }
                              },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _maxUsesController,
                        enabled: !_creating,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Количество использований',
                          hintText: '1',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _expiresController,
                        enabled: !_creating,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Срок действия, дней',
                          hintText: '30',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _creating || !online
                              ? null
                              : _createInvite,
                          icon: _creating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.add_link_rounded),
                          label: Text(
                            _creating ? 'Создание...' : 'Создать приглашение',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ],
                if (_result case final result?) ...[
                  const SizedBox(height: 18),
                  Text(
                    'КОД СОЗДАН',
                    style: TextStyle(
                      color: TactixTheme.gold,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: TactixTheme.panel,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: TactixTheme.gold),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(
                          result.code,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            _InfoChip(
                              label: 'Роль',
                              value: _roleLabel(result.role),
                            ),
                            _InfoChip(
                              label: 'Использований',
                              value: '${result.maxUses}',
                            ),
                            _InfoChip(
                              label: 'Действует до',
                              value: result.expiresAt == null
                                  ? 'Без срока'
                                  : result.expiresAt!
                                        .toLocal()
                                        .toString()
                                        .split('.')
                                        .first,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _copyCode,
                          icon: const Icon(Icons.copy_rounded),
                          label: const Text('Скопировать код'),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: TactixTheme.line),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Colors.white70,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

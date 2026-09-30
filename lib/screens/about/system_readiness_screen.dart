import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/auth_service.dart';
import '../../services/system_readiness_service.dart';

typedef SystemReadinessLoader = Future<SystemReadinessSnapshot> Function();

class SystemReadinessScreen extends StatefulWidget {
  final SystemReadinessLoader? loader;

  const SystemReadinessScreen({super.key, this.loader});

  @override
  State<SystemReadinessScreen> createState() => _SystemReadinessScreenState();
}

class _SystemReadinessScreenState extends State<SystemReadinessScreen> {
  SystemReadinessSnapshot? _snapshot;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final loader = widget.loader;
      final value = loader != null
          ? await loader()
          : await SystemReadinessService.fetch();
      if (!mounted) return;
      setState(() => _snapshot = value);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _snapshot = null;
        _error = error;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ГОТОВНОСТЬ СИСТЕМЫ',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
        actions: [
          IconButton(
            tooltip: 'Повторить проверку',
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _SummaryCard(
                  loading: _loading,
                  ready: snapshot?.ready,
                  error: _error,
                ),
                const SizedBox(height: 14),
                _InfoCard(
                  title: 'СБОРКА И ОКРУЖЕНИЕ',
                  rows: [
                    ('Канал сборки', TactixBuildInfo.buildChannel),
                    ('Идентификатор сборки', TactixBuildInfo.releaseId),
                    ('Backend', AuthApiConfig.baseUrl),
                    ('Серверный релиз', snapshot?.release ?? '—'),
                    ('Окружение', snapshot?.environment ?? '—'),
                  ],
                ),
                const SizedBox(height: 14),
                _ComponentsCard(snapshot: snapshot),
                const SizedBox(height: 14),
                _CapabilitiesCard(snapshot: snapshot),
                const SizedBox(height: 14),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.security_outlined, color: TactixTheme.cyan),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Диагностика показывает только состояние компонентов. '
                            'Пароли, токены, ключи ИИ и строка подключения к базе данных '
                            'на этом экране не отображаются.',
                            style: TextStyle(
                              color: TactixTheme.textMuted,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final bool loading;
  final bool? ready;
  final Object? error;

  const _SummaryCard({
    required this.loading,
    required this.ready,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final Color color;
    final IconData icon;
    final String title;
    final String detail;

    if (loading) {
      color = TactixTheme.cyan;
      icon = Icons.sync_rounded;
      title = 'Проверка готовности';
      detail = 'TACTIX проверяет доступность основных компонентов.';
    } else if (error != null) {
      color = TactixTheme.warning;
      icon = Icons.cloud_off_outlined;
      title = 'Backend недоступен';
      detail = 'Не удалось получить состояние сервера. Локальные функции могут оставаться доступными.';
    } else if (ready == true) {
      color = TactixTheme.positive;
      icon = Icons.verified_outlined;
      title = 'Система готова';
      detail = 'База данных и серверная аутентификация готовы к работе.';
    } else {
      color = TactixTheme.warning;
      icon = Icons.warning_amber_rounded;
      title = 'Требуется настройка';
      detail = 'Один или несколько обязательных серверных компонентов не готовы.';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: .4)),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    style: const TextStyle(
                      color: TactixTheme.textMuted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (loading)
              const Padding(
                padding: EdgeInsets.only(left: 12),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<(String, String)> rows;

  const _InfoCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: TactixTheme.gold,
                fontWeight: FontWeight.w900,
                letterSpacing: .8,
              ),
            ),
            const SizedBox(height: 12),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 170,
                      child: Text(
                        row.$1,
                        style: const TextStyle(color: TactixTheme.textMuted),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SelectableText(
                        row.$2,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ComponentsCard extends StatelessWidget {
  final SystemReadinessSnapshot? snapshot;

  const _ComponentsCard({required this.snapshot});

  String _label(String key) => switch (key) {
    'database' => 'База данных',
    'authentication' => 'Аутентификация',
    'ai' => 'ИИ-контур',
    _ => key,
  };

  bool _positive(String value) =>
      value == 'available' || value == 'configured' || value == 'optional_offline';

  String _state(String value) => switch (value) {
    'available' => 'Доступна',
    'configured' => 'Настроено',
    'not_configured' => 'Не настроено',
    'unavailable' => 'Недоступна',
    'optional_offline' => 'Автономный режим доступен',
    _ => value,
  };

  @override
  Widget build(BuildContext context) {
    final components = snapshot?.components ?? const <String, String>{};
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'КОМПОНЕНТЫ',
              style: TextStyle(
                color: TactixTheme.gold,
                fontWeight: FontWeight.w900,
                letterSpacing: .8,
              ),
            ),
            const SizedBox(height: 12),
            if (components.isEmpty)
              const Text(
                'Нет данных сервера.',
                style: TextStyle(color: TactixTheme.textMuted),
              )
            else
              for (final entry in components.entries)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    _positive(entry.value)
                        ? Icons.check_circle_outline
                        : Icons.error_outline,
                    color: _positive(entry.value)
                        ? TactixTheme.positive
                        : TactixTheme.warning,
                  ),
                  title: Text(_label(entry.key)),
                  trailing: Text(
                    _state(entry.value),
                    style: TextStyle(
                      color: _positive(entry.value)
                          ? TactixTheme.positive
                          : TactixTheme.warning,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _CapabilitiesCard extends StatelessWidget {
  final SystemReadinessSnapshot? snapshot;

  const _CapabilitiesCard({required this.snapshot});

  String _label(String key) => switch (key) {
    'digital_thread' => 'Цифровой контур',
    'training' => 'Подготовка',
    'simulation_lab' => 'Центр моделирования',
    'ask_tactix' => 'Анализ TACTIX',
    'branches' => 'Варианты плана',
    'pulse' => 'Контроль процессов',
    _ => key,
  };

  @override
  Widget build(BuildContext context) {
    final capabilities = snapshot?.capabilities ?? const <String, bool>{};
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ВОЗМОЖНОСТИ РЕЛИЗА',
              style: TextStyle(
                color: TactixTheme.gold,
                fontWeight: FontWeight.w900,
                letterSpacing: .8,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in capabilities.entries.where((e) => e.value))
                  Chip(
                    avatar: const Icon(
                      Icons.check_rounded,
                      size: 17,
                      color: TactixTheme.positive,
                    ),
                    label: Text(_label(entry.key)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

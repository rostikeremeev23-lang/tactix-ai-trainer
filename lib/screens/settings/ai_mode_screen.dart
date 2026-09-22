import 'package:flutter/material.dart';

import '../../services/ai_service.dart';

class AIModeScreen extends StatefulWidget {
  const AIModeScreen({super.key});

  @override
  State<AIModeScreen> createState() => _AIModeScreenState();
}

class _AIModeScreenState extends State<AIModeScreen> {
  static const _gold = Color(0xFFE0B64A);
  static const _cyan = Color(0xFF32B9E8);
  static const _bg = Color(0xFF060B10);
  static const _panel = Color(0xFF0D151D);
  static const _panel2 = Color(0xFF111C25);
  static const _line = Color(0xFF233746);

  bool _busy = true;
  bool _online = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await AIService.loadConfig();
    final online = await AIService.refreshStatus();
    if (!mounted) return;
    setState(() {
      _online = online;
      _busy = false;
    });
  }

  Future<void> _select(AIMode mode) async {
    if (_busy) return;
    setState(() => _busy = true);

    await AIService.setMode(mode);
    final online = await AIService.refreshStatus();

    if (!mounted) return;
    setState(() {
      _online = online;
      _busy = false;
    });
  }

  Future<void> _check() async {
    if (_busy) return;
    setState(() => _busy = true);
    final online = await AIService.refreshStatus();
    if (!mounted) return;
    setState(() {
      _online = online;
      _busy = false;
    });
  }

  Future<void> _editLocalUrl() async {
    final controller = TextEditingController(text: AIService.localBaseUrl);

    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _panel,
        title: const Text('LOCAL AI BACKEND'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Адрес FastAPI',
            hintText: 'http://127.0.0.1:8000',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ОТМЕНА'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('СОХРАНИТЬ'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (value == null || value.isEmpty) return;

    try {
      await AIService.setBaseUrl(value);
      await _check();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          'AI MODE',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.1),
        ),
        backgroundColor: _bg,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            _statusPanel(),
            const SizedBox(height: 18),
            const Text(
              'РЕЖИМ РАБОТЫ',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            _modeCard(
              mode: AIMode.auto,
              icon: Icons.auto_awesome_rounded,
              title: 'AUTO',
              subtitle: 'Gemini → Ollama → автономный движок',
              detail: 'Рекомендуемый режим для конкурса.',
            ),
            _modeCard(
              mode: AIMode.cloud,
              icon: Icons.cloud_outlined,
              title: 'CLOUD',
              subtitle: 'Render + Gemini Cloud',
              detail: AIService.cloudBaseUrl,
            ),
            _modeCard(
              mode: AIMode.local,
              icon: Icons.computer_rounded,
              title: 'LOCAL',
              subtitle: 'FastAPI + Ollama + gemma3:1b',
              detail: AIService.localBaseUrl,
            ),
            _modeCard(
              mode: AIMode.offline,
              icon: Icons.offline_bolt_outlined,
              title: 'OFFLINE',
              subtitle: 'Без сервера и без интернета',
              detail: 'TACTIX Score и локальная логика продолжают работать.',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _check,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('ПРОВЕРИТЬ'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _editLocalUrl,
                    icon: const Icon(Icons.link_rounded),
                    label: const Text('LOCAL URL'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusPanel() {
    final active = _online && AIService.activeBackend != AIBackendKind.none;
    final color = active ? _cyan : Colors.white38;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: active ? _cyan.withValues(alpha: .45) : _line),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: _busy
                ? const Padding(
                    padding: EdgeInsets.all(13),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    active ? Icons.bolt_rounded : Icons.power_settings_new_rounded,
                    color: color,
                  ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _busy ? 'ПРОВЕРКА...' : AIService.statusLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Выбрано: ${AIService.modeLabel} • ${AIService.providerLabel}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                if (AIService.activeBaseUrl != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    AIService.activeBaseUrl!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeCard({
    required AIMode mode,
    required IconData icon,
    required String title,
    required String subtitle,
    required String detail,
  }) {
    final selected = AIService.mode == mode;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: _busy ? null : () => _select(mode),
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? _panel2 : _panel,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selected ? _gold : _line,
              width: selected ? 1.3 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: (selected ? _gold : Colors.white38).withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: selected ? _gold : Colors.white54),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: selected ? _gold : Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          selected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: selected ? _gold : Colors.white30,
                          size: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

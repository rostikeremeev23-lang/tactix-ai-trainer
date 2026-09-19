import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/ai_chat_message.dart';
import '../../models/training_result.dart';
import '../../services/ai_chat_storage.dart';
import '../../services/ai_service.dart';
import '../../services/result_storage_service.dart';

class AIChatScreen extends StatefulWidget {
  final AIChatContextType initialContext;

  const AIChatScreen({
    super.key,
    this.initialContext = AIChatContextType.general,
  });

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<AIChatMessage> _messages = const [];
  TrainingResult? _lastResult;
  AIChatContextType _contextType = AIChatContextType.general;
  bool _loading = true;
  bool _sending = false;
  bool _aiOnline = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _contextType = widget.initialContext;
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await AIService.loadConfig();
      final loadedMessages = await AIChatStorage.load();
      final results = await ResultStorageService.load();
      final online = await AIService.refreshStatus();

      if (!mounted) return;
      setState(() {
        _messages = loadedMessages;
        _lastResult = results.isEmpty ? null : results.first;
        _aiOnline = online;
        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить TACTIX AI: $e';
      });
    }
  }

  List<AIChatMessage> get _visibleMessages => _messages
      .where((item) => item.contextType == _contextType)
      .toList(growable: false);

  Map<String, dynamic> _debriefContext() {
    final result = _lastResult;
    if (result == null) return const {};

    return <String, dynamic>{
      'scenario_title': result.scenarioTitle,
      'score': result.score,
      'level': result.level,
      'outcome': result.outcome,
      'decisions': result.decisionHistory,
      'metrics': <String, dynamic>{
        'goal': result.goalScore,
        'resources': result.resourceScore,
        'stability': result.stabilityScore,
        'uncertainty': result.uncertaintyScore,
        'time': result.timeScore,
        'progress': result.progressScore,
      },
    };
  }

  Map<String, dynamic> _activeContext() {
    if (_contextType == AIChatContextType.debrief) {
      return _debriefContext();
    }
    return const {};
  }

  String _contextLabel(AIChatContextType type) {
    switch (type) {
      case AIChatContextType.general:
        return 'ОБЩИЙ';
      case AIChatContextType.coach:
        return 'ТРЕНЕР';
      case AIChatContextType.debrief:
        return 'РАЗБОР';
    }
  }

  IconData _contextIcon(AIChatContextType type) {
    switch (type) {
      case AIChatContextType.general:
        return Icons.chat_bubble_outline_rounded;
      case AIChatContextType.coach:
        return Icons.school_outlined;
      case AIChatContextType.debrief:
        return Icons.analytics_outlined;
    }
  }

  List<String> _suggestions() {
    switch (_contextType) {
      case AIChatContextType.general:
        return const [
          'Что умеет TACTIX?',
          'Как работает TACTIX Score?',
          'Объясни режим AUTO',
        ];
      case AIChatContextType.coach:
        return const [
          'Предложи цель следующей тренировки',
          'Как правильно разбирать свои ошибки?',
          'Как улучшать качество решений?',
        ];
      case AIChatContextType.debrief:
        if (_lastResult == null) {
          return const ['Как открыть разбор результата?'];
        }
        return const [
          'Почему у меня такой Score?',
          'Что мне улучшить?',
          'Разбери мои последние решения',
        ];
    }
  }

  Future<void> _send([String? preset]) async {
    if (_sending) return;

    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty) return;

    if (preset == null) {
      _controller.clear();
    }

    final previous = _visibleMessages;
    final userMessage = AIChatMessage(
      id: 'u-${DateTime.now().microsecondsSinceEpoch}',
      role: AIChatRole.user,
      text: text,
      timestamp: DateTime.now(),
      contextType: _contextType,
    );

    final updated = <AIChatMessage>[..._messages, userMessage];
    setState(() {
      _messages = updated;
      _sending = true;
      _error = null;
    });
    await AIChatStorage.save(updated);
    _scrollToBottom();

    try {
      final response = await AIService.chat(
        message: text,
        contextType: _contextType,
        history: previous,
        context: _activeContext(),
      );

      final assistantMessage = AIChatMessage(
        id: 'a-${DateTime.now().microsecondsSinceEpoch}',
        role: AIChatRole.assistant,
        text: response,
        timestamp: DateTime.now(),
        contextType: _contextType,
      );

      final withAnswer = <AIChatMessage>[..._messages, assistantMessage];
      await AIChatStorage.save(withAnswer);

      if (!mounted) return;
      setState(() {
        _messages = withAnswer;
        _sending = false;
        _aiOnline = AIService.activeBackend != AIBackendKind.none;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = _friendlyError(e);
      });
      _scrollToBottom();
    }
  }

  String _friendlyError(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '').trim();
    if (AIService.mode == AIMode.cloud) {
      return 'CLOUD сейчас недоступен. $text';
    }
    if (AIService.mode == AIMode.local) {
      return 'LOCAL AI сейчас недоступен. $text';
    }
    return text;
  }

  Future<void> _newChat() async {
    final next = _messages
        .where((item) => item.contextType != _contextType)
        .toList(growable: false);
    await AIChatStorage.save(next);
    if (!mounted) return;
    setState(() {
      _messages = next;
      _error = null;
    });
  }

  void _openDebrief() {
    setState(() {
      _contextType = AIChatContextType.debrief;
      _error = null;
    });
    _scrollToBottom();
  }

  Future<void> _refreshStatus() async {
    if (_sending) return;
    setState(() => _loading = true);
    final online = await AIService.refreshStatus();
    if (!mounted) return;
    setState(() {
      _aiOnline = online;
      _loading = false;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 760;

    return Scaffold(
      backgroundColor: TactixTheme.bg,
      appBar: AppBar(
        backgroundColor: TactixTheme.bg,
        titleSpacing: 8,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: TactixTheme.cyan.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: TactixTheme.cyan.withValues(alpha: .35),
                ),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: TactixTheme.cyan,
                size: 19,
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TACTIX AI',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
                ),
                Text(
                  'ИНТЕЛЛЕКТУАЛЬНЫЙ ПОМОЩНИК',
                  style: TextStyle(
                    color: TactixTheme.textMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .8,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Обновить AI статус',
            onPressed: _loading ? null : _refreshStatus,
            icon: const Icon(Icons.sync_rounded),
          ),
          IconButton(
            tooltip: 'Новый чат',
            onPressed: _sending ? null : _newChat,
            icon: const Icon(Icons.add_comment_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 12 : 20,
                12,
                compact ? 12 : 20,
                12,
              ),
              child: Column(
                children: [
                  _statusBar(compact),
                  const SizedBox(height: 10),
                  _contextSelector(compact),
                  if (_contextType == AIChatContextType.debrief) ...[
                    const SizedBox(height: 10),
                    _resultCard(),
                  ],
                  const SizedBox(height: 10),
                  Expanded(child: _conversation()),
                  const SizedBox(height: 10),
                  _suggestionBar(),
                  const SizedBox(height: 8),
                  _composer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusBar(bool compact) {
    final actualOffline = AIService.activeBackend == AIBackendKind.none;
    final color = actualOffline ? const Color(0xFFFFC857) : const Color(0xFF4EE39A);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: TactixTheme.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TactixTheme.line),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          Text(
            AIService.statusLabel,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            '${AIService.modeLabel} • ${AIService.providerLabel}',
            style: const TextStyle(
              color: TactixTheme.textMuted,
              fontSize: 11,
            ),
          ),
          if (_loading)
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.6),
            ),
          if (!compact && !_aiOnline && AIService.mode == AIMode.auto)
            const Text(
              'AUTO сохранит локальный fallback',
              style: TextStyle(
                color: TactixTheme.textMuted,
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
  }

  Widget _contextSelector(bool compact) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: TactixTheme.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TactixTheme.line),
      ),
      child: Row(
        children: AIChatContextType.values.map((type) {
          final selected = type == _contextType;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: InkWell(
                borderRadius: BorderRadius.circular(9),
                onTap: _sending
                    ? null
                    : () {
                        setState(() {
                          _contextType = type;
                          _error = null;
                        });
                        _scrollToBottom();
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 6 : 10,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? TactixTheme.cyan.withValues(alpha: .10)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: selected
                          ? TactixTheme.cyan.withValues(alpha: .35)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _contextIcon(type),
                        size: 15,
                        color: selected ? TactixTheme.cyan : TactixTheme.textMuted,
                      ),
                      if (!compact) ...[
                        const SizedBox(width: 7),
                        Text(
                          _contextLabel(type),
                          style: TextStyle(
                            color: selected ? Colors.white : TactixTheme.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _resultCard() {
    final result = _lastResult;
    if (result == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: TactixTheme.panel2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: TactixTheme.line),
        ),
        child: const Text(
          'Нет завершённого сценария. Завершите тренировку — и TACTIX AI сможет разобрать результат.',
          style: TextStyle(color: TactixTheme.textMuted, fontSize: 11, height: 1.4),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: TactixTheme.cyan.withValues(alpha: .055),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TactixTheme.cyan.withValues(alpha: .24)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: TactixTheme.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: TactixTheme.cyan.withValues(alpha: .28)),
            ),
            child: Text(
              '${result.score}',
              style: const TextStyle(
                color: TactixTheme.cyan,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ПОСЛЕДНИЙ РЕЗУЛЬТАТ',
                  style: TextStyle(
                    color: TactixTheme.textMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .7,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  result.scenarioTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  '${result.level} • ${result.decisions} решения',
                  style: const TextStyle(color: TactixTheme.textMuted, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: _sending
                ? null
                : () => _send('Разбери мой последний результат: что получилось хорошо и что улучшить?'),
            icon: const Icon(Icons.auto_awesome_rounded, size: 16),
            label: const Text('РАЗОБРАТЬ'),
          ),
        ],
      ),
    );
  }

  Widget _conversation() {
    if (_loading && _messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final visible = _visibleMessages;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: TactixTheme.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TactixTheme.line),
      ),
      child: visible.isEmpty && _error == null
          ? _emptyState()
          : ListView(
              controller: _scrollController,
              padding: const EdgeInsets.all(14),
              children: [
                ...visible.map(_messageBubble),
                if (_sending) _thinkingBubble(),
                if (_error != null) _errorBubble(_error!),
              ],
            ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: TactixTheme.cyan.withValues(alpha: .08),
                shape: BoxShape.circle,
                border: Border.all(color: TactixTheme.cyan.withValues(alpha: .28)),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: TactixTheme.cyan, size: 30),
            ),
            const SizedBox(height: 16),
            Text(
              _contextType == AIChatContextType.debrief
                  ? 'РАЗБОР РЕЗУЛЬТАТА'
                  : _contextType == AIChatContextType.coach
                      ? 'AI-ТРЕНЕР'
                      : 'TACTIX AI',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: .7),
            ),
            const SizedBox(height: 8),
            Text(
              _contextType == AIChatContextType.debrief
                  ? 'Задайте вопрос о последнем прохождении. Числовой Score остаётся результатом локального движка.'
                  : _contextType == AIChatContextType.coach
                      ? 'Учебный помощник для анализа решений и постановки целей следующей тренировки.'
                      : 'Общайтесь с AI, спрашивайте о TACTIX и учебном процессе.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: TactixTheme.textMuted, fontSize: 11, height: 1.45),
            ),
            if (_contextType != AIChatContextType.debrief && _lastResult != null) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _openDebrief,
                icon: const Icon(Icons.analytics_outlined),
                label: const Text('ПЕРЕЙТИ К РАЗБОРУ РЕЗУЛЬТАТА'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _messageBubble(AIChatMessage message) {
    final user = message.role == AIChatRole.user;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 760),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(13, 10, 13, 10),
        decoration: BoxDecoration(
          color: user
              ? TactixTheme.cyan.withValues(alpha: .12)
              : TactixTheme.panel2,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(13),
            topRight: const Radius.circular(13),
            bottomLeft: Radius.circular(user ? 13 : 3),
            bottomRight: Radius.circular(user ? 3 : 13),
          ),
          border: Border.all(
            color: user
                ? TactixTheme.cyan.withValues(alpha: .28)
                : TactixTheme.line,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user ? 'ВЫ' : 'TACTIX AI',
              style: TextStyle(
                color: user ? TactixTheme.cyan : TactixTheme.gold,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: .6,
              ),
            ),
            const SizedBox(height: 5),
            SelectableText(
              message.text,
              style: const TextStyle(fontSize: 12, height: 1.48),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thinkingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: TactixTheme.panel2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: TactixTheme.line),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(strokeWidth: 1.6),
            ),
            SizedBox(width: 9),
            Text('TACTIX AI думает...', style: TextStyle(color: TactixTheme.textMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _errorBubble(String text) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFF5D6C).withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF5D6C).withValues(alpha: .24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFFF7B87), size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 11, height: 1.4)),
          ),
          TextButton(
            onPressed: _sending ? null : () => _send(_lastUserText()),
            child: const Text('ПОВТОРИТЬ'),
          ),
        ],
      ),
    );
  }

  String _lastUserText() {
    final visible = _visibleMessages.reversed;
    for (final item in visible) {
      if (item.role == AIChatRole.user) return item.text;
    }
    return '';
  }

  Widget _suggestionBar() {
    final suggestions = _suggestions();
    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: suggestions.map((text) {
            return Padding(
              padding: const EdgeInsets.only(right: 7),
              child: ActionChip(
                label: Text(text),
                onPressed: _sending ? null : () => _send(text),
                backgroundColor: TactixTheme.panel2,
                side: BorderSide(color: TactixTheme.line),
                labelStyle: const TextStyle(fontSize: 10),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _composer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
      decoration: BoxDecoration(
        color: TactixTheme.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TactixTheme.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: !_sending,
              minLines: 1,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Напишите сообщение TACTIX AI...',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 11),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 6),
          IconButton.filled(
            tooltip: 'Отправить',
            onPressed: _sending ? null : _send,
            style: IconButton.styleFrom(
              backgroundColor: TactixTheme.cyan,
              foregroundColor: TactixTheme.bg,
            ),
            icon: const Icon(Icons.arrow_upward_rounded),
          ),
        ],
      ),
    );
  }
}

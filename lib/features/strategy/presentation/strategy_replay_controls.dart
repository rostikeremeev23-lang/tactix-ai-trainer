import 'dart:async';

import 'package:flutter/material.dart';

class StrategyReplayControls extends StatefulWidget {
  final int count, index;
  final ValueChanged<int> onChanged;
  final VoidCallback onClose;
  const StrategyReplayControls({
    super.key,
    required this.count,
    required this.index,
    required this.onChanged,
    required this.onClose,
  });
  @override
  State<StrategyReplayControls> createState() => _StrategyReplayControlsState();
}

class _StrategyReplayControlsState extends State<StrategyReplayControls> {
  Timer? _timer;
  int _speed = 1;
  bool get playing => _timer?.isActive ?? false;
  void _pause() {
    _timer?.cancel();
    setState(() {});
  }

  void _play() {
    if (widget.count < 2) return;
    if (widget.index == widget.count - 1) widget.onChanged(0);
    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: 1000 ~/ _speed), (_) {
      if (widget.index >= widget.count - 1) {
        _pause();
      } else {
        widget.onChanged(widget.index + 1);
      }
    });
    setState(() {});
  }

  void _seek(int index) {
    _pause();
    widget.onChanged(index);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('История ${widget.index + 1} / ${widget.count}'),
          IconButton(
            tooltip: 'Предыдущее событие',
            onPressed: widget.index > 0 ? () => _seek(widget.index - 1) : null,
            icon: const Icon(Icons.skip_previous),
          ),
          IconButton(
            tooltip: playing ? 'Пауза' : 'Воспроизвести',
            onPressed: widget.count < 2
                ? null
                : playing
                ? _pause
                : _play,
            icon: Icon(playing ? Icons.pause : Icons.play_arrow),
          ),
          IconButton(
            tooltip: 'Следующее событие',
            onPressed: widget.index < widget.count - 1
                ? () => _seek(widget.index + 1)
                : null,
            icon: const Icon(Icons.skip_next),
          ),
          DropdownButton<int>(
            value: _speed,
            items: [1, 2, 4]
                .map((s) => DropdownMenuItem(value: s, child: Text('${s}x')))
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              final resume = playing;
              _pause();
              setState(() => _speed = value);
              if (resume) _play();
            },
          ),
          TextButton(
            onPressed: widget.onClose,
            child: const Text('К текущему состоянию'),
          ),
        ],
      ),
      if (widget.count > 1)
        Slider(
          value: widget.index.toDouble(),
          max: (widget.count - 1).toDouble(),
          divisions: widget.count - 1,
          onChanged: (value) => _seek(value.round()),
        ),
    ],
  );
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

const storyCyan = Color(0xFF7BE3E6);
const storyGold = Color(0xFFF0C58D);
const storyBackground = Color(0xFF0B1421);

class StoryBackdrop extends StatelessWidget {
  final Widget child;
  const StoryBackdrop({super.key, required this.child});
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF203A4B), storyBackground, Color(0xFF111B28)],
      ),
    ),
    child: CustomPaint(painter: _StormPainter(), child: child),
  );
}

class _StormPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF8FBAC8).withValues(alpha: .055);
    for (var i = 0; i < 60; i++) {
      final x = (i * 79.0) % math.max(1, size.width);
      final y = (i * 113.0) % math.max(1, size.height);
      canvas.drawLine(
        Offset(x, y),
        Offset(x - 16, y + 52),
        paint..strokeWidth = 1,
      );
    }
    paint.color = const Color(0xFF06101A).withValues(alpha: .3);
    for (var i = 0; i < 15; i++) {
      final width = size.width / 14;
      final height = 45.0 + (i * 37 % 100);
      canvas.drawRect(
        Rect.fromLTWH(i * width, size.height - height, width - 5, height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StormPainter oldDelegate) => false;
}

class StoryPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const StoryPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
  });
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: const Color(0xFF122230).withValues(alpha: .94),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withValues(alpha: .10)),
    ),
    child: Material(type: MaterialType.transparency, child: child),
  );
}

Future<void> showStoryText(BuildContext context, String title, String text) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: storyBackground,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .78,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                          color: storyCyan,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SelectableText(
                        text,
                        style: const TextStyle(
                          fontSize: 17,
                          height: 1.65,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Закрыть'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

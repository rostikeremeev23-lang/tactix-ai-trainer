import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';

/// A self-contained, offline-first visual entry point for the existing Strategy
/// simulator. It is intentionally decorative: the city geometry is fictional.
class StrategySpotlight extends StatelessWidget {
  const StrategySpotlight({
    super.key,
    required this.sessionCount,
    required this.activeAssignments,
    required this.onLaunch,
  });

  final int sessionCount;
  final int activeAssignments;
  final VoidCallback onLaunch;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Semantics(
      label: 'Стратегическая симуляция. Открыть сценарии.',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onLaunch,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: TactixTheme.cyan.withValues(alpha: .32)),
              gradient: const LinearGradient(
                colors: [Color(0xFF162D3C), Color(0xFF0B1724), TactixTheme.bg],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: TactixTheme.cyan.withValues(alpha: .07),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(23),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(painter: _FictionalCityPainter()),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(compact ? 20 : 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.hub_outlined, size: 15, color: TactixTheme.cyan),
                            SizedBox(width: 8),
                            Flexible(
                              child: Text('TRAINING  /  SIMULATION LAB',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: TactixTheme.cyan,
                                  fontSize: 11, fontWeight: FontWeight.w800,
                                  letterSpacing: 1.4),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text('Город решений',
                          style: TextStyle(fontSize: compact ? 27 : 36,
                            height: 1.05, letterSpacing: -.7,
                            color: Colors.white, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 9),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 390),
                          child: const Text(
                            'Учебная симуляция на вымышленной карте. '
                            'Исследуйте сценарии, принимайте решения и разбирайте результаты.',
                            style: TextStyle(fontSize: 13.5, height: 1.55,
                              color: Color(0xFFD0DAE3)),
                          ),
                        ),
                        const SizedBox(height: 23),
                        Wrap(spacing: 9, runSpacing: 9, children: [
                          _MetricPill(icon: Icons.history_rounded,
                            label: 'Сессий: $sessionCount'),
                          _MetricPill(icon: Icons.assignment_outlined,
                            label: 'Заданий: $activeAssignments'),
                          const _MetricPill(icon: Icons.offline_bolt_outlined,
                            label: 'Карта офлайн'),
                        ]),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 17, vertical: 13),
                          decoration: BoxDecoration(
                            color: TactixTheme.cyan,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Открыть симулятор', style: TextStyle(
                                color: TactixTheme.bg, fontSize: 13.5,
                                fontWeight: FontWeight.w800)),
                              SizedBox(width: 12),
                              Icon(Icons.arrow_forward_rounded,
                                color: TactixTheme.bg, size: 18),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
    decoration: BoxDecoration(
      color: TactixTheme.bg.withValues(alpha: .72),
      border: Border.all(color: Colors.white.withValues(alpha: .13)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: const Color(0xFFC3E9F8)),
      const SizedBox(width: 7),
      Text(label, style: const TextStyle(fontSize: 11.5,
        fontWeight: FontWeight.w600, color: Colors.white)),
    ]),
  );
}

/// Decorative synthetic geometry, not a map of any real city.
class _FictionalCityPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final opacity = Paint()
      ..color = const Color(0xFF8BE0FF).withValues(alpha: .15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8;
    final ox = size.width * .56;
    final oy = size.height * .14;
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.translate(ox, oy);
    canvas.rotate(-.34);
    for (var i = -12; i < 24; i++) {
      final x = i * 34.0;
      canvas.drawLine(Offset(x, -500), Offset(x, size.height + 500), opacity);
    }
    for (var i = -16; i < 30; i++) {
      final y = i * 29.0;
      canvas.drawLine(Offset(-600, y), Offset(size.width + 600, y), opacity);
    }
    final road = Paint()
      ..color = TactixTheme.cyan.withValues(alpha: .29)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()
      ..moveTo(-40, -100)
      ..cubicTo(48, 75, -65, 140, 120, 240)
      ..cubicTo(205, 300, 85, 460, 230, 650);
    canvas.drawPath(path, road);
    final blocks = Paint()
      ..color = const Color(0xFF4CB9E8).withValues(alpha: .13)
      ..style = PaintingStyle.fill;
    for (var i = 0; i < 42; i++) {
      final x = (i % 7) * 70.0 - 75;
      final y = (i ~/ 7) * 65.0 - 5;
      final inset = ((i * 13) % 21).toDouble();
      canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(x + inset, y + inset / 3, 26 + (i % 3) * 7, 30),
        const Radius.circular(3)), blocks);
    }
    canvas.restore();
    final halo = Paint()..color = TactixTheme.cyan.withValues(alpha: .18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);
    canvas.drawCircle(Offset(size.width * .88, size.height * .32),
      math.min(48.0, size.width * .11), halo);
  }

  @override
  bool shouldRepaint(covariant _FictionalCityPainter oldDelegate) => false;
}

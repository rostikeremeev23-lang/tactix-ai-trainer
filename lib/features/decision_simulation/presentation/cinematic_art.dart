import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Presentation-only art direction. Story text and rules remain in the scenario.
enum SceneSet { controlRoom, radioRoom, evidenceDesk }

class SceneDirection {
  final SceneSet set;
  final Color accent;
  final String caption;
  const SceneDirection(this.set, this.accent, this.caption);

  static SceneDirection forScene(String id) => switch (id) {
    's1' => const SceneDirection(
      SceneSet.controlRoom,
      Color(0xFFE9B879),
      'ЛАДИН  /  18:40',
    ),
    's2' => const SceneDirection(
      SceneSet.radioRoom,
      Color(0xFF86C9DC),
      'МАЯК  /  КАНАЛ СВЯЗИ',
    ),
    's3' => const SceneDirection(
      SceneSet.evidenceDesk,
      Color(0xFFB6CAB7),
      'СВЕДЕНИЯ  /  ПРОВЕРКА',
    ),
    _ => const SceneDirection(
      SceneSet.controlRoom,
      Color(0xFF8ACAC8),
      'СИГНАЛ ПОСЛЕ ШТОРМА',
    ),
  };
}

/// Finite light sweep, not a perpetual ticker. Safe for reduced motion and tests.
class SceneIllustration extends StatelessWidget {
  final SceneDirection direction;
  const SceneIllustration({super.key, required this.direction});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 1600),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => CustomPaint(
          painter: _ScenePainter(direction, value),
          size: Size.infinite,
        ),
      ),
    ),
  );
}

class _ScenePainter extends CustomPainter {
  final SceneDirection direction;
  final double arrival;
  _ScenePainter(this.direction, this.arrival);

  void _rect(Canvas c, Rect rect, Color color, {double radius = 0}) {
    c.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      Paint()..color = color,
    );
  }

  void _line(Canvas c, Offset a, Offset b, Color color, [double width = 1]) {
    c.drawLine(
      a,
      b,
      Paint()
        ..color = color
        ..strokeWidth = width,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    // Cover without distorting the illustration on portrait displays.
    final scale = math.max(size.width / 1200, size.height / 380);
    canvas.translate(
      size.width - 1200 * scale,
      (size.height - 380 * scale) / 2,
    );
    canvas.scale(scale);
    final frame = const Rect.fromLTWH(0, 0, 1200, 380);
    canvas.drawRect(
      frame,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1C3643), Color(0xFF0A171F)],
        ).createShader(frame),
    );
    switch (direction.set) {
      case SceneSet.controlRoom:
        _controlRoom(canvas);
      case SceneSet.radioRoom:
        _radioRoom(canvas);
      case SceneSet.evidenceDesk:
        _evidenceDesk(canvas);
    }
    // Glass reflection and quiet film grain, deterministic and asset-free.
    final glow = Rect.fromCircle(
      center: Offset(915, 70 + 20 * arrival),
      radius: 270,
    );
    canvas.drawRect(
      frame,
      Paint()
        ..shader = RadialGradient(
          colors: [
            direction.accent.withValues(alpha: .12 * arrival),
            Colors.transparent,
          ],
        ).createShader(glow),
    );
    for (var i = 0; i < 680; i++) {
      canvas.drawCircle(
        Offset((i * 73.7) % 1200, (i * 41.3) % 380),
        .55,
        Paint()..color = Colors.white.withValues(alpha: .055),
      );
    }
    canvas.restore();
  }

  void _city(Canvas c, {double base = 257}) {
    for (var i = 0; i < 18; i++) {
      final x = i * 74.0;
      final height = 38.0 + i * 43 % 86;
      _rect(
        c,
        Rect.fromLTWH(x, base - height, 62, height),
        const Color(0xFF11232C),
      );
      for (var floor = 0; floor < 5; floor++) {
        if (floor * 16 + 10 > height) break;
        for (var window = 0; window < 4; window++) {
          if ((i + floor + window) % 3 == 0) continue;
          _rect(
            c,
            Rect.fromLTWH(
              x + 8 + window * 12,
              base - height + 9 + floor * 16,
              4,
              6,
            ),
            (i + floor) % 4 == 0
                ? const Color(0xFFBD9464)
                : const Color(0xFF31515C),
          );
        }
      }
    }
    for (var i = 0; i < 90; i++) {
      final x = (i * 101.0) % 1200;
      final y = (i * 67.0) % 265;
      _line(
        c,
        Offset(x, y),
        Offset(x - 8, y + 26),
        const Color(0xFF8BC4D5).withValues(alpha: .16),
      );
    }
  }

  void _controlRoom(Canvas c) {
    _city(c);
    for (final x in [450.0, 720.0, 1070.0]) {
      _rect(c, Rect.fromLTWH(x, 0, 13, 270), const Color(0xFF07141B));
      _line(c, Offset(x + 13, 0), Offset(x + 13, 270), const Color(0xFF4C6870));
    }
    _rect(c, const Rect.fromLTWH(0, 268, 1200, 112), const Color(0xFF101C23));
    _line(
      c,
      const Offset(0, 268),
      const Offset(1200, 268),
      const Color(0xFF4D5E60),
      2,
    );
    _rect(
      c,
      const Rect.fromLTWH(754, 154, 228, 153),
      const Color(0xFF071018),
      radius: 7,
    );
    _rect(
      c,
      const Rect.fromLTWH(763, 163, 210, 130),
      const Color(0xFF203E49),
      radius: 2,
    );
    for (var i = 0; i < 7; i++) {
      _line(
        c,
        Offset(778 + i * 28.0, 174),
        Offset(778 + i * 28.0, 280),
        const Color(0xFF36545C),
      );
    }
    for (var i = 0; i < 4; i++) {
      _line(
        c,
        Offset(774, 182 + i * 28.0),
        Offset(960, 182 + i * 28.0),
        const Color(0xFF36545C),
      );
    }
    final route = Path()
      ..moveTo(784, 256)
      ..lineTo(814, 216)
      ..lineTo(869, 231)
      ..lineTo(939, 185);
    c.drawPath(
      route,
      Paint()
        ..color = const Color(0xFF8ACAC8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    for (final p in [
      const Offset(814, 216),
      const Offset(869, 231),
      const Offset(939, 185),
    ]) {
      c.drawCircle(p, 4, Paint()..color = direction.accent);
    }
    _rect(c, const Rect.fromLTWH(851, 307, 22, 28), const Color(0xFF23323B));
    _rect(
      c,
      const Rect.fromLTWH(820, 334, 83, 5),
      const Color(0xFF43545B),
      radius: 2,
    );
    // Desk lamp and its warm pool of light.
    final beam = Path()
      ..moveTo(1057, 123)
      ..lineTo(962, 350)
      ..lineTo(1195, 350)
      ..close();
    c.drawPath(beam, Paint()..color = direction.accent.withValues(alpha: .07));
    _line(
      c,
      const Offset(1114, 317),
      const Offset(1102, 73),
      const Color(0xFF677276),
      7,
    );
    _line(
      c,
      const Offset(1102, 73),
      const Offset(1054, 110),
      const Color(0xFF677276),
      7,
    );
    c.drawPath(
      Path()
        ..moveTo(1032, 103)
        ..lineTo(1068, 107)
        ..lineTo(1085, 130)
        ..lineTo(1021, 130)
        ..close(),
      Paint()..color = const Color(0xFFD3B186),
    );
    _rect(
      c,
      const Rect.fromLTWH(1090, 318, 59, 8),
      const Color(0xFF4A565C),
      radius: 4,
    );
    _rect(
      c,
      const Rect.fromLTWH(651, 322, 121, 5),
      const Color(0xFF8B999A),
      radius: 2,
    );
    _rect(
      c,
      const Rect.fromLTWH(627, 329, 134, 5),
      const Color(0xFF455B66),
      radius: 2,
    );
    _rect(
      c,
      const Rect.fromLTWH(1010, 292, 28, 34),
      const Color(0xFF8E8070),
      radius: 5,
    );
  }

  void _radioRoom(Canvas c) {
    _city(c, base: 279);
    _rect(
      c,
      const Rect.fromLTWH(729, 80, 299, 206),
      const Color(0xFF1A3039),
      radius: 3,
    );
    final roof = Path()
      ..moveTo(702, 84)
      ..lineTo(874, 31)
      ..lineTo(1051, 84)
      ..close();
    c.drawPath(roof, Paint()..color = const Color(0xFF0B1A22));
    for (var i = 0; i < 5; i++) {
      _rect(
        c,
        Rect.fromLTWH(751 + i * 52.0, 109, 30, 57),
        const Color(0xFFB09973),
      );
      _line(
        c,
        Offset(766 + i * 52.0, 109),
        Offset(766 + i * 52.0, 166),
        const Color(0xFF253C44),
        3,
      );
    }
    _rect(c, const Rect.fromLTWH(853, 207, 53, 79), const Color(0xFFBBA985));
    _rect(c, const Rect.fromLTWH(865, 216, 28, 70), const Color(0xFF384E55));
    _rect(c, const Rect.fromLTWH(0, 289, 1200, 91), const Color(0xFF09161E));
    for (var i = 0; i < 25; i++) {
      final x = 680 + (i * 53.0) % 480;
      _line(
        c,
        Offset(x, 294 + i * 3.0),
        Offset(x + 33, 294 + i * 3.0),
        direction.accent.withValues(alpha: .12),
      );
    }
    // Radio in the near foreground; the light is visual, never an engine fact.
    _rect(
      c,
      const Rect.fromLTWH(1014, 205, 120, 132),
      const Color(0xFF0C1F29),
      radius: 9,
    );
    _line(
      c,
      const Offset(1111, 210),
      const Offset(1123, 110),
      const Color(0xFF78949C),
      5,
    );
    _rect(
      c,
      const Rect.fromLTWH(1030, 223, 57, 25),
      const Color(0xFF638F92),
      radius: 2,
    );
    for (var i = 0; i < 7; i++) {
      _line(
        c,
        Offset(1030, 268 + i * 6.0),
        Offset(1090, 268 + i * 6.0),
        const Color(0xFF3F5B66),
        2,
      );
    }
    c.drawCircle(
      const Offset(1111, 238),
      9,
      Paint()..color = const Color(0xFF899FA3),
    );
    for (var i = 0; i < 3; i++) {
      c.drawArc(
        Rect.fromCircle(center: const Offset(1120, 117), radius: 24 + i * 15.0),
        -2.3,
        1.1,
        false,
        Paint()
          ..color = direction.accent.withValues(alpha: .3 - i * .07)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  void _evidenceDesk(Canvas c) {
    for (var i = 0; i < 11; i++) {
      _line(
        c,
        Offset(0, i * 42.0),
        Offset(1200, i * 42.0 - 60),
        const Color(0xFF334247),
        1,
      );
    }
    c.save();
    c.translate(748, 54);
    c.rotate(-.10);
    _rect(
      c,
      const Rect.fromLTWH(0, 0, 194, 261),
      const Color(0xFFADB4A5),
      radius: 2,
    );
    _rect(c, const Rect.fromLTWH(16, 17, 162, 135), const Color(0xFF465C63));
    _rect(c, const Rect.fromLTWH(33, 36, 91, 116), const Color(0xFF6B7B7A));
    final crack = Path()
      ..moveTo(106, 42)
      ..lineTo(84, 69)
      ..lineTo(92, 91)
      ..lineTo(79, 123);
    c.drawPath(
      crack,
      Paint()
        ..color = const Color(0xFF344C54)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    for (var i = 0; i < 5; i++) {
      _line(
        c,
        Offset(18, 177 + i * 13.0),
        Offset(i == 4 ? 110 : 164, 177 + i * 13.0),
        const Color(0xFF6A7978),
        2,
      );
    }
    c.restore();
    c.save();
    c.translate(960, 74);
    c.rotate(.12);
    _rect(
      c,
      const Rect.fromLTWH(0, 0, 170, 246),
      const Color(0xFF06141C),
      radius: 12,
    );
    _rect(
      c,
      const Rect.fromLTWH(10, 16, 150, 210),
      const Color(0xFF29434B),
      radius: 5,
    );
    _rect(
      c,
      const Rect.fromLTWH(22, 34, 126, 73),
      const Color(0xFF475E61),
      radius: 3,
    );
    for (var i = 0; i < 4; i++) {
      _line(
        c,
        Offset(24, 129 + i * 15.0),
        Offset(135 - i * 7.0, 129 + i * 15.0),
        const Color(0xFF90B3B1),
        2,
      );
    }
    c.drawCircle(
      const Offset(85, 236),
      3,
      Paint()..color = const Color(0xFF6D8C93),
    );
    c.restore();
    _line(
      c,
      const Offset(680, 304),
      const Offset(715, 119),
      const Color(0xFFD3B689),
      5,
    );
    _line(
      c,
      const Offset(680, 304),
      const Offset(677, 321),
      const Color(0xFF9BAEB0),
      3,
    );
  }

  @override
  bool shouldRepaint(_ScenePainter oldDelegate) =>
      oldDelegate.direction.set != direction.set ||
      oldDelegate.arrival != arrival;
}

class CharacterPortrait extends StatelessWidget {
  final String characterId;
  final double size;
  const CharacterPortrait({
    super.key,
    required this.characterId,
    this.size = 72,
  });

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: CustomPaint(
        painter: _PortraitPainter(characterId),
        size: Size(size, size * 1.16),
      ),
    ),
  );
}

/// Stylised editorial portraits, kept as vectors at every window/text scale.
class _PortraitPainter extends CustomPainter {
  final String id;
  _PortraitPainter(this.id);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 120, size.height / 140);
    final female = id == 'engineer' || id == 'community';
    final engineer = id == 'engineer';
    final skin = id == 'shelter'
        ? const Color(0xFFB89479)
        : const Color(0xFFC5A58C);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 120, 140),
      Paint()
        ..shader = LinearGradient(
          colors: [
            engineer ? const Color(0xFF3C626B) : const Color(0xFF465354),
            const Color(0xFF132732),
          ],
        ).createShader(const Rect.fromLTWH(0, 0, 120, 140)),
    );
    canvas.drawCircle(
      const Offset(65, 61),
      45,
      Paint()..color = Colors.white.withValues(alpha: .06),
    );
    final shoulders = Path()
      ..moveTo(7, 140)
      ..quadraticBezierTo(12, 100, 43, 99)
      ..lineTo(78, 99)
      ..quadraticBezierTo(108, 106, 117, 140)
      ..close();
    canvas.drawPath(
      shoulders,
      Paint()
        ..color = engineer ? const Color(0xFFAA784D) : const Color(0xFF324B56),
    );
    if (engineer) {
      canvas.drawLine(
        const Offset(27, 110),
        const Offset(25, 140),
        Paint()
          ..color = const Color(0xFFCFD1BA)
          ..strokeWidth = 8,
      );
      canvas.drawLine(
        const Offset(91, 111),
        const Offset(98, 140),
        Paint()
          ..color = const Color(0xFFCFD1BA)
          ..strokeWidth = 8,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(47, 82, 26, 28),
        const Radius.circular(8),
      ),
      Paint()..color = skin,
    );
    canvas.drawOval(
      const Rect.fromLTWH(30, 20, 59, 81),
      Paint()
        ..color = female ? const Color(0xFF302E2D) : const Color(0xFF343B3E),
    );
    canvas.drawOval(const Rect.fromLTWH(35, 31, 48, 65), Paint()..color = skin);
    canvas.drawPath(
      Path()
        ..moveTo(35, 59)
        ..lineTo(32, 33)
        ..quadraticBezierTo(53, 9, 83, 29)
        ..lineTo(87, female ? 84 : 53)
        ..lineTo(77, 52)
        ..lineTo(72, 37)
        ..quadraticBezierTo(50, 50, 35, 45)
        ..close(),
      Paint()
        ..color = id == 'shelter'
            ? const Color(0xFF858480)
            : const Color(0xFF303538),
    );
    final ink = Paint()
      ..color = const Color(0xFF494443)
      ..strokeWidth = 1.8;
    canvas.drawLine(const Offset(43, 62), const Offset(50, 62), ink);
    canvas.drawLine(const Offset(66, 62), const Offset(73, 62), ink);
    canvas.drawLine(
      const Offset(57, 65),
      const Offset(55, 75),
      ink..color = const Color(0xFF947867),
    );
    canvas.drawLine(
      const Offset(51, 83),
      const Offset(65, 82),
      ink..color = const Color(0xFF80645A),
    );
    if (id == 'transport') {
      canvas.drawArc(
        const Rect.fromLTWH(27, 18, 64, 75),
        3.1,
        3.1,
        false,
        Paint()
          ..color = const Color(0xFF0E232F)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(78, 55, 13, 24),
          const Radius.circular(5),
        ),
        Paint()..color = const Color(0xFF142C38),
      );
      canvas.drawLine(
        const Offset(88, 74),
        const Offset(72, 87),
        Paint()
          ..color = const Color(0xFF81A7AC)
          ..strokeWidth = 2,
      );
    }
    canvas.drawPath(
      Path()
        ..moveTo(39, 102)
        ..lineTo(57, 118)
        ..lineTo(81, 101)
        ..lineTo(62, 140)
        ..close(),
      Paint()..color = const Color(0xFF182D37),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PortraitPainter oldDelegate) => id != oldDelegate.id;
}

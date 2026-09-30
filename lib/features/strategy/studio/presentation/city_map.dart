import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Entirely invented, offline vector geometry. No real locations.
class CityMapPainter extends CustomPainter {
  final bool labels, sectors;
  const CityMapPainter({this.labels = true, this.sectors = true});
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 1000, size.height / 1000);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 1000, 1000),
      Paint()..color = const Color(0xFF0B171C),
    );
    final road = Paint()
      ..color = const Color(0xFF29404A)
      ..strokeWidth = 9;
    final fine = Paint()
      ..color = const Color(0xFF1A3038)
      ..strokeWidth = 2;
    for (var x = 60; x < 960; x += 90) {
      for (var y = 90; y < 960; y += 80) {
        final rect = Rect.fromLTWH(x.toDouble(), y.toDouble(), 55, 43);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(5)),
          Paint()
            ..color = (x + y) % 7 < 2
                ? const Color(0xFF183B34)
                : const Color(0xFF21323A),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.deflate(5), const Radius.circular(2)),
          Paint()
            ..color = const Color(0xFF30454B)
            ..style = PaintingStyle.stroke,
        );
      }
    }
    for (var i = 0; i < 10; i++) {
      canvas.drawLine(Offset(40 + i * 90, 50), Offset(40 + i * 90, 960), fine);
      canvas.drawLine(Offset(30, 70 + i * 80), Offset(970, 70 + i * 80), fine);
    }
    for (final y in [270.0, 430.0, 750.0]) {
      canvas.drawLine(Offset(25, y), Offset(975, y), road);
      canvas.drawLine(
        Offset(25, y),
        Offset(975, y),
        Paint()
          ..color = const Color(0xFF667065)
          ..strokeWidth = 1,
      );
    }
    final river = Path()
      ..moveTo(-60, 540)
      ..cubicTo(170, 420, 290, 660, 470, 575)
      ..cubicTo(670, 460, 770, 570, 1070, 455);
    canvas.drawPath(
      river,
      Paint()
        ..color = const Color(0xFF35515A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 86,
    );
    canvas.drawPath(
      river,
      Paint()
        ..color = const Color(0xFF102F3D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 72,
    );
    canvas.drawPath(
      river,
      Paint()
        ..color = const Color(0xFF215166)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    for (final bridge in [
      const Offset(210, 561),
      const Offset(510, 552),
      const Offset(820, 514),
    ]) {
      canvas.save();
      canvas.translate(bridge.dx, bridge.dy);
      canvas.rotate(.12);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-13, -63, 26, 126),
          const Radius.circular(4),
        ),
        Paint()..color = const Color(0xFF778079),
      );
      canvas.drawLine(
        const Offset(0, -62),
        const Offset(0, 62),
        Paint()
          ..color = const Color(0xFFE0C38C)
          ..strokeWidth = 2,
      );
      canvas.restore();
    }
    canvas.drawCircle(
      const Offset(490, 320),
      63,
      Paint()..color = const Color(0xFF2B3C3D),
    );
    canvas.drawCircle(
      const Offset(490, 320),
      53,
      Paint()
        ..color = const Color(0xFFB6A078)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final spire = Path()
      ..moveTo(472, 346)
      ..lineTo(486, 257)
      ..lineTo(494, 257)
      ..lineTo(508, 346)
      ..close();
    canvas.drawPath(spire, Paint()..color = const Color(0xFFB6A078));
    canvas.drawCircle(
      const Offset(490, 270),
      19,
      Paint()..color = const Color(0xFFD9BC81),
    );
    final tent = Path()
      ..moveTo(680, 820)
      ..quadraticBezierTo(745, 660, 820, 820)
      ..close();
    canvas.drawPath(tent, Paint()..color = const Color(0xFF48616A));
    for (var i = 0; i < 7; i++) {
      canvas.drawLine(const Offset(745, 711), Offset(682 + i * 22, 820), fine);
    }
    if (sectors) {
      for (final bounds in [
        const Rect.fromLTWH(90, 150, 280, 300),
        const Rect.fromLTWH(410, 160, 230, 300),
        const Rect.fromLTWH(680, 130, 250, 300),
      ]) {
        final path = Path()
          ..addRRect(
            RRect.fromRectAndRadius(bounds, const Radius.circular(25)),
          );
        for (final metric in path.computeMetrics()) {
          for (double d = 0; d < metric.length; d += 20) {
            canvas.drawPath(
              metric.extractPath(d, math.min(d + 9, metric.length)),
              Paint()
                ..color = const Color(0x7776B7AC)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2,
            );
          }
        }
      }
    }
    if (labels) {
      _label(canvas, '01 / АРКА', const Offset(110, 175));
      _label(canvas, '02 / САД', const Offset(430, 185));
      _label(canvas, '03 / МАЯК', const Offset(700, 155));
      _label(canvas, 'РЕКА ЛИНИЯ', const Offset(340, 565));
      _label(canvas, 'ПАВИЛЬОН ВЕТРА', const Offset(660, 850));
      _label(canvas, 'ЮЖНЫЙ БЕРЕГ', const Offset(95, 875));
    }
    canvas.restore();
  }

  void _label(Canvas canvas, String text, Offset at) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontFamily: 'Arial',
          fontSize: 24,
          fontWeight: FontWeight.w600,
          letterSpacing: 2,
          color: Color(0xFFCBD1C5),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at);
  }

  @override
  bool shouldRepaint(CityMapPainter oldDelegate) =>
      labels != oldDelegate.labels || sectors != oldDelegate.sectors;
}

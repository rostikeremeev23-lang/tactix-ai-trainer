import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../domain/scenario.dart';
import '../domain/engine.dart';
import 'city_map.dart';

IconData objectIcon(ObjectKind kind) => switch (kind) {
  ObjectKind.group => Icons.groups_rounded,
  ObjectKind.transport => Icons.local_shipping_rounded,
  ObjectKind.armor => Icons.shield_rounded,
  ObjectKind.objective => Icons.flag_rounded,
  ObjectKind.facility => Icons.warehouse_rounded,
  ObjectKind.recon => Icons.visibility_outlined,
  ObjectKind.aerial => Icons.air_rounded,
  ObjectKind.emergency => Icons.health_and_safety_outlined,
  ObjectKind.reserve => Icons.all_inclusive,
  ObjectKind.logistics => Icons.inventory_2_outlined,
};
Color objectColor(ObjectKind kind) => switch (kind) {
  ObjectKind.objective => TactixTheme.gold,
  ObjectKind.facility => const Color(0xFFDCE4EA),
  ObjectKind.armor => const Color(0xFFB7A4FC),
  _ => TactixTheme.cyan,
};

/// Rendering consumes normalized world coordinates; no simulation logic here.
/// A future perspective renderer can consume this same frame contract.
class TerrainView extends StatefulWidget {
  final List<MapObject> objects;
  final ExerciseFrame? frame;
  final String? selectedId, instruction;
  final bool labels, routes, zones;
  final bool cityMap;
  final Set<String> selectedIds;
  final void Function(String, MapPoint)? onDragObject;
  final ValueChanged<String> onSelect;
  final ValueChanged<MapPoint> onMapTap;
  const TerrainView({
    super.key,
    required this.objects,
    required this.onSelect,
    required this.onMapTap,
    this.frame,
    this.selectedId,
    this.instruction,
    this.cityMap = false,
    this.selectedIds = const {},
    this.onDragObject,
    this.labels = true,
    this.routes = true,
    this.zones = true,
  });
  @override
  State<TerrainView> createState() => TerrainViewState();
}

class TerrainViewState extends State<TerrainView>
    with SingleTickerProviderStateMixin {
  final TransformationController _camera = TransformationController();
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  Animation<Matrix4>? _animation;
  Size _viewport = Size.zero;
  bool _initialized = false;
  final GlobalKey _canvasKey = GlobalKey();
  MapPoint? _dragPoint;
  Matrix4 _overview() {
    final scale =
        (widget.cityMap
            ? math.min(_viewport.width, _viewport.height)
            : math.max(_viewport.width, _viewport.height)) /
        1000;
    return _position(
      MapPoint(
        .5,
        !widget.cityMap && _viewport.width > _viewport.height ? .64 : .5,
      ),
      scale,
    );
  }

  @override
  void initState() {
    super.initState();
    _motion.addListener(() {
      if (_animation != null) _camera.value = _animation!.value;
    });
  }

  void _animate(Matrix4 end) {
    _animation = Matrix4Tween(
      begin: _camera.value,
      end: end,
    ).animate(CurvedAnimation(parent: _motion, curve: Curves.easeOutCubic));
    _motion.forward(from: 0);
  }

  Matrix4 _position(MapPoint point, double scale) => Matrix4.identity()
    ..translateByDouble(
      _viewport.width / 2 - point.x * 1000 * scale,
      _viewport.height / 2 - point.y * 1000 * scale,
      0,
      1,
    )
    ..scaleByDouble(scale, scale, 1, 1);
  void focus(MapPoint point) => _animate(
    _position(point, math.max(_camera.value.getMaxScaleOnAxis(), 1.25)),
  );
  void fit() => _animate(
    _position(
      const MapPoint(.5, .5),
      math.min(_viewport.width, _viewport.height) / 1000,
    ),
  );
  void zoom(double factor) {
    final point = _camera.toScene(_viewport.center(Offset.zero));
    _animate(
      _position(
        MapPoint(point.dx / 1000, point.dy / 1000),
        (_camera.value.getMaxScaleOnAxis() * factor).clamp(.15, 4),
      ),
    );
  }

  @override
  void dispose() {
    _motion.dispose();
    _camera.dispose();
    super.dispose();
  }

  MapPoint _worldPoint(Offset global) {
    final box = _canvasKey.currentContext!.findRenderObject() as RenderBox;
    final local = box.globalToLocal(global);
    return MapPoint(
      (local.dx / 1000).clamp(.025, .975),
      (local.dy / 1000).clamp(.025, .975),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      if (_viewport != size) {
        _viewport = size;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _animate(_overview());
        });
      }
      if (!_initialized) {
        _initialized = true;
        _camera.value = _overview();
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: const Color(0xFF101C22),
                child: InteractiveViewer(
                  transformationController: _camera,
                  constrained: false,
                  minScale: .15,
                  maxScale: 4,
                  boundaryMargin: const EdgeInsets.all(1000),
                  trackpadScrollCausesScale: true,
                  onInteractionStart: (_) => _motion.stop(),
                  child: GestureDetector(
                    key: const ValueKey('terrain-canvas'),
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) => widget.onMapTap(
                      MapPoint(
                        (details.localPosition.dx / 1000).clamp(.025, .975),
                        (details.localPosition.dy / 1000).clamp(.025, .975),
                      ),
                    ),
                    child: SizedBox(
                      key: _canvasKey,
                      width: 1000,
                      height: 1000,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: RepaintBoundary(
                              child: widget.cityMap
                                  ? CustomPaint(
                                      painter: CityMapPainter(
                                        labels: widget.labels,
                                        sectors: widget.zones,
                                      ),
                                    )
                                  : Image.asset(
                                      'assets/strategy/valley.png',
                                      fit: BoxFit.fill,
                                      filterQuality: FilterQuality.medium,
                                    ),
                            ),
                          ),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: _OverlayPainter(
                                  widget.objects,
                                  widget.frame,
                                  routes: widget.routes,
                                  zones: widget.zones,
                                ),
                              ),
                            ),
                          ),
                          if (_dragPoint != null)
                            Positioned(
                              left: _dragPoint!.x * 1000 - 25,
                              top: _dragPoint!.y * 1000 - 25,
                              child: IgnorePointer(
                                child: Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: TactixTheme.gold.withValues(
                                      alpha: .25,
                                    ),
                                    border: Border.all(
                                      color: TactixTheme.gold,
                                      width: 3,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ...widget.objects.map(
                            (o) => AnimatedPositioned(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.linear,
                              left: o.position.x * 1000 - 85,
                              top: o.position.y * 1000 - 34,
                              width: 170,
                              child: ValueListenableBuilder<Matrix4>(
                                valueListenable: _camera,
                                builder: (context, matrix, child) {
                                  final scale =
                                      .75 / matrix.getMaxScaleOnAxis();
                                  return Transform(
                                    transform: Matrix4.identity()
                                      ..translateByDouble(85, 34, 0, 1)
                                      ..scaleByDouble(scale, scale, 1, 1)
                                      ..translateByDouble(-85, -34, 0, 1),
                                    child: child,
                                  );
                                },
                                child: Semantics(
                                  label: o.name,
                                  button: true,
                                  selected: (widget.selectedId == o.id || widget.selectedIds.contains(o.id)),
                                  child: GestureDetector(
                                    onLongPressStart:
                                        widget.onDragObject == null
                                        ? null
                                        : (details) {
                                            setState(
                                              () => _dragPoint = _worldPoint(
                                                details.globalPosition,
                                              ),
                                            );
                                          },
                                    onLongPressMoveUpdate:
                                        widget.onDragObject == null
                                        ? null
                                        : (details) {
                                            setState(
                                              () => _dragPoint = _worldPoint(
                                                details.globalPosition,
                                              ),
                                            );
                                          },
                                    onLongPressEnd: widget.onDragObject == null
                                        ? null
                                        : (details) {
                                            final point = _worldPoint(
                                              details.globalPosition,
                                            );
                                            setState(() => _dragPoint = null);
                                            widget.onDragObject!(o.id, point);
                                          },
                                    onLongPressCancel: () =>
                                        setState(() => _dragPoint = null),
                                    onTap: () => widget.instruction != null
                                        ? widget.onMapTap(o.position)
                                        : widget.onSelect(o.id),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          key: ValueKey('map-${o.id}'),
                                          width: 68,
                                          height: 68,
                                          decoration: BoxDecoration(
                                            color: const Color(0xEF08141D),
                                            borderRadius: BorderRadius.circular(
                                              o.kind == ObjectKind.objective
                                                  ? 34
                                                  : 14,
                                            ),
                                            border: Border.all(
                                              color: (widget.selectedId == o.id || widget.selectedIds.contains(o.id))
                                                  ? Colors.white
                                                  : objectColor(o.kind),
                                              width: (widget.selectedId == o.id || widget.selectedIds.contains(o.id))
                                                  ? 4
                                                  : 2,
                                            ),
                                            boxShadow: const [
                                              BoxShadow(
                                                color: Colors.black54,
                                                blurRadius: 10,
                                              ),
                                            ],
                                          ),
                                          child: Transform.rotate(
                                            angle: o.rotation * math.pi / 180,
                                            child: Icon(
                                              objectIcon(o.kind),
                                              color: objectColor(o.kind),
                                              size: 36,
                                            ),
                                          ),
                                        ),
                                        if (widget.labels)
                                          Container(
                                            constraints: const BoxConstraints(
                                              maxWidth: 170,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xEC08141D),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              o.group.isEmpty
                                                  ? o.name
                                                  : '${o.name} · ${o.group}',
                                              maxLines: 2,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              top: 12,
              right: 64,
              child: IgnorePointer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _chip(
                      widget.cityMap
                          ? 'ASTRA / ВЫМЫШЛЕННЫЙ ГОРОД'
                          : 'ДОЛИНА СЕВЕРНАЯ / УЧЕБНАЯ ТЕРРИТОРИЯ',
                    ),
                    const SizedBox(height: 6),
                    if (widget.instruction != null)
                      _chip(widget.instruction!, gold: true),
                    if (widget.frame?.pending != null)
                      _chip(
                        'ВВОДНАЯ • ${injectLabels[widget.frame!.pending!.kind.index]}',
                        gold: true,
                      ),
                    if (widget.frame?.condition.startsWith('Сниженный темп') ??
                        false)
                      _chip(widget.frame!.condition, gold: true),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 10,
              top: 10,
              child: Material(
                color: TactixTheme.panel,
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  children: [
                    IconButton(
                      tooltip: 'Приблизить',
                      onPressed: () => zoom(1.4),
                      icon: const Icon(Icons.add),
                    ),
                    IconButton(
                      tooltip: 'Отдалить',
                      onPressed: () => zoom(1 / 1.4),
                      icon: const Icon(Icons.remove),
                    ),
                    IconButton(
                      tooltip: 'Вся территория',
                      onPressed: fit,
                      icon: const Icon(Icons.fit_screen),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: IgnorePointer(
                child: _chip(
                  widget.cityMap
                      ? 'Синтетическая карта · архитектурное вдохновение: Астана\nПанорама: перетаскивание · жетон: удержать и переместить'
                      : 'Вымышленная растровая учебная подложка • не спутниковые данные\nПанорама: перетаскивание • масштаб: колесо / два пальца',
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
  Widget _chip(String text, {bool gold = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xE808141D),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: gold ? TactixTheme.gold : Colors.white70,
        fontSize: 11,
      ),
    ),
  );
}

class _OverlayPainter extends CustomPainter {
  final List<MapObject> objects;
  final ExerciseFrame? frame;
  final bool routes, zones;
  _OverlayPainter(
    this.objects,
    this.frame, {
    required this.routes,
    required this.zones,
  });
  Offset point(MapPoint p) => Offset(p.x * 1000, p.y * 1000);
  @override
  void paint(Canvas canvas, Size size) {
    if (zones) {
      for (final o in objects.where((o) => o.kind == ObjectKind.objective)) {
        final done = frame?.reached.contains(o.id) ?? false;
        final color = done ? Colors.greenAccent : TactixTheme.gold;
        canvas.drawCircle(
          point(o.position),
          55,
          Paint()..color = color.withValues(alpha: .15),
        );
        canvas.drawCircle(
          point(o.position),
          55,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }
    if (routes && frame != null) {
      for (final o in objects) {
        final target = frame!.destinations[o.id];
        if (target == null) continue;
        canvas.drawLine(
          point(o.position),
          point(target),
          Paint()
            ..color = objectColor(o.kind)
            ..strokeWidth = 4,
        );
        canvas.drawCircle(
          point(target),
          8,
          Paint()..color = objectColor(o.kind),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter old) =>
      old.objects != objects ||
      old.frame != frame ||
      old.routes != routes ||
      old.zones != zones;
}

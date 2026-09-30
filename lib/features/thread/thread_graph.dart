import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'thread_store.dart';

/// Native Flutter Digital Thread graph. It intentionally avoids a WebView or
/// a third-party graph engine so the first Phase C slice stays lightweight and
/// works offline with the same cached records as ThreadStore.
class ThreadGraphView extends StatefulWidget {
  const ThreadGraphView({
    super.key,
    required this.store,
    this.selectedCaseId,
    required this.onOpenCase,
  });

  final ThreadStore store;
  final String? selectedCaseId;
  final ValueChanged<String> onOpenCase;

  @override
  State<ThreadGraphView> createState() => _ThreadGraphViewState();
}

class _ThreadGraphViewState extends State<ThreadGraphView> {
  bool _showAll = false;
  String _filter = 'ALL';

  @override
  Widget build(BuildContext context) {
    final model = _GraphModel.build(
      widget.store,
      selectedCaseId: widget.selectedCaseId,
      showAll: _showAll,
      relationFilter: _filter,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'DIGITAL THREAD',
                style: TextStyle(
                  color: TactixTheme.textPrimary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              ChoiceChip(
                label: const Text('Focus'),
                selected: !_showAll,
                onSelected: (_) => setState(() => _showAll = false),
              ),
              ChoiceChip(
                label: const Text('All cached'),
                selected: _showAll,
                onSelected: (_) => setState(() => _showAll = true),
              ),
              for (final value in ['ALL', 'RELATED_TO', 'REQUIRES', 'SUPPORTED_BY', 'TRAINED_BY', 'PRODUCED'])
                ChoiceChip(
                  label: Text(value.replaceAll('_', ' ')),
                  selected: _filter == value,
                  onSelected: (_) => setState(() => _filter = value),
                ),
            ],
          ),
        ),
        Expanded(
          child: model.nodes.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Create or select a Case to build its Digital Thread.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: TactixTheme.textMuted),
                    ),
                  ),
                )
              : ClipRect(
                  child: InteractiveViewer(
                    minScale: .55,
                    maxScale: 2.4,
                    boundaryMargin: const EdgeInsets.all(260),
                    constrained: false,
                    child: SizedBox(
                      width: _GraphModel.canvas.width,
                      height: _GraphModel.canvas.height,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _ThreadEdgesPainter(model),
                            ),
                          ),
                          for (final node in model.nodes)
                            Positioned(
                              left: node.position.dx - node.size.width / 2,
                              top: node.position.dy - node.size.height / 2,
                              child: _GraphNodeCard(
                                node: node,
                                selected: node.id == widget.selectedCaseId,
                                onTap: node.type == 'CASE'
                                    ? () => widget.onOpenCase(node.id)
                                    : null,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: Text(
            '${model.nodes.length} nodes · ${model.edges.length} relationships · drag to pan · pinch/scroll to zoom',
            style: const TextStyle(
              color: TactixTheme.textMuted,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _GraphNodeCard extends StatelessWidget {
  const _GraphNodeCard({
    required this.node,
    required this.selected,
    this.onTap,
  });

  final _GraphNode node;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (node.type) {
      'CASE' => node.closed ? TactixTheme.positive : TactixTheme.cyan,
      'TRAINING' => node.completed ? TactixTheme.positive : TactixTheme.gold,
      _ => node.verified ? TactixTheme.positive : TactixTheme.warning,
    };
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: TactixTheme.motionFast,
          width: node.size.width,
          height: node.size.height,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: TactixTheme.panel2.withValues(alpha: .97),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? TactixTheme.gold : color.withValues(alpha: .7),
              width: selected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: selected ? .22 : .08),
                blurRadius: selected ? 24 : 12,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(
                    switch (node.type) {
                      'CASE' => Icons.account_tree_outlined,
                      'TRAINING' => Icons.school_outlined,
                      _ => Icons.fact_check_outlined,
                    },
                    color: color,
                    size: 18,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      node.type,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                node.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: TactixTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                node.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: TactixTheme.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThreadEdgesPainter extends CustomPainter {
  const _ThreadEdgesPainter(this.model);
  final _GraphModel model;

  @override
  void paint(Canvas canvas, Size size) {
    for (final edge in model.edges) {
      final from = model.byKey[edge.fromKey];
      final to = model.byKey[edge.toKey];
      if (from == null || to == null) continue;
      final start = from.position;
      final end = to.position;
      final paint = Paint()
        ..color = edge.pending
            ? TactixTheme.warning.withValues(alpha: .65)
            : TactixTheme.line.withValues(alpha: .95)
        ..strokeWidth = edge.highlighted ? 2.2 : 1.25
        ..style = PaintingStyle.stroke;
      final path = Path()..moveTo(start.dx, start.dy);
      final midpoint = (start.dx + end.dx) / 2;
      path.cubicTo(midpoint, start.dy, midpoint, end.dy, end.dx, end.dy);
      canvas.drawPath(path, paint);

      final direction = end - start;
      if (direction.distance > 1) {
        final angle = math.atan2(direction.dy, direction.dx);
        const arrow = 8.0;
        final tip = Offset(
          end.dx - math.cos(angle) * (to.size.width / 2 + 2),
          end.dy - math.sin(angle) * (to.size.height / 2 + 2),
        );
        final p1 = Offset(
          tip.dx - math.cos(angle - .55) * arrow,
          tip.dy - math.sin(angle - .55) * arrow,
        );
        final p2 = Offset(
          tip.dx - math.cos(angle + .55) * arrow,
          tip.dy - math.sin(angle + .55) * arrow,
        );
        canvas.drawPath(Path()..moveTo(p1.dx, p1.dy)..lineTo(tip.dx, tip.dy)..lineTo(p2.dx, p2.dy), paint);
      }

      final labelOffset = Offset(
        (start.dx + end.dx) / 2,
        (start.dy + end.dy) / 2 - 13,
      );
      final painter = TextPainter(
        text: TextSpan(
          text: edge.label.replaceAll('_', ' '),
          style: TextStyle(
            color: edge.pending ? TactixTheme.warning : TactixTheme.textMuted,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 150);
      final rect = Rect.fromCenter(
        center: labelOffset,
        width: painter.width + 12,
        height: painter.height + 6,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        Paint()..color = TactixTheme.bg.withValues(alpha: .88),
      );
      painter.paint(canvas, Offset(rect.left + 6, rect.top + 3));
    }
  }

  @override
  bool shouldRepaint(covariant _ThreadEdgesPainter oldDelegate) =>
      oldDelegate.model.signature != model.signature;
}

class _GraphModel {
  const _GraphModel(this.nodes, this.edges);

  static const canvas = Size(1200, 780);
  final List<_GraphNode> nodes;
  final List<_GraphEdge> edges;
  Map<String, _GraphNode> get byKey => {for (final n in nodes) n.key: n};
  String get signature => '${nodes.map((n) => '${n.key}:${n.position}').join('|')}#${edges.map((e) => '${e.fromKey}>${e.toKey}:${e.label}:${e.pending}').join('|')}';

  static _GraphModel build(
    ThreadStore store, {
    required String? selectedCaseId,
    required bool showAll,
    required String relationFilter,
  }) {
    final allCases = store.cases;
    if (allCases.isEmpty) return const _GraphModel([], []);
    final rootId = selectedCaseId ?? allCases.first['id'] as String;
    final root = store.caseById(rootId);
    if (root == null) return const _GraphModel([], []);

    final explicit = store.relations.where((r) =>
        relationFilter == 'ALL' || r['relationship_type'] == relationFilter).toList();
    final caseIds = <String>{rootId};
    if (showAll) {
      caseIds.addAll(allCases.take(24).map((c) => c['id'] as String));
    } else {
      for (final relation in explicit) {
        if (relation['from_type'] == 'CASE' && relation['from_id'] == rootId && relation['to_type'] == 'CASE') {
          caseIds.add(relation['to_id'] as String);
        }
        if (relation['to_type'] == 'CASE' && relation['to_id'] == rootId && relation['from_type'] == 'CASE') {
          caseIds.add(relation['from_id'] as String);
        }
      }
    }

    final selectedCases = allCases.where((c) => caseIds.contains(c['id'])).toList();
    final nodes = <_GraphNode>[];
    final rootCenter = const Offset(600, 385);
    final others = selectedCases.where((c) => c['id'] != rootId).toList();
    nodes.add(_GraphNode.caseNode(root, rootCenter));
    for (var i = 0; i < others.length; i++) {
      final angle = (math.pi * 2 * i / math.max(1, others.length)) - math.pi / 2;
      final radius = showAll ? 300.0 : 270.0;
      nodes.add(_GraphNode.caseNode(
        others[i],
        rootCenter + Offset(math.cos(angle) * radius, math.sin(angle) * radius),
      ));
    }

    // Evidence is intentionally focused around the selected Case to keep a
    // bounded, readable neighborhood even when the cache grows.
    final evidence = (root['evidence'] as List).take(8).toList();
    for (var i = 0; i < evidence.length; i++) {
      final angle = (math.pi * 2 * i / math.max(1, evidence.length)) + math.pi / 8;
      nodes.add(_GraphNode.evidenceNode(
        Map<String, dynamic>.from(evidence[i] as Map),
        rootCenter + Offset(math.cos(angle) * 175, math.sin(angle) * 175),
      ));
    }

    final training = store.trainingForCase(rootId).take(8).toList();
    for (var i = 0; i < training.length; i++) {
      final angle = training.length == 1
          ? 0.0
          : (-math.pi / 3) + (2 * math.pi / 3) * i / math.max(1, training.length - 1);
      nodes.add(_GraphNode.trainingNode(
        training[i],
        rootCenter + Offset(math.cos(angle) * 315, math.sin(angle) * 315),
      ));
    }

    final nodeKeys = nodes.map((n) => n.key).toSet();
    final edges = <_GraphEdge>[];
    for (final relation in explicit) {
      final fromKey = '${relation['from_type']}:${relation['from_id']}';
      final toKey = '${relation['to_type']}:${relation['to_id']}';
      if (!nodeKeys.contains(fromKey) || !nodeKeys.contains(toKey)) continue;
      edges.add(_GraphEdge(
        fromKey,
        toKey,
        relation['relationship_type'] as String,
        pending: relation['pending'] == true,
        highlighted: relation['from_id'] == rootId || relation['to_id'] == rootId,
      ));
    }

    // Evidence belongs to a Case even before an explicit user-created relation
    // exists. Render that structural ownership as a thin implicit edge.
    if (relationFilter == 'ALL' || relationFilter == 'SUPPORTED_BY') {
      for (final item in evidence) {
        final id = (item as Map)['id'] as String;
        final hasExplicit = edges.any((e) =>
            e.fromKey == 'CASE:$rootId' && e.toKey == 'EVIDENCE:$id');
        if (!hasExplicit) {
          edges.add(_GraphEdge(
            'CASE:$rootId',
            'EVIDENCE:$id',
            'SUPPORTED_BY',
            highlighted: true,
          ));
        }
      }
    }
    return _GraphModel(nodes, edges);
  }
}

class _GraphNode {
  const _GraphNode({
    required this.type,
    required this.id,
    required this.label,
    required this.caption,
    required this.position,
    required this.size,
    this.closed = false,
    this.verified = false,
    this.completed = false,
  });

  factory _GraphNode.caseNode(Map<String, dynamic> row, Offset position) =>
      _GraphNode(
        type: 'CASE',
        id: row['id'] as String,
        label: row['title'] as String,
        caption: (row['status'] ?? 'OPEN').toString().replaceAll('_', ' '),
        position: position,
        size: const Size(190, 92),
        closed: row['status'] == 'CLOSED',
      );

  factory _GraphNode.evidenceNode(Map<String, dynamic> row, Offset position) =>
      _GraphNode(
        type: 'EVIDENCE',
        id: row['id'] as String,
        label: (row['title'] ?? 'Evidence').toString(),
        caption: (row['verification_state'] ?? 'UNVERIFIED').toString(),
        position: position,
        size: const Size(160, 82),
        verified: row['verification_state'] == 'VERIFIED',
      );

  factory _GraphNode.trainingNode(Map<String, dynamic> row, Offset position) =>
      _GraphNode(
        type: 'TRAINING',
        id: row['id'] as String,
        label: (row['title'] ?? 'Simulation Lab training').toString(),
        caption: (row['status'] ?? 'assigned').toString().replaceAll('_', ' '),
        position: position,
        size: const Size(178, 88),
        completed: row['status'] == 'submitted',
      );

  final String type;
  final String id;
  final String label;
  final String caption;
  final Offset position;
  final Size size;
  final bool closed;
  final bool verified;
  final bool completed;
  String get key => '$type:$id';
}

class _GraphEdge {
  const _GraphEdge(
    this.fromKey,
    this.toKey,
    this.label, {
    this.pending = false,
    this.highlighted = false,
  });
  final String fromKey;
  final String toKey;
  final String label;
  final bool pending;
  final bool highlighted;
}

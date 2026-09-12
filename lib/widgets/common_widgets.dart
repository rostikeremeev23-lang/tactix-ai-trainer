import 'package:flutter/material.dart';

import '../app/theme.dart';

class StatCard
    extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child:
          Padding(
        padding:
            const EdgeInsets.all(14),
        child:
            Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 24,
            ),
            const SizedBox(
              height: 8,
            ),
            Text(
              value,
              style:
                  const TextStyle(
                fontSize: 24,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(
              height: 3,
            ),
            Text(
              title,
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                color:
                    Colors.white60,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SectionTitle
    extends StatelessWidget {
  final String text;

  const SectionTitle({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style:
          const TextStyle(
        fontSize: 19,
        fontWeight:
            FontWeight.bold,
      ),
    );
  }
}

class AppTextField
    extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 14,
      ),
      child:
          TextField(
        controller:
            controller,
        maxLines:
            maxLines,
        decoration:
            InputDecoration(
          labelText:
              label,
          hintText:
              hint,
          border:
              const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class MetricCard
    extends StatelessWidget {
  final String title;
  final String value;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child:
          Padding(
        padding:
            const EdgeInsets.all(12),
        child:
            Column(
          children: [
            Text(
              title,
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                color:
                    Colors.white60,
                fontSize: 12,
              ),
            ),
            const SizedBox(
              height: 5,
            ),
            Text(
              value,
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                fontSize: 17,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InfoRow
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const InfoRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      child:
          ListTile(
        leading:
            Icon(icon),
        title:
            Text(title),
        trailing:
            SizedBox(
          width: 150,
          child:
              Text(
            value,
            textAlign:
                TextAlign.right,
            overflow:
                TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

class DecisionButton
    extends StatelessWidget {
  final String letter;
  final String text;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const DecisionButton({
    super.key,
    required this.letter,
    required this.text,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary =
        Theme.of(context)
            .colorScheme
            .primary;

    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 10,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap:
              enabled ? onTap : null,
          borderRadius:
              BorderRadius.circular(17),
          child:
              AnimatedContainer(
            duration:
                const Duration(
              milliseconds: 180,
            ),
            padding:
                const EdgeInsets.all(15),
            decoration:
                BoxDecoration(
              borderRadius:
                  BorderRadius.circular(
                17,
              ),
              color: selected
                  ? primary.withValues(
                      alpha: .14,
                    )
                  : Colors.white.withValues(
                      alpha: .035,
                    ),
              border:
                  Border.all(
                color: selected
                    ? primary
                    : Colors.white12,
                width:
                    selected ? 2 : 1,
              ),
              boxShadow:
                  selected
                      ? [
                          BoxShadow(
                            color:
                                primary
                                    .withValues(
                              alpha: .12,
                            ),
                            blurRadius: 18,
                            spreadRadius: 1,
                          ),
                        ]
                      : const [],
            ),
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment:
                      Alignment.center,
                  decoration:
                      BoxDecoration(
                    borderRadius:
                        BorderRadius
                            .circular(
                      12,
                    ),
                    color: selected
                        ? primary
                        : Colors.white10,
                  ),
                  child: Text(
                    letter,
                    style: TextStyle(
                      fontWeight:
                          FontWeight.w900,
                      color: selected
                          ? Colors.white
                          : Colors.white70,
                    ),
                  ),
                ),
                const SizedBox(
                  width: 13,
                ),
                Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets
                            .only(
                      top: 2,
                    ),
                    child: Text(
                      text,
                      style:
                          const TextStyle(
                        fontSize: 14.5,
                        height: 1.45,
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                  width: 8,
                ),
                Icon(
                  selected
                      ? Icons
                          .check_circle
                      : Icons
                          .radio_button_unchecked,
                  color: selected
                      ? primary
                      : Colors.white30,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ScoreRow
    extends StatelessWidget {
  final String title;
  final int value;

  const ScoreRow({
    super.key,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final safe =
        value.clamp(0, 100);

    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 12,
      ),
      child:
          Row(
        children: [
          Expanded(
            child:
                Text(title),
          ),
          SizedBox(
            width: 120,
            child:
                LinearProgressIndicator(
              value:
                  safe / 100,
            ),
          ),
          const SizedBox(
            width: 10,
          ),
          SizedBox(
            width: 35,
            child:
                Text(
              safe.toString(),
              textAlign:
                  TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class PanelCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? accent;
  final Widget child;
  final Widget? trailing;

  const PanelCard({
    super.key,
    required this.title,
    required this.icon,
    this.accent,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TactixTheme.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TactixTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 19, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .45,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                Flexible(child: trailing!),
              ],
            ],
          ),
          const SizedBox(height: 13),
          child,
        ],
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;

  const SectionLabel(
    this.text, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 14,
          decoration: BoxDecoration(
            color: TactixTheme.gold,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: TactixTheme.textMuted,
            letterSpacing: 1.6,
          ),
        ),
      ],
    );
  }
}

class StatusChip extends StatelessWidget {
  final String text;
  final bool online;

  const StatusChip({
    super.key,
    required this.text,
    required this.online,
  });

  @override
  Widget build(BuildContext context) {
    final color = online
        ? const Color(0xFF4EE39A)
        : const Color(0xFFFFC857);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.circle,
            size: 7,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}



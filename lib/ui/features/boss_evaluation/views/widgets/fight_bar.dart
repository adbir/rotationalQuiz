import 'package:flutter/material.dart';

import '../../../../../domain/models/boss_comparison.dart';
import '../../../../core/theme.dart';

/// The fought portion on one row. Wave ticks mark where the stretches start,
/// and each stretch is shaded amber by how far behind rank 1 the player's casts
/// per minute were: full for the worst, clear for on par or ahead.
class FightBar extends StatelessWidget {
  const FightBar({super.key, required this.stretches, required this.shortfall});

  final List<Stretch> stretches;

  /// Per stretch, 0 to 1.
  final List<double> shortfall;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: scheme.onSurfaceVariant);
    return Semantics(
      label: 'Fight bar. Amber stretches are where you were behind rank 1.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 28,
            width: double.infinity,
            child: CustomPaint(
              painter: _FightBarPainter(
                stretches: stretches,
                shortfall: shortfall,
                base: scheme.surfaceContainerHighest,
                tick: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 4),
          _TimeLabels(stretches: stretches, style: style),
          const SizedBox(height: 4),
          Text(
            'Darker amber: further behind rank 1 in buttons per minute. '
            'Clear: on par or ahead.',
            style: style,
          ),
        ],
      ),
    );
  }
}

class _FightBarPainter extends CustomPainter {
  _FightBarPainter({
    required this.stretches,
    required this.shortfall,
    required this.base,
    required this.tick,
  });

  final List<Stretch> stretches;
  final List<double> shortfall;
  final Color base;
  final Color tick;

  @override
  void paint(Canvas canvas, Size size) {
    final total = stretches.last.end.inMilliseconds;
    double x(Duration d) => d.inMilliseconds / total * size.width;
    canvas.drawRect(Offset.zero & size, Paint()..color = base);
    for (var i = 0; i < stretches.length; i++) {
      final a = x(stretches[i].start);
      final b = x(stretches[i].end);
      canvas.drawRect(
        Rect.fromLTRB(a, 0, b, size.height),
        Paint()..color = AppTheme.gapColor.withValues(alpha: shortfall[i]),
      );
      if (i > 0) {
        canvas.drawRect(
          Rect.fromLTWH(a - 1, 0, 2, size.height),
          Paint()..color = tick,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_FightBarPainter old) =>
      old.stretches != stretches ||
      old.shortfall != shortfall ||
      old.base != base;
}

/// "0 s", each wave's time and the end, left to right. A label that would
/// overlap the one before it is skipped; the end label always stays.
class _TimeLabels extends StatelessWidget {
  const _TimeLabels({required this.stretches, required this.style});

  final List<Stretch> stretches;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final total = stretches.last.end.inMilliseconds;
        double width(String t) => (TextPainter(
          text: TextSpan(text: t, style: style),
          textDirection: TextDirection.ltr,
        )..layout()).width;
        final end = '${stretches.last.end.inSeconds} s';
        final endLeft = box.maxWidth - width(end);
        final labels = <(double, String)>[(0, '0 s')];
        var right = width('0 s');
        for (final s in stretches.skip(1)) {
          final t = '${s.start.inSeconds} s';
          final left =
              (s.start.inMilliseconds / total * box.maxWidth - width(t) / 2)
                  .clamp(0.0, box.maxWidth);
          if (left < right + 6 || left + width(t) + 6 > endLeft) continue;
          labels.add((left, t));
          right = left + width(t);
        }
        return SizedBox(
          height: 16,
          child: Stack(
            children: [
              for (final (left, t) in labels)
                Positioned(
                  left: left,
                  child: Text(t, style: style),
                ),
              Positioned(right: 0, child: Text(end, style: style)),
            ],
          ),
        );
      },
    );
  }
}

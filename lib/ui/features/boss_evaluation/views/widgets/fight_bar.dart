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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0 s', style: style),
              Text('${stretches.last.end.inSeconds} s', style: style),
            ],
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

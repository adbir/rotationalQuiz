import 'package:flutter/foundation.dart';

/// What the resource and spenders did around one known event. It says what\r\n/// happened, not why.
@immutable
class PoolingReport {
  const PoolingReport({
    required this.eventTime,
    required this.levelAtEvent,
    required this.lowestBefore,
    required this.highestBefore,
    required this.gapSinceLastSpender,
    this.medianSpenderGap,
    this.firstSpenderAfter,
    this.firstSpenderAfterName,
    required this.isHeld,
  });

  final Duration eventTime;

  /// The resource at the event, and the lowest and highest in the lead-up
  /// window.
  final double levelAtEvent;
  final double lowestBefore;
  final double highestBefore;

  /// Time from the last spender before the event to the event, or from the
  /// pull when there was none.
  final Duration gapSinceLastSpender;

  /// The player's median gap between spender casts over the fight, or `null`
  /// with fewer than two spenders.
  final Duration? medianSpenderGap;

  /// The first spender after the event: how long after, and its name.
  final Duration? firstSpenderAfter;
  final String? firstSpenderAfterName;

  /// No spender for much longer than the player's own rhythm, then one soon
  /// after the event: a spender held for it.
  final bool isHeld;
}

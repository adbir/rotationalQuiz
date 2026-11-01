import 'package:flutter/foundation.dart';

/// What the resource and spenders did around one known event.
@immutable
class PoolingReport {
  const PoolingReport({
    required this.eventTime,
    required this.meanBefore,
    required this.normalLevel,
    required this.spendersBefore,
    required this.spendersAfter,
    required this.isPooled,
    this.levelAtEvent = 0,
    this.lowestBefore = 0,
    this.highestBefore = 0,
    this.gapSinceLastSpender = Duration.zero,
    this.medianSpenderGap,
    this.firstSpenderAfter,
    this.firstSpenderAfterName,
    this.isHeld = false,
  });

  final Duration eventTime;

  /// Mean resource over the lead-up window.
  final double meanBefore;

  /// Mean resource over the whole fight.
  final double normalLevel;

  /// Spender casts in the lead-up window and in the follow window.
  final int spendersBefore;
  final int spendersAfter;

  /// The resource sat [meanBefore] above [normalLevel] by the margin, and
  /// spenders came after the event. This misses a hold that starts from a low
  /// level or ends in a spend; see [isHeld].
  final bool isPooled;

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

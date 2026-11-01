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
  /// spenders came after the event.
  final bool isPooled;
}

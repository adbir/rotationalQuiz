import 'package:flutter/foundation.dart';

/// One stretch with no cast, and what the log shows at that moment. It says
/// what was up, never whether the player could have cast.
@immutable
class GapDetail {
  const GapDetail({
    required this.start,
    required this.length,
    required this.inMovementForm,
    required this.graceUp,
    required this.graceReady,
  });

  /// From the pull.
  final Duration start;
  final Duration length;

  /// Ghost Wolf was cast or up during the gap.
  final bool inMovementForm;

  /// Spiritwalker's Grace was up during the gap.
  final bool graceUp;

  /// Spiritwalker's Grace was off cooldown at the start, from the player's own
  /// casts, and not up.
  final bool graceReady;
}

/// A free spender lost by refreshing the buff that gives it.
@immutable
class LostFreeSpender {
  const LostFreeSpender({required this.time, this.sourceName});

  /// From the pull.
  final Duration time;

  /// The nearest earlier fade of a buff that gives free spenders, or `null`
  /// when none faded before.
  final String? sourceName;
}

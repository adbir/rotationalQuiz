import 'package:flutter/foundation.dart';

/// One cast made while a free-cast buff was up.
@immutable
class FreeCast {
  const FreeCast({
    required this.time,
    required this.abilityId,
    required this.name,
    required this.cost,
  });

  /// When the cast began, from the pull.
  final Duration time;
  final int abilityId;
  final String name;

  /// What the spell's table says it costs, `0` for a spell it doesn't hold.
  final double cost;
}

/// One time the buff was up on the player, and what was cast inside it.
@immutable
class FreeCastWindowUse {
  const FreeCastWindowUse({
    required this.start,
    required this.length,
    required this.casts,
    required this.fill,
  });

  final Duration start;
  final Duration length;
  final List<FreeCast> casts;

  /// The share of the window spent casting, 0 to 1. A GCD cast counts the
  /// longer of its cast time and the base GCD, so haste reads a little high.
  final double fill;

  /// What the casts would have cost without the buff.
  double get manaSaved => casts.fold(0, (sum, c) => sum + c.cost);
}

/// Every window of one free-cast buff in a fight, per spec rule.
@immutable
class FreeCastWindowMetrics {
  const FreeCastWindowMetrics({
    required this.buffId,
    required this.name,
    required this.windows,
  });

  final int buffId;
  final String name;

  /// In fight order. Empty when the player received none.
  final List<FreeCastWindowUse> windows;

  double get manaSaved => windows.fold(0, (sum, w) => sum + w.manaSaved);

  /// Mana saved per window, or `null` with none.
  double? get averageManaSaved =>
      windows.isEmpty ? null : manaSaved / windows.length;
}

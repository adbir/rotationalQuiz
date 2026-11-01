import 'package:flutter/foundation.dart';

import 'debuff_windows.dart';

/// How much of the fight one of the player's DoTs was up on the boss.
@immutable
class DotUptime {
  const DotUptime({
    required this.name,
    required this.windows,
    required this.applications,
  });

  final String name;
  final DebuffWindows windows;

  /// Apply and refresh rows on the boss.
  final int applications;

  /// Of the whole fight, 0 to 100.
  double get percent => windows.uptimePercent;

  Duration get down => windows.length - windows.uptime;

  /// Stretches of a second or more with the DoT down.
  List<DebuffGap> get gaps => windows.gaps;
}

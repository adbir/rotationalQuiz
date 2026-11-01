import 'package:flutter/foundation.dart';

import 'buff_windows.dart';
import 'fight_log.dart';

/// A stretch with the debuff down.
typedef DebuffGap = ({Duration start, Duration length});

/// When one of the player's debuffs was up on the boss. A band runs from an
/// apply to the next remove and a refresh changes nothing, so time before the
/// first apply counts as down.
@immutable
class DebuffWindows {
  factory DebuffWindows.of(FightLog log, int debuffId) {
    final windows = <BuffWindow>[];
    Duration? start;
    for (final event in log.debuffEvents) {
      final boss = log.fight.bossActorId;
      if (event.abilityId != debuffId ||
          (boss != null && event.targetId != boss)) {
        continue;
      }
      switch (event.change) {
        case LogBuffChange.apply:
          start ??= event.time;
        // ponytail: a refresh before any band means a window that began with
        // the debuff already up (it can't refresh otherwise).
        case LogBuffChange.refresh:
          if (start == null && windows.isEmpty) start = Duration.zero;
        case LogBuffChange.remove:
          if (start != null) windows.add(BuffWindow(start, event.time));
          start = null;
        case _:
          break;
      }
    }
    if (start != null) windows.add(BuffWindow(start, log.fight.duration));
    return DebuffWindows._(windows, log.fight.duration);
  }

  const DebuffWindows._(this.windows, this._length);

  /// Shorter gaps are within event-ordering tolerance.
  static const gapThreshold = Duration(seconds: 1);

  final List<BuffWindow> windows;
  final Duration _length;

  Duration get uptime =>
      windows.fold(Duration.zero, (sum, w) => sum + (w.end - w.start));

  /// Of the whole fight, 0 to 100.
  double get uptimePercent =>
      100 * uptime.inMicroseconds / _length.inMicroseconds;

  /// Stretches of [gapThreshold] or more with the debuff down, including
  /// before the first band and after the last.
  List<DebuffGap> get gaps {
    final found = <DebuffGap>[];
    var from = Duration.zero;
    for (final w in [...windows, BuffWindow(_length, _length)]) {
      if (w.start - from >= gapThreshold) {
        found.add((start: from, length: w.start - from));
      }
      from = w.end;
    }
    return found;
  }
}

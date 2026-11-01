import 'package:flutter/foundation.dart';

import 'fight_log.dart';

/// Events from one action can be logged milliseconds apart and in either order.
/// Real logs show a buff ending 1 ms before the cast that spent it, and 3 ms
/// after one, so comparing times exactly undercounts.
const logMoment = Duration(milliseconds: 60);

bool isSameMoment(Duration a, Duration b) => (a - b).abs() <= logMoment;

/// A stretch of a fight with a buff up.
@immutable
class BuffWindow {
  const BuffWindow(this.start, this.end);

  final Duration start;
  final Duration end;
}

/// When one buff was up on the player. A buff that ends and starts again on the
/// same moment is one window.
@immutable
class BuffWindows {
  factory BuffWindows.of(FightLog log, int buffId) {
    final windows = <BuffWindow>[];
    Duration? start;
    var isUp = false;

    void close(Duration end) {
      final begun = start ?? Duration.zero;
      final last = windows.lastOrNull;
      if (last != null && isSameMoment(last.end, begun)) {
        windows.last = BuffWindow(last.start, end);
      } else {
        windows.add(BuffWindow(begun, end));
      }
      start = null;
      isUp = false;
    }

    for (final event in log.buffEvents) {
      if (event.abilityId != buffId || event.targetId != log.playerId) continue;
      switch (event.change) {
        case LogBuffChange.apply:
          if (!isUp) start = event.time;
          isUp = true;
        case LogBuffChange.remove:
          close(event.time);
        case _:
          break;
      }
    }
    if (isUp) close(log.fight.duration);
    return BuffWindows._(windows);
  }

  const BuffWindows._(this.windows);

  /// Windows worked out some other way than from buff events.
  const BuffWindows.fromWindows(this.windows);

  final List<BuffWindow> windows;

  /// Whether the buff was up just before [time], so that something happening
  /// at [time] could use it. A buff applied on that moment comes too late, and
  /// one removed on that moment was still there.
  bool isUpFor(Duration time) {
    final moment = time - logMoment;
    return windows.any((w) => w.start < moment && w.end >= moment);
  }
}

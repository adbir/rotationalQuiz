import '../models/buff_windows.dart';
import '../models/fight_log.dart';
import '../models/free_cast_window.dart';
import '../specs/rotation_spec.dart';

/// What was cast inside each window of a buff that makes casts free.
class ComputeFreeCastMetrics {
  const ComputeFreeCastMetrics(this.spec, this.log);

  /// The GCD with no haste.
  // ponytail: haste shortens it, so fill reads a little high.
  static const _gcd = Duration(milliseconds: 1500);

  final RotationSpec spec;
  final FightLog log;

  /// [events] are the fight's cast events without duplicates, in log order.
  List<FreeCastWindowMetrics> call(List<LogCast> events) => [
    for (final rule in spec.logRules.freeCastWindows)
      FreeCastWindowMetrics(
        buffId: rule.buffId,
        name: rule.name,
        windows: [
          for (final w in BuffWindows.of(log, rule.buffId).windows)
            _use(w, events),
        ],
      ),
  ];

  FreeCastWindowUse _use(BuffWindow window, List<LogCast> events) {
    final inside = BuffWindows.fromWindows([window]);
    final casts = <FreeCast>[];
    var busy = Duration.zero;
    var busyUntil = window.start;
    for (final cast in events) {
      if (cast.isBegin) continue;
      final spell = spec.spells.values
          .where((s) => s.spellId == cast.abilityId)
          .firstOrNull;
      final begin = _begin(cast, events);
      if (!inside.isUpFor(begin)) continue;
      casts.add(
        FreeCast(
          time: begin,
          abilityId: cast.abilityId,
          name: log.abilityNames[cast.abilityId] ?? 'Ability ${cast.abilityId}',
          cost: spell?.cost ?? 0,
        ),
      );
      if (spell == null || spell.offGcd) continue;
      final taken = cast.time - begin;
      final end = begin + (taken > _gcd ? taken : _gcd);
      final from = begin > busyUntil ? begin : busyUntil;
      final to = end < window.end ? end : window.end;
      if (to > from) {
        busy += to - from;
        busyUntil = to;
      }
    }
    final length = window.end - window.start;
    return FreeCastWindowUse(
      start: window.start,
      length: length,
      casts: casts,
      fill: length == Duration.zero
          ? 0
          : busy.inMilliseconds / length.inMilliseconds,
    );
  }

  /// When [cast] began: the last `begincast` of it since the ability's
  /// previous finished cast, else its own time. The spell tables don't all
  /// hold cast times, so none is assumed.
  Duration _begin(LogCast cast, List<LogCast> events) {
    final earlier = events.takeWhile((c) => !identical(c, cast)).toList();
    final previous = earlier
        .where((c) => !c.isBegin && c.abilityId == cast.abilityId)
        .lastOrNull;
    return earlier
            .where(
              (c) =>
                  c.isBegin &&
                  c.abilityId == cast.abilityId &&
                  (previous == null || c.time > previous.time),
            )
            .lastOrNull
            ?.time ??
        cast.time;
  }
}

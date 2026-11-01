import '../models/buff_windows.dart';
import '../models/fight_log.dart';
import '../models/log_rules.dart';
import '../models/window_cast.dart';
import '../specs/rotation_spec.dart';

/// Finds casts made inside a window they belonged before.
class ComputeWindowCastMetrics {
  const ComputeWindowCastMetrics(this.spec, this.log);

  final RotationSpec spec;
  final FightLog log;

  /// [events] are the fight's cast events without duplicates, in log order.
  List<WindowCastMetrics> call(List<LogCast> events) => [
    for (final rule in spec.logRules.castsBeforeWindow)
      WindowCastMetrics(name: rule.name, details: _inside(rule, events)),
  ];

  List<WindowCastDetail> _inside(CastBeforeWindow rule, List<LogCast> events) {
    final windows = BuffWindows.of(log, rule.windowBuffId);
    final spell = spec.spells.values
        .where((s) => s.spellId == rule.castId)
        .firstOrNull;
    final castTime = _span(spell?.castTime ?? 0);
    final details = <WindowCastDetail>[];
    for (final cast in events) {
      if (cast.isBegin || cast.abilityId != rule.castId) continue;
      final begin = events
          .where(
            (c) =>
                c.isBegin &&
                c.abilityId == cast.abilityId &&
                c.time <= cast.time &&
                cast.time - c.time <= castTime * 2,
          )
          .lastOrNull;
      final start = begin?.time ?? cast.time;
      if (!windows.isUpFor(start)) continue;
      final window = windows.windows.firstWhere(
        (w) => w.start < start && w.end >= start,
      );
      details.add(
        WindowCastDetail(
          time: start,
          remaining: window.end - start,
          // ponytail: without a logged begincast this is the cast time with
          // no haste, so a little long.
          lost: begin == null ? castTime : cast.time - start,
        ),
      );
    }
    return details;
  }

  static Duration _span(double seconds) =>
      Duration(milliseconds: (seconds * 1000).round());
}

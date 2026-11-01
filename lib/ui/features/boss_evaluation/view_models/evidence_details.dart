import '../../../../domain/models/boss_comparison.dart';
import '../../../../domain/models/buff_windows.dart';
import '../../../../domain/models/fight_log.dart';
import '../../../../domain/models/player_metrics.dart';
import '../../../../domain/specs/rotation_spec.dart';

/// One cast of a cooldown, and how long after the cooldown came back it was
/// made. `late` is `null` for the first cast and for a cooldown with charges.
class CooldownCast {
  const CooldownCast(this.time, this.late);

  final Duration time;
  final Duration? late;
}

/// Times from the player's own log that the evidence tables list, which the
/// metrics only count: each cast of a cooldown, and the stretches an aura was
/// down.
class EvidenceDetails {
  const EvidenceDetails({
    required this.spec,
    required this.comparison,
    required this.mine,
  });

  final RotationSpec spec;
  final BossComparison comparison;

  /// The player's own fight.
  final FightLog mine;

  Duration get _fought => comparison.fought;

  /// The player's finished casts of the cooldown named [name], over the fought
  /// portion, oldest first.
  List<CooldownCast> cooldownCasts(String name) {
    final metrics = _cooldown(name);
    if (metrics == null) return const [];
    final ids = {
      for (final s in spec.spells.values)
        if (s.cooldownId == metrics.id && s.spellId != null) s.spellId,
    };
    final charges = spec.cooldowns.any(
      (c) => c.id == metrics.id && c.maxCharges != null,
    );
    final times = [
      for (final c in mine.casts)
        if (!c.isBegin && ids.contains(c.abilityId) && c.time < _fought) c.time,
    ];
    return [
      for (final (i, t) in times.indexed)
        CooldownCast(
          t,
          i == 0 || charges ? null : _late(times[i - 1], t, metrics),
        ),
    ];
  }

  Duration _late(Duration previous, Duration at, CooldownMetrics cooldown) {
    final wait = at - previous - Duration(seconds: cooldown.cooldown.round());
    return wait.isNegative ? Duration.zero : wait;
  }

  /// The stretches the player's own aura named [name] was down, over the
  /// fought portion. `null` for an aura on others, which the log gives only
  /// as a total.
  List<BuffWindow>? downStretches(String name) {
    final aura = comparison.logs.first.metrics.upkeep
        .where((u) => u.name == name)
        .firstOrNull;
    if (aura == null || aura.onOthers) return null;
    final up = BuffWindows.of(mine, aura.buffId).windows;
    final down = <BuffWindow>[];
    var from = Duration.zero;
    for (final w in up) {
      if (w.start > from) down.add(BuffWindow(from, w.start));
      if (w.end > from) from = w.end;
    }
    if (from < _fought) down.add(BuffWindow(from, _fought));
    return [
      for (final w in down)
        BuffWindow(w.start, w.end > _fought ? _fought : w.end),
    ];
  }

  CooldownMetrics? _cooldown(String name) => comparison
      .logs
      .first
      .metrics
      .cooldowns
      .where((c) => c.name == name)
      .firstOrNull;
}

import '../models/combat_state.dart';
import '../models/enemy_presence.dart';
import '../models/fight_log.dart';
import '../models/resource_timeline.dart';
import '../models/spec_definition.dart';
import '../specs/rotation_spec.dart';

/// Rebuilds the [CombatState] a player had at a moment of a fight, from the
/// log. What the log can't show is assumed, and [estimated] names the
/// identifiers that rest on such an assumption.
class LogStateBuilder {
  /// [casts] are the fight's finished casts without echoes, in log order.
  LogStateBuilder(
    this.spec,
    this.log,
    this.casts,
    this.timeline, {
    required this.talents,
    this.fightRemainsAfter,
    this.targets = 1,
    this.presence,
    this.maelstromTolerance = 5,
  });

  final RotationSpec spec;
  final FightLog log;
  final List<LogCast> casts;
  final ResourceTimeline timeline;
  final Set<String> talents;

  /// How long the fight went on after the log ends, when the log is a window
  /// of it. `null` means unknown, and `fight_remains` then counts as a guess.
  final Duration? fightRemainsAfter;

  /// Enemies in range, held for the whole log when there is no [presence].
  final int targets;

  /// The enemies alive over the fight. When given, `active_enemies` and
  /// `spell_targets` read the number alive at the moment.
  // ponytail: alive is not in range. An add across the room counts, so this
  // can overcount an AoE ability's targets. The ceiling is a fight where the
  // adds are spread out.
  final EnemyPresence? presence;

  /// Drift between the rebuild and a logged reading that a Maelstrom value
  /// still counts as seen.
  final double maelstromTolerance;

  static const _unknownTail = Duration(minutes: 5);
  static const _flameShockIds = {188389, 470057};

  // ponytail: Flame Shock is on the target and no event shows it. Its time
  // left is rebuilt from the player's casts (pandemic 30%, no haste) and
  // assumed 12 s at the start of the log. The ceiling is a recast the log
  // doesn't show, such as an add's Flame Shock.
  static const _flameShockStart = 12.0;
  static const _flameShockLength = 18.0;

  CombatState at(Duration q) {
    final resource = timeline.at(q);
    final max = spec.maxResource(talents);
    final tail = fightRemainsAfter ?? _unknownTail;
    return CombatState(
      resource: resource > max ? max : resource,
      maxResource: max,
      fightRemains: _seconds(log.fight.duration - q + tail),
      talents: talents,
      targets: presence?.aliveAt(q) ?? targets,
      setBonuses: {for (final bonus in spec.setBonuses) bonus.id},
      buffs: _buffs(q),
      dots: {'flame_shock': _flameShock(q)},
      cooldowns: _cooldowns(q),
    );
  }

  /// The identifiers in [identifiers] that [at] could only guess at [q].
  Set<String> estimated(Iterable<String> identifiers, Duration q) => {
    for (final identifier in identifiers)
      if (_isEstimated(identifier.split('.'), q)) identifier,
  };

  bool _isEstimated(List<String> parts, Duration q) {
    final rules = spec.logRules;
    switch (parts) {
      case ['buff' || 'debuff' || 'dot', final name, ...]:
        final talent = spec.auras
            .where((a) => a.id == name)
            .firstOrNull
            ?.requiredTalent;
        // An aura the build can't have is exactly down.
        if (talent != null && !talents.contains(talent)) return false;
        return parts[0] != 'buff' || rules.unobservableAuras.contains(name);
      case ['cooldown', final name, ...]:
        return _cooldownEstimated(name, q);
      case ['active_dot', ...] || ['target', 'time_to_die']:
        return true;
      case ['spell_targets', ...] || ['active_enemies']:
        return presence == null;
      case ['fight_remains']:
        return fightRemainsAfter == null;
    }
    if (parts.first == spec.resourceName) {
      final checkpoint = timeline.checkpoints
          .where((c) => c.time <= q)
          .lastOrNull;
      return checkpoint != null && checkpoint.drift.abs() > maelstromTolerance;
    }
    return false;
  }

  bool _cooldownEstimated(String id, Duration q) {
    final rules = spec.logRules;
    final shortened = rules.chanceProcs.any(
      (r) =>
          r.cooldownId == id &&
          talents.contains(r.requiredTalent) &&
          talents.contains(r.cooldownTalent),
    );
    return shortened ||
        rules.raidCooldownSupport.containsKey(id) ||
        !_castTimes(id).any((t) => t <= q);
  }

  Map<String, AuraState> _buffs(Duration q) {
    final buffs = <String, AuraState>{
      'lightning_shield': const AuraState.up(remains: 3600),
    };
    for (final aura in spec.auras) {
      if (aura.kind != AuraKind.buff) continue;
      final ids = {?aura.spellId, ...?spec.logRules.auraLogIds[aura.id]};
      var stacks = 0;
      var remains = 0.0;
      for (final id in ids) {
        final state = _buff(id, q);
        stacks += state.stacks;
        if (state.remains > remains) remains = state.remains;
      }
      if (stacks > 0) {
        buffs[aura.id] = AuraState(stacks: stacks, remains: remains);
      }
    }
    return buffs;
  }

  /// A buff on the player at [q]. Time left reads ahead to the log's own
  /// removal, so it is what the buff really had.
  AuraState _buff(int id, Duration q) {
    var stacks = 0;
    Duration? removedAt;
    for (final e in log.buffEvents) {
      if (e.abilityId != id || e.targetId != log.playerId) continue;
      if (e.time > q) {
        if (stacks > 0 && e.change == LogBuffChange.remove) {
          removedAt = e.time;
          break;
        }
        continue;
      }
      stacks = switch (e.change) {
        LogBuffChange.apply => e.stack ?? 1,
        LogBuffChange.applyStack => e.stack ?? stacks + 1,
        LogBuffChange.refresh => stacks == 0 ? 1 : stacks,
        LogBuffChange.removeStack => e.stack ?? (stacks - 1),
        LogBuffChange.remove => 0,
      };
    }
    if (stacks <= 0) return AuraState.down;
    final end = removedAt ?? log.fight.duration;
    return AuraState(stacks: stacks, remains: _seconds(end - q) + 0.001);
  }

  AuraState _flameShock(Duration q) {
    var remains = _flameShockStart;
    var cursor = Duration.zero;
    for (final cast in casts) {
      if (cast.time > q) break;
      if (!_flameShockIds.contains(cast.abilityId)) continue;
      remains = (remains - _seconds(cast.time - cursor)).clamp(0, 99);
      remains = (remains + _flameShockLength).clamp(0, _flameShockLength * 1.3);
      cursor = cast.time;
    }
    remains -= _seconds(q - cursor);
    return remains > 0
        ? AuraState(stacks: 1, remains: remains)
        : AuraState.down;
  }

  Map<String, CooldownState> _cooldowns(Duration q) {
    final cooldowns = <String, CooldownState>{};
    for (final cooldown in spec.cooldowns) {
      if (cooldown.requiredTalent != null &&
          !talents.contains(cooldown.requiredTalent)) {
        continue;
      }
      final duration = spec.cooldownDuration(cooldown, talents);
      final maxCharges = spec.maxCharges(cooldown, talents);
      cooldowns[cooldown.id] = maxCharges == null
          ? _plainCooldown(cooldown, duration, q)
          : CooldownState(charges: _charges(cooldown, maxCharges, duration, q));
    }
    return cooldowns;
  }

  List<Duration> _castTimes(String id) {
    final spellId = spec.spells[id]?.spellId;
    return [
      for (final cast in casts)
        if (cast.abilityId == spellId) cast.time,
    ];
  }

  // ponytail: a cooldown starts at the cast and runs its table length. A cast
  // another player paid for (Time Spiral) and a shortened cooldown (Offering
  // from Beyond) are not seen; those cooldowns are named in [estimated]. One
  // not yet cast in the log is assumed to come off cooldown just as the log
  // first casts it, which hides a late press; one never cast at all is assumed
  // just used.
  CooldownState _plainCooldown(
    CooldownDefinition cooldown,
    double duration,
    Duration q,
  ) {
    final times = _castTimes(cooldown.id);
    final last = times.where((t) => t <= q).lastOrNull;
    if (last != null) {
      final remains = duration - _seconds(q - last);
      return CooldownState(remains: remains > 0 ? remains : 0);
    }
    if (times.isEmpty) return CooldownState(remains: duration);
    final wait = _seconds(times.first - q) - 0.1;
    return CooldownState(remains: wait > 0 ? wait : 0);
  }

  // ponytail: charges start full and refill at the table cooldown (no haste).
  // Lava Surge gives one back. The ceiling is haste, which recharges faster.
  double _charges(
    CooldownDefinition cooldown,
    int maxCharges,
    double duration,
    Duration q,
  ) {
    final surgeId = spec.auraDefinition('lava_surge', AuraKind.buff)?.spellId;
    final spellId = spec.spells[cooldown.id]?.spellId;
    final moments = <(Duration, double)>[
      for (final cast in casts)
        if (cast.abilityId == spellId) (cast.time, -1),
      if (cooldown.id == 'lava_burst')
        for (final e in log.buffEvents)
          if (e.abilityId == surgeId &&
              e.targetId == log.playerId &&
              e.change == LogBuffChange.apply)
            (e.time, 1),
    ]..sort((a, b) => a.$1.compareTo(b.$1));

    var charges = maxCharges.toDouble();
    var cursor = Duration.zero;
    for (final (time, change) in moments) {
      if (time > q) break;
      charges += _seconds(time - cursor) / duration;
      charges = (charges.clamp(0, maxCharges) + change)
          .clamp(0, maxCharges)
          .toDouble();
      cursor = time;
    }
    charges += _seconds(q - cursor) / duration;
    return charges.clamp(0, maxCharges).toDouble();
  }

  static double _seconds(Duration d) => d.inMicroseconds / 1e6;
}

import 'package:flutter/foundation.dart';

import '../models/enemy_group.dart';
import '../models/fight_log.dart';
import '../models/pooling_report.dart';
import '../specs/rotation_spec.dart';

/// One timed line of a raid note: what to show, when, and which icon.
@immutable
class Reminder {
  const Reminder({
    required this.time,
    required this.label,
    required this.spellId,
  });

  /// From the pull.
  final Duration time;
  final String label;
  final int spellId;
}

/// Turns the top log's add-wave behaviour into reminders: when to start
/// pooling, when to press the spender, and when to cast Stormkeeper.
class BuildReminders {
  const BuildReminders(this.spec);

  final RotationSpec spec;

  static const stormkeeperId = 191634;

  /// A Stormkeeper cast this close to a wave was saved for it.
  static const stormkeeperWindow = Duration(seconds: 3);

  /// [reports] are the top log's, one per wave in time order; [casts] are its
  /// casts. Waves it did not hold a spender for give no pool or spender
  /// reminders unless [allWaves].
  // ponytail: one median hold and one median offset for every wave, not each
  // wave's own, so the note reads as a rule. The ceiling is per-wave times.
  List<Reminder> call({
    required List<PoolingReport> reports,
    required List<LogCast> casts,
    required List<EnemyGroup> groups,
    bool allWaves = false,
  }) {
    final spellIds = {
      for (final s in spec.spells.values)
        if (s.spellId != null) s.name: s.spellId!,
    };
    final held = [
      for (final r in reports)
        if (r.isHeld) r,
    ];
    final shown = allWaves ? reports : held;
    final hold = _median([for (final r in held) r.gapSinceLastSpender]);
    final offset = _median([
      for (final r in held)
        if (r.firstSpenderAfter != null) r.firstSpenderAfter!,
    ]);

    final result = <Reminder>[];
    for (final r in shown) {
      final spender = r.firstSpenderAfterName;
      final id = spellIds[spender];
      if (spender == null || id == null) continue;
      final enemy = groups
          .where((g) => g.waveStarts().contains(r.eventTime))
          .map((g) => g.name)
          .firstOrNull;
      if (hold != null) {
        result.add(
          Reminder(
            time: _tenths(r.eventTime - hold),
            label: 'Pool for ${enemy ?? 'the add wave'}',
            spellId: id,
          ),
        );
      }
      if (offset != null) {
        result.add(
          Reminder(
            time: _tenths(r.eventTime + offset),
            label: spender,
            spellId: id,
          ),
        );
      }
    }

    final storms = [
      for (final c in casts)
        if (!c.isBegin && c.abilityId == stormkeeperId) c.time,
    ];
    final stormOffsets = <Duration>[];
    final stormWaves = <Duration>[];
    for (final r in reports) {
      final near = storms
          .where((t) => (t - r.eventTime).abs() <= stormkeeperWindow)
          .firstOrNull;
      if (near == null) continue;
      stormWaves.add(r.eventTime);
      stormOffsets.add(near - r.eventTime);
    }
    final stormOffset = _median(stormOffsets);
    if (stormOffset != null) {
      for (final wave in stormWaves) {
        result.add(
          Reminder(
            time: _tenths(wave + stormOffset),
            label: 'Stormkeeper',
            spellId: stormkeeperId,
          ),
        );
      }
    }
    return result..sort((a, b) => a.time.compareTo(b.time));
  }

  static Duration? _median(List<Duration> values) {
    if (values.isEmpty) return null;
    final sorted = [...values]..sort();
    return sorted[sorted.length ~/ 2];
  }

  static Duration _tenths(Duration d) =>
      Duration(milliseconds: (d.inMilliseconds / 100).round() * 100);
}

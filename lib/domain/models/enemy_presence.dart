import 'package:flutter/foundation.dart';

import 'enemy_group.dart';

/// Which enemies were up, and when, over one fight.
@immutable
class EnemyPresence {
  /// [groups] holds the boss or bosses too, as groups that arrive at the pull
  /// and never leave.
  ///
  /// [hitGroups] is the other fact: the enemies the player's own spells hit,
  /// per kind, in spans (bosses too). Empty when not known.
  const EnemyPresence(this.groups, {this.hitGroups = const []});

  /// A fight with one enemy, up throughout.
  static const single = EnemyPresence([
    EnemyGroup(name: 'Boss', arrivals: [Duration.zero]),
  ]);

  /// When enemies arrived and left (waves), however the player played.
  final List<EnemyGroup> groups;

  /// When the player's own spells were hitting each kind of enemy.
  final List<EnemyGroup> hitGroups;

  /// Enemies up at [time], per kind. Kinds with none are left out.
  Map<String, int> aliveByKindAt(Duration time) => {
    for (final group in groups)
      if (group.aliveAt(time) case final n when n > 0) group.name: n,
  };

  int aliveAt(Duration time) =>
      groups.fold(0, (sum, group) => sum + group.aliveAt(time));

  /// Enemies the player could hit at [time]: the [hitGroups] when there are
  /// any, else everything [aliveAt].
  int targetsAt(Duration time) => hitGroups.isEmpty
      ? aliveAt(time)
      : hitGroups.fold(0, (sum, group) => sum + group.aliveAt(time));
}

import 'package:flutter/foundation.dart';

import 'enemy_group.dart';

/// Which enemies were up, and when, over one fight.
@immutable
class EnemyPresence {
  /// [groups] holds the boss or bosses too, as groups that arrive at the pull
  /// and never leave.
  const EnemyPresence(this.groups);

  /// A fight with one enemy, up throughout.
  static const single = EnemyPresence([
    EnemyGroup(name: 'Boss', arrivals: [Duration.zero]),
  ]);

  final List<EnemyGroup> groups;

  /// Enemies up at [time], per kind. Kinds with none are left out.
  Map<String, int> aliveByKindAt(Duration time) => {
    for (final group in groups)
      if (group.aliveAt(time) case final n when n > 0) group.name: n,
  };

  int aliveAt(Duration time) =>
      groups.fold(0, (sum, group) => sum + group.aliveAt(time));
}

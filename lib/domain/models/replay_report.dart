import 'package:flutter/foundation.dart';

/// How far a deviation can be trusted.
enum ReplayConfidence {
  /// Every identifier the winning condition read was seen in the log.
  exact,

  /// Some identifier was estimated, so the state may be what differs.
  uncertain,
}

/// A press that was not what the APL wanted.
@immutable
class ReplayDeviation {
  const ReplayDeviation({
    required this.time,
    required this.pressed,
    required this.wanted,
    required this.winningLine,
    required this.confidence,
    this.estimated = const {},
  });

  /// Measured from the pull.
  final Duration time;

  /// SimC action names.
  final String pressed;
  final String? wanted;

  /// The APL line that won, as written, or `null` if nothing was castable.
  final String? winningLine;
  final ReplayConfidence confidence;

  /// The identifiers of the winning condition that came from an estimate.
  final Set<String> estimated;
}

/// A press counted as agreement with something to say about it.
@immutable
class ReplayNote {
  const ReplayNote(this.time, this.text);

  final Duration time;
  final String text;
}

/// What replaying a log through the APL found: what the player pressed
/// against what the APL wanted. It says what happened, never why.
@immutable
class ReplayReport {
  const ReplayReport({
    required this.compared,
    required this.agreements,
    required this.deviations,
    required this.notes,
    required this.skippedPresses,
    required this.skippedOffGcd,
  });

  /// GCD presses of abilities the spec models.
  final int compared;

  /// Presses that matched, including lenient ones listed in [notes].
  final int agreements;
  final List<ReplayDeviation> deviations;
  final List<ReplayNote> notes;

  /// Presses of abilities outside the spec's table, such as Ghost Wolf.
  final int skippedPresses;

  /// Off-GCD abilities the APL wanted with a press that the log doesn't show.
  /// They don't change the score, as in the quiz.
  final int skippedOffGcd;

  double get agreementRate => compared == 0 ? 1 : agreements / compared;

  /// Deviations the log's own state backs up.
  List<ReplayDeviation> get exactDeviations => [
    for (final d in deviations)
      if (d.confidence == ReplayConfidence.exact) d,
  ];

  /// How often each "pressed X, wanted Y" happened, most common first.
  Map<String, int> get kinds {
    final counts = <String, int>{};
    for (final d in deviations) {
      final key = '${d.pressed} instead of ${d.wanted ?? 'nothing'}';
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return {for (final e in sorted) e.key: e.value};
  }
}

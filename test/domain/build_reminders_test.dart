import 'package:flutter_test/flutter_test.dart';
import 'package:rotational_quiz/domain/models/enemy_group.dart';
import 'package:rotational_quiz/domain/models/fight_log.dart';
import 'package:rotational_quiz/domain/models/pooling_report.dart';
import 'package:rotational_quiz/domain/use_cases/build_reminders.dart';
import 'package:rotational_quiz/domain/use_cases/format_nsrt_note.dart';

import '../test_helpers.dart';

Duration s(double seconds) => Duration(milliseconds: (seconds * 1000).round());

PoolingReport report(double wave, {required bool held, double gap = 5}) =>
    PoolingReport(
      eventTime: s(wave),
      levelAtEvent: 80,
      lowestBefore: 20,
      highestBefore: 80,
      gapSinceLastSpender: s(gap),
      firstSpenderAfter: s(2),
      firstSpenderAfterName: 'Earthquake',
      isHeld: held,
    );

LogCast cast(double at, int id) =>
    LogCast(time: s(at), abilityId: id, targetId: 1, isBegin: false);

void main() {
  final groups = [
    EnemyGroup(name: 'Broodlings', arrivals: [s(37), s(98)]),
  ];
  final reports = [
    report(37, held: false, gap: 4.6),
    report(98, held: true, gap: 17.8),
  ];
  final earthquake = spec.spells['earthquake']!.spellId!;

  test('a held wave gives a pool and a spender reminder', () {
    final reminders = BuildReminders(spec)(
      reports: reports,
      casts: const [],
      groups: groups,
    );
    expect(reminders.map((r) => (r.time, r.label, r.spellId)), [
      (s(80.2), 'Pool for Broodlings', earthquake),
      (s(100), 'Earthquake', earthquake),
    ]);
  });

  test('All waves adds the waves that were not held', () {
    final reminders = BuildReminders(spec)(
      reports: reports,
      casts: const [],
      groups: groups,
      allWaves: true,
    );
    expect(reminders.length, 4);
    expect(reminders.first.time, s(37 - 17.8));
  });

  test(
    'Stormkeeper within 3 s of a wave is a reminder at its median offset',
    () {
      final reminders = BuildReminders(spec)(
        reports: reports,
        casts: [
          cast(38.5, BuildReminders.stormkeeperId),
          cast(97.7, BuildReminders.stormkeeperId),
          cast(130, BuildReminders.stormkeeperId),
        ],
        groups: groups,
      );
      final storm = reminders.where((r) => r.label == 'Stormkeeper');
      // Offsets +1.5 and -0.3; the upper median is +1.5. A cast 3.2 s after a wave is too far.
      expect(storm.map((r) => r.time), [s(38.5), s(99.5)]);
    },
  );

  test('formats the NSRT note exactly', () {
    final text = formatNsrtNote(
      encounterId: 3421,
      difficulty: 'Mythic',
      boss: 'The Twin Fangs',
      reminders: const [
        Reminder(
          time: Duration(milliseconds: 100200),
          label: 'Earthquake',
          spellId: 61882,
        ),
        Reminder(
          time: Duration(milliseconds: 700),
          label: 'Stormkeeper',
          spellId: 191634,
        ),
      ],
    );
    expect(
      text,
      'EncounterID:3421;Difficulty:Mythic;Name:The Twin Fangs;\n'
      'ph:1;time:0.7;tag:Stormkeeper;spellid:191634;\n'
      'ph:1;time:100.2;tag:Earthquake;spellid:61882;',
    );
  });
}

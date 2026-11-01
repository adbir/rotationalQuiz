import 'package:flutter_test/flutter_test.dart';
import 'package:rotational_quiz/domain/models/boss_comparison.dart';
import 'package:rotational_quiz/domain/models/finding.dart';
import 'package:rotational_quiz/domain/use_cases/compare_fights.dart';
import 'package:rotational_quiz/domain/use_cases/rank_findings.dart';
import 'package:rotational_quiz/utils/result.dart';

import '../fake_warcraft_logs_repository.dart';
import '../test_helpers.dart';

Future<BossComparison> compare(List<String> reports) async {
  final fake = FakeWarcraftLogsRepository();
  final fights = <FightToCompare>[];
  for (final (i, code) in reports.indexed) {
    final log = switch (await fake.loadFight(reportCode: code, fightId: 1)) {
      Ok(:final value) => value,
      Error(:final error) => throw error,
    };
    fights.add(FightToCompare(label: 'Log $i', log: log));
  }
  final groups = switch (await fake.loadEnemyGroups(
    reportCode: 'mine',
    fightId: 1,
  )) {
    Ok(:final value) => value,
    Error(:final error) => throw error,
  };
  return CompareFights(spec)(fights, groups);
}

void main() {
  test('leads with casts per minute, then orders by the difference, at most three', () async {
    final report = const RankFindings()(
      await compare([FakeWarcraftLogsRepository.mine, 'rank53', 'rank1']),
    );
    expect(report.findings.length, lessThanOrEqualTo(3));
    expect(report.findings, isNotEmpty);
    // Casts per minute leads; the rest follow by how far behind in their unit.
    expect(report.findings.first.kind, FindingKind.castsPerMinute);
    final rest = [for (final f in report.findings.skip(1)) f.behind];
    expect(rest, [...rest]..sort((a, b) => b.compareTo(a)));
    final shares = [for (final f in report.findings) f.share];
    expect(shares.every((s) => s >= RankFindings.sameShare), isTrue);

    final casts = report.findings.firstWhere(
      (f) => f.kind == FindingKind.castsPerMinute,
    );
    expect(casts.yours, lessThan(casts.rank1));
    expect(casts.valuesByLog, hasLength(3));
    expect(casts.stretchIndexes, isNotEmpty);
    expect(report.stretchShortfall.reduce((a, b) => a > b ? a : b), 1);
    for (final f in report.findings) {
      expect(report.sameAsRank1, isNot(contains(f.kind)));
    }
  });

  test('a log identical to rank 1 has no findings, all the same', () async {
    final report = const RankFindings()(await compare(['rank1', 'rank1']));
    expect(report.findings, isEmpty);
    expect(report.sameAsRank1, hasLength(4));
    expect(report.stretchShortfall.every((s) => s == 0), isTrue);
  });

  test('every kind has a fixed sentence', () {
    for (final kind in FindingKind.values) {
      expect(kind.whatToTry, endsWith('.'));
    }
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:rotational_quiz/domain/models/boss_comparison.dart';
import 'package:rotational_quiz/domain/use_cases/compare_fights.dart';
import 'package:rotational_quiz/ui/features/boss_evaluation/views/widgets/log_header_table.dart';

import '../test_helpers.dart';
import 'player_metrics_fixture_test.dart' show loadFixture;

void main() {
  test('a comparison lists the raid buffs each fixture window received', () {
    final c = CompareFights(spec)([
      FightToCompare(label: 'You', log: loadFixture()),
      FightToCompare(label: 'Rank 1', log: loadFixture('twin_fangs_window')),
    ], const []);

    expect(c.logs.first.raidSupport.map((r) => r.name), [
      'Power Infusion',
      'Ebon Might',
      'Time Spiral',
    ], reason: "in the rule's order, not the table's");
    final ebon = c.logs.first.raidSupport[1];
    expect(ebon.uptimePercent, closeTo(93.84, 0.01));
    expect(ebon.uses, 12);
    expect(
      LogHeaderTable.raidSupportText(c.logs.last),
      'Ebon Might 92.5% (9), Time Spiral 18% (2)',
    );
  });

  test('a log with none of them says none seen', () {
    final c = CompareFights(spec)([
      FightToCompare(label: 'You', log: loadFixture()),
    ], const []);
    expect(
      LogHeaderTable.raidSupportText(
        ComparedLog(label: 'x', metrics: c.logs.first.metrics, kill: true),
      ),
      'none seen',
    );
  });
}

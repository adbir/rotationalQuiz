import 'package:flutter_test/flutter_test.dart';
import 'package:rotational_quiz/domain/models/report_reference.dart';

void main() {
  test('reads report, fight and source from the query', () {
    final ref = parseReportUrl(
      ' https://www.warcraftlogs.com/reports/dvpkyx8D4YnAHGJK?fight=18&source=278 ',
    )!;
    expect(ref.code, 'dvpkyx8D4YnAHGJK');
    expect(ref.fightId, 18);
    expect(ref.sourceId, 278);
  });

  test('reads values after a #, and ignores other parameters', () {
    final ref = parseReportUrl(
      'https://classic.warcraftlogs.com/reports/a:AbC123#fight=2&source=5&type=casts',
    )!;
    expect((ref.code, ref.fightId, ref.sourceId), ('a:AbC123', 2, 5));
  });

  test('needs a report, a numeric fight and a source', () {
    for (final bad in [
      '',
      'not a link',
      'https://www.warcraftlogs.com/reports/',
      'https://www.warcraftlogs.com/reports/abc?fight=3',
      'https://www.warcraftlogs.com/reports/abc?source=3',
      'https://www.warcraftlogs.com/reports/abc?fight=last&source=3',
      'https://www.warcraftlogs.com/guild/id/1?fight=3&source=3',
      'https://www.warcraftlogs.com/reports/a%20b?fight=3&source=3',
    ]) {
      expect(parseReportUrl(bad), isNull, reason: bad);
    }
  });
}

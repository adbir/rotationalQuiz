import 'package:flutter_test/flutter_test.dart';
import 'package:rotational_quiz/domain/talents/generated/shaman_talent_tree.g.dart';
import 'package:rotational_quiz/domain/talents/talent_string_codec.dart';

// Real builds from SimulationCraft's profiles/MID2 directory.
const farseer =
    'CYQAAAAAAAAAAAAAAAAAAAAAAAAAAAzMbbzMmZmZZbZMMjBAAAAsYmNYADY2YCZWAgZbmZGjtF'
    'TYmxYxMzMmZWsMjFzMMzyAAGGAzMGGGA';
const stormbringer =
    'CYQAAAAAAAAAAAAAAAAAAAAAAAAAAAzMbbzMmZmZZbZgxMDAAAAAWMjhNYBmRDN2AgZbmZGjtF'
    'TYmxYxMzMmZWsMjFzMjZWAAGGYmBGGGA';
// An Enhancement build from profiles/MID2.
const enhancement =
    'CcQAAAAAAAAAAAAAAAAAAAAAAMzMjZGGDzMzMzMbzMWGAAAAAAAAAAgFYDmxiGbDgZC2AwsMZGYZZMzM'
    'DmZmNjlZmJbsMMmZAAGA';

void main() {
  const codec = TalentStringCodec(shamanTalentTree);
  const elemental = 262;

  test('reads the spec id', () {
    expect(TalentStringCodec.specIdOf(farseer), elemental);
    expect(TalentStringCodec.specIdOf(enhancement), 263);
  });

  test('decodes the SimC Farseer profile', () {
    final build = codec.decode(farseer, expectedSpecId: elemental);
    expect(build.heroTreeId, 56);
    expect(build.tokens, contains('call_of_the_ancestors'));
    expect(build.tokens, contains('ancestral_swiftness'));
    expect(build.tokens, isNot(contains('tempest')));
    expect(build.tokens, containsAll(['stormkeeper', 'ascendance']));
    // Earth Shock / Elemental Blast is a choice node: exactly one is taken.
    expect(
      build.tokens.contains('earth_shock') ^
          build.tokens.contains('elemental_blast'),
      isTrue,
    );
  });

  test('decodes the SimC Stormbringer profile', () {
    final build = codec.decode(stormbringer, expectedSpecId: elemental);
    expect(build.heroTreeId, 55);
    expect(build.tokens, contains('tempest'));
    expect(build.tokens, isNot(contains('call_of_the_ancestors')));
  });

  test('rejects strings for another spec', () {
    expect(
      () => codec.decode(enhancement, expectedSpecId: elemental),
      throwsA(isA<TalentStringException>()),
    );
  });

  test('rejects garbage', () {
    expect(() => codec.decode(''), throwsA(isA<TalentStringException>()));
    expect(() => codec.decode('abc'), throwsA(isA<TalentStringException>()));
    expect(
      () => codec.decode('${farseer.substring(0, 40)}!'),
      throwsA(isA<TalentStringException>()),
    );
  });
}

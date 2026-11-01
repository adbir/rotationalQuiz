import 'package:flutter_test/flutter_test.dart';
import 'package:rotational_quiz/domain/specs/restoration_shaman.dart';
import 'package:rotational_quiz/domain/specs/restoration_shaman_data.dart';
import 'package:rotational_quiz/domain/talents/talent_string_codec.dart';

void main() {
  const spec = RestorationShaman();
  final codec = TalentStringCodec(spec.talentTree);

  // Written from the rank 1 Heroic Coiled Altar log's CombatantInfo, with a
  // zero tree hash. SimC ships no Restoration profile.
  test('the top Heroic build decodes to its Totemic spec and hero talents', () {
    final build = codec.decode(topHeroicExport, expectedSpecId: spec.specId);
    expect(build.heroTreeId, 54);
    expect(build.tokens, containsAll(spec.loadouts.single.talents));
    expect(spec.loadouts.single.exportString, topHeroicExport);
    expect(spec.heroTreeNames, {54: 'Totemic', 56: 'Farseer'});
  });

  test('rejects an Elemental build for Restoration', () {
    const elemental =
        'CYQAAAAAAAAAAAAAAAAAAAAAAAAAAAzMbbzMmZmZZbZMMjBAAAAsYmNYADY2YCZWAgZbmZGjtF'
        'TYmxYxMzMmZWsMjFzMMzyAAGGAzMGGGA';
    expect(
      () => codec.decode(elemental, expectedSpecId: spec.specId),
      throwsA(isA<TalentStringException>()),
    );
  });
}

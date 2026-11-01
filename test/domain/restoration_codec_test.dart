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
    expect(build.tokens, containsAll(spec.loadouts.first.talents));
    expect(spec.loadouts.first.exportString, topHeroicExport);
    expect(spec.heroTreeNames, {54: 'Totemic', 56: 'Farseer'});
  });

  // Written from the Mythic rank 1 ranking's CombatantInfo talents, the same
  // way. The Heroic build stays first.
  test('the top Mythic build decodes to its swaps against the Heroic one', () {
    final build = codec.decode(topMythicExport, expectedSpecId: spec.specId);
    final mythic = spec.loadouts[1];
    expect(build.heroTreeId, 54);
    expect(build.tokens, containsAll(mythic.talents));
    expect(mythic.exportString, topMythicExport);
    expect(mythic.name, 'Top Mythic logs, Totemic, 2026-11-01');
    final heroic = spec.loadouts.first.talents;
    expect(mythic.talents.difference(heroic), {'acid_rain', 'oversurge'});
    expect(heroic.difference(mythic.talents), {
      'torrent',
      'amplification_core',
    });
    expect(build.tokens, isNot(contains('torrent')));
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

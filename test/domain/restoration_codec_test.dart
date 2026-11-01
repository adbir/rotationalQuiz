import 'package:flutter_test/flutter_test.dart';
import 'package:rotational_quiz/domain/specs/restoration_shaman.dart';
import 'package:rotational_quiz/domain/talents/talent_string_codec.dart';

// SimC ships no Restoration Shaman profile (profiles/MID2 has Elemental and
// Enhancement only), so there is no real export string in the repo yet. This
// test writes one in the export format (version 2, spec 264, a zero tree hash,
// then the node bits the codec reads) selecting one spec talent and a hero
// tree. Replace it with a real string when the research ticket has one.
String _export(RestorationShaman spec, {required int heroTree}) {
  final bits = <int>[];
  void write(int value, int width) {
    for (var i = 0; i < width; i++) {
      bits.add((value >> i) & 1);
    }
  }

  write(2, 8);
  write(spec.specId, 16);
  write(0, 128);
  for (final node in spec.talentTree.nodes) {
    final entryIndex = node.entries.indexWhere(
      (e) => e.tree == 4 && e.availableTo(spec.specId) && e.subTree == heroTree,
    );
    final isPrimalTideCore = node.entries.any(
      (e) => e.token == 'primal_tide_core',
    );
    if (entryIndex < 0 && !isPrimalTideCore) {
      write(0, 1);
      continue;
    }
    write(1, 1); // selected
    write(1, 1); // purchased
    write(0, 1); // not partially ranked
    if (entryIndex < 0) {
      write(0, 1); // no choice
    } else {
      write(1, 1);
      write(entryIndex, 2);
    }
  }
  const alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  final text = StringBuffer();
  for (var i = 0; i < bits.length; i += 6) {
    var char = 0;
    for (var b = 0; b < 6 && i + b < bits.length; b++) {
      char |= bits[i + b] << b;
    }
    text.write(alphabet[char]);
  }
  return text.toString();
}

void main() {
  const spec = RestorationShaman();
  final codec = TalentStringCodec(spec.talentTree);

  test('hero trees are the ones the Restoration selection node offers', () {
    for (final tree in spec.heroTreeNames.keys) {
      final build = codec.decode(
        _export(spec, heroTree: tree),
        expectedSpecId: spec.specId,
      );
      expect(build.heroTreeId, tree);
      expect(build.tokens, contains('primal_tide_core'));
    }
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

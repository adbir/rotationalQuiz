import 'package:flutter_test/flutter_test.dart';
import 'package:rotational_quiz/data/repositories/keybind_repository.dart';
import 'package:rotational_quiz/data/repositories/talent_build_repository.dart';
import 'package:rotational_quiz/data/services/local_store.dart';
import 'package:rotational_quiz/domain/models/keybind.dart';
import 'package:rotational_quiz/utils/result.dart';

import '../domain/talent_string_codec_test.dart' as strings;
import '../test_helpers.dart';

void main() {
  group('KeybindRepository', () {
    const one = Keybind(code: 0x0007001e, keyLabel: '1');
    const mouse4 = Keybind(code: -4, keyLabel: 'Mouse 4', shift: true);

    test('persists binds', () async {
      final store = InMemoryStore();
      final repo = KeybindRepository(spec: spec, store: store);
      await repo.bind('lava_burst', one);
      await repo.bind('earth_shock', mouse4);

      final reloaded = KeybindRepository(spec: spec, store: store);
      expect(reloaded.bindFor('lava_burst'), one);
      expect(reloaded.bindFor('earth_shock'), mouse4);
      expect(reloaded.bindFor('earth_shock')!.shortLabel, 'SM4');
      expect(reloaded.spellFor(one), 'lava_burst');
    });

    test('a key moves to the newly bound spell', () async {
      final repo = KeybindRepository(spec: spec, store: InMemoryStore());
      await repo.bind('lava_burst', one);
      final displaced = await repo.bind('lightning_bolt', one);
      expect(displaced, 'lava_burst');
      expect(repo.bindFor('lava_burst'), isNull);
      expect(repo.spellFor(one), 'lightning_bolt');
    });

    test('ignores corrupt data', () {
      final store = InMemoryStore({'keybinds.${spec.id}': '{not json'});
      expect(KeybindRepository(spec: spec, store: store).binds, isEmpty);
    });
  });

  group('TalentBuildRepository', () {
    test('defaults to the first reference build', () {
      final repo = TalentBuildRepository(spec: spec, store: InMemoryStore());
      expect(repo.active, spec.loadouts.first);
      expect(repo.customLoadouts, isEmpty);
    });

    test('imports, activates and persists a build', () async {
      final store = InMemoryStore();
      final repo = TalentBuildRepository(spec: spec, store: store);
      final result = await repo.importBuild(
        name: 'Raid',
        exportString: ' ${strings.stormbringer}\n',
      );
      expect(result, isA<Ok<Object>>());
      expect(repo.active.name, 'Raid');
      expect(repo.active.talents, contains('tempest'));
      expect(repo.active.description, contains('Stormbringer'));

      final reloaded = TalentBuildRepository(spec: spec, store: store);
      expect(reloaded.active.name, 'Raid');
      expect(reloaded.active.talents, repo.active.talents);

      await reloaded.delete(reloaded.active);
      expect(reloaded.active, spec.loadouts.first);
    });

    test('rejects builds for other specs', () async {
      final repo = TalentBuildRepository(spec: spec, store: InMemoryStore());
      final result = await repo.importBuild(
        name: 'Enh',
        exportString: strings.enhancement,
      );
      expect(result, isA<Error<Object>>());
      expect(repo.customLoadouts, isEmpty);
    });
  });
}

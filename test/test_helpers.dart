import 'dart:io';

import 'package:flutter/services.dart';
import 'package:rotational_quiz/data/repositories/apl_repository.dart';
import 'package:rotational_quiz/data/repositories/keybind_repository.dart';
import 'package:rotational_quiz/data/repositories/talent_build_repository.dart';
import 'package:rotational_quiz/data/services/apl_asset_service.dart';
import 'package:rotational_quiz/data/services/local_store.dart';
import 'package:rotational_quiz/data/services/simc_remote_service.dart';
import 'package:rotational_quiz/domain/specs/elemental_shaman.dart';

/// Serves assets straight from the project directory.
class FileAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final bytes = await File(key).readAsBytes();
    return ByteData.sublistView(bytes);
  }
}

const spec = ElementalShaman();

/// A repository with the bundled Elemental APL already loaded.
Future<AplRepository> loadedRepository() async {
  final repository = AplRepository(
    spec: spec,
    assetService: AplAssetService(bundle: FileAssetBundle()),
    remoteService: SimcRemoteService(),
  );
  await repository.loadBundled();
  return repository;
}

/// Everything the view models need, backed by an in-memory store.
class TestRepositories {
  TestRepositories._(this.apl, this.store)
    : talentBuilds = TalentBuildRepository(spec: spec, store: store),
      keybinds = KeybindRepository(spec: spec, store: store);

  static Future<TestRepositories> create([LocalStore? store]) async =>
      TestRepositories._(await loadedRepository(), store ?? InMemoryStore());

  final AplRepository apl;
  final LocalStore store;
  final TalentBuildRepository talentBuilds;
  final KeybindRepository keybinds;
}

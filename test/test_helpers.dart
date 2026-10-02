import 'dart:io';

import 'package:flutter/services.dart';
import 'package:rotational_quiz/data/repositories/apl_repository.dart';
import 'package:rotational_quiz/data/services/apl_asset_service.dart';
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

/// A repository with the bundled Elemental APL already loaded.
Future<AplRepository> loadedRepository() async {
  final repository = AplRepository(
    spec: const ElementalShaman(),
    assetService: AplAssetService(bundle: FileAssetBundle()),
    remoteService: SimcRemoteService(),
  );
  await repository.loadBundled();
  return repository;
}

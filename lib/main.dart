import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/repositories/apl_repository.dart';
import 'data/repositories/keybind_repository.dart';
import 'data/repositories/talent_build_repository.dart';
import 'data/services/apl_asset_service.dart';
import 'data/services/local_store.dart';
import 'data/services/simc_remote_service.dart';
import 'domain/specs/elemental_shaman.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const spec = ElementalShaman();
  final store = await SharedPreferencesStore.create();

  final aplRepository = AplRepository(
    spec: spec,
    assetService: const AplAssetService(),
    remoteService: SimcRemoteService(),
  );
  // The UI shows a spinner until the APL is in; no need to delay startup.
  unawaited(aplRepository.loadBundled());

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: aplRepository),
        ChangeNotifierProvider(
          create: (_) => TalentBuildRepository(spec: spec, store: store),
        ),
        ChangeNotifierProvider(
          create: (_) => KeybindRepository(spec: spec, store: store),
        ),
      ],
      child: const RotationalQuizApp(),
    ),
  );
}

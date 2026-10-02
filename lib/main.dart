import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/repositories/apl_repository.dart';
import 'data/services/apl_asset_service.dart';
import 'data/services/simc_remote_service.dart';
import 'domain/specs/elemental_shaman.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final repository = AplRepository(
    spec: const ElementalShaman(),
    assetService: const AplAssetService(),
    remoteService: SimcRemoteService(),
  )..loadBundled();

  runApp(
    ChangeNotifierProvider.value(
      value: repository,
      child: const RotationalQuizApp(),
    ),
  );
}

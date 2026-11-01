import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/repositories/apl_repository.dart';
import 'data/repositories/keybind_repository.dart';
import 'data/repositories/spell_icon_repository.dart';
import 'data/repositories/talent_build_repository.dart';
import 'data/repositories/warcraft_logs_repository.dart';
import 'data/services/apl_asset_service.dart';
import 'data/services/browser_navigation.dart';
import 'data/services/local_store.dart';
import 'data/services/pkce_access_token_source.dart';
import 'data/services/simc_remote_service.dart';
import 'data/services/spell_icon_service.dart';
import 'data/services/warcraft_logs_service.dart';
import 'domain/specs/elemental_shaman.dart';
import 'ui/core/widgets/spell_icon.dart';

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

  final warcraftLogs = PkceAccessTokenSource(
    store: store,
    client: http.Client(),
    navigation: platformNavigation(),
    redirectUri: wclRedirectUri(),
  );
  // Finishes a sign-in when the page is the return from Warcraft Logs.
  unawaited(warcraftLogs.handleRedirect());

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: aplRepository),
        ChangeNotifierProvider.value(value: warcraftLogs),
        Provider(
          create: (_) => WarcraftLogsRepository(
            spec: spec,
            service: WarcraftLogsService(
              accessToken: warcraftLogs.call,
              endpoint: WarcraftLogsService.userEndpoint,
            ),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => TalentBuildRepository(spec: spec, store: store),
        ),
        ChangeNotifierProvider(
          create: (_) => KeybindRepository(spec: spec, store: store),
        ),
      ],
      child: SpellIconScope(
        repository: SpellIconRepository(
          service: SpellIconService(),
          store: store,
        ),
        child: const RotationalQuizApp(),
      ),
    ),
  );
}

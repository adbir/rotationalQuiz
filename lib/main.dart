import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/repositories/active_spec_repository.dart';
import 'data/repositories/spell_icon_repository.dart';
import 'data/services/browser_navigation.dart';
import 'data/services/local_store.dart';
import 'data/services/pkce_access_token_source.dart';
import 'data/services/spell_icon_service.dart';
import 'domain/specs/elemental_shaman.dart';
import 'domain/specs/restoration_shaman.dart';
import 'ui/core/widgets/spell_icon.dart';
import 'ui/features/home/views/spec_host.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final store = await SharedPreferencesStore.create();

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
        ChangeNotifierProvider.value(value: warcraftLogs),
        Provider<LocalStore>.value(value: store),
        ChangeNotifierProvider(
          create: (_) => ActiveSpecRepository(
            specs: const [ElementalShaman(), RestorationShaman()],
            store: store,
          ),
        ),
      ],
      child: SpellIconScope(
        repository: SpellIconRepository(
          service: SpellIconService(),
          store: store,
        ),
        child: const SpecHost(child: RotationalQuizApp()),
      ),
    ),
  );
}

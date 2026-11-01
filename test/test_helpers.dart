import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rotational_quiz/data/repositories/apl_repository.dart';
import 'package:rotational_quiz/data/repositories/keybind_repository.dart';
import 'package:rotational_quiz/data/repositories/talent_build_repository.dart';
import 'package:rotational_quiz/data/services/apl_asset_service.dart';
import 'package:rotational_quiz/data/services/browser_navigation.dart';
import 'package:rotational_quiz/data/services/local_store.dart';
import 'package:rotational_quiz/data/services/pkce_access_token_source.dart';
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
  late final warcraftLogs = PkceAccessTokenSource(
    store: store,
    client: MockClient(
      (_) async =>
          http.Response('{"access_token":"abc","expires_in":3600}', 200),
    ),
    navigation: navigation,
    redirectUri: FakeNavigation.site,
  );

  /// The fake browser behind [warcraftLogs]; see [signInWithCode].
  final navigation = FakeNavigation();

  /// Runs the return from Warcraft Logs, which leaves [warcraftLogs] signed in.
  Future<void> signInWithCode() async {
    await store.setString(PkceAccessTokenSource.verifierKey, 'verifier');
    await store.setString(PkceAccessTokenSource.stateKey, 'state');
    navigation.current = FakeNavigation.site.replace(
      queryParameters: {'code': 'the-code', 'state': 'state'},
    );
    await warcraftLogs.handleRedirect();
  }
}

/// A browser that records where sign-in sent it.
class FakeNavigation implements BrowserNavigation {
  static final site = Uri.parse('https://adbir.github.io/rotationalQuiz/');

  @override
  Uri current = site;

  Uri? wentTo;

  @override
  void goTo(Uri url) => wentTo = url;

  @override
  void replaceUrl(Uri url) => current = url;
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/repositories/active_spec_repository.dart';
import '../../../../data/repositories/apl_repository.dart';
import '../../../../data/repositories/keybind_repository.dart';
import '../../../../data/repositories/talent_build_repository.dart';
import '../../../../data/repositories/warcraft_logs_repository.dart';
import '../../../../data/services/apl_asset_service.dart';
import '../../../../data/services/local_store.dart';
import '../../../../data/services/pkce_access_token_source.dart';
import '../../../../data/services/simc_remote_service.dart';
import '../../../../data/services/warcraft_logs_service.dart';

/// Provides the per-spec repositories for the active spec, and rebuilds them
/// (and everything below) when the user picks another spec.
///
/// Needs [ActiveSpecRepository], [LocalStore] and [PkceAccessTokenSource]
/// above it.
class SpecHost extends StatelessWidget {
  const SpecHost({
    super.key,
    required this.child,
    this.aplAssets = const AplAssetService(),
    this.simcRemote,
  });

  final Widget child;
  final AplAssetService aplAssets;
  final SimcRemoteService? simcRemote;

  @override
  Widget build(BuildContext context) {
    final activeSpec = context.watch<ActiveSpecRepository>();
    final spec = activeSpec.spec;
    final store = context.read<LocalStore>();
    final signIn = context.read<PkceAccessTokenSource>();
    return MultiProvider(
      key: ValueKey(spec.id),
      providers: [
        ChangeNotifierProvider(
          lazy: false,
          create: (_) {
            final repository = AplRepository(
              spec: spec,
              assetService: aplAssets,
              remoteService: simcRemote ?? SimcRemoteService(),
            );
            // The UI shows a spinner until the APL is in.
            if (spec.hasApl) unawaited(repository.loadBundled());
            return repository;
          },
        ),
        Provider(
          create: (_) => WarcraftLogsRepository(
            spec: spec,
            service: WarcraftLogsService(
              accessToken: signIn.call,
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
      child: child,
    );
  }
}

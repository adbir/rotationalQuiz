import 'package:flutter/foundation.dart';

import '../../domain/apl/apl_document.dart';
import '../../domain/specs/rotation_spec.dart';
import '../../utils/result.dart';
import '../services/apl_asset_service.dart';
import '../services/simc_remote_service.dart';

/// Single source of truth for the APL currently in use.
///
/// Starts from the copy bundled with the app and can be refreshed from the
/// SimulationCraft repository or replaced by pasted text.
class AplRepository extends ChangeNotifier {
  AplRepository({
    required this.spec,
    required this._assetService,
    required this._remoteService,
  });

  final RotationSpec spec;
  final AplAssetService _assetService;
  final SimcRemoteService _remoteService;

  AplDocument? _document;

  late final _noApl = FormatException('${spec.name} has no APL.');

  /// The APL in use, or `null` until [loadBundled] completes.
  AplDocument? get document => _document;

  Future<Result<AplDocument>> loadBundled() async {
    try {
      final path = spec.aplAssetPath;
      if (path == null) return Result.error(_noApl);
      final source = await _assetService.load(path);
      return Result.ok(_use(source, 'Bundled ($path)'));
    } on Exception catch (e) {
      return Result.error(e);
    }
  }

  Future<Result<AplDocument>> refreshFromSimc() async {
    try {
      final url = spec.remoteAplUrl;
      if (url == null) return Result.error(_noApl);
      final source = await _remoteService.fetch(url);
      return Result.ok(_use(source, url.toString()));
    } on Exception catch (e) {
      return Result.error(e);
    }
  }

  /// Uses APL text supplied by the user, e.g. an exported SimC profile.
  Result<AplDocument> usePasted(String source) {
    final document = AplDocument.parse(source, origin: 'Pasted');
    if (document[spec.entryList] == null) {
      return Result.error(
        FormatException('No "actions=" lines found for ${spec.name}.'),
      );
    }
    _document = document;
    notifyListeners();
    return Result.ok(document);
  }

  AplDocument _use(String source, String origin) {
    final document = AplDocument.parse(source, origin: origin);
    _document = document;
    notifyListeners();
    return document;
  }
}

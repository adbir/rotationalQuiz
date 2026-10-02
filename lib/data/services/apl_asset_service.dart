import 'package:flutter/services.dart';

/// Reads APL files bundled with the app.
class AplAssetService {
  const AplAssetService({this._bundle});

  final AssetBundle? _bundle;

  Future<String> load(String assetPath) =>
      (_bundle ?? rootBundle).loadString(assetPath);
}

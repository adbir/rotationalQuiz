import 'package:flutter/foundation.dart';

import '../../domain/specs/rotation_spec.dart';
import '../services/local_store.dart';

/// Which spec the app is showing. Everything per-spec is rebuilt when it
/// changes, so this is the one thing that outlives a spec switch.
class ActiveSpecRepository extends ChangeNotifier {
  ActiveSpecRepository({required this.specs, required this._store})
    : assert(specs.isNotEmpty);

  static const storeKey = 'active_spec';

  /// The specs the user can pick from; the first is the default.
  final List<RotationSpec> specs;
  final LocalStore _store;

  RotationSpec get spec {
    final id = _store.getString(storeKey);
    return specs.where((s) => s.id == id).firstOrNull ?? specs.first;
  }

  Future<void> select(RotationSpec spec) async {
    if (spec.id == this.spec.id) return;
    await _store.setString(storeKey, spec.id);
    notifyListeners();
  }
}

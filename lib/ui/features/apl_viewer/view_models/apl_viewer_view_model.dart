import 'package:flutter/foundation.dart';

import '../../../../data/repositories/apl_repository.dart';
import '../../../../domain/apl/apl_document.dart';
import '../../../../domain/specs/rotation_spec.dart';
import '../../../../utils/result.dart';

/// Shows the APL in use and lets the user refresh it from SimulationCraft or
/// paste their own.
class AplViewerViewModel extends ChangeNotifier {
  AplViewerViewModel({required this._repository}) {
    _repository.addListener(notifyListeners);
  }

  final AplRepository _repository;

  RotationSpec get spec => _repository.spec;
  AplDocument? get document => _repository.document;

  bool _busy = false;
  bool get busy => _busy;

  String? _message;

  /// Feedback from the last refresh / paste.
  String? get message => _message;

  Future<void> refreshFromSimc() async {
    _busy = true;
    _message = null;
    notifyListeners();
    final result = await _repository.refreshFromSimc();
    _busy = false;
    _message = switch (result) {
      Ok() => 'Loaded the latest APL from SimulationCraft.',
      Error(:final error) => 'Could not download the APL: $error',
    };
    notifyListeners();
  }

  Future<void> restoreBundled() async {
    final result = await _repository.loadBundled();
    _message = switch (result) {
      Ok() => 'Using the APL bundled with the app.',
      Error(:final error) => 'Could not load the bundled APL: $error',
    };
    notifyListeners();
  }

  void usePasted(String source) {
    final result = _repository.usePasted(source);
    _message = switch (result) {
      Ok() => 'Using your pasted APL.',
      Error(:final error) => '$error',
    };
    notifyListeners();
  }

  @override
  void dispose() {
    _repository.removeListener(notifyListeners);
    super.dispose();
  }
}

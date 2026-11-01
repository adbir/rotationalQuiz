import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Hard limit for hand-written files under lib/. The target in CLAUDE.md
/// ("Code organisation") is ~300 lines; this catches files that have clearly
/// outgrown one responsibility.
const maxLines = 400;

/// Generated code and pure data tables (e.g. a spec's spell list) are exempt.
bool _isExempt(String path) =>
    path.endsWith('.g.dart') || path.endsWith('_data.dart');

void main() {
  test('hand-written files in lib/ stay under $maxLines lines', () {
    final tooLong = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (_isExempt(entity.path)) continue;
      final lines = entity.readAsLinesSync().length;
      if (lines > maxLines) tooLong.add('${entity.path} ($lines lines)');
    }
    expect(
      tooLong,
      isEmpty,
      reason: 'Split these by responsibility; see CLAUDE.md, Code organisation',
    );
  });

  test('domain/ does not depend on widgets', () {
    final offenders = <String>[];
    for (final entity in Directory('lib/domain').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      if (source.contains('package:flutter/material.dart') ||
          source.contains('package:flutter/widgets.dart') ||
          source.contains('package:flutter/services.dart')) {
        offenders.add(entity.path);
      }
    }
    expect(offenders, isEmpty);
  });
}

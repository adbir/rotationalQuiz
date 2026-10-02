import 'package:flutter/material.dart';

import '../../domain/apl/apl_evaluator.dart';
import '../../domain/models/spec_definition.dart';

abstract final class AppTheme {
  static const _seed = Color(0xFF0070DD); // Shaman blue.

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      visualDensity: VisualDensity.standard,
      cardTheme: const CardThemeData(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
      ),
      sliderTheme: const SliderThemeData(
        showValueIndicator: ShowValueIndicator.onDrag,
      ),
    );
  }

  static Color schoolColor(SpellSchool school) => switch (school) {
    SpellSchool.fire => const Color(0xFFE5631E),
    SpellSchool.nature => const Color(0xFF3F7FE8),
    SpellSchool.frost => const Color(0xFF4FC3D8),
    SpellSchool.earth => const Color(0xFF9C6B3A),
    SpellSchool.physical => const Color(0xFF8D8D8D),
    SpellSchool.arcane => const Color(0xFF9B59D0),
  };

  /// Colours for the APL trace; tuned to read on both light and dark
  /// surfaces.
  static Color outcomeColor(TraceOutcome outcome, ColorScheme scheme) =>
      switch (outcome) {
        TraceOutcome.selected => const Color(0xFF2E9E5B),
        TraceOutcome.offGcd => const Color(0xFF2E9E5B),
        TraceOutcome.jumped => scheme.primary,
        TraceOutcome.conditionFalse => scheme.onSurfaceVariant,
        TraceOutcome.unavailable => const Color(0xFFD08A1A),
        TraceOutcome.notMoving || TraceOutcome.notModelled => scheme.outline,
        TraceOutcome.error => scheme.error,
      };

  static const passColor = Color(0xFF2E9E5B);
  static const failColor = Color(0xFFD9534F);
}

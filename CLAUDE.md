# Rotational Quiz

A Flutter app that turns SimulationCraft action priority lists (APLs) into a
sandbox and quiz for World of Warcraft rotations. The first supported spec is
**Elemental Shaman, single target**.

## Commands

```bash
flutter pub get
flutter analyze                                       # must be clean
dart format lib test                                  # CI fails on unformatted code
flutter test                                          # unit + widget tests
flutter run -d chrome                                 # or any desktop/mobile device
```

## Architecture

Follows the official Flutter architecture guidance (the
`flutter-apply-architecture-best-practices` skill from the `dart-flutter`
plugin): MVVM UI layer, repositories over services, pure-Dart domain.

```text
lib/
├── domain/                 # Pure Dart. No Flutter widgets. Fully unit tested.
│   ├── apl/                # SimC parsing + evaluation
│   │   ├── apl_expression.dart   # Expression AST + Pratt parser for `if=`
│   │   ├── apl_document.dart     # `actions.<list>+=/...` line parser
│   │   └── apl_evaluator.dart    # Walks lists like SimC; produces a trace
│   ├── models/             # CombatState (scenario), Keybind, spec metadata types
│   ├── specs/              # One RotationSpec per spec (spell book, costs…)
│   ├── talents/            # Talent tree data + in-game export string decoder
│   │   └── generated/      # *.g.dart from tool/generate_talent_tree.py
│   └── use_cases/          # GenerateScenario (random quiz states)
├── data/
│   ├── services/           # Asset loading, SimC download, LocalStore (prefs)
│   └── repositories/       # AplRepository, TalentBuildRepository, KeybindRepository
├── ui/
│   ├── core/               # Theme + shared widgets (SpellButton, TraceList…)
│   └── features/<feature>/{view_models,views}/   # sandbox, quiz, apl_viewer, setup, home
└── utils/result.dart
```

Key ideas:

- **The APL is the source of truth for priority.** Never hard-code rotation
  logic in Dart. A `RotationSpec` only answers "can this button be pressed?"
  (talents, cooldowns, resource cost, moving) and resolves spec-specific
  identifiers such as `maelstrom.deficit`.
- Generic identifiers (`buff.*`, `dot.*`, `cooldown.*`, `talent.*`,
  `set_bonus.*`, `active_dot.*`) are resolved in `AplEvaluator`. Unknown ones
  evaluate to `0` and are surfaced in the UI as a warning; the APL tests
  assert there are none for the single-target path.
- Off-GCD abilities (Ancestral Swiftness, Wind Shear, Spiritwalker's Grace…)
  are collected and evaluation continues, so the app can suggest "press X
  *and* Y".
- **Talent builds** come from in-game export strings, decoded by
  `TalentStringCodec` (a port of SimC's `parse_traits_hash`). Talent tokens
  are SimC's (`talent.<token>`). Regenerate the tree after a game patch:
  `tool/generate_talent_tree.py --class-id 7 --name shaman >
  lib/domain/talents/generated/shaman_talent_tree.g.dart`, then run the
  codec tests (they decode real SimC profile strings).
- **Keybinds** are stored per spec by physical key (layout independent) with
  modifiers; middle/side mouse buttons are supported.
- **Quiz modes:** action bar, multiple choice (distractors come from APL lines
  that were considered before the winner) and hot keys (timed, uses the
  user's keybinds, off-GCD presses are allowed before the GCD ability).
- User data (builds, binds, active build) is persisted through `LocalStore`
  (`shared_preferences`); tests use `InMemoryStore`.
- `assets/apl/*.simc` are verbatim upstream copies; see `assets/apl/README.md`
  to refresh them. Don't edit them by hand.

## Adding a spec

1. Copy the upstream `.simc` into `assets/apl/`, and generate the class
   talent tree if it doesn't exist yet.
2. Implement a `RotationSpec` in `lib/domain/specs/` (spells, auras,
   cooldowns, talents, loadouts, `resolveScalar`, `availability`).
3. Add an APL test like `test/domain/elemental_apl_test.dart`: every
   condition parses, no unknown identifiers, and a handful of known
   situations produce the expected button.

## Conventions

- Immutable models with `copyWith`; ViewModels extend `ChangeNotifier` and are
  consumed with `ListenableBuilder`. Dependency injection via `provider`.
- Keep `domain/` free of `package:flutter/material.dart`.
- Write a failing test in `test/domain/` before changing evaluator behaviour.
- Spell numbers (costs, cooldowns, durations) in spec files are
  approximations; note the source when you change them.

## Flutter agent tooling

This repo enables the official **Dart and Flutter** Claude Code plugin
(`dart-flutter@dart-flutter` from
[flutter/agent-plugins](https://github.com/flutter/agent-plugins)) in
`.claude/settings.json`. It provides the Flutter/Dart agent skills and the
Dart MCP server (`dart mcp-server`). Prefer those skills (e.g.
`flutter-add-widget-test`, `flutter-build-responsive-layout`,
`dart-run-static-analysis`) when they match the task.

The official Flutter agent rules from
[flutter/agent-plugins/rules](https://github.com/flutter/agent-plugins/tree/main/rules)
are included below, as recommended for Claude Code.

<!-- Source: https://github.com/flutter/agent-plugins/blob/main/rules/flutter-hot-reload.md -->
### Proactive Flutter Hot Reload Rule

Applies to edits of `**/lib/**/*.dart`.

Whenever you edit or modify any `.dart` file under `lib/` in this project:

1. **When to Skip**:
   - **Files Outside `lib/`**: Only trigger hot reload or hot restart for edits under `lib/`. Do not trigger when modifying files in other directories (e.g., `test/**`, `integration_test/**`, `benchmark/**`, `test_driver/**` or `example/**`).
   - **Comments & Documentation**: Do not trigger hot reload or hot restart when changes only affect comments, docstrings, or whitespace.

2. **Discover & Connect**:
   - Discover active running application instances using the `dtd` MCP Tool (or `list_running_apps` / `vm_service`) from the Dart MCP server.

3. **Trigger Hot Reload / Hot Restart**:
   - Execute the `hot_reload` MCP tool immediately after making changes to UI widgets (including `build` methods of stateful widgets) or simple methods.
   - Execute the `hot_restart` MCP tool if fundamental logic, state initialization (e.g., `initState`), global/static state, or `main()` was modified.

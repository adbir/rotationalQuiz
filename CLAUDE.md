# Rotational Quiz

A Flutter app that turns SimulationCraft action priority lists (APLs) into a
sandbox and quiz for World of Warcraft rotations. The first supported spec is
**Elemental Shaman, single target** (Midnight).

## Setup

- **Flutter stable ≥ 3.47 / Dart ≥ 3.13.5** (`pubspec.yaml` pins
  `sdk: ^3.13.5`; the code uses private named initializing formals such as
  `required this._store`, which need it).
- **Cloud sessions:** `.claude/hooks/session-start.sh` installs Flutter to
  `$HOME/flutter`, puts it on `PATH` and runs `flutter pub get`. Running as
  root prints a "Woah! … as root" banner. It's harmless.
- **Local sessions:** use your own Flutter install. The hook does nothing
  outside cloud sessions.

## Commands

```bash
flutter pub get
flutter analyze                                       # must be clean
dart format lib test                                  # CI fails on unformatted code
flutter test                                          # unit + widget tests (~5s)
flutter run -d chrome                                 # or any desktop/mobile device
```

CI (`.github/workflows/ci.yaml`) runs `pub get`, then the format check
(`dart format --output=none --set-exit-if-changed lib test`), then `analyze`,
then `test`. Run all three before pushing.

## Seeing the UI without a browser

Cloud containers have no Chrome and no GTK, so `flutter run` and the hot
reload rule below don't apply there. Render screenshots with the opt-in
golden test instead (it loads real Roboto fonts from the Flutter SDK, so
text is readable):

```bash
SCREENSHOT_DIR=/tmp/shots flutter test test/screenshots --update-goldens
# phone layout:
SCREENSHOT_DIR=/tmp/shots SCREENSHOT_WIDTH=420 SCREENSHOT_HEIGHT=900 \
  flutter test test/screenshots --update-goldens
```

It writes `sandbox.png`, `quiz_action_bar.png`, `quiz_multiple_choice.png`,
`quiz_hot_keys.png`, `apl.png` and `setup.png`, and is skipped in normal
test runs. Extend `test/screenshots/screenshot_test.dart` when you add a
screen.

`flutter build web` works, but headless Chromium in the container can't run
CanvasKit, so the build renders blank. Use the screenshot test instead.

## Architecture

Follows the official Flutter architecture guidance (the
`flutter-apply-architecture-best-practices` skill from the `dart-flutter`
plugin): an MVVM UI layer, repositories over services, and a domain layer
without widgets.

```text
lib/
├── main.dart               # Creates the store + repositories, provides them
├── app.dart                # MaterialApp + theme
├── domain/                 # No widgets: Dart + package:flutter/foundation.dart only
│   ├── apl/                # SimC parsing + evaluation
│   │   ├── apl_expression.dart   # Expression AST + Pratt parser for `if=`
│   │   ├── apl_document.dart     # `actions.<list>+=/...` line parser
│   │   └── apl_evaluator.dart    # Walks lists like SimC; produces a trace
│   ├── models/             # CombatState (scenario), Keybind, spec metadata types
│   ├── specs/              # RotationSpec + one implementation per spec
│   ├── talents/            # Talent tree types + in-game export string decoder
│   │   └── generated/      # *.g.dart from tool/generate_talent_tree.py
│   └── use_cases/          # GenerateScenario (random quiz states)
├── data/
│   ├── services/           # Asset loading, SimC download, LocalStore (prefs)
│   └── repositories/       # AplRepository, TalentBuildRepository, KeybindRepository
├── ui/
│   ├── core/               # theme.dart, keybind_input.dart (key/mouse → Keybind)
│   │   └── widgets/        # SpellButton, ConditionView, TraceList, RecommendationCard…
│   └── features/
│       ├── sandbox/        # {view_models,views}/
│       ├── quiz/           # {view_models,views}/
│       ├── apl_viewer/     # {view_models,views}/
│       ├── setup/          # {view_models,views}/: talent import, keybinds
│       └── home/views/     # HomeShell: navigation, creates the view models
└── utils/result.dart       # Result<T> = Ok | Error
tool/generate_talent_tree.py  # SimC trait data → talent tree .g.dart
```

### How a recommendation is made

1. `AplRepository` holds the parsed `AplDocument`: the bundled asset, the
   latest version from SimC, or pasted text.
2. `AplEvaluator.recommend(document, state)` starts at `spec.entryList`
   (`default`) and walks each list top to bottom.
   - For each line it evaluates the `if=` condition, then asks
     `spec.availability(...)` whether the ability can be pressed (talent,
     cooldown, resource cost, moving).
   - The first line that passes both wins.
   - Off-GCD abilities are collected and their effect applied
     (`spec.applyOffGcd`), and evaluation continues. That's how "press X
     *and* Y" works.
   - Every line looked at goes into a trace, which the UI renders.
3. **The APL is the source of truth for priority.** Never hard-code rotation
   logic in Dart. A `RotationSpec` only answers "can this button be
   pressed?" and resolves spec-specific identifiers.

### Identifier support

| Resolved by | Identifiers |
| ----------- | ----------- |
| `AplEvaluator` | `buff/debuff/dot.<name>.{up,down,stack,react,remains,ticking,refreshable,duration,max_stack}`, `cooldown.<name>.{remains,ready,up,charges,charges_fractional,max_charges,duration,full_recharge_time}`, `talent.<name>[.enabled]`, `set_bonus.<name>`, `active_dot.<name>`, `spell_targets.*`, `active_enemies`, `fight_remains`, `target.time_to_die`, `gcd`, `gcd.max`, `movement.distance` |
| `RotationSpec.resolveScalar` | Resource (`maelstrom`, `.deficit`, `.max`, `.pct`) and spec extras (`lightning_rod`) |
| Not supported | `variable.*` (`variable` actions are skipped), `trinket.*`, `prev_gcd.*`, `time`, `target_if=` (ignored; single target), `use_item`/`potion`/racials (listed in `spec.unmodelledActions`) |

Unknown identifiers evaluate to `0`, and the UI shows them as a warning.
Any `buff.<name>` resolves even without an `AuraDefinition`; it just reads
as "down". So `test/domain/apl_coverage_test.dart` statically checks every
identifier, aura and ability on the single-target path (including clauses
that `&`/`|` would short-circuit past). Keep it green.

An APL that relies on `variable.*` (most specs other than Elemental do) needs
variable support in the evaluator before it will give correct answers.

## Recipes

### Add an aura or proc the APL reads

1. Add an `AuraDefinition` to `ElementalShaman.auras`
   (`lib/domain/specs/elemental_shaman.dart`).
   - Set `kind` (buff, dot or debuff), `duration`, `maxStacks` and
     `requiredTalent`/`requiredSetBonus` (these hide it when not taken).
   - Set `quizChance`: the probability it's up in random quiz scenarios.
     `null` means the quiz never changes it.
2. Nothing else is needed for the UI: `ScenarioEditor`, `StateSummary` and
   `GenerateScenario` all read `spec.auras`.
3. `flutter test`. The coverage test fails if the APL reads an aura you
   haven't defined.

### Add an ability

1. Add a `SpellDefinition` to `spells`, keyed by the SimC action name.
   - Fill in `cost`, `castTime`, `offGcd` and `requiredTalent`.
   - `requiredBuff` is for spells that only exist during a proc, like
     Tempest.
   - `onActionBar: false` hides it from the quiz bar.
2. If it has a cooldown, add a `CooldownDefinition` (`maxCharges` for charge
   spells) and set `cooldownId`/`usesCharges` on the spell.
3. Special rules go in `availability()` (e.g. Wind Shear needs a casting
   target) and `applyOffGcd()` (the buff an off-GCD press applies).
4. APL actions you deliberately don't model go in `unmodelledActions`.
   Otherwise the trace shows "Not in the spell book".

### Add a spec

The app is **single-spec today**: `ElementalShaman` is hard-coded in
`lib/main.dart` and `test/test_helpers.dart`, and each repository takes one
`spec`. A second spec needs, in addition to the steps below, a spec picker
and either per-spec repositories or a spec-aware provider setup. Persisted
data is already keyed by `spec.id`.

1. Copy the upstream `.simc` into `assets/apl/` and add a row to
   `assets/apl/README.md`.
2. If the class has no talent tree yet, generate one (see below). Class ids
   are SimC's (warrior 1, … shaman 7, … evoker 13).
3. Implement `RotationSpec` in `lib/domain/specs/`:
   - `specId`: the Blizzard spec id, e.g. 262.
   - `talentTree`.
   - `heroTreeNames`: SimC sub-tree ids, found as `subTree:` on the
     `tree: 4` entries in the generated tree.
   - `remoteAplUrl`, `entryList`/`focusList`.
   - `spells`, `auras`, `cooldowns`, `talents` (the toggles the APL checks).
   - `loadouts`: decode SimC `profiles/<tier>/*.simc` `talents=` strings so
     the defaults are real builds.
   - `maxResource`, `defaultState`, `availability`, `resolveScalar`,
     `applyOffGcd`.
4. Copy `test/domain/elemental_apl_test.dart` and
   `test/domain/apl_coverage_test.dart`, and add a codec test with a real
   build string.

### Regenerate the talent tree (after a game patch)

```bash
python3 -I tool/generate_talent_tree.py --class-id 7 --name shaman \
  > lib/domain/talents/generated/shaman_talent_tree.g.dart
dart format lib/domain/talents/generated   # generator output isn't formatted
flutter test test/domain/talent_string_codec_test.dart
```

The script downloads SimC's `midnight` branch `trait_data.inc`. Pass
`--trait-data <file>` to use a local copy. The WoW build is recorded at the
top of the generated file. Export strings depend on the tree's node list,
so stale data can mis-decode builds made on a newer patch.

### Refresh the APL

See `assets/apl/README.md`. The files are verbatim upstream copies; don't
edit them by hand. Run the tests afterwards: the coverage test lists
anything new the sandbox doesn't model.

## Features and where they live

- **Sandbox** (`ui/features/sandbox`): edit a `CombatState`, re-evaluate on
  every change. "Save as build" stores hand-edited talents.
- **Quiz** (`ui/features/quiz`), in `QuizViewModel`:
  - **Action bar mode.**
  - **Multiple choice:** `_buildOptions`. Distractors are abilities from
    trace lines the APL considered before the winner. Answer with keys 1–4.
  - **Hot keys:** timed, uses the user's keybinds. An off-GCD press before
    the GCD ability is allowed. Auto-advances after a correct answer.
  - Scenarios come from `GenerateScenario` and are re-rolled to down-weight
    the unconditional filler.
- **Talent builds** (`TalentBuildRepository`): reference builds from the
  spec plus user imports. `TalentStringCodec` decodes in-game export strings
  (a port of SimC's `parse_traits_hash`). Talent tokens are SimC's
  (`talent.<token>`). The active build drives both the sandbox and the quiz.
- **Keybinds** (`KeybindRepository`): stored per spec by physical key (USB
  HID usage, so they're layout independent) plus modifiers. Middle and side
  mouse buttons are stored as negative codes. A key maps to one ability.
- **Persistence:** `LocalStore`, backed by `shared_preferences`
  (localStorage on the web). Keys are `keybinds.<spec>`,
  `talent_builds.<spec>` and `active_talent_build.<spec>`. Imported builds
  are re-decoded on load, so they pick up talent data updates.

## Testing

```text
test/
├── test_helpers.dart   # spec, FileAssetBundle, loadedRepository(),
│                       # TestRepositories (APL + builds + keybinds on InMemoryStore)
├── domain/             # parser, evaluator, real-APL behaviour, coverage, codec, generator
├── data/               # repository persistence
├── ui/                 # view models, quiz key handling, app navigation
└── screenshots/        # opt-in PNG renders (see above)
```

- **Evaluator changes:** write a failing test in
  `test/domain/elemental_apl_test.dart` first, describing the situation and
  the expected button.
- **Determinism:** `QuizViewModel` and `GenerateScenario` take a `Random`.
  Use a seed in tests. Timers (hot keys) are tested with `fake_async`.
- **Widget tests that start timers:** dispose the view model before the test
  ends, or Flutter reports "A Timer is still pending".

## Conventions

- Immutable models with `copyWith`. ViewModels extend `ChangeNotifier` and
  are consumed with `ListenableBuilder`. Dependency injection is via
  `provider`.
- `domain/` may use `package:flutter/foundation.dart` (`@immutable`,
  `mapEquals`) but never `material.dart` or widgets.
- Use `Result<T>` (`utils/result.dart`) for repository operations that can
  fail.
- Spell numbers (costs, cooldowns, durations) in spec files are
  approximations; note the source when you change them. Known assumptions:
  - Swelling Maelstrom is +50 Maelstrom (in-game tooltip).
  - Fire Elemental is treated as baseline.
  - Storm Elemental and Wind Gust stay hidden: they're not talents in
    Midnight.

## Flutter agent tooling

This repo enables the official **Dart and Flutter** Claude Code plugin
(`dart-flutter@dart-flutter` from
[flutter/agent-plugins](https://github.com/flutter/agent-plugins)) in
`.claude/settings.json`. It provides the Flutter/Dart agent skills and the
Dart MCP server (`dart mcp-server`). Prefer those skills (e.g.
`flutter-add-widget-test`, `flutter-build-responsive-layout`,
`dart-run-static-analysis`) when they match the task. The plugin may not be
loaded in every environment. If its tools are missing, use the `flutter` and
`dart` CLIs directly.

The official Flutter agent rules from
[flutter/agent-plugins/rules](https://github.com/flutter/agent-plugins/tree/main/rules)
are included below, as recommended for Claude Code. They need a running app
and the Dart MCP server. In cloud sessions neither exists; use the
screenshot test instead.

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

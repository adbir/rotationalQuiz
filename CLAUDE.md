# Rotational Quiz

A Flutter app that turns SimulationCraft action priority lists (APLs) into a
sandbox and quiz for World of Warcraft rotations. The first supported spec is
**Elemental Shaman, single target** (Midnight).

**Glossary:** [`docs/glossary.md`](docs/glossary.md) defines WoW raiding, WCL
log and SimC terms. Read it before naming a raiding concept in code or UI, and
before any Boss Evaluation or log-analysis work: each term says how to measure
it in a log and whether that is verified.

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

## Deployment

`.github/workflows/deploy-pages.yaml` builds the web app on every push to
`main`, runs the tests, and publishes it to GitHub Pages at
https://adbir.github.io/rotationalQuiz/ (built with
`--base-href /rotationalQuiz/`). Anything merged to `main` goes live, so keep
`main` green. Pages needs the repository to be public, with Settings → Pages
→ Source set to "GitHub Actions".

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
│   │   ├── apl_evaluator.dart    # Walks lists like SimC; produces a trace
│   │   └── apl_state_resolver.dart  # buff./cooldown./talent./… → numbers
│   ├── models/             # CombatState (scenario), Keybind, spec metadata types
│   ├── specs/              # RotationSpec + per spec: <spec>.dart (behaviour)
│   │                       #   and <spec>_data.dart (spell/aura/talent tables)
│   ├── talents/            # Talent tree types + in-game export string decoder
│   │   └── generated/      # *.g.dart from tool/generate_talent_tree.py
│   └── use_cases/          # GenerateScenario (quiz states), PickAnswerOptions
├── data/
│   ├── services/           # Asset loading, SimC download, LocalStore (prefs)
│   └── repositories/       # AplRepository, TalentBuildRepository, KeybindRepository
├── ui/
│   ├── core/               # theme.dart, keybind_input.dart (key/mouse → Keybind)
│   │   └── widgets/        # SpellButton, ConditionView, TraceList, RecommendationCard…
│   └── features/
│       ├── sandbox/        # view_models/, views/ (+ views/widgets/)
│       ├── quiz/           # view_models/, views/ (+ views/widgets/)
│       ├── apl_viewer/     # view_models/, views/
│       ├── setup/          # view_models/, views/ (+ views/widgets/): builds, keybinds
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
| `AplStateResolver` | `buff/debuff/dot.<name>.{up,down,stack,react,remains,ticking,refreshable,duration,max_stack}`, `cooldown.<name>.{remains,ready,up,charges,charges_fractional,max_charges,duration,full_recharge_time}`, `talent.<name>[.enabled]`, `set_bonus.<name>`, `active_dot.<name>`, `spell_targets.*`, `active_enemies`, `fight_remains`, `target.time_to_die`, `gcd`, `gcd.max`, `movement.distance` |
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

1. Add an `AuraDefinition` to `elementalAuras`
   (`lib/domain/specs/elemental_shaman_data.dart`).
   - Set `kind` (buff, dot or debuff), `duration`, `maxStacks` and
     `requiredTalent`/`requiredSetBonus` (these hide it when not taken).
   - Set `quizChance`: the probability it's up in random quiz scenarios.
     `null` means the quiz never changes it.
   - Set `spellId` (the buff's in-game spell id) so its icon shows. Check
     it against SimC's `engine/dbc/generated/sc_spell_data.inc`.
2. Nothing else is needed for the UI: `ScenarioEditor`, `StateSummary` and
   `GenerateScenario` all read `spec.auras`.
3. `flutter test`. The coverage test fails if the APL reads an aura you
   haven't defined.

### Add an ability

1. Add a `SpellDefinition` to `elementalSpells` (in
   `elemental_shaman_data.dart`), keyed by the SimC action name.
   - Fill in `cost`, `castTime`, `offGcd` and `requiredTalent`.
   - `requiredBuff` is for spells that only exist during a proc, like
     Tempest.
   - `onActionBar: false` hides it from the quiz bar.
   - `spellId`: the in-game spell id, for its icon (see the aura recipe).
2. If it has a cooldown, add a `CooldownDefinition` (`maxCharges` for charge
   spells) and set `cooldownId`/`usesCharges` on the spell. For abilities used
   on cooldown, set `quizReadyChance` so quiz scenarios usually have them ready.
3. Special rules go in `ElementalShaman.availability()` (e.g. Wind Shear
   needs a casting target) and `applyOffGcd()` (the buff an off-GCD press
   applies).
4. APL actions you deliberately don't model go in
   `elementalUnmodelledActions`.
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
3. Implement `RotationSpec` in `lib/domain/specs/<spec>.dart`, with its
   tables in `<spec>_data.dart`:
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
  - **Action bar mode.** Off-GCD abilities are on a row of their own and are
    part of the answer. Skipping one still counts, with a reminder.
  - **Multiple choice:** options come from the `PickAnswerOptions` use case
    and are whole sequences, such as "Ancestral Swiftness → Lightning Bolt".
    Wrong answers are that GCD ability alone and abilities from trace lines
    the APL considered before the winner. Answer with keys 1–4.
  - **Hot keys:** timed, uses the user's keybinds, and treats off-GCD abilities
    as Action bar mode does. Auto-advances after a correct answer.
  - Scenarios come from `GenerateScenario` and are re-rolled to down-weight
    the unconditional filler.
- **Talent builds** (`TalentBuildRepository`): reference builds from the
  spec plus user imports. `TalentStringCodec` decodes in-game export strings
  (a port of SimC's `parse_traits_hash`). Talent tokens are SimC's
  (`talent.<token>`). The active build drives both the sandbox and the quiz.
- **Keybinds** (`KeybindRepository`): stored per spec by physical key (USB
  HID usage, so they're layout independent) plus modifiers. Middle and side
  mouse buttons are stored as negative codes. A key maps to one ability.
- **Spell icons** (`SpellIconRepository`, `ui/core/widgets/spell_icon.dart`):
  Blizzard's artwork, so never committed (the repo is GPL). At runtime the
  app asks Wowhead's tooltip API (`nether.wowhead.com/tooltip/spell/<id>`)
  for the icon name and loads the image from `wow.zamimg.com`. Names are
  cached in `LocalStore` under `spell_icons` and validated before use.
  Without a `SpellIconScope`, offline, or on any error, buttons show their
  coloured abbreviation and chips show text only. The cloud container
  can't reach these hosts, so check icons on the live site.
- **Persistence:** `LocalStore`, backed by `shared_preferences`
  (localStorage on the web). Keys are `keybinds.<spec>`,
  `talent_builds.<spec>`, `active_talent_build.<spec>` and `spell_icons`. Imported builds
  are re-decoded on load, so they pick up talent data updates.

## Testing

```text
test/
├── test_helpers.dart   # spec, FileAssetBundle, loadedRepository(),
│                       # TestRepositories (APL + builds + keybinds on InMemoryStore)
├── code_organisation_test.dart  # file-size limit, domain/ import rules
├── domain/             # parser, evaluator, real-APL behaviour, coverage,
│                       # codec, scenario generator, answer options
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

## Code organisation

**Extend before you add.** Most changes fit an existing extension point;
use it rather than creating a parallel file or class.

| To change… | Extend | Not |
| ---------- | ------ | --- |
| Per-spec behaviour (costs, availability, resources) | the spec's `RotationSpec` overrides | `if (spec is …)` checks elsewhere |
| Spells, procs, cooldowns, talents | the data lists on the spec (`SpellDefinition`, `AuraDefinition`, …) | new widgets or editors for one aura |
| Spec-agnostic APL identifiers | `AplStateResolver.resolve` | each spec's `resolveScalar` |
| Quiz rules that don't need Flutter | a use case in `domain/use_cases/` | private ViewModel methods |
| A spec's static tables | `<spec>_data.dart` | the spec class body |
| Persistence | a repository over `LocalStore` | direct `SharedPreferences` calls |
| A widget used by two features | `ui/core/widgets/` | copy-pasted private widgets |
| Feature behaviour | the feature's ViewModel | logic in `build()` |

When a new file *is* justified:
- **A new responsibility,** not "more of the same". A second screen, a new
  repository, or a new use case qualifies; a helper for one function does
  not.
- **It lives in the layer folder that owns it** (see the tree above).
  Avoid `utils/` or `helpers/` grab-bags.
- **Prefer composition over inheritance.** Add a method to an existing
  interface, with a default implementation in the base class when only some
  implementations need it, as `RotationSpec.applyOffGcd` does.

Keep files focused:
- **Size:** aim for ≤ 300 hand-written lines per file. When a file passes
  that, split it by responsibility. Typical splits:
  - a screen's helper widgets go into `views/widgets/`, one public widget
    per file
  - a spec's data tables go in `<spec>_data.dart`, apart from its behaviour
  - logic that doesn't need Flutter goes into a domain use case
  - `test/code_organisation_test.dart` fails CI above 400 lines (generated
    `*.g.dart` and data-only `*_data.dart` files are exempt), and if
    `domain/` imports `material`, `widgets` or `services`.
- **Widgets:** one public widget per file. Private helper widgets may share
  the file while they're small.
- **Exceptions:** generated files (`*.g.dart`) and test files.
- **No dead code:** delete it. Never leave commented-out blocks or unused
  parameters "for later".
- **No duplication:** if you're about to copy a block, extract it to where
  both callers can reach it.

`analysis_options.yaml` enforces part of this. It turns on strict casts,
inference and raw types, plus `prefer_final_locals`, `unawaited_futures`,
`avoid_dynamic_calls`, `directives_ordering` and `sort_constructors_first`.
Fix what it flags; don't `// ignore:` it without a comment explaining why.

## Conventions

- Immutable models with `copyWith`. ViewModels extend `ChangeNotifier` and
  are consumed with `ListenableBuilder`. Dependency injection is via
  `provider`.
- `domain/` may use `package:flutter/foundation.dart` (`@immutable`,
  `mapEquals`) but never `material.dart` or widgets.
- Use `Result<T>` (`utils/result.dart`) for repository operations that can
  fail.
- For a spell's current wording, use its Wowhead page, whose changelog shows
  the patch history (we're on 12.1.5):
  `https://www.wowhead.com/spell=16166/master-of-the-elements#changelog`.
  Those pages block scripts, so read them in a browser. From a script, use
  `https://nether.wowhead.com/tooltip/spell/<id>`. Tooltips show base values
  before talents, so check talents too.
- Spell numbers (costs, cooldowns, durations) in spec files are
  approximations; note the source when you change them. Known assumptions:
  - Maximum Maelstrom is 100, +50 with Swelling Maelstrom and +25 with
    Primordial Capacity (in-game tooltips; a rank-1 Farseer log shows 125).
  - Fire Elemental is treated as baseline.
  - Cooldowns are tooltip values with the talents both reference builds take
    (First Ascendant, Graceful Spirit). Stormkeeper stays at its 60 s base:
    Offering from Beyond shortens it during play.
  - Spiritwalker's Grace has one charge. Logs show casts seconds apart because
    an Evoker's Time Spiral allows a free cast, so count those separately.
  - Lava Burst has 1 charge, +1 from Echo of the Elements and +1 from Elemental
    Reverb (`ElementalShaman.maxCharges`).
  - Stormkeeper gives 2 stacks (tooltip, three logs and the project owner).
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

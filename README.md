# Rotational Quiz

Learn your World of Warcraft rotation from the source: this app reads the
[SimulationCraft](https://github.com/simulationcraft/simc) action priority
list (APL) for a spec and lets you poke at it.

First spec: **Elemental Shaman — single target** (Midnight APL).

## Features

- **Sandbox** – set Maelstrom, procs (Master of the Elements, Lava Surge,
  Stormkeeper, Tempest, Call of the Ancestors…), DoTs, cooldowns, talents and
  tier set, and see which button(s) the APL presses next. Every APL line is
  shown with its condition colour-coded clause by clause, so you can see
  *why* a line won or lost.
- **Quiz** – random combat situations for your build, in three modes:
  - *Action bar*: click the button you would press.
  - *Multiple choice*: four options (keys 1–4) for a snapshot of the fight;
    the wrong options are abilities the APL considered just before.
  - *Hot keys*: press your real keybind before the timer runs out. Tracks
    reaction time; weaving an off-GCD ability first counts.

  Every answer shows the APL line and its reasoning; jump into the sandbox
  to explore a question further.
- **Setup** – paste your in-game talent export string (or a Wowhead /
  Raidbots / SimC one) to use your own build, and record your keybinds
  (keys with Shift/Ctrl/Alt, middle and side mouse buttons). Saved on the
  device.
- **APL viewer** – read the APL, download the latest from SimulationCraft, or
  paste your own.

## How it works

The app contains a small SimC expression engine (`lib/domain/apl/`):

1. `AplDocument.parse` reads `actions.<list>+=/<action>,if=<expr>` lines
   (keeping the `#` comments that explain them).
2. `AplExpressionParser` turns each `if=` into an expression tree, with SimC
   operator semantics (`&`, `|`, `!`, comparisons, `>?`/`<?` max/min, `%`
   division…).
3. `AplEvaluator` walks the lists top to bottom against a `CombatState`,
   following `run_action_list`, collecting off-GCD abilities, and skipping
   abilities that are not pressable (cooldown, cost, talent, moving). It
   records a trace of every line it looked at.

Spec knowledge that isn't in the APL (spell costs, cooldowns, which talents
replace which spells) lives in `lib/domain/specs/`. Talent export strings are
decoded with the class talent tree generated from SimulationCraft's trait
data (`tool/generate_talent_tree.py`).

## Development

Requires Flutter (stable). See [`CLAUDE.md`](CLAUDE.md) for architecture and
conventions.

```bash
flutter pub get
flutter test
flutter run -d chrome
```

The repo is set up for Claude Code with the official Flutter agent plugin
(`.claude/settings.json`) and the Flutter agent rules in `CLAUDE.md`.

## Disclaimer

Not affiliated with Blizzard Entertainment or SimulationCraft. The bundled APL
is copied from SimulationCraft (GPL-3.0). Spell numbers in the sandbox are
approximations; the APL decides the priority.

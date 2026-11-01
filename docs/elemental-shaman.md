# Elemental Shaman mechanics

What we've verified about the spec on patch 12.1.5 (Midnight). Spell data in
`lib/domain/specs/elemental_shaman_data.dart` should agree with this file. Each
fact names its source: **owner** (the project owner, in game), **log** (real
fights), **tooltip** or **SimC**.

## Checking a game fact

In order of trust:

1. **The project owner, in game.** Ask about anything that decides a design.
2. **Real logs.** See [warcraft-logs.md](warcraft-logs.md).
3. **Current tooltip.** The spell's Wowhead page has the wording and its patch
   history, e.g.
   `https://www.wowhead.com/spell=16166/master-of-the-elements#changelog`. Those
   pages return 403 to scripts, so read them in a browser. From a script, use
   `https://nether.wowhead.com/tooltip/spell/<id>`.
4. **SimC:** `engine/class_modules/sc_shaman.cpp`, plus `trait_data.inc` and
   `sc_spell_data.inc` under `engine/dbc/generated/`, on the `midnight` branch.

Lessons that cost us time:

- **Tooltips show base values, before talents.** Read the talents too. Ascendance
  says 3 min and is really 2.
- **An odd pattern in a log may come from the raid, not the spell.** We read
  Spiritwalker's Grace casts seconds apart as a second charge. They were an
  Evoker's Time Spiral. Check buffs from other players before concluding
  anything about a spell.
- **Base a spell's id on a check, not its name.** "Overcharge" is both a talent
  (1251026, crit damage) and part of the tier set (1300222, free spender).

## Maelstrom

The cap is 100, +50 from Swelling Maelstrom and +25 from Primordial Capacity
(tooltip). A rank 1 Farseer log shows 125.

| Spell | Maelstrom | Source |
| ----- | --------- | ------ |
| Elemental Blast | costs 90 | log |
| Earth Shock, Earthquake | cost 60 | estimate |
| Eye of the Storm | -5 on spenders, -10 on Elemental Blast | inferred from APL thresholds |
| Lava Burst | gives 8 | tooltip |
| Flame Shock | gives 3 | tooltip |
| Voltaic Blaze | gives 6 | tooltip |
| Stormkeeper | gives 10 | tooltip |

The app has no table of gains yet. Logs record every gain and any waste.

## Cooldowns

| Ability | Cooldown | Why | Source |
| ------- | -------- | --- | ------ |
| Ancestral Swiftness | 30 s | | tooltip, log |
| Ascendance | 120 s | 180 s, -60 s from First Ascendant | tooltip, log |
| Stormkeeper | 60 s, shortened in play | -3 s per Ancestor called (Offering from Beyond) | tooltip, SimC, log |
| Spiritwalker's Grace | 90 s, one charge | 120 s, -30 s from Graceful Spirit | tooltip, log |
| Voltaic Blaze | 10 s | | tooltip |
| Wind Shear | 12 s | | tooltip |
| Nature's Swiftness | 60 s | | tooltip |
| Flame Shock | none | | tooltip |

App values assume First Ascendant and Graceful Spirit, which both reference
builds take.

**Lava Burst** recharges in 8 s. It has 1 charge, +1 from Echo of the Elements
and +1 from Elemental Reverb, a Farseer talent, so a Farseer can hold 3 (owner,
tooltip). `ElementalShaman.maxCharges` works this out from talents.

**Evokers change Spiritwalker's Grace** (owner, log):

- Time Spiral allows one free cast of a major movement ability within 10 s, on
  or off cooldown. It can also be spent on Gust of Wind.
- Blessing of the Bronze takes 15% off its cooldown, so 76.5 s.

## Procs and buffs

**Stormkeeper:** 2 stacks (owner, tooltip, log). Each makes a Lightning Bolt or
Chain Lightning instant with 150% more damage. The APL's
`buff.stormkeeper.stack<4` passes at any stack count.

**Master of the Elements:** Lava Burst adds 15% to your next Nature, Physical or
Frost spell (tooltip). The aim is to always make that a spender (owner). Flame
Shock doesn't consume it (owner), so the APL comment "Consume spare MotE to buff
Flame Shock" doesn't match the game.

**Lava Surge:** resets Lava Burst's cooldown and makes it instant (owner, SimC).
Lava Burst has no Maelstrom cost, so the proc doesn't save any.

**Ancestral Swiftness:** replaces Nature's Swiftness for Farseer. The next spell
is instant, deals 10% more, and calls an Ancestor (tooltip).

**Ascendance:** 15 s. It instantly casts Flame Shock and a 50% Lava Burst, and
boosts Elemental Overload (tooltip).

**Flame Shock:** 18 s, and has no cooldown (tooltip).

### Ancestors (Farseer)

(Tooltip and SimC `summon_ancestor`.) Each lasts 8 s.

- **Always:** Stormkeeper and Ancestral Swiftness each call one.
- **8% chance:** Lightning Bolt, Lava Burst, Flame Shock, Voltaic Blaze and Chain
  Lightning (Routine Communication). SimC also rolls it on Ascendance.
- **20% chance:** a departing Ancestor calls another (Ancient Fellowship).

So part of Stormkeeper's cooldown is luck. A gap with 3 Ancestors allows 51 s and
one with 8 allows 36 s.

### Season 2 tier set (four-piece)

Tooltip of 1300222: when Stormkeeper or Ascendance fade, the next 2 Lightning
Bolts, Chain Lightnings or Lava Bursts deal 25% more damage and make the next
Earthquake, Earth Shock or Elemental Blast free.

1. A fade gives 2 stacks of **Flowing Elements** (1300219), up to 4.
2. A builder spends a stack and gives **Overcharge!** (1300222).
3. The next spender is free and consumes Overcharge!.

If Stormkeeper fades during Ascendance, its stacks wait for Ascendance to end, so
4 arrive together (owner; one direct example in a log).

In three logs, 61 of 121 Elemental Blasts were free, and every Overcharge! went on
Elemental Blast. The app has the set on by default, because current raiders have
it.

## The APL

- It models a target dummy with no fight timeline, so it can't pool for adds. See
  "Deviations" in [glossary.md](glossary.md).
- It still reads `buff.storm_elemental` and `buff.wind_gust`, although Fire and
  Storm Elemental aren't talents in Midnight. The app treats Fire Elemental as
  baseline and hides the Storm Elemental buffs.
- Comments can lag behind the game, as the Flame Shock line shows. Follow its
  conditions for priority, and check its comments against the game.

## Open questions

- Expected Ancestors run 1.4 to 2.8 below actual in three logs. Ascendance's rolls
  are the likely cause.
- The talent tree has two Earthquake entries in one node. Do they log under
  different ids?
- What do the three Elemental Blast stat buffs in the APL's `aoe` list do in
  Midnight?

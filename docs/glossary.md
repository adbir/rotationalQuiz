# World of Warcraft raider glossary

This file does two jobs for Rotational Quiz:

1. It is the shared vocabulary, so the owner and future agents use words the
   same way.
2. It is the spec for **Boss Evaluation**, the planned feature that compares a
   player's Warcraft Logs (WCL) log with top-ranked logs on the same boss and
   explains the difference. WCL is the website that stores uploaded combat logs
   and ranks players. Each term that can be measured says how.

The app may later reuse these definitions as tooltips.

**The rule that matters most:** a difference from the APL is not automatically
a mistake. See [Deviations: mistakes and plans](#deviations-mistakes-and-plans).

## How to read an entry

- **Meaning:** one or two plain sentences for a newer raider.
- **In a log:** the metric and its unit. Only present where it makes sense.
- **Status:** whether the measure can be relied on. See below.
- **In this repo:** the matching SimC identifiers and how the app uses the
  term. Only present where useful.
- **To check:** game behaviour we have not verified for Midnight. Don't state
  these as fact in the UI until someone has checked them.
- **Not to be confused with:** only where terms really do get mixed up.

Status describes the measure, not the meaning. It has three values:

| Status | What it means |
| ------ | ------------- |
| `confirmed` | Every API name the measure needs is on the [verified list](#verified-wcl-api-facts). Raw units and argument values are not covered: see [not yet verified](#not-yet-verified). |
| `needs checking` | The measure depends on something unverified: a log field, an ability id or a game number. |
| `not measurable from logs` | A log cannot show this. |

An entry with one confirmed route and one unverified route takes its status
from the route written first. The unverified route says so in its text.

Game facts come from `lib/domain/specs/elemental_shaman_data.dart`,
`assets/apl/shaman_elemental.simc` and the generated talent tree (WoW build
12.1.0.69933). Spell numbers in those files are approximations.

### Verified WCL API facts

Checked against the real v2 GraphQL API on 2026-11-01:

- `reportData.report.events` takes `dataType`, `sourceID`, `fightIDs`,
  `includeResources`, `filterExpression`, `limit`, `startTime` and `endTime`,
  among others. Results are paged with `nextPageTimestamp`.
- Cast events have `timestamp`, `type` (`begincast` or `cast`), `sourceID`,
  `targetID`, `abilityGameID`, `x`, `y`, `facing`, `hitPoints`, `itemLevel`, and
  a `classResources` array of `{amount, max, type, cost}` entries.
- `worldData.zone.encounters.characterRankings(className, specName, metric,
  difficulty, page)` returns ranked entries with `amount`, `duration`,
  `report {code, fightID}`, `guild`, `server` and `bracketData`.
- A report also has `fights`, `masterData`, `playerDetails`, `rankings`,
  `table`, `graph` and `phases`.
- `timestamp` and `duration` are in milliseconds. `timestamp`, like a fight's
  `startTime` and `endTime`, is measured from the start of the report.
- With `metric: dps`, `amount` is damage per second. For one kill it matched
  the `table(dataType: DamageDone)` total divided by fight length.
- `bracketData` on a ranked entry is the item level.
- `difficulty`: 5 Mythic, 4 Heroic, 3 Normal, 1 LFR.
- `fights` has `id`, `name`, `encounterID`, `kill`, `startTime`, `endTime`,
  `difficulty`, `size`, `enemyNPCs` and `phaseTransitions {id, startTime}`.
- `masterData` has `actors(type: "Player") {id, name, subType}` and
  `abilities {gameID, name, type}`.
- `dataType: Resources` returns `resourcechange` events with `abilityGameID`,
  `resourceChange`, `resourceChangeType`, `maxResourceAmount` and `waste`. Every
  Maelstrom gain is there, with `resourceChangeType` 11.
- Maelstrom is `type` 11 in `classResources`, on about a quarter of casts. Most
  other casts show Mana, `type` 0. `cost` is 90 on Elemental Blast.
- `dataType: Buffs` returns `applybuff`, `refreshbuff`, `applybuffstack`,
  `removebuffstack` and `removebuff` events, the stack ones with `stack`. Buff
  ids can differ from cast ids: Ascendance is cast as 114050 but its buff is
  1219480. A buff that goes up before the pull and lasts the fight, such as
  Blessing of the Bronze, has no events.
- Events from one action can land milliseconds apart, in either order. A buff
  can end 1 ms before the cast that spent it, so allow about 60 ms.
- `dataType: CombatantInfo` has `talentTree: [{id, rank, nodeID}]`, whose ids
  match `TalentEntry.id` in the generated tree (80 of 80), plus `specID`, `gear`
  and stats such as `hasteSpell` and `intellect`.
- `table` works with `dataType` `DamageDone`, `Buffs` and `Deaths`. `Buffs`
  returns `auras` with `name`, `guid`, `totalUptime` and `totalUses`.
  `Healing` (with `total` and `overheal` per ability), `Casts`, `Debuffs` and
  `DamageTaken` work too. With `metric: hps`, `amount` is net healing per second.
  `viewBy: Target` splits damage by target.

### Not yet verified

- The raw units of `x` and `y`.
- What `amount` holds for any `metric` other than `dps` and `hps`.
- The fields inside `playerDetails`, `graph` and `phases`.
- Damage, healing and debuff events. Their field names are unknown, so this
  file doesn't name any.
- Enemy debuff uptime is measured: see "Flame Shock uptime" in
  [warcraft-logs.md](warcraft-logs.md). `hostilityType: Enemies` returns nothing
  for a player's debuffs; the default works.
- Whether `includeResources` is what adds `classResources`, `x` and `y` to cast
  events. Requests with it return them; none has been tried without it.
- Whose hit points and item level `hitPoints` and `itemLevel` report.
- Whether `abilityGameID` matches the app's `spellId` for every ability. Some
  abilities have two ids in the app's tables, one for the cast and one for the
  buff: Tempest (452201, 454015) and Ancestral Swiftness (443454, 448861).

## Logs and ranking

### Cast event

- **Meaning:** A log record of a player starting or finishing a spell.
- **In a log:** An entry from `events` with `type` `begincast` (started) or
  `cast` (finished). Casts per minute: count of `cast` entries for one
  `abilityGameID` and `sourceID`, divided by [kill time](#kill-time).
- **Status:** `confirmed`

### Cohort

- **Meaning:** A group of ranked logs treated as one for comparison, such as
  rank 1-10 or rank 200-250, on the same boss, spec and difficulty. This is a
  project word, not raider slang.
- **In a log:** `characterRankings` entries, walked by `page` until the rank
  range is covered. See [rank](#rank).
- **Status:** `confirmed`

### DPS (damage per second)

- **Meaning:** Damage done divided by fight length. It is the main measure for
  a damage dealer.
- **In a log:** Damage per second: `amount` on a ranked entry with
  `metric: dps`. For a player's own log, the `table(dataType: DamageDone)` total
  divided by fight length gives the same number.
- **Status:** `confirmed`
- **Not to be confused with:** [HPS](#hps-healing-per-second). Also, WCL may
  rank on a metric that moves support damage between players, so a DPS number
  can depend on the metric. See
  [Augmentation support](#augmentation-support-aug).

### Event

- **Meaning:** One timestamped record in a log, such as a cast.
- **In a log:** `reportData.report.events`, narrowed with `sourceID`, `fightIDs`
  and `filterExpression`. Keep requesting from `nextPageTimestamp` until it runs
  out. So far only [cast events](#cast-event) have been seen.
- **Status:** `confirmed`

### HPS (healing per second)

- **Meaning:** Healing done divided by fight length. It is the main measure for
  a healer, and Elemental Shaman is rarely judged on it.
- **In a log:** Healing per second: `amount` on a ranked entry with
  `metric: hps`. It is net: the `table(dataType: Healing)` total less Spirit
  Link's negative healing, over fight length. Bounded by
  [healing intake](#healing-intake), so show it, never rank on it.
- **Status:** `confirmed`
- **Not to be confused with:** [DPS](#dps-damage-per-second).

### Item-level bracket (ilvl bracket)

- **Meaning:** A ranking that groups players by item level, the number that
  sums up how strong their gear is. It compares a player with others in similar
  gear rather than with everyone.
- **In a log:** Item level: `bracketData` on a ranked entry. `itemLevel` on cast
  events is a second candidate, not yet compared with it.
- **Status:** `confirmed`
- **Not to be confused with:** [parse percentile](#parse-percentile-percentile),
  which may be measured against all players or only a bracket. Always say which.

### Kill time

- **Meaning:** How long a successful [pull](#pull-fight-attempt) lasted, from
  the start of the fight to the boss's death. It changes how many
  [cooldown](#cooldown-cd) uses fit into a fight, so it affects any comparison.
- **In a log:** Seconds: `duration` on a ranked entry, divided by 1,000. For any
  other log, `endTime` minus `startTime` from `fights`.
- **Status:** `confirmed`

### Parse

- **Meaning:** One player's ranked performance on one boss kill. "A 90 parse"
  is shorthand for a [parse percentile](#parse-percentile-percentile) of 90.
- **In a log:** One ranked entry. `report {code, fightID}` leads to the log
  behind it.
- **Status:** `confirmed`
- **Not to be confused with:** [rank](#rank), which is a position in a list.

### Parse percentile (percentile)

- **Meaning:** The share of comparable parses that this parse beat, from 0
  to 100. A percentile of 95 beat about 95% of them.
- **In a log:** Percent. The field name is unverified. `rankings` on a report
  is the likely source. Don't derive it from [rank](#rank) without knowing how
  many parses exist in total.
- **Status:** `needs checking`
- **Not to be confused with:** [rank](#rank). The same rank can be a different
  percentile on different bosses, because the number of parses differs.

### Patchwerk

- **Meaning:** A fight with one target, no [adds](#add) and almost no
  [movement](#movement), where only the rotation matters. It is named after an
  old raid boss, and SimC uses the same name for this kind of simulated fight.
- **In a log:** Two proxies: percent of the player's casts on the boss
  (`targetID`), and [movement](#movement) per minute. Telling which `targetID`
  is the boss needs `masterData`, whose fields are unverified.
- **Status:** `needs checking`

### Rank

- **Meaning:** A log's position in the list for one boss, spec, difficulty and
  metric. Rank 1 is the best.
- **In a log:** Position in the `characterRankings` pages. Page size is not on
  the verified list, so count the entries a page returns.
- **Status:** `confirmed`
- **Not to be confused with:** [parse percentile](#parse-percentile-percentile).

### Report (log upload)

- **Meaning:** One uploaded combat log, often a whole raid night with many
  [pulls](#pull-fight-attempt). In this file, "a log" means one player's record
  of one pull inside a report.
- **In a log:** `reportData.report`, found by `code`.
- **Status:** `confirmed`

## Resources and casting

### ABC (always be casting)

- **Meaning:** The habit of always having a spell in progress, because time
  spent doing nothing is lost damage.
- **In a log:** Gaps over 1.8 seconds (count) and the longest gap (seconds): time
  between neighbouring [cast events](#cast-event), skipping a `begincast` to its
  own `cast`. A cancelled cast counts as stopping where it started. Idle seconds
  per minute would need the [GCD](#gcd-global-cooldown), which is not in the log.
  Each gap also notes what the log shows then: Ghost Wolf (2645) cast or up,
  Spiritwalker's Grace (79206) up, a Grace charge off cooldown by the player's own
  casts, and a gap of rank 1's starting within 3 s (an intermission shows in
  both). It says what was up, never why.
- **Status:** `confirmed`
- **What to try (Boss Evaluation):** for casts per minute, which also carries the
  gaps as its "where": "Keep a cast going while you move, queue the next spell
  before this one ends, and use instant spells while you move."
  (`FindingKind` in `lib/domain/models/finding.dart`.) Gaps are not a finding of
  their own (#28).
- **Not to be confused with:** [active time](#active-time-uptime-activity). ABC
  is the habit, active time is the number.

### Active time (uptime, activity)

- **Meaning:** The share of a fight the player spent casting or locked by the
  [GCD](#gcd-global-cooldown). Raiders also call this "uptime".
- **In a log:** Percent of [kill time](#kill-time). Add up each
  `begincast`-to-`cast` span, add one GCD for each instant cast, then divide by
  kill time. The GCD length is not in the log, and telling instants apart needs
  [instant cast](#instant-cast) to be verified.
- **Status:** `needs checking`
- **Not to be confused with:** buff or DoT uptime, the share of a fight an
  effect was active. See [buff](#buff-aura). Write "active time" or "buff
  uptime" in this project, never "uptime" alone.

### Builder (generator)

- **Meaning:** A spell that gives you more of a [resource](#resource) to spend
  later.
- **In a log:** Maelstrom gained per cast: `resourceChange` on `resourcechange`
  events with `resourceChangeType` 11, grouped by `abilityGameID`.
- **Status:** `confirmed`
- **In this repo:** The APL uses the word in a comment ("next builder").
  It stops Lava Burst near the cap with `maelstrom.deficit>15`. The app's tables
  hold costs but no gains.
- **Not to be confused with:** [spender](#spender).

### Cast time

- **Meaning:** How long a spell takes from starting it to finishing it.
  [Haste](#haste) shortens it, and an [instant cast](#instant-cast) has none.
- **In a log:** Seconds: `timestamp` of a `cast` minus `timestamp` of the
  `begincast` before it, for the same `sourceID` and `abilityGameID`. A
  `begincast` with no `cast` after it is probably a cancelled or interrupted
  cast.
- **Status:** `confirmed`
- **Not to be confused with:** [GCD](#gcd-global-cooldown).

### Filler

- **Meaning:** The spell you cast when nothing better is available. It is
  always usable, so it sits at the bottom of the priority.
- **In a log:** Percent of all casts. A high share can come from few
  [procs](#proc) rather than poor play.
- **Status:** `needs checking`
- **In this repo:** The APL labels it "Filler spell. Always available. Always
  the bottom line." That is `lightning_bolt` on one target and
  `chain_lightning` on two. While moving it falls through to `flame_shock`,
  `voltaic_blaze` and `frost_shock` with `moving=1`.

### GCD (global cooldown)

- **Meaning:** A short lockout after most spells, during which you can't start
  another spell that uses it. [Haste](#haste) shortens it.
- **In a log:** Seconds. There is no verified field. One estimate is the
  smallest gap between two instant on-GCD casts, which is an upper limit.
- **Status:** `needs checking`
- **In this repo:** APL identifiers `gcd` and `gcd.max`. The sandbox default of
  1.2 seconds in `CombatState` is a starting value, not game data.
- **To check:** The base length and the minimum in Midnight.
- **Not to be confused with:** [cooldown](#cooldown-cd),
  [cast time](#cast-time).

### Haste

- **Meaning:** A stat that makes spells cast faster and shortens the
  [GCD](#gcd-global-cooldown), so you fit in more casts per minute.
- **In a log:** Percent: base [cast time](#cast-time) divided by observed cast
  time, minus 1. Base cast times come from game data, and the app's values are
  approximations. The stat itself may be in `playerDetails`, unverified.
- **Status:** `needs checking`
- **To check:** Whether haste also speeds up Flame Shock ticks and cooldown
  recharge for Elemental in Midnight.

### Instant cast

- **Meaning:** A spell with no [cast time](#cast-time), so it can be used while
  moving. It still uses the [GCD](#gcd-global-cooldown) unless it is also
  [off-GCD](#off-gcd).
- **In a log:** A `cast` with no `begincast` before it, as a percent of casts.
  The verified list doesn't say instants never produce a `begincast`, so check
  this on a sample.
- **Status:** `needs checking`
- **Not to be confused with:** [off-GCD](#off-gcd).

### Maelstrom

- **Meaning:** The [resource](#resource) Elemental Shaman builds and spends.
- **In a log:** Points. Gains and waste come from `resourcechange` events with
  `resourceChangeType` 11. Exact readings come from `classResources` entries with
  `type` 11, on about a quarter of casts. `max` or `maxResourceAmount` gives the
  player's cap.
- **Status:** `confirmed`
- **In this repo:** `maelstrom`, `maelstrom.deficit` (points below the cap),
  `maelstrom.max` and `maelstrom.pct`. The cap is 100, +50 with Swelling Maelstrom
  and +25 with Primordial Capacity (in-game tooltips; a Farseer log shows 125).

### Off-GCD

- **Meaning:** An ability that neither uses nor waits for the
  [GCD](#gcd-global-cooldown), so you can press it alongside another spell.
- **In a log:** A `cast` closer to the previous cast than one GCD allows, as a
  count per minute. Better, keep a list of known off-GCD abilities, since the
  GCD length is not in the log.
- **Status:** `needs checking`
- **In this repo:** `offGcd: true` on Ancestral Swiftness, Nature's Swiftness,
  Spiritwalker's Grace and Wind Shear. In the APL, `use_off_gcd=1` lets SimC use
  an item during the GCD.
- **Not to be confused with:** [instant cast](#instant-cast). Most instants
  still use the GCD.

### Overcap (overcapping, capped)

- **Meaning:** Gaining a [resource](#resource) while already at the maximum, so
  the gain is lost. The same word is used for charges and proc stacks.
- **In a log:** Wasted Maelstrom per minute: the sum of `waste` on
  `resourcechange` events with `resourceChangeType` 11, divided by
  [kill time](#kill-time) in minutes.
- **Status:** `confirmed`
- **What to try (Boss Evaluation):** "Cast a spender before your resource
  reaches its cap."
- **Not to be confused with:** [pooling](#pooling), which stays below the cap.

### Pooling

- **Meaning:** Deliberately not spending a [resource](#resource) in the seconds
  before a known event, usually [adds](#add) spawning, while staying below the
  cap, so it can all be spent when the event starts.
- **In a log:** Around each event: Maelstrom at the moment the event starts
  (points), [spender](#spender) casts per minute in the seconds before and after
  it, and any [overcap](#overcap-overcapping-capped) during the hold. The event
  time comes from [add wave](#add-wave) or [phase](#phase). Maelstrom at a given
  moment has to be rebuilt from gains and spender costs, checked against
  `classResources` readings (`RebuildResourceTimeline`).
- **Status:** `needs checking`
- **In this repo:** The default APL cannot pool, because it has no fight
  timeline. Its main spender lines fire on
  `buff.master_of_the_elements.up` or `maelstrom.deficit<15`, whatever is coming
  next. So pooling always shows up as a [deviation](#deviation), and that
  deviation can be the right play.
- **Measured here as:** `DetectPooling.isHeld`: the gap since the player's last
  [spender](#spender) at the event is over 10 s or twice their own median gap
  between spenders over the fight, and a spender is cast within 5 s after. The
  report also gives Maelstrom at the event, its low and high in the 10 s before,
  and the first spender after. Checked on Twin Fangs: rank 1 held at 98, 192,
  253 and 347 s, not at 37 or 408 s (see [warcraft-logs.md](warcraft-logs.md)).
  A test on the mean Maelstrom (15 above the fight's mean) missed those holds\r\n  and was removed.
- **What to try (Boss Evaluation):** "Let your resource build for about 10 s
  before an add wave, then cast a spender as it arrives."
- **Not to be confused with:** [overcap](#overcap-overcapping-capped), and with
  holding a resource when nothing is coming, which is a
  [mistake](#mistake).

### Resource

- **Meaning:** The bar a spec fills and spends to cast spells, such as Mana or
  [Maelstrom](#maelstrom).
- **In a log:** Points: `classResources` entries with `amount`, `max`, `type`
  and `cost` on a [cast event](#cast-event). They are readings at each cast, so
  nothing between casts is visible. Mana is `type` 0 and Maelstrom is `type` 11.
  For Maelstrom, `resourcechange` events show every gain between casts.
- **Status:** `confirmed`

### Spender

- **Meaning:** A spell that costs a [resource](#resource) and turns it into
  damage.
- **In a log:** Spender casts per minute, from a list of ability ids. A `cost`
  on a `classResources` entry with `type` 11 can confirm the list.
- **Status:** `confirmed`
- **In this repo:** Earth Shock (60), Elemental Blast (90, confirmed in a log) and
  Earthquake (60). The others are approximations. Eye of the Storm takes 5 off, or
  10 off Elemental Blast.
- **Not to be confused with:** [builder](#builder-generator).

## Buffs, debuffs and procs

### Buff (aura)

- **Meaning:** A temporary helpful effect on a player. "Aura" covers both buffs
  and [debuffs](#debuff).
- **In a log:** Buff uptime: percent of [kill time](#kill-time) the buff was
  active, from `applybuff` and `removebuff` events for the player. Stack count at
  a given cast is a second metric. Whether a buff was up for a cast needs the
  roughly 60 ms allowance in the [verified list](#verified-wcl-api-facts).
- **Status:** `confirmed`
- **In this repo:** `buff.<name>.up`, `.stack`, `.remains`, `.react`, and
  `BuffWindows` for logs.
- **Not to be confused with:** [active time](#active-time-uptime-activity).

### Debuff

- **Meaning:** A temporary harmful effect, on an enemy or a player.
- **In a log:** Debuff uptime: percent of the time the target was alive and
  affected, from `events(dataType: Debuffs, sourceID, abilityID)` or the
  `Debuffs` table, which agree. Read as [aura bands](#aura-band).
- **Status:** `confirmed`
- **In this repo:** `debuff.<name>`, such as `debuff.lightning_rod.remains`.

### Aura band

- **Meaning:** One unbroken stretch of an aura on one target, from its apply to
  its remove. A refresh inside a band doesn't start a new one.
- **In a log:** The `bands` of a `Debuffs` table row, or `applydebuff` to the
  next `removedebuff` in events. Uptime is the bands' summed length. A band
  still open at the end of the fight closes at the fight's end. Down time is the
  fight minus the bands.
- **Status:** `confirmed`

### DoT (damage over time)

- **Meaning:** A [debuff](#debuff) that damages its target in repeated ticks.
- **In a log:** DoT uptime per target: percent of the time the target was alive.
  Needs debuff or tick events, which have not been sampled.
- **Status:** `needs checking`
- **In this repo:** `dot.<name>.ticking`, `.remains`, `.refreshable`. Elemental's
  DoT is [Flame Shock](#flame-shock-fs).

### Pandemic

- **Meaning:** The rule that lets you renew a [DoT](#dot-damage-over-time) a
  little early without losing the time it had left, up to a limit.
- **In a log:** Early refreshes: applications that landed with more than 30% of
  the duration left, as a count per minute. Needs debuff events and a verified
  duration.
- **Status:** `needs checking`
- **In this repo:** `dot.flame_shock.refreshable` is true below 30% of duration
  (`apl_state_resolver.dart`). That is 5.4 seconds with the app's 18-second
  Flame Shock.
- **To check:** That the limit is still 30% in Midnight, and that it applies to
  Flame Shock.

### Proc

- **Meaning:** An effect that triggers on its own, often by chance, such as
  [Lava Surge](#lava-surge).
- **In a log:** Procs per minute, from buff applications, and unused procs
  (count) that ended without being spent. Compare rates rather than totals,
  because [kill time](#kill-time) differs. Needs buff events.
- **Status:** `needs checking`
- **Not to be confused with:** [RNG](#rng-random-number-generator-luck). A proc
  is the event, RNG is the luck behind it.

### RNG (random number generator, luck)

- **Meaning:** The random chance built into the game. "Good RNG" means more
  [procs](#proc) or critical hits than average.
- **Status:** `not measurable from logs`
- **In this repo:** A log shows what happened, not what was expected. Boss
  Evaluation should treat a small gap between single logs as possible luck, and
  never as a [mistake](#mistake) on its own.
- **Not to be confused with:** [proc](#proc).

### Snapshot (snapshotting)

- **Meaning:** A lasting effect, usually a [DoT](#dot-damage-over-time), keeping
  the buffs and stats it had when applied, even after those buffs end.
- **In a log:** Damage per tick of one DoT before and after a buff ends, with no
  refresh in between. Needs tick damage events.
- **Status:** `needs checking`
- **To check:** Whether Flame Shock snapshots in Midnight. The APL says "Consume
  spare MotE to buff Flame Shock", which doesn't settle it.
- **Not to be confused with:** SimC's `snapshot_stats` action, which records
  raid-buffed stats before combat and has nothing to do with DoTs.

## Cooldowns and burst

### Alignment (sync)

- **Meaning:** Timing cooldowns so that their effects overlap and multiply each
  other.
- **In a log:** Alignment offset: seconds between the casts of two cooldowns,
  such as Ascendance and Stormkeeper.
- **Status:** `needs checking`
- **In this repo:** The APL says "Ascendance on CD (always with MID2 set), unless
  SK can be sync'd with it" and has trinkets "mimic Ascendance activation
  conditions".

### Burst window

- **Meaning:** A short stretch where [cooldowns](#cooldown-cd) and buffs overlap,
  giving much higher damage than normal.
- **In a log:** Damage per second inside the window, and percent of total damage
  done in it. The window comes from buff start and end times, and both measures
  need unverified events.
- **Status:** `needs checking`

### Cooldown (CD)

- **Meaning:** The wait before an ability can be used again, which some abilities
  store as charges. "CDs" often means just the big ones.
- **In a log:** Cast interval: seconds between `cast` events with the same
  `abilityGameID` and `sourceID`. This shows when the ability was used, not when
  it became ready. Drift is how long after it came ready the next use started,
  which needs the cooldown from game data.
- **Status:** `confirmed`
- **In this repo:** `cooldown.<name>.remains`, `.ready`, `.charges`,
  `.charges_fractional`.
- **Not to be confused with:** [GCD](#gcd-global-cooldown).

### Cooldown efficiency

- **Meaning:** How many uses of a [cooldown](#cooldown-cd) a player got, compared
  with the most they could have had in that fight.
- **In a log:** Percent: casts divided by possible casts. For a one-charge
  ability, possible casts are about `1 + floor(kill time / cooldown)`; with
  charges, the charges plus `floor(kill time / cooldown)`, plus one per cast
  that restores a charge (`PossibleCastsRule`, #78). The cooldown comes from
  game data, and the app's values are approximations that ignore cooldown
  reduction.
- **Status:** `needs checking`
- **Not to be confused with:** a verdict. A cooldown held for an
  [add wave](#add-wave) lowers this number and can still be correct. See
  [deviation](#deviation).

### Potion (pot)

- **Meaning:** A consumable you drink for a strong short effect during a fight.
- **In a log:** Uses per pull, and seconds into the fight of each use. Needs the
  current season's potion ids.
- **Status:** `needs checking`
- **In this repo:** `potion,if=buff.bloodlust.up|cooldown.ascendance.ready|fight_remains<31`.
  The app lists `potion` as unmodelled.

### Trinket

- **Meaning:** A gear slot, of which you wear two. Some trinkets have an effect
  you press (on-use), and others work by themselves (passive).
- **In a log:** Seconds into the fight of each on-use press. Whether presses
  appear as cast events is unverified. The equipped trinkets may be in
  `playerDetails`.
- **Status:** `needs checking`
- **In this repo:** `use_item` lines in the APL, which the app lists as
  unmodelled. `trinket.*` identifiers are not supported.

## Fight and target handling

### Add

- **Meaning:** An extra enemy that joins a boss fight.
- **In a log:** Number of distinct enemy targets besides the boss. A `targetID`
  on a cast shows that a player hit it, and `masterData` may name it.
- **Status:** `needs checking`

### Add wave

- **Wording:** say "add wave" when generic and the add's name when known
  (`EnemyGroup.name`), such as "4 Spawn of Vexhul arrivals".
- **Meaning:** A group of [adds](#add) that arrive together, often at a
  predictable point in the fight.
- **In a log:** Spawn time: seconds into the pull of the first record for a new
  enemy. A player's first cast on it is a late estimate. Compare the same wave
  across logs. Measured here as the first cast by each copy of an enemy NPC
  (`EnemyGroup.arrivals`), a second or so after the spawn; a wave starts when
  none of its group has arrived for 15 s. Twin Fangs waves repeat to within
  0.2 s between pulls. Coiled Altar's Spiteful Soulcoilers (two at a time)
  repeat to within 0.7 s of the phase they follow, but not of the pull, since
  the phases are not on a timer.
- **Not a target:** Twin Fangs' Barbed Bulwark is removed by crowd control or a
  stun, not killed (the owner). It never counts as an enemy alive: an add counts
  only if the player damaged it. Coiled Altar's Manifestations of Dread and
  Axegrinders are left out the same way (the player never hits them).
- **Status:** `needs checking`

### AoE (area of effect)

- **Meaning:** Damage that hits many targets at once, or a stretch of fight with
  many targets.
- **In a log:** Targets hit per cast. Needs damage events.
- **Status:** `needs checking`
- **In this repo:** The APL moves to its `aoe` list at
  `spell_targets.chain_lightning>=3`.
- **Not to be confused with:** [cleave](#cleave).

### Cleave

- **Meaning:** Hitting a small number of extra targets alongside the main one. In
  this project it means exactly two targets.
- **In a log:** Percent of damage on targets other than the main one. Needs
  damage events.
- **Status:** `needs checking`
- **In this repo:** The APL has no cleave list. `single_target` covers one and
  two targets, with conditions such as `spell_targets.chain_lightning=2`.
- **Not to be confused with:** [AoE](#aoe-area-of-effect) and
  [padding](#padding). Cleave on adds that must die is useful damage.

### Intermission

- **Meaning:** A break in a boss fight, usually with different rules or a boss
  you can't hit, after which the fight carries on.
- **In a log:** Start and end in seconds into the pull, from `phases` if they are
  listed there.
- **Status:** `needs checking`
- **Not to be confused with:** [phase](#phase). An intermission is one kind of
  phase, and a short one.

### Mechanic

- **Meaning:** A boss ability the raid must respond to, for example by moving,
  interrupting or standing in a marked place.
- **In a log:** Enemy casts and debuffs on the player, matched to a per-boss list
  of ability ids. Needs events that have not been sampled. Mechanics are the main
  honest reason for a gap in casting.
- **Status:** `needs checking`

### Movement

- **Meaning:** Having to move during a fight. Most non-instant spells can't be
  cast while moving, so casters lose time.
- **In a log:** Straight-line distance between the `x`, `y` of consecutive cast
  events, per minute. Positions exist only at casts, so this undercounts. The
  raw unit is unverified.
- **Status:** `confirmed`
- **In this repo:** `spiritwalkers_grace,moving=1,if=movement.distance>6` and the
  `moving=1` instant lines at the end of each list.
- **Not to be confused with:** SimC's `movement.distance`, a planned distance in
  a simulated fight.

### Opener

- **Meaning:** The planned series of casts at the start of a pull.
- **In a log:** The first casts of a fight: `cast` events for one `sourceID` in
  one of `fightIDs`, in `timestamp` order, as a list of `abilityGameID`s. How many
  casts count as the opener is not decided.
- **Note:** Elemental's accepted openers are listed in
  [elemental-shaman.md](elemental-shaman.md#opener).
- **Status:** `confirmed`
- **Not to be confused with:** [prepull](#prepull).

### Padding

- **Meaning:** Damage that raises a player's numbers without helping to kill the
  boss, such as hitting adds that don't matter. It is a criticism.
- **In a log:** Percent of damage on targets listed as low priority for that boss.
  The log doesn't say which targets those are, so this needs a per-boss list and
  damage events.
- **Status:** `needs checking`
- **Not to be confused with:** [cleave](#cleave) and
  [priority damage](#priority-damage).

### Phase

- **Meaning:** A stage of a boss fight with its own rules, often started by boss
  health or by time.
- **In a log:** Start and end in seconds into the pull. `phases` exists on a
  report, but its fields are unverified.
- **Status:** `needs checking`

### Prepull

- **Meaning:** The time just before a fight starts, used for buffing and for
  casting anything that lasts into the fight.
- **In a log:** Casts with a `timestamp` before the fight starts, and buffs
  already active at the start. Whether `events` returns anything before the fight
  start is unverified.
- **Status:** `needs checking`
- **In this repo:** `actions.precombat` casts Lightning Shield, Flametongue
  Weapon, Thunderstrike Ward and Stormkeeper.
- **Not to be confused with:** [opener](#opener).

### Priority damage

- **Meaning:** Damage on the target that matters most at that moment, usually one
  that must die first.
- **In a log:** Percent of damage on listed priority targets. Needs a per-boss
  list and damage events.
- **Status:** `needs checking`
- **Not to be confused with:** [padding](#padding).

### Pull (fight, attempt)

- **Meaning:** One attempt at a boss, ending in a kill or a [wipe](#wipe). WCL
  calls it a fight.
- **In a log:** One entry in `fights`, chosen with `fightIDs`. A ranked entry
  names its pull with `report {code, fightID}`. Whether `fights` also holds
  non-boss fights is unverified.
- **Status:** `confirmed`

### Target swap

- **Meaning:** Changing your target, usually to deal with an [add](#add).
- **In a log:** Swaps per minute: changes of `targetID` between consecutive `cast`
  events from one `sourceID`. Self-cast and ground-targeted spells may add false
  swaps, so check a sample.
- **Status:** `confirmed`

### Wipe

- **Meaning:** A [pull](#pull-fight-attempt) that ended without killing the boss,
  usually because the raid died or gave up.
- **In a log:** A kill or wipe marker in `fights`, unverified. Also unverified:
  that ranked entries are only ever kills.
- **Status:** `needs checking`

## Group and external buffs

### Augmentation support (Aug)

- **Meaning:** The support spec Augmentation Evoker raises other players' damage
  with buffs. Whether one buffed a player can change that player's numbers.
- **In a log:** Buff uptime on the player, percent, with the buff's source being
  an Augmentation player. Needs buff events and the spec of the source.
- **Status:** `needs checking`
- **To check:** The buffs involved in Midnight, and whether any WCL `metric`
  moves damage from the buffed player to the support. Compare logs on one metric
  only.

### Bloodlust (lust, Heroism, Time Warp)

- **Meaning:** A raid-wide [haste](#haste) buff, usually available once per pull.
  Several classes bring it under different names.
- **In a log:** Seconds into the pull of each use. Needs buff events, and a list
  of every version's ability id.
- **Status:** `needs checking`
- **In this repo:** `buff.bloodlust.up`. The app's aura uses spell id 2825 and a
  40-second duration. Other versions have other ids.

### External buffs (externals)

- **Meaning:** Buffs a player receives from someone else, such as
  [Power Infusion](#power-infusion-pi). A player can't always control whether
  they get them.
- **In a log:** Buff uptime, percent, for buffs whose source is another player.
  Needs buff events. Top logs may have more of these, so a damage gap can come
  from the raid rather than the player.
- **Status:** `needs checking`
- **In this repo:** `invoke_external_buff`, listed as unmodelled.
- **Not to be confused with:** defensive externals, a healer's damage reduction
  on another player. Raiders often say "externals" for those.

### Power Infusion (PI)

- **Meaning:** A [haste](#haste) buff a Priest can put on another player.
- **In a log:** Applications per pull, and buff uptime as a percent. Needs buff
  events.
- **Status:** `needs checking`
- **In this repo:** `invoke_external_buff,name=power_infusion`, under the APL
  comment "Use Power Infusion on Cooldown." The app lists it as unmodelled.
- **To check:** Its effect in Midnight.

### Blessing of the Bronze

- **Meaning:** An Evoker buff on the whole raid before the pull. It takes 15% off
  some cooldowns, such as Spiritwalker's Grace.
- **In a log:** Id 381756. It has no event in the fight, because it is applied
  before the pull. Only `table(dataType: Buffs, sourceID: <player>)` lists it,
  at 100% uptime. See [carried-over aura](#carried-over-aura).
- **Status:** `confirmed`

### Buff `sourceID` and `targetID` (Buffs data)

- **Meaning:** In `dataType: Buffs`, `sourceID` filters on the player holding the
  buff and `targetID` on its caster, the opposite of damage and casts.
- **In a log:** To list a player's buffs, use `sourceID`. The events' own
  `sourceID` field is still the caster.
- **Status:** `confirmed`, on three Sszorak logs.

### Carried-over aura

- **Meaning:** A buff already active when the pull starts, which the fight's
  events never apply.
- **In a log:** Absent from `events(dataType: Buffs)` within the fight. The buff
  `table` reports it with its full uptime. An earlier window shows only
  `removebuff` events from past pulls.
- **Status:** `confirmed`
- **In this repo:** [Blessing of the Bronze](#blessing-of-the-bronze).

### Ebon Might, Prescience and Shifting Sands

- **Meaning:** Buffs an Augmentation Evoker gives other players
  ([Aug support](#augmentation-support-aug)). Ebon Might raises damage.
  Prescience and Shifting Sands came from the same Evoker in the logs checked.
- **In a log:** Ids 395152, 410089 and 413984. Uptime from the buff `table` with
  `sourceID` set to the player. The caster is the `sourceID` of the events.
- **Status:** `needs checking`
- **To check:** Their numbers in Midnight.

### Time Spiral

- **Meaning:** An Evoker spell that gives raid members one free use of a movement
  ability, so raids with more Evokers get more casts. Elemental can spend it on
  Spiritwalker's Grace or Gust of Wind.
- **In a log:** Uses available, and uses spent, from buff id 375256. A buff ending
  on a cast paid for that cast. Overlapping buffs end with a new one starting on
  the same moment, so they count as one use. A normal cast straight after a free
  one only refreshes the buff. Report these apart from normal casts, and name
  them as raid support.
- **Status:** `confirmed`
- **In this repo:** `RaidFreeCastMetrics`. Blessing of the Bronze, also from
  Evokers, takes 15% off Spiritwalker's Grace. It has no buff events in a fight,
  but gaps under 90 seconds show it.

## Character setup and difficulty

### Hero talent (hero tree)

- **Meaning:** A small extra talent tree. Each spec picks one of two, which
  shapes how it plays.
- **In a log:** Which tree was taken. `playerDetails` may show it, unverified.
  A proxy is a tree-only ability appearing in the casts:
  [Ancestral Swiftness](#ancestral-swiftness) for
  [Farseer](#farseer), [Tempest](#tempest) for
  [Stormbringer](#stormbringer).
- **Status:** `needs checking`
- **In this repo:** `heroTreeNames`: 55 Stormbringer, 56 Farseer. Totemic (54) is
  not available to Elemental.

### Heroic

- **Meaning:** The raid difficulty just below [Mythic](#mythic).
- **In a log:** The `difficulty` argument of `characterRankings`. Its values are
  unverified. Compare logs from the same difficulty only.
- **Status:** `confirmed`

### Mythic

- **Meaning:** The highest raid difficulty. Boss fights can have extra mechanics
  there.
- **In a log:** The `difficulty` argument of `characterRankings`. Its values are
  unverified. Compare logs from the same difficulty only.
- **Status:** `confirmed`
- **Not to be confused with:** Mythic+, the dungeon mode, which is ranked
  separately.

### Talent

- **Meaning:** A permanent choice in a character's talent trees that adds or
  changes abilities. A choice node makes you pick one of two talents.
- **In a log:** Which talents were taken: `talentTree` on the `CombatantInfo`
  event, whose ids map to tokens through `TalentEntry.id`. Differences in talents
  can explain a gap on their own, so note them before comparing casts.
- **Status:** `confirmed`
- **In this repo:** `talent.<token>`. `TalentStringCodec` decodes in-game export
  strings, a separate route to the same tokens. Fire Elemental and Storm
  Elemental are not talents in Midnight: the app treats Fire Elemental as baseline
  and hides Storm Elemental and Wind Gust, although the APL still reads them.

### Tier set (set bonus)

- **Meaning:** A seasonal set of gear that gives extra effects for wearing two or
  four pieces.
- **In a log:** Which bonus was active. Gear may be in `playerDetails`, unverified.
  A proxy is the set's [proc](#proc) buffs appearing.
- **Status:** `needs checking`
- **In this repo:** `set_bonus.mid2_4pc`, on by default, with procs
  [Flowing Elements](#flowing-elements) and [Overcharge!](#overcharge). The
  4-piece changes how the APL times Stormkeeper and Ascendance, so compare like
  with like.

## Elemental Shaman terms

These describe how the terms are used in this repo. All the ids and numbers are
the app's, and all the log measures depend on ability ids, so every entry here is
`needs checking`.

### Ancestral Swiftness

- **Meaning:** A [Farseer](#farseer) talent that replaces Nature's Swiftness. It
  is an [off-GCD](#off-gcd) button that makes your next cast instant.
- **In a log:** [Cooldown efficiency](#cooldown-efficiency), percent.
- **Status:** `needs checking`
- **In this repo:** `ancestral_swiftness`, `talent.ancestral_swiftness`,
  `buff.ancestral_swiftness.up`. Cooldown 30 seconds. The APL has no condition on
  it, so it is used whenever ready.
- **To check:** Whether "next cast" covers every spell.
- **Not to be confused with:** [Call of the Ancestors](#call-of-the-ancestors).

### Ascendance

- **Meaning:** A talent with a long [cooldown](#cooldown-cd). The APL plans
  Stormkeeper, Flame Shock and trinkets around it.
- **In a log:** [Cooldown efficiency](#cooldown-efficiency) (percent) and
  [alignment](#alignment-sync) offset with Stormkeeper (seconds).
- **Status:** `needs checking`
- **In this repo:** `ascendance`, `talent.ascendance`, `buff.ascendance.up`,
  `cooldown.ascendance.remains`, `cooldown.ascendance.ready`. Cooldown 180
  seconds, or 120 with First Ascendant. Cast id 114050, buff id 1219480.
- **To check:** What it does while active, and for how long. The app doesn't
  model that. Enhancement and Restoration have their own Ascendance talents, so
  confirm the ability id.
- **Stormkeeper during Ascendance (Boss Evaluation):** casts of Stormkeeper
  (191634) whose `begincast` falls inside an Ascendance window, with the time
  they took (`begincast` to `cast`, else the 1.5 s cast time, which haste
  shortens) and the window left. The window is the buff (114050) events, or when
  the log has none, the Ascendance cast plus 15 s. The APL pre-spends
  Stormkeeper before Ascendance. Rule: `SpecLogRules.castsBeforeWindow`. What to
  try: "Cast Stormkeeper first, then Ascendance."
  (`FindingKind.castBeforeWindow`.)
- **Flame Shock uptime (Boss Evaluation):** the share of the fight Flame Shock
  (188389) was up on the boss, from its [aura bands](#aura-band), with each
  stretch of 1 s or more it was down. Ranked when yours is 10% or more below
  rank 1's. What to try: "Refresh Flame Shock before it falls off."
  (`FindingKind.dotUptime`, `PlayerMetrics.dotUptime`.)

### Call of the Ancestors

- **Meaning:** A [Farseer](#farseer) talent that brings Ancestors to fight
  alongside you. The app tracks how many are active.
- **In a log:** Ancestors called (count): `applybuff` and `applybuffstack` events
  for buff ids 447244 and 445624. Expected is `(guaranteed + 0.08 × eligible casts)
  / 0.8`, using only terms for talents taken. Actual minus expected is luck: read
  it next to its spread, not as a verdict.
- **Status:** `confirmed`
- **In this repo:** `talent.call_of_the_ancestors`,
  `buff.call_of_the_ancestors.up`, `.stack` (up to 5 in the app). The APL often
  uses the talent to mean "this is a Farseer build". The log rule is in
  `elemental_shaman_log_data.dart`.
- **To check:** How long Ancestors stay, whether rolls are shuffled as in SimC, and
  why expected runs 1.4 to 2.8 under actual. Ascendance's rolls are the likely
  reason.
- **Not to be confused with:** `ancestral_call`, a racial action in the APL, and
  [Ancestral Swiftness](#ancestral-swiftness).

### Earth Shock

- **Meaning:** A single-target [spender](#spender). It shares a choice node with
  [Elemental Blast](#elemental-blast-eb), so a build has one or the other.
- **In a log:** Casts per minute, and percent of casts with
  [Master of the Elements](#master-of-the-elements-mote) up.
- **Status:** `needs checking`
- **In this repo:** `earth_shock`, `talent.earth_shock`. Cost 60 in the app. In
  the APL it fires on `buff.master_of_the_elements.up|maelstrom.deficit<15`.
- **Not to be confused with:** [Earthquake](#earthquake-eq), or Frost Shock, which
  the APL only uses while moving.

### Earthquake (EQ)

- **Meaning:** An area [spender](#spender) that hits several targets.
- **In a log:** Casts per minute, and targets hit per cast. `targetID` may not be
  useful if the spell is ground-targeted.
- **Status:** `needs checking`
- **In this repo:** `earthquake`. Cost 60 in the app. In `single_target` every
  Earthquake line needs `spell_targets.chain_lightning=2`, so the APL never casts
  it on one target.
- **To check:** The talent tree has a node with two entries both named
  Earthquake, which suggests two versions of the spell. Farseer logs cast it as
  462620, which is the id the app now uses; 61882 never appeared. The app
  doesn't treat Earthquake as a talent.

### Elemental Blast (EB)

- **Meaning:** An expensive [spender](#spender). It shares a choice node with
  [Earth Shock](#earth-shock), so a build has one or the other.
- **In a log:** Casts per minute, and percent of casts with
  [Master of the Elements](#master-of-the-elements-mote) up. Ability id 117014.
- **Status:** `confirmed`
- **In this repo:** `elemental_blast`, `talent.elemental_blast`. Cost 90, confirmed
  in a log. The APL's `aoe` list also reads `buff.elemental_blast_critical_strike`,
  `_haste` and `_mastery`, which the app doesn't define.
- **To check:** What those three buffs do in Midnight.

### Farseer

- **Meaning:** One of Elemental's two [hero trees](#hero-talent-hero-tree), built
  around [Call of the Ancestors](#call-of-the-ancestors).
- **In a log:** See [hero talent](#hero-talent-hero-tree).
- **Status:** `needs checking`
- **In this repo:** Sub-tree 56, loadout `simc_farseer`. There is no
  `talent.farseer`, so the APL checks `talent.call_of_the_ancestors`.
- **Not to be confused with:** [Stormbringer](#stormbringer).

### Flame Shock (FS)

- **Meaning:** Elemental's [DoT](#dot-damage-over-time), kept on the target for
  most of the fight.
- **In a log:** DoT uptime on the boss, percent of [kill time](#kill-time), and
  early refreshes per minute (see [pandemic](#pandemic)). Counting Flame Shock
  casts isn't enough, because the APL also maintains it with Voltaic Blaze and
  Ascendance casts it unpressed. Uptime comes from debuff events for id 188389
  on the boss (1 API point). Count casts of 188389 only: 470411 fires with every
  cast, never appears as a debuff, and isn't a press.
- **Status:** `confirmed` for uptime. Early-refresh waste is `needs checking`:
  a refresh event carries no remaining time.
- **In this repo:** `flame_shock`, `dot.flame_shock.refreshable`, `.remains`,
  `active_dot.flame_shock`. Duration 18 seconds and cooldown 6 seconds in the app.
  The APL's main refresh line needs `cooldown.ascendance.remains>5`.
- **To check:** How it interacts with Lava Burst in Midnight. The app doesn't
  model any link between them.

### Flowing Elements

- **Meaning:** A Season 2 [tier set](#tier-set-set-bonus) buff. Stormkeeper or
  Ascendance fading gives 2 stacks. Each builder cast spends one, deals 25% more
  damage and gives [Overcharge!](#overcharge).
- **In a log:** Buff id 1300219, from `applybuff`, `applybuffstack`,
  `removebuffstack` and `removebuff` events. Stacks gained per trigger, and stacks
  that ended unused (count).
- **Status:** `confirmed`
- **In this repo:** `buff.flowing_elements`. It stacks to 4. If Stormkeeper fades
  during Ascendance, its stacks wait for Ascendance to end, so both arrive together.
- **To check:** That waiting rule rests on one direct example in a log and the
  project owner's experience.

### Lava Burst (LvB)

- **Meaning:** A cast-time attack on a [cooldown](#cooldown-cd) with charges. It
  also sets up [Master of the Elements](#master-of-the-elements-mote).
- **In a log:** Casts per minute, and casts made at or near maximum charges. Charge
  count isn't logged, so it would have to be estimated from cast times.
- **Status:** `needs checking`
- **In this repo:** `lava_burst`, `cooldown.lava_burst.charges_fractional`. One
  charge, plus one each from Echo of the Elements and Elemental Reverb, with an
  8-second recharge and a 2-second cast. The APL fires it at
  `charges_fractional>1.8` to avoid wasting a charge.
- **Not to be confused with:** [Lava Surge](#lava-surge).

### Lava Surge

- **Meaning:** A [proc](#proc) that resets [Lava Burst](#lava-burst-lvb)'s cooldown
  and makes it instant. It is not free in any other sense: Lava Burst has no
  Maelstrom cost to begin with.
- **In a log:** Procs per minute, and procs that ended unused (count). A Lava
  Burst `cast` with no `begincast` is a proxy, but
  [Ancestral Swiftness](#ancestral-swiftness) gives the same pattern. Needs buff
  events to be exact.
- **Status:** `needs checking`
- **In this repo:** `buff.lava_surge.up`. Duration 10 seconds in the app. The app
  lets it fire Lava Burst with no charges, which matches the reset. It is not in
  the talent tree, so the app treats it as baseline.
- **To check:** What triggers it.

### Master of the Elements (MotE)

- **Meaning:** A talent where casting [Lava Burst](#lava-burst-lvb) buffs your
  next Nature, Physical or Frost spell. The aim is to always make that spell a
  [spender](#spender). It shares a choice node with Molten Wrath.
- **In a log:** Percent of spenders cast with the buff up, from `applybuff` and
  `removebuff` events for buff id 260734. Allow about 60 ms around the cast, but
  the buff must be up before it. A higher percent isn't simply better: a spender
  without the buff is right while Flowing Elements and Overcharge! are both up.
- **Status:** `confirmed`
- **In this repo:** `talent.master_of_the_elements`,
  `buff.master_of_the_elements.up`. The APL also spends it on Tempest and on
  Lightning Bolt with Stormkeeper.
- **Note:** Flame Shock consumes it, and using a spare one there is deliberate.
  With [Flowing Elements](#flowing-elements) and [Overcharge!](#overcharge) both
  up, spend without waiting for it, so a spender without this buff isn't always a
  mistake.

### Overcharge!

- **Meaning:** A Season 2 [tier set](#tier-set-set-bonus) buff that makes your next
  [spender](#spender) free. [Flowing Elements](#flowing-elements) gives it.
- **In a log:** Buff id 1300222. Gains (count), and free spender casts (count), which
  have no `cost` in `classResources`. In three logs, 61 of 121 Elemental Blasts were
  free.
- **Status:** `confirmed`
- **What to try (Boss Evaluation), when free spenders are lost by refreshing:**
  "Cast the free spender before you refresh the buff that gives it."
- **In this repo:** `buff.overcharge_tier`. Don't confuse it with the Overcharge
  talent (1251026), an unrelated critical strike effect.

### Stormbringer

- **Meaning:** One of Elemental's two [hero trees](#hero-talent-hero-tree), built
  around [Tempest](#tempest).
- **In a log:** See [hero talent](#hero-talent-hero-tree).
- **Status:** `needs checking`
- **In this repo:** Sub-tree 55, loadout `simc_stormbringer`. There is no
  `talent.stormbringer`, so the APL checks `talent.tempest`.
- **Not to be confused with:** [Farseer](#farseer) and
  [Stormkeeper](#stormkeeper-sk).

### Stormkeeper (SK)

- **Meaning:** A talent you cast to gain stacks that make Lightning Bolt and Chain
  Lightning instant.
- **In a log:** Press delay (seconds): from a cast, take 3 seconds off the 60 for
  each Ancestor called before it comes ready, including the one it calls itself,
  then measure to the next `begincast`. Luck moves the raw gap, and this is the
  part the player controls. Also stacks that ended unused (count).
- **Status:** `confirmed`
- **In this repo:** `stormkeeper`, `talent.stormkeeper`, `buff.stormkeeper.up`,
  `.stack`, `cooldown.stormkeeper.remains`. Cast 1.5 seconds, cooldown 60 seconds.
  It is also in `actions.precombat`, so a log may show it as the pull starts, with
  no `begincast`.
- **To check:** Whether it does more than make those spells instant. It gives 2
  stacks, so the APL's `buff.stormkeeper.stack<4` passes at any stack count.
- **Not to be confused with:** [Stormbringer](#stormbringer).

### Tempest

- **Meaning:** A [Stormbringer](#stormbringer) spell that replaces Lightning Bolt
  when its buff is up. The same word names the talent, the buff and the spell.
- **In a log:** Casts per minute, and buff stacks that ended unused (count). Spell
  and buff have different ids, so match the right one.
- **Status:** `needs checking`
- **In this repo:** `tempest`, `talent.tempest`, `buff.tempest.up`, `.stack` (up
  to 2 in the app). Spell id 452201, buff id 454015. The app gives it no Maelstrom
  cost.
- **To check:** What grants stacks. The APL's `buff.tempest.stack<2` before
  spending suggests that spending does, but the app doesn't say so.
- **Not to be confused with:** [Stormbringer](#stormbringer), which is the hero
  tree.

## Healer terms

Measured on three Heroic Coiled Altar logs: see "Restoration Shaman" in
[warcraft-logs.md](warcraft-logs.md) and
[restoration-shaman.md](restoration-shaman.md).

### Healing intake

- **Meaning:** The damage the raid takes. Healing done is bounded by it (raid
  healing was 99% to 103% of damage taken in the three logs), so it depends on
  the raid as much as on the healer.
- **In a log:** Raid damage taken per second: the `table(dataType: DamageTaken)`
  total for the fight, no `sourceID`, over fight length. A healer's share of
  raid healing (their `total` in the whole-raid `table(dataType: Healing)`)
  depends on intake and the other healers too: show both, never rank.
- **Status:** `confirmed`

### Overheal (overhealing)

- **Meaning:** Healing past full health, which does nothing. Some is
  unavoidable from heal-over-time effects and totems.
- **In a log:** Overheal share: `overheal` over `total` plus `overheal`, summed
  over the `table(dataType: Healing, sourceID: P)` entries. Shown, not ranked:
  three logs had 13.1% to 14.5%.
- **Status:** `confirmed`

### Healing cooldown (raid cooldown)

- **Meaning:** A long-cooldown spell for heavy raid damage, such as Ascendance
  or Spirit Link Totem. Raids plan them so healers don't overlap.
- **In a log:** Casts against possible, `floor(fight length / cooldown) + 1`.
  Whether a press met heavy damage or overlapped another healer's: not measured.
- **What to try (Boss Evaluation):** "Cast Ascendance each time it comes off
  cooldown." and the same for each such cooldown (generic: "Cast it each time
  it comes off cooldown.")
- **Status:** `needs checking` (cooldowns are tooltip base values)

### Upkeep

- **Meaning:** Keeping an effect running all fight, such as Healing Rain under
  Surging Totem or a Riptide on someone.
- **In a log:** Uptime: `totalUptime` over fight length from
  `table(dataType: Buffs)`, `sourceID: P` for buffs on the healer, `targetID: P`
  for buffs the healer put on others. In the app: `UpkeepAura` rules give
  `PlayerMetrics.upkeep` (#78).
- **What to try (Boss Evaluation):** the spec's sentence for the aura, such as
  "Keep Surging Totem down so Healing Rain never stops." (generic: "Keep it up
  all fight.")
- **Status:** `confirmed`

### Proc hold time

- **Meaning:** How long a [proc](#proc) the player must spend, such as
  Stormstream Totem, waited before it went.
- **In a log:** From the player's buff events: each application or added stack
  waits until a stack goes, oldest first; the average over procs that went
  (`HeldProcMetrics`, #78). Procs still up at the end are counted apart. A proc
  that ran out counts as held until it did. The buff table's `totalUptime` over
  `totalUses` gives nearly the same number, lower when two procs stack.
- **What to try (Boss Evaluation):** "Cast Stormstream Totem as soon as it
  procs." (generic: "Spend the proc as soon as it comes.")
- **Status:** `confirmed`

### Mana

- **Meaning:** The healer's resource. Unspent mana at a kill is healing not
  done; running out early stops healing.
- **In a log:** Mana percent over time: `classResources` type 0 `amount` over
  `max` on each cast, from `events(dataType: Casts, includeResources: true)`.
  Mana from others (Innervate 29166, Source of Magic 369459) is raid support.
  In the app: `ResourceLevelMetrics` (at each phase change, at the end, the
  lowest), when `SpecLogRules.readsResourceLevel` is set (#78).
- **What to try (Boss Evaluation), on mana at the end:** "Spend your mana so
  that it runs out as the boss dies." Mana at phase changes is shown, not
  ranked.
- **Status:** `confirmed`

### Innervate use (free-cast window)

- **Meaning:** Innervate (29166) makes every cast free for 8 s. What the healer
  casts inside it is theirs to control: expensive spells back to back save the
  most mana. How many Innervates a healer gets is raid support, never ranked.
- **In a log:** The player's buff events for 29166 give each window; the casts
  that began inside it are the player's cast events (`FreeCastWindowRule`, #82).
- **Measured as:** per Innervate, the casts inside, **mana saved** (the sum of
  the spec table's nominal `cost` for those casts; spells the table lacks add 0)
  and **fill** (the share of the window spent casting, a GCD cast taking the
  longer of its cast time and the 1.5 s base GCD). Ranked on the average mana
  saved per Innervate, higher is better, left out when any compared log
  received none.
- **What to try (Boss Evaluation):** "Cast Chain Heal back to back while
  Innervate is up." (generic: "Cast your most expensive spells, back to back,
  while the buff is up.")
- **Status:** `unconfirmed`: the owner's must-do; neither Wowhead nor Icy Veins
  states it (validation in #81).

## Raid notes

### NSRT (Northern Sky Raid Tools) note

- **Meaning:** A text note that the NSRT addon imports to show timed
  reminders to a raider during a fight.
- **Format:** One header line, then one line per reminder. `ph` is the phase (1
  when the fight has no phases), `time` is seconds from the pull with one
  decimal, `tag` is the label (lorrgs fills it with the player's name), `spellid`
  is the ability whose icon shows. Every field ends with `;`:

  ```text
  EncounterID:3421;Difficulty:Mythic;Name:The Twin Fangs;
  ph:1;time:0.7;tag:Eliance;spellid:191634;
  ph:1;time:40.2;tag:Eliance;spellid:191634;
  ```

- **Source:** A lorrgs export for Twin Fangs, pasted by the owner on issue #38
  (2026-11-01).
- **Status:** `needs checking`
- **To check:** Whether the import shows a `tag` that is plain text, such as
  `Pool for Broodlings`, on a reminder that is not a cooldown. The app writes
  those with the spender's spell id.
- **In this repo:** `formatNsrtNote` writes it; `BuildReminders` makes the lines
  from rank 1's held waves and Stormkeeper presses.

## SimC and APL terms

### APL (action priority list)

- **Meaning:** A SimulationCraft script listing what to cast, in order, each with
  conditions. At every decision, the first line that passes and can be pressed
  wins.
- **Status:** `not measurable from logs`
- **In this repo:** `assets/apl/shaman_elemental.simc`, a verbatim upstream copy.
  It is the source of truth for priority. A log doesn't contain an APL, but one
  can be replayed against a log. See [deviation](#deviation).
- **Not to be confused with:** a guide. An APL is written for a simulator and has
  no knowledge of a specific boss.

### Priority list (rotation)

- **Meaning:** A way to play where you always cast the highest thing available
  rather than following a fixed order. Raiders usually call this the rotation.
- **Status:** `not measurable from logs`
- **In this repo:** An [APL](#apl-action-priority-list) is the written form. What
  a player actually did is a list of [cast events](#cast-event), and that can be
  compared with a priority list but doesn't show one.

### Sim (simulation, SimC)

- **Meaning:** A run of SimulationCraft, a program that plays a character through
  a fight many times to estimate its damage.
- **Status:** `not measurable from logs`
- **Not to be confused with:** a log. A sim is modelled and a log is what really
  happened. Sims assume things about the fight, often that it is
  [Patchwerk](#patchwerk).

## Deviations: mistakes and plans

**A deviation from the APL is not automatically a mistake.** The APL sees only the
current moment. The bundled file has no fight timeline: it has no `raid_event.*`
condition, and `fight_remains` is the nearest thing to one. It can't know that adds
spawn in 15 seconds, so a player who knows that can do better than it.

Boss Evaluation must report the deviation first and judge it second, in this order:

| Test | Points to a plan | Points to a mistake |
| ---- | ---------------- | ------------------- |
| **Event:** did a known event follow? | Yes: an [add wave](#add-wave), [phase](#phase), [intermission](#intermission) or [burst window](#burst-window) soon after | Nothing followed |
| **Payoff:** was it used at the event? | The held resource or cooldown was spent as the event started | It stayed unspent, or was spent late |
| **Cost:** did the hold waste anything? | Stayed below the cap, and no cooldown use was lost | [Overcapped](#overcap-overcapping-capped), lost a cooldown use, or sat idle |
| **Repeat:** does it recur? | Same deviation at the same point across pulls, or in the top [cohort](#cohort) | One-off |

- **Plan:** Event, Payoff and Cost all point to a plan. Repeat adds support.
- **Mistake:** Cost points to a mistake, and so does Event or Payoff. Value was
  lost, and nothing the log shows justifies it.
- **Unclear:** anything else. Show it to the player, but don't score it.

A deviation forced by a [mechanic](#mechanic) or [movement](#movement) is neither.
A match with the top cohort is evidence, not proof, because top players make
mistakes too. The time windows and the number of matching logs are not decided.
Set them from real logs rather than guessing.

**Example.** Just before an add wave, the APL recommends a [spender](#spender). The
player casts [filler](#filler) instead, stays below the Maelstrom cap, and spends
everything as the adds arrive. That is [pooling](#pooling), and a plan. The same
hold with no adds coming, ending in an overcap, is a mistake. A hold that overcaps
briefly but still spends everything on the adds is unclear: the idea was sound, and
the execution cost something.

### Deliberate plan (plan)

- **Meaning:** A [deviation](#deviation) made on purpose for something coming later
  in the fight. A log can't show intent, so this label comes from evidence.
- **In a log:** The Event, Payoff and Cost tests above all pass.
- **Status:** `needs checking`
- **Not to be confused with:** [mistake](#mistake).

### Deviation

- **Meaning:** A cast that differs from what the
  [APL](#apl-action-priority-list) would recommend at that moment. The word is
  neutral: it doesn't say whether the cast was good or bad.
- **In a log:** Deviations per minute. Rebuild the state at each `cast`, run
  `AplEvaluator.recommend`, and compare with `abilityGameID`. The rebuild needs
  buffs and Maelstrom, which are unverified, and cooldown lengths from game data.
- **Status:** `needs checking`
- **In this repo:** Use this word, not "error", in anything shown to a player until
  the tests above have run.

### Mistake

- **Meaning:** A [deviation](#deviation) that lost value, with no reason the log can
  show.
- **In a log:** The Cost test above fails, and so does Event or Payoff. Cost
  means an [overcap](#overcap-overcapping-capped), a lost cooldown use or idle
  time.
- **Status:** `needs checking`
- **Not to be confused with:** [deliberate plan](#deliberate-plan-plan) or
  [RNG](#rng-random-number-generator-luck). Poor luck is not a mistake.

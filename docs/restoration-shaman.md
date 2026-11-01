# Restoration Shaman mechanics

What we've checked about Restoration (spec 264) on patch 12.1.5, for Boss
Evaluation of healing logs. SimC has no Restoration APL or profile. Sources:
**log** (queries and the three logs under "Restoration Shaman" in
[warcraft-logs.md](warcraft-logs.md)), **tooltip**
(`nether.wowhead.com/tooltip/spell/<id>`, base values before talents), **tree**
(the generated talent tree, build 12.1.5.70688) and **guide**.

## Community guidance

**Questionably Epic has no Restoration Shaman guide** (checked 2026-11-01). Its
site has Restoration Druid and Mistweaver Monk guides, and
`questionablyepic.com/resto-shaman` and `/restoration-shaman` return 404. Its
raid pages are per boss. The Coiled Altar sheet
(`questionablyepic.com/venomous-abyss/coiled-altar`, PDF) tells healers:
"CDs when globules are destroyed. Dispel Venomfang poison."

The owner's written sources are **Wowhead** (Harreks, "Restoration Shaman
Rotation Guide - Midnight", 12.1.5, updated 2026-10-13) and **Icy Veins**
(Seksixeny, "Healing Rotation, Cooldowns, and Abilities", 12.1.5, updated
2026-10-12), with **Method** (Radio, playstyle and talents pages, 12.1.5,
updated 16 Oct 2026) third. Wowhead's page body is drawn by script and Icy
Veins returns 403 to fetches, so the owner captured both pages' text in a
browser on 2026-11-01; every row below is from that text or Method's page.
Icy Veins marks Totemic "BEST CHOICE" for raid and Mythic+; Method agrees.

Totemic raid priorities, in order. Wowhead: Stormstream procs, Riptide on
cooldown, Nature's Swiftness, keep Surging Totem up, Healing Stream Totem on
cooldown, Chain Heal or Healing Wave. Icy Veins: Healing Stream / Stormstream
at max charges or in Ascendance, Nature's Swiftness on cooldown (on Chain Heal),
place Surging Totem well, Riptide on cooldown, Chain Heal, Healing Wave, DPS when
safe. Method: Surging Totem, Healing Stream Totem, Riptide, then filler.

| Must-do | Named by | How a log measures it | Log evidence (#81, partial): H top / mid / owner; M top / mid |
| --- | --- | --- | --- |
| Spend Stormstream procs at once (buff lasts 60 s, stacks to 2) | Wowhead (first), Icy Veins | Average time buff 1267089 is held: `totalUptime` / `totalUses`. Buff uses equalled casts in all three logs; stack events not checked | hold 1.77 / 2.51 / 4.15 s; 3.28 / 2.66 s |
| Riptide on cooldown, on someone without one | all three | Riptide casts per minute; Riptide out (61295, `targetID` Buffs table) | of possible at 5 s: 97 / 93 / 43%; 96 / 93% |
| Nature's Swiftness on cooldown, on Chain Heal | Wowhead, Icy Veins (Method: not named) | Casts against possible (1 min). What it was spent on is the next cast | 100 / 88 / 67%; 90 / 90% |
| Keep Surging Totem (its Healing Rain) up, placed where most stand | all three; first for Method, fourth for Wowhead, third for Icy Veins | Healing Rain buff 1307888 uptime; casts against possible (25 s, lasts 25 s). Placement: not measurable | Healing Rain 93.7 / 92.8 / 66.8%; 94.5 / 90.4%. Casts 92 / 91 / 69%; 92 / 90% |
| Healing Stream Totem on cooldown | all three | Casts of 5394 against possible: a Stormstream cast restores a charge (Wowhead), so possible is `2 + floor(length / 30) + Stormstream casts` (recharge assumed unhasted) | 93 / 91 / 68%; 92 / 94% |
| Ascendance prepared: two Tidal Waves, Surging Totem right before, totems during | Wowhead | Surging Totem cast within about 1 s before Ascendance; Healing Stream and Stormstream casts in its 15 s. Tidal Waves stacks need Buffs events (not fetched); two Riptides in the 12 s before is a proxy | not measured |
| Ascendance, Spirit Link Totem for heavy damage, not overlapping | all three | Casts against possible. Whether damage was heavy or overlapped: raid-dependent | Ascendance 100 / 100 / 50%; 75 / 75%. Spirit Link 67 / 100 / 50%; 67 / 71% |
| Chain Heal or Healing Wave by how many are hurt and mana | all three | Cast counts only. How many were hurt: not measurable | not measured |
| Mana: percent near the boss's health percent, ending near 0% (Icy Veins); pace Chain Heal (Wowhead) | Wowhead, Icy Veins | Mana at phase changes and at the end from `classResources`. Boss health over time not fetched | end 12.9 / 5.7 / 19%; 14.8 / 20.0% |
| DPS when no one is in danger (Icy Veins); Lava Burst on Lava Surge (Method) | Icy Veins, Method | Damage casts per minute. Whether anyone was in danger: not measurable | not measured |
| Pre-pull: Water Shield on self, Earth Shield on tank and self | Icy Veins (Method: Earth Shield on tank) | Earth Shield 974 (others) and 383648 (self) uptime. Water Shield 52127 is in no log's Buffs table; whether logs record it is unknown | Earth Shield on others 0 / 0 / 94%; 0 / 99% |
| Unleash Life on cooldown | Wowhead (short cooldowns in general), Icy Veins (Farseer list only), Method | Not ranked: no top-40 log takes it | not measured |

**Where they differ:** Surging Totem's place (first for Method, below Riptide
for Icy Veins); Nature's Swiftness (high for Wowhead and Icy Veins, absent from
Method); only Wowhead gives the Ascendance preparation. Icy Veins says Lightning
Bolt is free, but it cost 500 mana in the owner's log.

## Hero trees and the top-log build

Restoration has Farseer (sub-tree 56) and Totemic (54) (tree). **All 40 of the
top 20 Heroic and top 20 Mythic Coiled Altar logs are Totemic** (rankings,
2026-11-01), as Icy Veins and Method recommend.

The API gives no export string, only `talents: [{talentID, points}]` on each
ranked entry. Every `talentID` matched a `TalentEntry.id` in the tree. Class
trees all differ, so builds are compared on the spec and hero trees:

- **Heroic:** 14 of the top 20 run the same build. **The owner's Heroic kill
  runs exactly this build** (its `CombatantInfo`).
- **Mythic:** no build leads clearly: the top three have 5, 5 and 4 of 20. The
  most common swaps Torrent for Acid Rain and Amplification Core for Oversurge.
- **Choices that vary:** the hero choice Amplification Core / Oversurge (15/5
  Heroic, 11/9 Mythic); Torrent (17 Heroic, 10 Mythic); Acid Rain (3, 12);
  Coalescing Water (19, 18).
- **Choices nobody makes:** Healing Tide Totem shares a node with Ascendance and
  all 40 take Ascendance. Unleash Life, Downpour and First Ascendant are in no
  top-40 build.

The Heroic build's spec and hero talents: Ancestral Reach, Ascendance,
Coalescing Water, Current Control, Deeply Rooted Elements, Deluge, Earthliving
Weapon, Echo of the Elements, Healing Rain, Healing Stream Totem, Living Stream,
Overflowing Shores, Preeminence, Primal Tide Core, Quickstream, Resurgence, Rip
Current, Riptide, Soothing Rain, Spirit Link Totem, Stormstream Totem (three
nodes, one at 2), Swelling Tides, Tidal Waves, Tidewaters, Torrent, Undercurrent
(2), Water Totem Mastery, Wavespeaker's Blessing (2), White Water; Totemic:
Amplification Core, Earthsurge, Elemental Attunement, Imbuement Mastery, Lively
Totems, Oversized Totems, Primal Catalyst, Splitstream, Supportive Imbuements,
Surging Totem, Totemic Momentum, Totemic Rebound, Whirling Elements, Wind
Barrier.

## Spells and ids

Ids seen in the three Coiled Altar logs; names checked on the Wowhead tooltip.
Cost is the `classResources` `cost` in the logs (max mana 250,000 for the owner,
283,920 for both top logs; the log doesn't say why they differ).

| Spell | Cast | Buff / heal | Cost | Base cooldown (tooltip) |
| --- | --- | --- | --- | --- |
| Riptide | 61295 | 61295 (HoT, heal) | 3,800 | 6 s; Echo of the Elements adds a charge |
| Chain Heal | 1064 | 1064 | 10,700 | |
| Healing Wave | 77472 | 77472 | 5,950 | |
| Healing Stream Totem | 5394 | 5394 (heal) | 4,500 | 30 s, a second charge from the second node |
| Stormstream Totem | 1267068 | proc 1267089 | 4,500 | Proc from each Nature's Swiftness and 6% of Riptide casts (Wowhead); restores a Healing Stream charge |
| Surging Totem | 444995 | Healing Rain 1307888 (buff), 73921 (heal) | 16,250 | 25 s, lasts 25 s |
| Ascendance | 114052 | 114052 | | 3 min, 15 s |
| Spirit Link Totem | 98008 | 325174; heal and damage 98021 | 5,500 | 3 min |
| Earth Shield | 974 on others, 383648 on the Shaman (in rank 50's own Buffs table) | heal 379 | 5,000 | |
| Earthliving Weapon | 382021 (imbue) | 382024 (HoT) | | |
| Nature's Swiftness | 378081 | 378081 | | 1 min |
| Spiritwalker's Grace | 79206 | 79206 | 7,050 | 2 min |
| Tidal Waves | | 53390 | | |
| Coalescing Water | | 470077 | | |
| Undercurrent | | 383235 | | |
| Amplification Core | | 456369 | | |

- **Ascendance procs.** Each log has more Ascendance buffs than casts (owner 4
  for 1 cast, both top logs 8 for 2), probably from Deeply Rooted Elements.
  Count casts of 114052 for cooldown use, not buffs.
- **Not in Midnight's tree or logs:** Primordial Wave and Mana Tide Totem have
  no tree entry, and no log cast them (Mana Tide 16191's tooltip still exists).
  Healing Tide Totem (108280) is untaken.
- **Not explained:** rank 1 cast Riptide 61 times in 305 s, more than two
  charges of a 6 s cooldown allow (52). Neither guide names a reduction for
  Totemic. Healing Stream Totem's counts fit once Stormstream restores charges.

## What the tables hold (#76)

`restoration_shaman_data.dart` and `restoration_shaman_log_data.dart` take their
ids, costs and cooldowns from the Spells table above, with these additions:

| Entry | Value | Source |
| --- | --- | --- |
| Lightning Bolt 188196 | 500 mana, 2.5 s cast | log (owner's cost, above); tooltip |
| Flame Shock 188389, Lava Burst 51505 | 750 and 1,250 mana | tooltip: 0.3% and 0.5% of 250,000 base mana (no log cast them) |
| Earth Shield | cast 974, alias 383648 | Spells table; `castAliases {383648: 974}` |
| Healing Rain 1307888 | 25 s | Surging Totem's duration above |
| Stormstream buff 1267089 | 60 s, 2 stacks | the ticket (#76); tooltip names the proc, not the length |
| Ascendance buff 114052 | 15 s | Spells table (the buff ran 24 s in the fixture's window) |
| Tidal Waves 53390 | 2 stacks | tooltip |
| Earthliving 382024 | 6 s HoT | tooltip |
| Earth Shield durations | 600 s, not checked | placeholder for the editor only |
| Innervate 29166, Source of Magic 372571 | raid support | fixture's received-buffs and abilities tables. Source of Magic's cast id on the Evoker is 369459 (tooltip); the buff on the Shaman logs as 372571 |
| Riptide, Healing Stream Totem charges | 2 each | Spells table; Echo of the Elements and the second node are in the build |

Ranking metric: `SpecLogRules.rankingMetric` is `hps` here and `dps` for
Elemental; the rankings query writes it in (`metric: hps`).

**The build.** Every spec and hero name in the list above resolved to one tree
entry, except Stormstream Totem, which has three entries (a one-rank, a two-rank
and a one-rank node) that share the token `stormstream_totem`. Rank 1's
`CombatantInfo` has exactly these 43 spec and hero tokens. The loadout's export
string is rank 1's whole tree written by the same bit layout the codec reads
(zero tree hash, as third-party tools write it); it decodes to spec 264, hero
tree 54. Not tried in game.

**The Mythic build (#78).** Rankings again on 2026-11-01
(`characterRankings(metric: hps, difficulty: 5, includeCombatantInfo: true)`,
page 1, 2 points): the top 20's most common spec and hero build is at ranks 1,
5, 6, 9 and 18. It **ties** with the Heroic build (ranks 4, 15, 16, 17 and 19,
5 each). Next: Acid Rain for Torrent alone (4), then two builds with 2 each. The
second loadout, "Top Mythic logs, Totemic, 2026-11-01", is the Heroic build with
Acid Rain for Torrent and Oversurge for Amplification Core, 43 tokens. Its export
string is Mythic rank 1's (`nDhy4JNt3kYamjwV`, fight 1) ranking `talents`
written the same way as the Heroic one (76 nodes taken, none granted or partly
ranked, 15 choices, the same as the Heroic string). It decodes to spec 264,
hero tree 54, with exactly those tokens. Not tried in game. The Heroic build
stays first.

**Earth Shield on whom.** Rank 50's buff table by caster has Earth Shield 383648
(self) at 100% and no 974 (others): it kept Earth Shield on itself, not on a
tank. The metrics rank 974 and show 383648 (see "Metrics and findings" in
[warcraft-logs.md](warcraft-logs.md)).

## Open questions

- ~~What shortens Riptide's cooldown~~: **Rip Current** (1254251, "Reduces the
  cooldown of Riptide by 1.0 sec", tooltip), so 5 s with Echo of the Elements'
  two charges. Every measured top and mid log takes it, and their Riptide casts
  fit a 5.0 s cooldown (#81, "Validation" in [warcraft-logs.md](warcraft-logs.md)).
- Heroic against Mythic: top-20 Mythic kills last 502 to 627 s, Heroic 250 to
  489 s, so pair Heroic with Heroic until someone checks.

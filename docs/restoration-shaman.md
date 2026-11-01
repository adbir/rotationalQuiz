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

The owner's written sources are **Wowhead** (Harreks, 12.1.5, updated
2026-10-13) and **Icy Veins**, with **Method** (Radio, 12.1.5, updated 16 Oct
2026) as a third. What was read, on 2026-11-01, with WebFetch and WebSearch:

- **Method** `method.gg/guides/restoration-shaman/playstyle-and-rotation` and
  `/talents`: loaded in full.
- **Wowhead** `guide/classes/shaman/restoration/overview-pve-healer` and
  `/rotation-cooldowns-pve-healer`: the pages load, but the guide body is
  rendered by script and came back empty (title and metadata only).
- **Icy Veins** `restoration-shaman-pve-healing-guide`,
  `-rotation-cooldowns-abilities` and `-spell-summary`: HTTP 403. The Wayback
  Machine can't be fetched. Icy Veins rows below come from search-result
  excerpts of those pages, not the page itself, so treat them as unconfirmed.

Wowhead adds nothing until someone reads it in a browser.

| Must-do | Named by | How a log measures it |
| --- | --- | --- |
| Keep Surging Totem (its Healing Rain) up | Method (first); Icy Veins (Healing Rain only where several allies will stay in it) | Healing Rain buff 1307888 uptime; Surging Totem casts against possible (25 s cooldown, lasts 25 s) |
| Healing Stream Totem on cooldown | Method, Icy Veins | Casts of 5394 plus 1267068 (Stormstream replaces one). Possible needs the real cooldown; see below |
| Riptide on cooldown, on targets without it | Method, Icy Veins | Riptide casts per minute; Riptide out (61295 in the `targetID` Buffs table) |
| Unleash Life on cooldown | Method, Icy Veins | **Disagrees with the logs:** no top-40 log takes it (tree, rankings), so not ranked |
| Earth Shield on a tank | Method | 974 uptime in the `targetID` Buffs table. Who held it needs events |
| Ascendance, Spirit Link Totem (Icy Veins adds Healing Tide Totem) for heavy damage, not overlapping other healers | Method, Icy Veins | Casts against possible. Whether the damage was heavy, or overlapped, is raid-dependent. Healing Tide is untaken |
| Nature's Swiftness on a Chain Heal | Icy Veins | Casts against possible (1 min). Which spell it was spent on needs the next cast |
| Chain Heal or Healing Wave by how many are hurt, as filler | Method, Icy Veins | Cast counts only. The log can't show how many were hurt when cast |
| Lava Burst on Lava Surge when a GCD is spare | Method | Damage casts. Whether a GCD was spare: not measurable |
| Mana | none: Method has no mana advice, and no 12.1.5 mana advice from Icy Veins turned up | Mana from `classResources` type 0 on every cast |

**Where the guides disagree:**

- **Hero tree:** a search excerpt says Icy Veins recommends Farseer for raid
  and Totemic for Mythic+. Method recommends Totemic for raid, and so do all 40
  top logs. Unconfirmed until the page is read.
- **Order:** Method puts Surging Totem first; Icy Veins lists Unleash Life,
  Riptide, Healing Stream Totem and Healing Rain as the short-cooldown core.
- **Riptide cooldown:** Icy Veins' 12.1.5 notes say Offering from Beyond now
  takes 2 s off Riptide's cooldown. That is a Farseer talent (sub-tree 56), so it
  doesn't explain the Totemic top logs' Riptide counts.

## Hero trees and the top-log build

Restoration has Farseer (sub-tree 56) and Totemic (54) (tree). **All 40 of the
top 20 Heroic and top 20 Mythic Coiled Altar logs are Totemic** (rankings,
2026-11-01). Method also recommends Totemic for raid.

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
| Stormstream Totem | 1267068 | proc 1267089 | 4,500 | Riptide has a 6% chance to turn the next Healing Stream Totem into it |
| Surging Totem | 444995 | Healing Rain 1307888 (buff), 73921 (heal) | 16,250 | 25 s, lasts 25 s |
| Ascendance | 114052 | 114052 | | 3 min, 15 s |
| Spirit Link Totem | 98008 | 325174; heal and damage 98021 | 5,500 | 3 min |
| Earth Shield | 974 (owner, rank 1), 383648 (rank 50) | heal 379 | 5,000 | |
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
- **Not checked:** cooldown reductions. Rank 1 cast Riptide 61 times and Healing
  Stream Totem 19 times in 305 s, more than the base cooldowns allow, so
  "possible" for those two needs the talents read first.

## Open questions

- Wowhead's and Icy Veins' guide text: read them in a browser and confirm the
  Icy Veins rows and its hero tree advice.
- Heroic against Mythic: top-20 Mythic kills last 502 to 627 s, Heroic 250 to
  489 s, so pair Heroic with Heroic until someone checks.

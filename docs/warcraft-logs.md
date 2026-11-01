# Working with Warcraft Logs

How to reach the API and read a fight without being misled. Field-level API
facts are in [glossary.md](glossary.md), under "Verified WCL API facts". Spell
facts are in [elemental-shaman.md](elemental-shaman.md).

## Access

- **API:** v2 GraphQL, at `https://www.warcraftlogs.com/api/v2/client`. Rankings
  and fights come from one endpoint, and the schema can be inspected with
  `__type` queries.
- **Local credentials:** a client ID and secret from your Warcraft Logs profile
  go in a git-ignored `.env` as `WCL_CLIENT_ID` and `WCL_CLIENT_SECRET`. The repo
  is public. Keep them out of commits, chat and output.
- **Rate limit:** 1,000 points per hour. It's cheap: rankings for all 10 bosses
  cost 1 point, and one full fight about 20.
- **Live check:**
  `WCL_LIVE=1 flutter test test/data/warcraft_logs_live_test.dart`. Normal test
  runs make no network calls.

## Sign-in for the public site

The site can't hold a client secret. CORS allows `oauth/token`, `api/v2/client`
and `api/v2/user` from `https://adbir.github.io`, so no backend is needed: each
user signs in with their own account through PKCE. `WarcraftLogsService` takes
its token from an `AccessTokenSource`, so sign-in plugs in there.

`PkceAccessTokenSource` (`lib/data/services/`) does the sign-in:

- **Client:** the public client ID is the constant `wclPublicClientId`. There is
  no secret. Never read or copy `WCL_CLIENT_SECRET`.
- **Start:** the Setup screen's Sign in button stores a random verifier and
  `state` in `LocalStore` and sends the browser to
  `https://www.warcraftlogs.com/oauth/authorize` with `response_type=code` and
  an S256 challenge.
- **Return:** `main()` calls `handleRedirect()` on startup. A `?code=` (with a
  matching `state`) is exchanged at `oauth/token`, and the query is removed from
  the address bar.
- **Token:** stored in `LocalStore` under `wcl_token` as
  `{access_token, expires_at}`. There is no refresh: once it expires the user
  signs in again.
  `PkceAccessTokenSource.call` is the `AccessTokenSource`, and throws when
  signed out.
- **Redirect URLs:** `https://adbir.github.io/rotationalQuiz/` on the site and
  `http://localhost:5000/` locally (`flutter run -d chrome --web-port 5000`).
  Both must be registered on the Warcraft Logs client.
- **Tests:** the URL, exchange, expiry and sign-out are unit tested with a mock
  HTTP client. The real browser round trip can't run headless; check it by hand
  on the live site.

The sign-in is not yet used by a screen that loads logs. That belongs with #13.

## Current raid

Zone 53, The Venomous Abyss. Difficulty 5 is Mythic.

| Id | Boss |
| -- | ---- |
| 3470 | Nek'zali the Soulcoiler |
| 3445 | Entombed Sentinels |
| 3455 | Vashnik the Malignant |
| 3497 | The Lost Explorers |
| 3420 | Sszorak |
| 3421 | The Twin Fangs |
| 3429 | The Coiled Altar |
| 3492 | Ula'tek |
| 3379 | Nymrissa Wavecaller |
| 3513 | Kith'ix |

Each boss's rankings return 100 rows a page. A report URL holds what `loadFight`
needs: `reports/<code>?fight=58&source=278`.

## Reading a fight

- **Maelstrom** comes from two places. `resourcechange` events show every gain
  and its `waste`. `classResources` on a cast is an exact reading, but only about
  a quarter of casts carry Maelstrom.
- **Rebuilding Maelstrom** (`RebuildResourceTimeline`, checked on the 75 s
  Sszorak fixture, 19 readings). A `resourcechange` has `resourceChange` (gross
  gain), `resourceChangeType` 11, `maxResourceAmount` (125 for this build) and
  `waste`. Findings:
  - A reading is taken after that moment's gains and before its spend.
  - A spender with a reading but no `cost` was free; with `cost` 90 it is
    Elemental Blast.
  - Hold gains at the cap and ignore `waste`. Also subtracting `waste` drifted
    8 points low, so the two double count.
  - Drift against readings: 0 for 15 of 19, worst 8 (one Lava Burst gain),
    mean about 1.
  - The first reading sets the starting amount when the log starts mid-pull.
- **Enemy first-seen times** (adds). `fights.enemyNPCs {id, gameID,
  instanceCount, groupCount}` lists each kind of enemy, the boss included, with
  no times. `masterData.actors(type: "NPC") {id name}` names them. Times come
  from `events(dataType: Casts, hostilityType: Enemies, sourceID: <npc id>)`:
  each copy has its own `sourceInstance`, and its first cast is when it
  arrived, a second or so after it spawned. `loadEnemyGroups` does this for
  every NPC with more than one copy, one query each. When they left comes from
  deaths and the damage they took: see "Enemies alive" under the Twin Fangs
  example.
- **Two readings in one millisecond** can come in the wrong order: one before
  a spend and one after. That shows as one large drift in a rebuild (81 in the
  rank 53 log) and nowhere else.
- **Buff ids can differ from cast ids:** Ascendance casts as 114050, and its buff
  is 1219480.
- **Some ids are echoes.** Flame Shock 470411 fires with every 188389 cast, so
  count only 188389.
- **A free spender has no `cost`.** About half of Elemental Blasts are free.
- **Allow for timing.** A buff can be removed a few milliseconds before or after
  the cast that used it. Treat a buff as up within about 60 ms of a cast, or
  buffed casts are undercounted.
- **A lost proc shows as `refreshbuff`.** Overcharge! refreshing means a free
  spender was lost.
- **Buffs from others appear in the player's stream.** Filter on `targetID` where
  it matters.
- **Overlapping buffs:** a second Time Spiral ends the first and starts a new
  one at the same moment. Merge those before counting.

| Buff | Id |
| ---- | -- |
| Master of the Elements | 260734 |
| Stormkeeper | 191634 |
| Ascendance | 1219480 |
| Call of the Ancestors | 447244, 445624 |
| Flowing Elements | 1300219 |
| Overcharge! | 1300222 |
| Time Spiral | 375256 |

## Comparing fairly

- **Match kill length and item level.** Rank 1 alone misleads: a short kill keeps
  more of the fight under Bloodlust. Show a top-100 log of similar length beside
  it.
- **Separate luck from play.** For Ancestors, compare actual with expected, then
  measure how long Stormkeeper sat ready before it was pressed.
- **Name raid support.** Time Spiral, Blessing of the Bronze, Power Infusion and
  Augmentation buffs come from others. Report them next to the result.
- **A metric says what happened, never why.** A mechanic may explain a gap.
- **A deviation from the APL isn't automatically a mistake.** See "Deviations" in
  [glossary.md](glossary.md).

## Worked example: Mythic Sszorak

All three are Farseers with the same key talents.

| | Rank ~1133 | Rank 18 | Rank 1 |
| --- | --- | --- | --- |
| Report / fight | `ycBrVaJAgKvNLCMj` / 58 | `HJ6dAfkFbV4tXRZp` / 38 | `mG9M7nV1CDZWgJHL` / 32 |
| Kill length | 371 s | 370 s | 288 s |
| DPS | 200,744 | 264,477 | 288,429 |
| Item level | 330 | 335 | 336 |
| Casts per minute | 44.7 | 53.8 | 53.1 |
| Gaps over 1.8 s | 18 | 4 | 7 |
| Maelstrom per minute | 284 | 358 | 352 |
| Maelstrom wasted | 99 | 11 | 0 |
| Elemental Blasts with Master of the Elements | 38 of 38 | 34 of 46 | 27 of 37 |
| Overcharge! lost by refreshing | 2 | 0 | 1 |
| Ancestors, actual / expected | 44 / 41.6 | 50 / 48.6 | 40 / 37.2 |
| Stormkeeper median press delay | 2.17 s | 0.76 s | 1.03 s |
| Free Elemental Blasts | 20 of 38 | 22 of 46 | 19 of 37 |
| Spiritwalker's Grace, normal + Time Spiral | 4 + 2 | 4 + 6 | 4 + 2 |

The biggest gap for rank ~1133 was casts per minute, in every phase. That lowered
Maelstrom gained and Elemental Blasts cast. Ancestors per cast were the same in
all three, so luck wasn't the cause. Buffing every Elemental Blast isn't simply
better: top players fire without Master of the Elements when both tier buffs are
up, and waiting for it lost two Overcharge! in that log. All damage went to the
boss on this fight, so it can't test pooling.

Casts per minute leaves out echo ids. Press delay runs from Stormkeeper coming
ready to the `begincast`, because a cast time isn't delay.

This is one comparison log, and it doesn't show how much DPS each difference is
worth.

## Worked example: Mythic Twin Fangs

Encounter 3421. Three Farseers (all have Call of the Ancestors), with the
owner's wipe first. Rank 1 and rank 53 are from the top 100 on 2026-11-01.

| | Owner, 1% wipe | Rank 53 | Rank 1 |
| --- | --- | --- | --- |
| Report / fight | `dvpkyx8D4YnAHGJK` / 18 | `pDkwjXv3Z2Q8mBVc` / 2 | `CGjdNa8RBfcQtAWg` / 33 |
| Fought length | 394 s (wipe) | 415 s (kill) | 420 s (kill) |
| DPS | 227,344 | 302,100 | 336,697 |
| Item level | 333 | 333 | 337 |
| Casts per minute | 41.0 | 52.0 | 55.0 |
| Gaps over 1.8 s | 20 | 2 | 2 |
| Maelstrom per minute | 318 | 407 | 452 |
| Maelstrom wasted | 111 | 136 | 208 |
| Spenders with Master of the Elements | 34 of 41 | 34 of 55 | 39 of 59 |
| Free spenders | 17 of 41 | 24 of 55 | 24 of 59 |
| Overcharge! lost by refreshing | 3 | 0 | 0 |
| Ancestors, actual / expected | 43 / 41.6 | 59 / 53.0 | 60 / 56.3 |
| Stormkeeper median press delay | 2.87 s | 3.00 s | 6.73 s |
| Spiritwalker's Grace, normal + Time Spiral | 2 + 0 | 4 + 2 | 4 + 3 |

Spenders here are Elemental Blast and Earthquake together. Compare fought
portions, not totals: the owner's pull ended at 394 s. Casts per minute by
stretch, for the 394 s all three fought (the stretches start at each add wave):

| Stretch (s) | 0-37 | 37-98 | 98-192 | 192-253 | 253-347 | 347-394 |
| --- | --- | --- | --- | --- | --- | --- |
| Owner | 76.2 | 39.3 | 42.1 | 37.4 | 38.3 | 23.0 |
| Rank 53 | 73.0 | 47.2 | 50.4 | 54.1 | 44.7 | 57.4 |
| Rank 1 | 76.2 | 47.2 | 50.4 | 55.1 | 52.3 | 62.6 |

All three open the same, then the owner drops about 8 casts per minute behind
in every stretch and ends at 23 against 57 and 63. The owner wasted 110 of the
111 Maelstrom between 192 s and 253 s, sitting at the cap.

### Add waves

Wave times come from `loadEnemyGroups`. Six waves of Spawn of Vexhul (3 each)
and Broodling of Ithraz (10 each) arrive at 37, 98, 192, 253, 347 and 408 s, and
six of Barbed Bulwark (15 each) at 11, 72, 166, 227, 321 and 382 s. They repeat
to within 0.2 s in all three logs, so they are on a timer, like Sszorak's
phases. The owner reached the first five Vexhul waves and all six Bulwark waves.
Rank 53 killed at 415 s: its 408 s Broodlings came, its Vexhul spawns did not
log. There are no phase changes in the log.

The Barbed Bulwarks are not adds to kill or to count as targets: crowd control or a
stun removes them (the owner). Their waves are timing markers only; see "Enemies
alive".

Per wave (the Broodlings' first cast, about 0.5 s after the spawn): the
rebuilt Maelstrom at the spawn, the lowest and highest in the 10 s before,
seconds since the last spender, and the first
spender after with its offset (Earthquake is EQ, Elemental Blast EB). A wave
reads as held when the gap since the last spender is over 10 s or twice the
player's median gap, and a spender follows within 5 s. Held waves are marked *.

Rank 1 (median gap between spenders 5.2 s):

| Wave (s) | At spawn | Low / high | Since last | First after |
| --- | --- | --- | --- | --- |
| 37 | 40 | 11 / 101 | 4.6 s | +5.1 s EQ |
| 98 * | 103 | 50 / 103 | 17.8 s | +3.3 s EQ |
| 192 * | 125 | 30 / 125 | 17.0 s | +0.5 s EQ |
| 253 * | 100 | 29 / 100 | 15.3 s | +2.1 s EQ |
| 347 * | 76 | 26 / 76 | 11.6 s | +2.7 s EQ |
| 408 | 22 | 22 / 112 | 0.6 s | +10.2 s EB |

Rank 53 (median 5.9 s):

| Wave (s) | At spawn | Low / high | Since last | First after |
| --- | --- | --- | --- | --- |
| 37 | 106 | 48 / 106 | 9.3 s | +2.0 s EQ |
| 98 * | 89 | 55 / 89 | 19.4 s | +2.3 s EQ |
| 192 | 125 | 34 / 125 | 8.8 s | +2.2 s EQ |
| 253 | 19 | 13 / 103 | 1.8 s | +4.8 s EQ |
| 347 | 12 | 6 / 96 | 2.2 s | +4.6 s EQ |
| 408 | 51 | 35 / 125 | 3.3 s | none before the kill |

Owner, 394 s wipe (median 6.9 s; the build's cap is above 125, so levels pass
it):

| Wave (s) | At spawn | Low / high | Since last | First after |
| --- | --- | --- | --- | --- |
| 37 | 69 | 16 / 106 | 7.7 s | +1.1 s EQ |
| 98 | 33 | 9 / 99 | 8.9 s | +4.7 s EB |
| 192 * | 155 | 66 / 155 | 15.0 s | +1.6 s EQ |
| 253 * | 133 | 85 / 133 | 11.0 s | +1.8 s EQ |
| 347 | 50 | 34 / 124 | 4.5 s | +15.2 s EB |

Do top players hold a spender for the waves? Yes, about every other one. Rank
1 goes 11 to 18 s without a spender before the waves at 98, 192, 253 and 347 s
(against a 5.2 s median), climbs from the 30s to 76 to 125, and casts
Earthquake 0.5 to 3.3 s after the spawn. It does not at 37 s (it had just
spent) or 408 s. Rank 53 does at 98 s, and sits at 125 with an 8.8 s gap at
192 s, just short of the rule. The owner does at 192 and 253 s. The waves where
a spender is simply cast soon after, such as 37 s, are ordinary play, which is
why the gap since the last spender is the test and not the spenders after.

A test on the mean of the 8 s before (15 above the fight mean) read these holds as 52 to 80 against a fight mean of 65 and flagged only 2 of 16 waves, no better than moments away from any wave, so this section first said wrongly that top players don't pool. The held-spender rule (`isHeld`) is the test.

### Enemies alive

`loadEnemyPresence` builds an `EnemyPresence`: for each kind of enemy, when every
copy arrived and when it was gone, with the bosses (kinds with one copy) up the
whole fight. `EnemyGroup.aliveAt` and `EnemyPresence.aliveAt` read it. Checked
on all three Twin Fangs logs by the live test `counts the enemies alive...`.

Queries and cost, in points. The rate-limit query itself costs 1, so the costs
below are measured differences minus that. A bare query costs about 1 and each
page of data about 1 more, so a whole fight is cheap:

| Query | Cost | Gives |
| ----- | ---- | ----- |
| `report` (`masterData.npcs`, `fights.enemyNPCs`) | 2 | kinds, names, copy counts |
| `events(dataType: Deaths, hostilityType: Enemies)`, no `sourceID` | 1 to 1.3 | every enemy death, one page |
| `events(dataType: Casts, hostilityType: Enemies, sourceID: <npc id>)` | 1 per kind | when each copy first acted |
| `events(dataType: DamageTaken, hostilityType: Enemies, sourceID: <npc id>)` | 1 per page | damage taken by the copies of that kind |
| `events(dataType: DamageDone, sourceID: <player id>)` | 1 per page | the player's hits, with `targetID` and `targetInstance` |

With `Enemies`, `sourceID` names the enemy that casts in `Casts` and the one that
is hit in `DamageTaken`. On Twin Fangs rank 1, `loadEnemyPresence` cost 8 points
before the Bulwark rule (report 2, deaths 1, three casts, two damage-taken); it now
adds the player's damage (1) and skips the Bulwark's two queries, so 7 by that list
(not re-measured). `loadFight` costs 6, and
`includeTargetsHit` adds 1 (one page of 3,800 rows for 420 s). The Vexhul's
damage taken alone is 4 pages, which is why a kind with any death uses the
deaths and skips it.

What the logs hold, on Twin Fangs (the same in all three):

- **Deaths** is 16 rows, one page: 15 Spawn of Vexhul and the boss that died
  first (`targetID`, `targetInstance`, `killerID`). Broodlings of Ithraz (60) and
  Barbed Bulwarks (90) have **no** death event, and neither has the second boss.
  Their end is taken from the last damage they took. For the Vexhul that last hit
  lands within 0.1 s of the death event, and Broodlings take hits for 1 to 10 s. A
  Bulwark that took no damage (12 of 90 in rank 1) is gone as it arrives, so its
  count is a floor.
- **Spawn is earlier than arrival.** The first damage taken is 0.5 to 2 s before
  the first cast. `arrivals` still means the first cast, since the add waves are
  measured that way.
- An earlier note here said `DamageTaken` returned nothing. It does when read by
  `targetID`; read by `sourceID` with `hostilityType: Enemies` it returns rows.
- **Chain Lightning's** damage events land 1 to 26 ms after the cast, with
  `abilityGameID` 188443; ones 1.2 s on are the next cast's overload. **Earthquake's**
  damage is 77478, not the cast id, ticking every 1.0 s from 0.9 to 1.0 s after the
  cast. A hit on an immune Barbed Bulwark has `amount` 0 but counts as a target.
  The `sourceID` filter also returns the player's pets and Ancestors, so
  `withTargetsHit` keeps `sourceID == player`. The rules are
  `SpecLogRules.aoeDamage`.

**Barbed Bulwark is not a target** (the owner, from play). It is not a killable
add: crowd control or a stun removes it. It takes no real damage (the player's hits
on it do 0, apart from two Flame Shock ticks for 1 of about 6,000), and no death
event exists for it. So an add kind counts toward enemies alive only if the player
damaged it: some hit for at least 1% of its unmitigated amount
(`damagedTargets`, from the same `DamageDone` page as the targets hit). That is
data, not a name check, and it drops the Bulwark in all three logs. A kind the
player simply ignored would drop out too; Bulwark is the case it is for. Bosses
always count.

Enemies alive over rank 1's 420 s, at the best 0.1 s of each wave (both bosses
always, plus the adds the player damaged). Between waves it is the 2 bosses, and
in a Bulwark wave (11, 72, 166, 227, 321 and 382 s) it stays 2:

| Wave (s) | Vexhul (3) | Broodlings (10) | Alive at peak |
| -------- | ---------- | --------------- | ------------- |
| 37 | 3 | 3 | 8 |
| 98 | 3 | 5 | 10 |
| 192 | 3 | 3 | 8 |
| 253 | 3 | 3 | 8 |
| 347 | 3 | 4 | 9 |
| 408 | 3 | 5 | 10 |

The adds die as they arrive, so at most 5 of the 10 Broodlings are up together.
Before this rule the Bulwarks (up to 10 of 15 at once) made the Bulwark waves 8 to
12 alive.

Targets hit per Chain Lightning, rank 1 (138 casts, mean 2.5). This counts every
enemy the chain touched, so a Bulwark it hit for 0 is in it:

| Targets hit | 1 | 2 | 3 | 4 | 5 |
| ----------- | - | - | - | - | - |
| Casts | 1 | 95 | 22 | 9 | 10 |

Earthquake hit 3 enemies on all 13 casts (the three Spawn of Vexhul). Chain
Lightning hit 5 at most. With a Bulwark wave up it hit 4 or 5, counting Bulwarks at
0 damage. The replay uses the alive count, which leaves the Bulwarks out; the
APL's `spell_targets` thresholds are 2 or 3.

### Rebuild check

The rebuild matched all 109 logged readings of rank 1 exactly once Earthquake's
cast id was right (462620, not 61882; see
[elemental-shaman.md](elemental-shaman.md)). Before that fix the rebuild sat at
the cap through every Earthquake and drifted up to 88. The owner's log drifts a
mean of 3.3 (worst 8) over its readings. Rank 53's mean is 2.1 and its worst 81 is
the same-millisecond case above.

The committed fixture is `test/fixtures/twin_fangs_window.json`: rank 1 from
225 s to 300 s, which holds the 253 s Vexhul wave and the 227 s Bulwark wave. It
rebuilds with no drift over 17 readings, and the 253 s wave reads as held (15 s
since the last spender, Earthquake 2.1 s after the spawn). It also holds each enemy
kind that counts (not the Bulwark) with its arrivals and departures, and the player's
Chain Lightning and Earthquake damage rows (82, no amounts, the player as id 1).
The owner's log is not in it.

## Worked example: Mythic Coiled Altar

Encounter 3429. Three Farseers with the owner's wipe first. Rank 1 and rank 50
are from the top 100 on 2026-11-01 (kills of 514 and 516 s). Rank 28 (507 s,
`ZaWTvbHVMwPq7d8L` / 15) was read too and is used only for the waves and
pooling below.

| | Owner, 93% wipe | Rank 50 | Rank 1 |
| --- | --- | --- | --- |
| Report / fight | `B3zd6Hb7gvynTXYj` / 9 | `APG4gqFxZnrtXRpa` / 16 | `n4jBN71KbyRkt28X` / 36 |
| Fought length | 58 s (wipe) | 516 s (kill) | 514 s (kill) |
| DPS | about 233,500 | 267,901 | 313,665 |
| Item level | 334 | 335 | 337 |
| Casts per minute | 41.2 | 50.2 | 53.6 |
| Gaps over 1.8 s | 1 | 12 | 3 |
| Maelstrom per minute | 293 | 329 | 404 |
| Maelstrom wasted | 0 | 166 | 187 |
| Spenders with Master of the Elements | 6 of 6 | 51 of 61 | 40 of 65 |
| Free spenders | 4 of 6 | 32 of 61 | 29 of 65 |
| Overcharge! lost by refreshing | 1 | 0 | 1 |
| Ancestors, actual / expected | 8 / 7.6 | 65 / 63.3 | 73 / 65.5 |
| Stormkeeper median press delay | 1.34 s | 0.77 s | 3.20 s |
| Spiritwalker's Grace, normal + Time Spiral | 1 + 0 | 6 + 0 | 4 + 5 |

The owner's DPS is the sum of the damage events of the player and pets over
58.2 s, which is not the ranking's number. The same sum gives 312,757 for rank 1
against the ranked 313,665. The owner's fight is 58 s of phase 1 against 514 s
and 516 s of the whole kill, so only the casts-per-minute stretches below are a
fair comparison; the totals are not. Spenders are Elemental Blast and Earthquake
together. Raid support received: rank 1 had Blessing of the Bronze all fight and
Time Spiral for 19 s, rank 50 had Power Infusion for 60 s, and the owner had
Blessing of the Bronze 50 s, Ebon Might 48 s and Power Infusion 15 s of 58 s.

Casts per minute by stretch, for the 58 s all three fought. The stretches start
at the first Axegrinder arrival (15 s), the only enemy event in that time:

| Stretch (s) | 0-15 | 15-30 | 30-45 | 45-58 |
| --- | --- | --- | --- | --- |
| Owner | 64.0 | 48.0 | 36.0 | 13.8 |
| Rank 50 | 80.0 | 48.0 | 52.0 | 27.7 |
| Rank 1 | 48.0 | 48.0 | 56.0 | 55.4 |

The owner and rank 50 open with more casts than rank 1 and equal it at 15 to
30 s. The owner then drops to 36 and 14, three casts in the last 13 s (the log
doesn't say why; deaths were not read). Rank 50 has 27.7 in 45 to 58 s, which
holds its longest gap of 8.0 s.

The Maelstrom rebuild over each whole log: rank 1 has 109 readings with a worst
drift of 34 and a mean of 1.1, rank 50 has 126 with 8 and 0.8, and rank 28 has 116 with 89 and
2.6 (the same-millisecond case under "Reading a fight"). The owner's 15 readings
have a worst drift of 8 and a mean of 1.7.

### Who the logs are

- **Owner's heroic kill** (`GaZ4Fj7VTm8YgqhQ` / 30, source 12, 316 s) is a
  Restoration Shaman log (spec 264: Chain Heal, Riptide and Healing Stream Totem
  lead its casts, with no Maelstrom gain or spender). It is not an Elemental log, so
  it gives the fight's shape only and no casts or Maelstrom. Its enemies are
  Heroic. Wherever it is quoted below it says so.
- **Owner's wipe** is source 14, Elemental (spec 262).

### Phases and add waves

Phases from `phaseTransitions`:

| Log | Phase 2 | Phase 3 | Phase 4 | Ends |
| --- | --- | --- | --- | --- |
| Rank 1 (Mythic) | 139.0 s | 319.6 s | 357.7 s | 514.0 s |
| Rank 28 (Mythic) | 142.0 s | 295.2 s | 333.5 s | 507.0 s |
| Rank 50 (Mythic) | 143.3 s | 325.6 s | 364.0 s | 516.4 s |
| Owner's wipe (Mythic) | not reached | | | 58.2 s |
| Owner's heroic kill (Heroic, healer log) | 84.0 s | 152.0 s | 190.1 s | 316.3 s |

Phase 2 starts 139 to 143 s into the Mythic kills (it is not on a timer), and
phase 3 is 38.1, 38.3 and 38.4 s long.

The add waves are the Spiteful Soulcoilers: two arrive together (their first
casts) and die in 20 to 36 s on Mythic (12 to 15 s in the Heroic kill). Their
waves are timed from the phases, not from the pull:

| Wave | Rank 1 | Rank 28 | Rank 50 | Heroic kill | From |
| --- | --- | --- | --- | --- | --- |
| 1 | 164.5 s | 168.2 s | 169.2 s | 110.3 s | phase 2 start + 25.5 / 26.2 / 25.9 / 26.3 s |
| 2 | 197.5 s | 201.2 s | 202.2 s | 143.3 s | phase 2 start + 58.5 / 59.2 / 58.9 / 59.3 s |
| 3 | 249.5 s | 253.2 s | 254.2 s | | phase 2 start + 110.5 / 111.2 / 110.9 s |
| 4 | 282.5 s | 286.2 s | 287.2 s | | phase 2 start + 143.5 / 144.2 / 143.9 s |
| 5 | 427.1 s | 402.9 s | 433.4 s | | phase 3 start + 107.5 / 107.7 / 107.8 s |
| 6 | | 499.6 s | | | phase 4 start + 166.1 s |

So the waves repeat between pulls to within 0.7 s of the phase they follow, in
all three Mythic kills, and the Heroic kill's first two sit at the same
offsets from its own phase 2 (26.3 and 59.3 s, so Heroic timings match the
Mythic ones here). Wave 6 came only in rank 28, the slowest kill. In pull
time the waves are 4 to 5 s apart between logs, so a comparison must start each
stretch at each log's own wave, as `waveStarts` does. The owner's 58 s holds no
wave.

Other enemies, none of them add waves to count:

| Enemy | Copies | Arrives | Player damaged it | Taken from others |
| --- | --- | --- | --- | --- |
| Manifestation of Dread | 30 (rank 1) | 6 at a time, 3 to 7 s before each Soulcoiler wave (157.5, 194.7, 242.7, 279.9, 421.3 s) | 0 hits | 0 damage events in the log |
| Axegrinder | 10 (5 in the owner's wipe) | 5 at 15 s and 5 at 100 s, in the owner's, rank 1's and rank 28's logs (15.0 to 15.3 s, 100.1 to 100.3 s) and at 15 s in the Heroic kill | 0 hits | 5 hits, all from Hex Lord Malacrass at 272 to 280 s |

Neither kind is an enemy alive under the existing rule (an add counts only if
the player damaged it), and neither dies in the log. Measured on rank 1:
`loadEnemyPresence` finds Spiteful Soulcoiler, Zul'jan and Hex Lord Malacrass
only. The rule needed no change. The Axegrinder arrivals at 15 and 100 s are timing
markers only, like Twin Fangs' Bulwark waves.

**Untargetable stretches.** Zul'jan and Hex Lord Malacrass are single-copy
enemies, which `loadEnemyPresence` used to have up for the whole fight. The
player's damage says otherwise, in hits more than 8 s apart (rank 1, with rank 28
alike):

| Boss | Rank 1 damaged it during | Rank 28 |
| --- | --- | --- |
| Zul'jan | 0 to 139.2 s, then 323.5 to 510.4 s | 0.4 to 142.0 s, then 298.9 to 505.5 s |
| Hex Lord Malacrass | 147.1 to 216.9 s, 231.3 to 301.6 s, 318.1 to 398.0 s, 409.3 to 494.6 s, 506.1 to 513.8 s | 150.9 to 220.5 s, 235.6 to 373.5 s, 387.9 to 470.3 s, 487.4 to 506.4 s |

The owner's wipe damaged only Zul'jan, from 2.8 s, and its report has no Malacrass.
So in phases 1 and 2 only one boss is hit at a time. Counting both gave 2 (4 in
a Soulcoiler wave, where 3 can be hit), and 1 in the owner's wipe (no Malacrass
in that report), so the same phase asked for an area spell in rank 1 and a
single-target one for the owner.

**Done (#65).** `loadEnemyPresence` builds a single-copy enemy's group from the
player's `DamageDone` rows (already fetched, no new query): one arrival and
departure per stretch, where a stretch ends at the last hit before a silence
over `WarcraftLogsRepository.bossHitGap` (8 s). A hit counts by the same test as
`damagedTargets` (at least 1% of the unmitigated amount), so a 0-damage hit on an
immune boss opens nothing. The model is unchanged: `EnemyGroup` already holds a
list of spans. A boss with no real hit keeps the whole-fight span, and so does
any call without a `playerId`. Live on rank 1 it reads Zul'jan 0.0 to 139.2 s and
324.0 to 510.4 s, Malacrass 147.1 to 216.9 s, 231.3 to 301.6 s, 318.1 to 398.0 s,
409.3 to 494.6 s and 506.1 to 513.8 s, matching the table. The ceiling is a boss
the player chose to ignore while it was hittable, which reads as untargetable.
Twin Fangs rank 1 is one span per boss, 0.7 to 406.5 s (Vexhul) and 0.7 to
419.8 s (Ithraz): they are hit all fight, so the only change is that a boss is
up from its first hit (0.7 s) to its last, not from 0 to the end.

Queries and cost, in points, measured on rank 1 by the change in `rateLimitData`
across each call (minus the 1 of the query itself): `loadEnemyPresence` 5,
`loadFight` 8, `loadFight(includeTargetsHit: true)` 9, rankings for 100 rows 1.
The whole job (five logs with their rankings, plus four extra single-page
casts and damage-taken queries for the Manifestations and Axegrinders on rank
1, and these measurements) had spent 133 points in the hour when it ended. The
Manifestations and Axegrinders were read with the existing `events` call.

### Do top players hold a spender for the waves?

Sometimes, and not the same ones. The held rule (`isHeld`: over 10 s or twice
the player's median gap since the last spender, and one follows within 5 s) reads:

- **Rank 1** (median gap 6.5 s) holds at waves 3 and 4 (12.5 and 12.6 s since
  the last spender, an Elemental Blast 3.7 s and 1.3 s after the arrival), not at
  1, 2 and 5. It also holds into phase 3 (14.9 s since the last spender, Elemental Blast
  4.9 s after).
- **Rank 28** (median 5.3 s) holds at waves 3 (11.8 s) and 6 (16.9 s), not at
  1, 2, 4 and 5. Wave 4 had 10.2 s, just under twice the median.
- **Rank 50** (median 7.3 s) holds at none. Its longest gap before a wave is 7.5 s
  (wave 4, and the first spender after it is at the arrival).

Rank 1 and rank 28 both hold at wave 3 (phase 2 start + 111 s). Two of five and two
of six waves is fewer than Twin Fangs' four of six, and rank 50 never holds, so this
boss shows no sign that pooling for the waves is the top players' habit. The
default held rule did not need changing. The mean Maelstrom in the 10 s before a
wave (below) is no guide: held waves read 59 and 85 against 76, 91 and 77.

Per wave (the Soulcoilers' first cast): the rebuilt Maelstrom at the arrival, the
lowest and highest in the 10 s before, the mean over those 10 s, seconds since the
last spender, the first spender after with its offset (all Elemental Blast), and
the spenders cast in the 10 s after. Held waves are marked *.

Rank 1:

| Wave (s) | At arrival | Low / high | Mean 10 s before | Since last | First after | Spenders next 10 s |
| --- | --- | --- | --- | --- | --- | --- |
| 164.5 | 45 | 26 / 116 | 76 | 4.1 s | +5.8 s | 1 |
| 197.5 | 32 | 24 / 114 | 91 | 1.0 s | +11.4 s | 0 |
| 249.5 * | 95 | 30 / 95 | 59 | 12.5 s | +3.7 s | 3 |
| 282.5 * | 121 | 47 / 121 | 85 | 12.6 s | +1.3 s | 1 |
| 427.1 | 53 | 33 / 123 | 77 | 4.0 s | +11.3 s | 0 |

Rank 50:

| Wave (s) | At arrival | Low / high | Mean 10 s before | Since last | First after | Spenders next 10 s |
| --- | --- | --- | --- | --- | --- | --- |
| 169.2 | 66 | 35 / 125 | 92 | 4.1 s | +4.1 s | 2 |
| 202.2 | 60 | 25 / 115 | 74 | 4.9 s | +9.7 s | 1 |
| 254.2 | 35 | 35 / 125 | 113 | 0.3 s | +13.5 s | 0 |
| 287.2 | 47 | 14 / 104 | 44 | 7.5 s | +0.0 s | 2 |
| 433.4 | 32 | 17 / 107 | 69 | 4.1 s | +23.3 s | 0 |

### Committed fixture

`test/fixtures/coiled_altar_window.json` is rank 1 from 225 s to 300 s of the
pull (the same shape and keys as the Twin Fangs one, 66 KB). It holds waves 3 and 4
(24.5 and 57.5 s into the window, two Soulcoilers each, which die at about 55 s and
past 75 s), Malacrass hittable from 6.3 s to the end (Zul'jan is not hittable in
the window, so he is left out), 11 Maelstrom readings, the player's Chain Lightning and
Earthquake damage rows (one, since this player cast almost no area spells), and
Flame Shock on both bosses. Its rebuild drifts a mean of 1.2: nine readings are
exact, one is 4 off, and one is 9 off at 23.0 s, where the Stormkeeper cast's reading
and a Lava Burst gain share a millisecond and the gain comes first. Both waves read as
held (12.5 and 12.6 s since the last spender, Elemental Blast 3.7 s and 1.3 s after).
The Manifestations and Axegrinders are not in it, since the player never damaged
them. The owner's log is not in it, and no player name is.

The live test `finds the Coiled Altar Soulcoiler waves...` (opt in, with
`WCL_LIVE=1`) reads rank 1's presence and checks the five waves and the three
kinds counted.

## Flame Shock uptime

Answers #26. Measured on 2026-11-01 on the three Sszorak logs above, with the
client-credentials token. Each query was fetched once; the cost is the change in
`rateLimitData { pointsSpentThisHour }` across the call.

| | Rank ~1133 | Rank 18 | Rank 1 |
| --- | --- | --- | --- |
| Report / fight | `ycBrVaJAgKvNLCMj` / 58 | `HJ6dAfkFbV4tXRZp` / 38 | `mG9M7nV1CDZWgJHL` / 32 |
| Player source id | 278 (Eliance) | 11 | 21 |
| Boss actor id (`fights.enemyNPCs`, game id 257347) | 196 | 192 | 225 |
| Fight length | 371.5 s | 370.2 s | 287.9 s |

Rank 18's other Shaman (id 22) is a different player with 6 debuff events. Pick
the source by name or by its casts, never by "the Shaman".

### Approach A: events

```graphql
query { reportData { report(code: "ycBrVaJAgKvNLCMj") {
  events(fightIDs: [58], dataType: Debuffs, sourceID: 278, abilityID: 188389,
         startTime: 14564187, endTime: 14935656, limit: 10000) {
    nextPageTimestamp data } } } }
```

- **Cost:** 1 point per call. All three fit one page (24, 23 and 16 events).
- **Rows:** `{timestamp, type, sourceID, targetID, abilityGameID, fight}` with `type`
  `applydebuff`, `refreshdebuff` or `removedebuff`. `targetID` is the boss actor.
  No stack, duration or `hostilityType` fields.
- **Leave `hostilityType` at its default (Friendlies).** `hostilityType: Enemies`
  with `sourceID` 278 or with the boss as `sourceID` returned zero rows, and cost
  10 and 7 points. The source is the player who applied the debuff, whatever
  the target.
- **Uptime:** band from each `applydebuff` to the next `removedebuff`; a
  `refreshdebuff` changes nothing. A band still open at the end of the fight
  closes at the fight's end. The first band opens at the first apply, so time
  before it counts as down.

### Approach B: the Debuffs table

```graphql
query { reportData { report(code: "ycBrVaJAgKvNLCMj") {
  table(fightIDs: [58], dataType: Debuffs, sourceID: 278, abilityID: 188389,
        startTime: 14564187, endTime: 14935656) } } }
```

- **Cost:** 1 point per call.
- **Result:** `data.auras` has one row per target (`name`, `id` = boss actor,
  `guid`, `totalUptime` ms, `totalUses`, `bands: [{startTime, endTime}]`) and
  `data.totalTime`. The bands are the same as approach A's, so it needs no event
  parsing and the bands are absolute log times.
- **Same default as A:** `hostilityType: Enemies` with a `sourceID` returned no
  auras (glossary, "Not yet verified"). Without it the table works.
- **Pitfall:** `totalTime` is the whole fight, so the percent is
  `totalUptime / totalTime`, but a wipe or phase-limited window must pass the
  matching `startTime` and `endTime`.

### Numbers

| | Rank ~1133 | Rank 18 | Rank 1 |
| --- | --- | --- | --- |
| A: uptime (events) | 333.25 s, 89.7% | 366.77 s, 99.1% | 287.47 s, 99.8% |
| B: `totalUptime` (table) | 333,250 ms | 366,769 ms | 287,465 ms |
| Down time | 38.2 s | 3.4 s | 0.5 s |
| Gaps (start, length) | 0 s 2.8; 73.1 s 0.6; 91.7 s 18.9; 200.6 s 12.2; 361.4 s 3.7 | 0 s 0.5; 87.3 s 0.3; 177.6 s 0.5; 332.7 s 0.4; 351.1 s 1.7 | 0 s 0.5 |
| Apply / refresh / remove | 5 / 15 / 4 | 5 / 14 / 4 | 1 / 15 / 0 |
| Casts of 188389 (= casts of 470411) | 16 | 17 | 13 |
| Ascendance casts (114050) | 4 | 2 | 3 |

A and B agree to the millisecond on all three logs. The table also reports
`totalUses` 20, 19 and 16: applies plus refreshes.

### Ascendance and the echo

- **Ascendance's Flame Shock** is a debuff event with no 188389 cast. Each
  Ascendance cast (114050) has an `applydebuff` or `refreshdebuff` within 17 ms
  and no 188389 cast within 150 ms of it (the nearest cast was 1.1 s away or
  more). Rank ~1133 shows 2 of its 4 as `refreshdebuff` at 123.8 s and 244.3 s
  and 2 as `applydebuff` at 2.8 s and 365.1 s (the debuff was down); rank 18
  shows 2 of 2 as refreshes, rank 1 shows 3 of 3 as refreshes. Every other debuff event has a 188389 cast
  at the same moment. So debuff events count Ascendance's Flame Shock, and
  casts do not.
- **The 470411 echo** never appears as a debuff. `Debuffs` events for 470411
  returned zero rows in all three logs. It exists only as a cast, once per 188389
  cast within 1 ms. Counting casts of 188389 alone gives 16, 17 and 13.
- **Counting rule for "Flame Shock presses":** casts of 188389. For
  "refreshes of the debuff", the `refreshdebuff` and `applydebuff` rows, which
  also include Ascendance's.

### Pitfalls

- **Several targets.** The events are per target, and the table has one row per
  target. These fights had one target, so each query returned only the boss.
  A multi-target fight needs filtering on the boss's `targetID` (not tried,
  `events` accepts `targetID`) or keeping only the aura row whose `id` is the
  boss.
- **Pandemic.** A refresh is a single `refreshdebuff` row, with no remaining or
  new duration. Remaining time at a refresh isn't in the log. The gaps between
  applies and refreshes run from 1.1 to 44.6 s, and a 40.9 s one had no remove
  between, so the in-log duration is not the 18 s of the app's tables (to
  check against the talents). Early refresh waste can't be read from the
  events alone.
- **Gaps are short.** A 0.3 to 0.6 s gap (remove then apply, as at 73.1 s in
  rank ~1133) is a real lapse of the debuff, but it is also within the timing
  allowance for ordering events. Report only gaps over about 1 s as "down".
- **Start of the pull.** Every log starts with 0.5 to 2.8 s down before the
  first apply. Count from the player's first cast, or from the first apply, if
  that is not to be blamed on the player.
- **A cast that missed.** Every 188389 cast in these logs had a debuff event
  within 150 ms; a cast on an immune or dead target might not.

### Recommendation

Use approach A at 1 point per log: `events(dataType: Debuffs, sourceID,
abilityID: 188389)` on default hostility. It gives the same uptime as the table
and also the apply, refresh and remove times, which the app needs to show "down
from 91.7 to 110.6 s" next to the casts, to separate Ascendance's Flame Shock
from a pressed one, and to test against the APL. The table is the cheaper
check for a bare percentage, and is the right source for a second opinion.

`FightLog` needs, without implementing it:

- **Boss actor id** on `LogFight` (the `fights.enemyNPCs` entry whose `gameID`
  matches the encounter's boss; 196, 192, 225 above), to filter `targetID`.
- **`WclEventType.debuffs('Debuffs')`**, one `events` call per log with
  `abilityID` 188389 taken from the spec's rules, merged by the existing
  paging in `WarcraftLogsService.events`. `abilityID` is a new argument.
- **`debuffEvents: List<LogBuffEvent>`** on `FightLog`. `LogBuffEvent` already
  holds time, ability, target and change, so the mapper's switch needs the
  `applydebuff`, `refreshdebuff` and `removedebuff` cases; `stack` stays null.
- **A `DebuffWindows` model**, like `BuffWindows`, built from them: bands,
  uptime and gaps, with open bands closed at the fight's end. No spec checks: the
  ability id comes from `RotationSpec.logRules`.
- **A cast-vs-debuff match** (a debuff event with no 188389 cast within about
  150 ms is Ascendance's) in the player metrics, kept apart from press counts.

### Implemented (#55)

- `WarcraftLogsService.events` takes `abilityId`; `WclEventType.debuffs` exists.
  `loadFight` makes one extra `Debuffs` call per DoT aura of the spec
  (`spec.auras`, `kind == AuraKind.dot`) and fills `FightLog.debuffEvents`
  (`applydebuff`, `refreshdebuff`, `removedebuff`; `buffEvents` is untouched).
- `LogFight.bossActorId` is the first `fights.enemyNPCs` entry with one copy
  (196 on Sszorak; 255, Vexhul, on Twin Fangs, where Ithraz 256 is hit at the
  same moment). `null` when there is none, and then `DebuffWindows` counts every
  target.
- `DebuffWindows.of(log, debuffId)` gives `windows`, `uptime`, `uptimePercent`
  and `gaps` (1 s or longer). A window that begins with the debuff up has only
  refreshes, so a refresh before any band opens one at the start.
- The fixtures hold a `debuffs` key and `fight.enemyNPCs`. Both 75 s windows
  (Sszorak 225 s to 300 s of the owner's log, Twin Fangs rank 1) show 100% uptime
  on the boss: 6 and 15 refresh rows, no apply or remove (Twin Fangs also holds 3
  applies on Spawn of Vexhul, which the boss filter drops). Fetching them cost
  about 8 points (two report queries and two event queries).

## Raid support received

Which query lists the buffs a player got from others (ticket #27). Checked on
2026-11-01 against the three Sszorak logs above, with a client token on the
owner's PC. The player ids are 278 (rank ~1133), 11 (rank 18) and 21 (rank 1).

### The `sourceID` / `targetID` swap

For `dataType: Buffs`, in both `table` and `events`, **`sourceID` is the player
who holds the buff and `targetID` is who cast it.** `table(dataType: Buffs,
targetID: <player>)`, the query first tried, lists only what the player cast
(Skyfury, Bloodlust). It had no Time Spiral, Power Infusion or Blessing of the
Bronze in any log. With `targetID: P` the events all have `sourceID` P too, and
`filterExpression: "source.id != P"` changed nothing (2,101, 1,996 and 2,008
events either way), so it is not a way to select external buffs. `FightLog`
already asks for `sourceID` = player, which is why Time Spiral reached it.

### Queries and cost

Cost is the change in `rateLimitData.pointsSpentThisHour` across the call.

| Query | Cost | Result |
| --- | --- | --- |
| (a) `table(dataType: Buffs, fightIDs: [F], sourceID: P)` | 1 point | 79 to 90 auras, each `{guid, name, totalUptime, totalUses, type}`, in ms. No caster. Includes Blessing of the Bronze. |
| (b) `events(dataType: Buffs, sourceID: P, startTime, endTime, limit: 10000)` | 1 point per page (about 2,000 events, one page) | Every apply, refresh and remove, with `sourceID` (caster) and `targetID` (P). The app's existing call. No Blessing of the Bronze. |
| (c) as (b) plus `filterExpression: "source.id != P"` | 1 point | The same events as (b). No use. |
| (d) as (a) with `targetID: P` | 1 point | What P cast. The wrong query. |

### What each log received

Uptime is `totalUptime` over the kill length (371, 370 and 288 s), then the
table's `totalUses`. Casters are the `sourceID`s in (b).

| Buff (id) | Rank ~1133 | Rank 18 | Rank 1 |
| --- | --- | --- | --- |
| Blessing of the Bronze (381756), table only | 100%, 1 | 100%, 1 | 100%, 1 |
| Power Infusion (10060) | 13.5%, 4 (priest 276) | 12.2%, 3 (priest 19) | 15.6%, 3 (priest 19) |
| Ebon Might (395152) | 90.0%, 43 (Aug 274) | 88.0%, 42 (Aug 12) | 93.7%, 40 (Aug 17) |
| Prescience (410089) | none | 21.2%, 3 (Aug 12) | none |
| Shifting Sands (413984) | none | 10.3%, 3 (Aug 12) | 8.9%, 2 (Aug 17) |
| Time Spiral (375256) | 6.7%, 5 (274 and 9) | 4.6%, 6 (7 and 12) | 2.6%, 2 (17) |
| Raid haste | Fury of the Aspects 390386: 10.8%, 1 (Evoker 9) | Time Warp 80353: 10.8%, 1 (mage 6) | Bloodlust 2825: 13.9%, 1 (cast by the player) |

Breath of Eons put no buff on the player in any log. Also seen, from the Aug or
other Evokers: Inferno's Blessing 410263 (ranks 18 and 1), Black / Bronze
Attunement 403295 / 403296 (ranks 18 and 1), Chrono Ward 409678 (rank ~1133),
Rewind 363534 and Temporal Anomaly 373862 (all three). Their effect on a
cooldown or haste is not checked.

### Why Blessing of the Bronze was missing

It is applied before the pull and lasts through it, so no event falls inside the
fight window. (b) never has it, while the table reports it at 100% with one use.
A window starting 900 s before the pull (rank 18, `ability.id = 381756`, 1
point) returned only `removebuff` events at the ends of the two earlier pulls
(fights 36 and 37), no `applybuff`. So an earlier window can't find the apply
either. The cause is the buff carrying over, not a filter or the source.

### Recommendation

Add query (a) to every comparison: 1 point per log, no extra paging. It is the
only route to Blessing of the Bronze, and it gives uptime and uses for every
other external. Keep (b), which `FightLog` already loads, for timing (Time
Spiral windows, Power Infusion, Time Warp) and for the caster.

`FightLog` would need:

- `LogBuffEvent.sourceId`. The mapper reads `targetID` and drops `sourceID`, so
  nobody can tell a player's own buff from a raid buff, or tell Evokers apart.
- A list of `{abilityId, name, uptime, uses}` from (a) for the player, such as
  `receivedBuffs`.
- A raid-support list in `SpecLogRules` (Blessing of the Bronze 381756, Power
  Infusion 10060, Ebon Might 395152, Prescience 410089, Shifting Sands 413984,
  Time Spiral 375256, and the lust ids 2825, 80353, 390386), replacing the
  hard-coded names in `raidCooldownSupport`.

Not implemented. The source is the v2 API responses above.

## APL replay

`ReplayLog` rebuilds the state at each GCD press of a fight (`LogStateBuilder`),
asks `AplEvaluator` what it wanted, and reports where the player pressed
something else. Measured on the two 75 s fixtures, with the Farseer talents each
log carries and the set bonus on:

| Fixture | Presses compared | Agreement | Exact deviations |
| ------- | ---------------- | --------- | ---------------- |
| `sszorak_window` (owner, low parse), one boss | 46 | 41% (19) | 16 of 27 |
| `twin_fangs_window` (rank 1), enemies alive | 59 | 61% (36) | 19 of 23 |
| `coiled_altar_window` (rank 1), hittable boss | 61 | 18% (11) | 42 of 50 |

The Coiled Altar window read both bosses as up all fight before #65, which gave
13% (8 of 61, 45 of 53 exact). Counting only the hittable boss moves three
presses to agreement. The 18% is low for rank 1 and mostly Lightning Bolt
pressed where the APL wanted Lava Burst, Chain Lightning, Earthquake or
Elemental Blast; it is not explained here, only measured.

Counting the Barbed Bulwarks as targets gave 68% (40 of 59, 16 of 19 exact), a
rate that rested on enemies the player can't hit; the figure above leaves them out.

Before the enemy count (#12), `ReplayLog` held a `targets` guess for the whole
log, and Sszorak had no count at all:

| Fixture | Presses compared | Agreement | Exact deviations |
| ------- | ---------------- | --------- | ---------------- |
| `sszorak_window`, 1 target | 46 | 41% (19) | 12 of 27 |
| `twin_fangs_window`, 1 target | 59 | 37% (22) | 1 of 37 |
| `twin_fangs_window`, 2 targets | 59 | 63% (37) | 0 of 22 |

Counting the enemies alive at each press (`EnemyPresence`, from the deaths and
arrivals of "Enemies alive" above) lifts rank 1 from the 1 target guess's 37% to 61%
without being told a number. It is a little under the 63% of guessing 2 targets for
the whole log, which was right between waves and wrong for the Vexhul wave. Sszorak is one boss, so it is unchanged at 41%; only its exact count
moves, from 12 to 16, because a count read from the log is no longer an estimate.
`ReplayLog` takes `presence` (and still `targets`, for a log with no enemy data).
The fixtures hold the enemies of their window that count: the two bosses and the
Vexhul wave at 28 s (the Bulwark wave at 2 s is left out, as above). The targets hit per Chain Lightning are in the
fixture too, but the replay does not use them: they are the player's own choice,
so feeding them back would make the state agree with the press.

Five presses (Sszorak) and two (Twin Fangs) are of abilities outside the spell
table, such as Ghost Wolf, and are not compared. Treat these as how well the APL
fits a window, not a grade: even rank 1 is at 61%.

Top deviation kinds (pressed instead of wanted):

| Sszorak | n | Twin Fangs, enemies alive | n |
| ------- | - | ------------------------- | - |
| Lava Burst instead of Elemental Blast | 6 | Chain Lightning instead of Lava Burst | 11 |
| Lightning Bolt instead of Lava Burst | 4 | Lightning Bolt instead of Lava Burst | 3 |
| Lava Burst instead of Lightning Bolt | 4 | Chain Lightning instead of Earthquake | 2 |
| Lava Burst instead of Flame Shock | 3 | Lava Burst instead of Earthquake | 2 |
| Lightning Bolt instead of Flame Shock | 3 | Elemental Blast instead of Earthquake | 2 |

What explains them:

- **Different play, owner.** Lava Burst instead of Elemental Blast is Maelstrom
  sitting at the 125 cap for about 15 s (33 s to 50 s of the window) with no
  spender, while the APL wanted Elemental Blast on every press. It matches this
  log's 99 wasted Maelstrom, and is exact.
- **Different play, rank 1.** Chain Lightning instead of Lava Burst, 11 times
  (13 when 2 targets was assumed), with Lava Surge up or 2+ charges: the player
  keeps cleaving at 2 enemies, where the APL prefers a Lava Burst. Chain
  Lightning instead of Earthquake and Lava Burst instead of Earthquake are
  builders pressed where the APL wanted a spender. The replay says what happened,
  not why; rank 1's habit of holding a spender for a wave is in "Add waves".
- **State the APL couldn't see: targets.** Now seen. The count is the enemies
  alive, not the enemies in range, with the Bulwarks left out (they are not
  targets). It can overcount, and an add's arrival
  is its first cast, up to 2 s after it spawned, so it can also undercount.
- **State the replay estimates.** Flame Shock is on the target and no event shows
  it, so its time left is rebuilt from the player's casts and assumed 12 s at the
  start. It drives the Flame Shock deviations, all `uncertain`.
- **Cooldowns.** Lava Burst charges refill at the table 8 s, but haste speeds
  them, so `charges_fractional > 1.8` is reached later than in play. Voltaic Blaze
  shows the same: rank 1 pressed it 1 to 2 s before the table said it was ready.
  These count as agreement with a note, as does Stormkeeper pressed 45 s after its
  last use (Offering from Beyond shortens it). A cooldown first cast inside the
  window is taken to come off cooldown just then, which hides a late press.
- **Timing.** An instant is read 60 ms before its own cast, and a cast with a
  `begincast` 10 ms after it, so buffs its predecessor applied are up and the ones
  it spends are not yet gone. A press within 10 ms of the previous finish is the
  one case still wrong.
- **Not rebuilt.** Movement (`moving` is always false), the fight length (a window
  gets a `fight_remains` of 5 minutes or more unless `fightRemainsAfter` is
  passed), Lava Surge's exact refund, pets (Fire and Storm Elemental), buffs up
  from before the window that never change, and haste.
- **Leniency.** A press counts as agreement, with a note, when the APL line for it
  passed but the rebuilt state said it was unavailable: the player did press it, so
  the state is wrong, not the play. An unmodelled action (potion, trinket) is never
  the winner because the evaluator skips it. Off-GCD abilities the APL wanted with
  a press and the log doesn't show are counted (`skippedOffGcd`) and don't change
  the score, as in the quiz.
- **Confidence.** A deviation is `exact` when every identifier read by the winning
  line and by the pressed ability's own lines was seen in the log. Dots, debuffs,
  pets, the enemy count when no `presence` is given, cooldowns with raid or proc
  support and Maelstrom more than 5 off the last logged reading are estimates.

**Implemented (#60).** `WarcraftLogsService.buffTable` runs query (a) for the whole
fight and `loadFight` fills `FightLog.receivedBuffs` (1 extra point).
`LogBuffEvent.sourceId` holds the caster. `SpecLogRules.raidSupportIds` lists the
buffs shown (the doc's six plus the lusts). `CompareFights` gives each `ComparedLog`
a `raidSupport` (name, percent of the fight, uses), and the Boss Evaluation header
prints it under "Raid support", or "none seen". It is never part of a finding or
score. A table asked for a window (the fixtures' 225 s to 300 s) leaves out a buff
that began before the window, so Blessing of the Bronze is not in the fixtures;
a whole-fight table does list it. The fixtures got `receivedBuffs`: the Sszorak
window shows Power Infusion 15 s (1), Ebon Might 70.4 s (12), Time Spiral 15.5 s (2);
the Twin Fangs window Ebon Might 69.4 s (9), Time Spiral 13.5 s (2). Fetching them
cost about 10 points (including two rankings pages and two report queries).

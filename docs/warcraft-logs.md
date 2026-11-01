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
(report 2, deaths 1, three casts, two damage-taken), `loadFight` 6, and
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

Enemies alive over rank 1's 420 s, at the best 0.1 s of each wave (both bosses
always, plus the adds):

| Wave (s) | Bulwarks (15) | Vexhul (3) | Broodlings (10) | Alive at peak |
| -------- | ------------- | ---------- | --------------- | ------------- |
| 11 | 8 | | | 10 |
| 37 | | 3 | 3 | 8 |
| 72 | 7 | | | 9 |
| 98 | | 3 | 5 | 10 |
| 166 | 6 | | | 8 |
| 192 | | 3 | 3 | 8 |
| 227 | 10 | | | 12 |
| 253 | | 3 | 3 | 8 |
| 321 | 8 | | | 10 |
| 347 | | 3 | 4 | 9 |
| 382 | 10 | | | 12 |
| 408 | | 3 | 5 | 10 |

Between waves it is the 2 bosses. The adds die as they arrive, so at most 10 of
the 15 Bulwarks and 5 of the 10 Broodlings are up together.

Targets hit per Chain Lightning, rank 1 (138 casts, mean 2.5, against a mean 3.3
alive at the same moments):

| Targets hit | 1 | 2 | 3 | 4 | 5 |
| ----------- | - | - | - | - | - |
| Casts | 1 | 95 | 22 | 9 | 10 |

Earthquake hit 3 enemies on all 13 casts (the three Spawn of Vexhul). Chain
Lightning hit 5 at most. With only the bosses up it hits 2 of 2, and with a Bulwark
wave up it hits 4 or 5 of the 8 to 10 alive, so the alive count overstates what it
reaches by up to 5. The APL's `spell_targets` thresholds are 2 or 3, so the replay
uses the alive count.

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
kind that was up in the window with its arrivals and departures, and the player's
Chain Lightning and Earthquake damage rows (82, no amounts, the player as id 1).
The owner's log is not in it.

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
| `twin_fangs_window` (rank 1), enemies alive | 59 | 68% (40) | 16 of 19 |

Before the enemy count (#12), `ReplayLog` held a `targets` guess for the whole
log, and Sszorak had no count at all:

| Fixture | Presses compared | Agreement | Exact deviations |
| ------- | ---------------- | --------- | ---------------- |
| `sszorak_window`, 1 target | 46 | 41% (19) | 12 of 27 |
| `twin_fangs_window`, 1 target | 59 | 37% (22) | 1 of 37 |
| `twin_fangs_window`, 2 targets | 59 | 63% (37) | 0 of 22 |

Counting the enemies alive at each press (`EnemyPresence`, from the deaths and
arrivals of "Enemies alive" above) lifts rank 1 from 63% to 68% without being
told a number, and the 1 target guess's 37% was the wrong guess for a fight with
two bosses. Sszorak is one boss, so it is unchanged at 41%; only its exact count
moves, from 12 to 16, because a count read from the log is no longer an estimate.
`ReplayLog` takes `presence` (and still `targets`, for a log with no enemy data).
The fixtures hold the enemies of their window: the two bosses, the Bulwark wave at
2 s and the Vexhul wave at 28 s. The targets hit per Chain Lightning are in the
fixture too, but the replay does not use them: they are the player's own choice,
so feeding them back would make the state agree with the press.

Five presses (Sszorak) and two (Twin Fangs) are of abilities outside the spell
table, such as Ghost Wolf, and are not compared. Treat these as how well the APL
fits a window, not a grade: even rank 1 is at 68%.

Top deviation kinds (pressed instead of wanted):

| Sszorak | n | Twin Fangs, enemies alive | n |
| ------- | - | ------------------------- | - |
| Lava Burst instead of Elemental Blast | 6 | Chain Lightning instead of Lava Burst | 8 |
| Lightning Bolt instead of Lava Burst | 4 | Lightning Bolt instead of Lava Burst | 3 |
| Lava Burst instead of Lightning Bolt | 4 | Chain Lightning instead of Earthquake | 2 |
| Lava Burst instead of Flame Shock | 3 | Lava Burst instead of Earthquake | 2 |
| Lightning Bolt instead of Flame Shock | 3 | Elemental Blast instead of Earthquake | 2 |

What explains them:

- **Different play, owner.** Lava Burst instead of Elemental Blast is Maelstrom
  sitting at the 125 cap for about 15 s (33 s to 50 s of the window) with no
  spender, while the APL wanted Elemental Blast on every press. It matches this
  log's 99 wasted Maelstrom, and is exact.
- **Different play, rank 1.** Chain Lightning instead of Lava Burst, 8 times
  (13 when 2 targets was assumed), with Lava Surge up or 2+ charges: the player
  keeps cleaving at 2 enemies, where the APL prefers a Lava Burst. Chain
  Lightning instead of Earthquake and Lava Burst instead of Earthquake are
  builders pressed where the APL wanted a spender. The replay says what happened,
  not why; rank 1's habit of holding a spender for a wave is in "Add waves".
- **State the APL couldn't see: targets.** Now seen. The count is the enemies
  alive, not the enemies in range: a Bulwark wave puts 8 to 10 alive where Chain
  Lightning hit 4 or 5 (see "Enemies alive"). It can overcount, and an add's arrival
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

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
  arrived, a second or so after it spawned. `DamageTaken` and `Summons` by
  `targetID` returned nothing for these adds. `loadEnemyGroups` does this for
  every NPC with more than one copy, one query each.
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
spenders cast in those 10 s, seconds since the last spender, and the first
spender after with its offset (Earthquake is EQ, Elemental Blast EB). A wave
reads as held when the gap since the last spender is over 10 s or twice the
player's median gap, and a spender follows within 5 s. Held waves are marked *.

Rank 1 (median gap between spenders 5.2 s):

| Wave (s) | At spawn | Low / high | Spenders | Since last | First after |
| --- | --- | --- | --- | --- | --- |
| 37 | 40 | 11 / 101 | 1 | 4.6 s | +5.1 s EQ |
| 98 * | 103 | 50 / 103 | 0 | 17.8 s | +3.3 s EQ |
| 192 * | 125 | 30 / 125 | 0 | 17.0 s | +0.5 s EQ |
| 253 * | 100 | 29 / 100 | 0 | 15.3 s | +2.1 s EQ |
| 347 * | 76 | 26 / 76 | 0 | 11.6 s | +2.7 s EQ |
| 408 | 22 | 22 / 112 | 3 | 0.6 s | +10.2 s EB |

Rank 53 (median 5.9 s):

| Wave (s) | At spawn | Low / high | Spenders | Since last | First after |
| --- | --- | --- | --- | --- | --- |
| 37 | 106 | 48 / 106 | 1 | 9.3 s | +2.0 s EQ |
| 98 * | 89 | 55 / 89 | 0 | 19.4 s | +2.3 s EQ |
| 192 | 125 | 34 / 125 | 1 | 8.8 s | +2.2 s EQ |
| 253 | 19 | 13 / 103 | 1 | 1.8 s | +4.8 s EQ |
| 347 | 12 | 6 / 96 | 1 | 2.2 s | +4.6 s EQ |
| 408 | 51 | 35 / 125 | 3 | 3.3 s | none before the kill |

Owner, 394 s wipe (median 6.9 s; the build's cap is above 125, so levels pass
it):

| Wave (s) | At spawn | Low / high | Spenders | Since last | First after |
| --- | --- | --- | --- | --- | --- |
| 37 | 69 | 16 / 106 | 1 | 7.7 s | +1.1 s EQ |
| 98 | 33 | 9 / 99 | 1 | 8.9 s | +4.7 s EB |
| 192 * | 155 | 66 / 155 | 0 | 15.0 s | +1.6 s EQ |
| 253 * | 133 | 85 / 133 | 0 | 11.0 s | +1.8 s EQ |
| 347 | 50 | 34 / 124 | 1 | 4.5 s | +15.2 s EB |

Do top players hold a spender for the waves? Yes, about every other one. Rank
1 goes 11 to 18 s without a spender before the waves at 98, 192, 253 and 347 s
(against a 5.2 s median), climbs from the 30s to 76 to 125, and casts
Earthquake 0.5 to 3.3 s after the spawn. It does not at 37 s (it had just
spent) or 408 s. Rank 53 does at 98 s, and sits at 125 with an 8.8 s gap at
192 s, just short of the rule. The owner does at 192 and 253 s. The waves where
a spender is simply cast soon after, such as 37 s, are ordinary play, which is
why the gap since the last spender is the test and not the spenders after.

The earlier mean test (`isPooled`: the mean of the 8 s before, 15 above the
fight mean) read these holds as 52 to 80 against a fight mean of 65 and
flagged only 2 of 16 waves, no better than moments away from any wave, so this
section first said wrongly that top players don't pool. The mean still comes
out in the report, but the held-spender rule (`isHeld`) is the test.

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
since the last spender, Earthquake 2.1 s after the spawn). The owner's log is not in it.

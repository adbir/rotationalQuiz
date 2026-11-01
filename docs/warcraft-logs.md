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

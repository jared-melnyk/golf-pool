# Event Leaderboard & Cross-Round Scoring — Design Specification

**Status:** Draft for review  
**Project:** `long_shot` (On-Course games)  
**Date:** 2026-06-10  

**Related:** [On-Course Games design](2026-05-06-on-course-games-design.md), [Golf Trip Pre-Trip Plan](2026-06-10-golf-trip-pre-trip-testing-plan.md), [Ad hoc games design](2026-05-18-ad-hoc-games-design.md)

---

## 1. Purpose

The first buddies golf trip will use On-Course games across **four rounds** with **twelve golfers** (eight on the final round). Today, leaderboards exist **per game** only — there is no event-level view that rolls up individual performance, side contests, or trip-wide accolades.

This document defines an **Event Leaderboard** hub: PGA-style cumulative net scoring, per-round honors, on-course contests (longest drive, closest-to-pin), and optional fun stats/prizes that span rounds and game formats.

**Goal for trip:** Commissioners and players can open one event page, see who is “winning the trip” in stroke play, who posted the low round, who won LD/CTP holes, and browse trip awards — without manually reconciling four separate game scorecards.

---

## 2. Trip context (constraints)

From the pre-trip plan:

| Detail | Value |
|--------|--------|
| Rounds | 4 |
| Field | 12 golfers; round 4 = 8 only (4 sit out) |
| Formats | Best Ball, Cha-Cha-Cha, 40 Score, Vegas (planned) |
| Foursomes | Up to 3 games per round (one per foursome) |
| Leaderboards today | Per game only |

**Implication:** A player appears in **exactly one game per round** they play. Gross hole scores for that round live on their `GameTeamPlayer` record for that foursome’s game. Cross-round aggregation must **read** those scores, not require duplicate entry.

---

## 3. Current baseline

### What exists

- **Event shell:** members, rounds, games list (`events#show`).
- **Per-game scorecards:** `BestBallScorecard`, `ChaChaChaScorecard`, `FortyScoreScorecard` compute team leaderboards; each service already derives **per-player net scores** hole-by-hole using WHS course/playing handicap math.
- **Hole scores:** `HoleScore` → `GameTeamPlayer` → `GameTeam` → `Game` → `Round`. One row per player per hole per game.
- **Handicap snapshot:** `GameTeamPlayer#snapshot_handicap_index` frozen at lineup time.
- **Pools precedent:** `format_total_to_par` helper and PGA-style display (`E`, `+3`, `-2`) on pool tournament pages; live “holes completed” semantics in `PlayerRoundResultsFormatter`.

### What is missing

- No event-level leaderboard route or service.
- No concept of **round-level individual stroke play** independent of game format.
- No **side contests** (longest drive, closest-to-pin).
- No **accolades / prizes** model.
- No rollup of format-specific results (e.g. Vegas match points) at event level.

---

## 4. Product overview

### 4.1 Event Leaderboard page

Add **`/events/:token/leaderboard`** (or a prominent tab/section on `events#show`) with sub-sections:

| Tab / section | Description |
|---------------|-------------|
| **Tournament** | Cumulative net score-to-par across all rounds played (PGA-style). |
| **Low rounds** | Best single-round net score-to-par per player. |
| **Contests** | Longest drive & closest-to-pin winners by hole and event totals. |
| **Awards** | Auto-computed fun stats + commissioner-defined prizes. |
| **Format standings** *(optional v1.1)* | Points or wins from team games (Best Ball, Vegas, etc.). |

All sections are **read-only aggregations** over existing game data plus new contest entries. Manual refresh only (consistent with on-course v1 — no WebSocket/polling).

### 4.2 Who can see / edit

| Action | Who |
|--------|-----|
| View leaderboard | Any event member |
| Designate contest holes | Commissioner |
| Enter LD / CTP measurements | Any player in the round (or commissioner override) |
| Define custom awards / prize labels | Commissioner |

---

## 5. Core concept: canonical round scoring

Team games use different playing-handicap allowances (85% for Best Ball / Cha-Cha-Cha, 100% for 40 Score). **Event stroke-play leaderboards need a single, consistent rule** so totals are comparable across rounds.

### 5.1 Decided rule: 100% course handicap individual net

For **event leaderboard purposes only**:

- **Playing handicap = course handicap** (100% allowance).
- **Net per hole** = gross − strokes received on that hole (same WHS stroke-index distribution as scorecard services).
- **Round net to par** = Σ (net_strokes − hole_par) for holes with a gross entered.
- **Source gross scores:** the player’s `HoleScore` rows from their game on that round (see §5.2).

This matches “how did I play my own ball that day?” and aligns with standard net stroke play. It is **independent** of whether the foursome played Best Ball or Cha-Cha-Cha for the team game.

**Display:** Reuse `format_total_to_par` (`E`, `+5`, `-3`).

### 5.2 Resolving scores per (user, round)

Algorithm for `EventRoundScore.for(user, round)`:

1. Find all `Game` records where `game.round_id == round.id` and `game.event_id == event.id`.
2. Find `GameTeamPlayer` where `user_id == user` in any of those games.
3. If **zero** GTPs → user did not play that round (show “—”).
4. If **one** GTP → use its `hole_scores` (expected case for trip).
5. If **multiple** GTPs (edge case: player in two games same round) → prefer the game with the most holes entered; if tied, raise a commissioner-visible warning. *Trip setup should prevent this.*

**Handicap index:** use `snapshot_handicap_index` from the chosen GTP (already frozen at lineup).

### 5.3 Incomplete rounds (live trip)

Mirror pool live leaderboard behavior:

| State | Tournament column | Per-round column |
|-------|-------------------|------------------|
| 0 holes | — | — |
| 1–17 holes | Current net to par | Same; show `(thru N)` |
| 18 holes, all gross present | Final net to par | Final |
| 18 holes, missing gross | Incomplete — exclude from “low round” eligibility; show partial in tournament with `(thru N)` |

**Cumulative total:** Sum net-to-par across rounds where the player has at least one hole entered. Rounds not played (sat out) contribute nothing and do not penalize.

**Ranking incomplete players:** Sort by cumulative net to par (fewer strokes better); players with fewer holes completed in the current round sort after those with more holes at the same to-par (optional tie-break — see §5.4).

### 5.4 Ranking and ties

Use **ordinal ranking** (1-2-2-4) with **`T` prefix** on ties, consistent with game leaderboards (§8 of on-course design).

**Tie-breakers (v1):** None for tournament or low-round boards — shared places only. *Countback (back nine, etc.) is a future enhancement.*

### 5.5 Worked example

| Player | R1 (par 72) | R2 | R3 | R4 | Event total |
|--------|-------------|----|----|-----|-------------|
| Alice | -2 | +1 | E | — (sat out) | -1 |
| Bob | +3 | +3 | -1 | +2 | +7 |

Alice leads at -1. Bob played four rounds; Alice’s three rounds count.

---

## 6. Feature: Tournament leaderboard (cumulative net to par)

**User story:** “Who is winning the trip overall, like the PGA Tour standings?”

### 6.1 UI

Table columns:

| Pos | Player | R1 | R2 | R3 | R4 | Total |
|-----|--------|----|----|----|-----|-------|
| 1 | Alice | -2 | +1 | E | — | **-1** |
| T3 | Bob | +3 | +3 | -1 | +2 | +7 |

- Column headers use round name or date (`R1 · Jun 12`).
- **Total** column bold; sort key for ranking.
- Players who sat out a round show em dash in that column.
- Optional: expand row to show gross/net hole grid (v1.1).

### 6.2 Service

`EventTournamentLeaderboard.new(event).call` →

```ruby
{
  rounds: [ { id:, name:, played_on: } ],
  rows: [
    {
      user_id:, name:,
      round_to_par: { round_id => { to_par:, thru:, complete: } },
      total_to_par:, rank:, tied:
    }
  ]
}
```

Extract shared handicap math into a small module (e.g. `HandicapScoring`) used by scorecard services and event leaderboard — **avoid duplicating** `course_handicap` / `strokes_on_hole` a fourth time.

---

## 7. Feature: Low individual net rounds

**User story:** “Who shot the best single round of the trip?”

### 7.1 Rules

- Eligible round: **18 holes complete** (all gross scores present) under §5.1 net math.
- Each player’s **best** (lowest) net to par across eligible rounds is their entry.
- Display which round achieved the low score (`R2 · +1`).
- Player with multiple great rounds still contributes only their **one** best to this board.

### 7.2 UI

| Pos | Player | Round | Score | HI |
|-----|--------|-------|-------|-----|
| 1 | Carol | R3 · Pebble | -5 | 12.4 |
| T2 | Dave | R1 · Spyglass | -4 | 8.2 |

Optional secondary table: **all rounds ranked** (every complete round by every player) for “best rounds of the week” banter.

---

## 8. Feature: On-course contests (longest drive & closest to pin)

**User story:** “Commissioner picks hole 7 for LD on round 1; players enter drive distances; leaderboard shows longest.”

### 8.1 Domain model

```
RoundContest
  round_id
  contest_type     # "longest_drive" | "closest_to_pin"
  hole_number      # 1–18
  notes            # optional string ("downwind hole")

RoundContestEntry
  round_contest_id
  user_id
  measurement      # decimal: yards (LD) or feet (CTP)
  measurement_unit # "yards" | "feet" (or store canonical inches internally)
  entered_by_id    # audit
  timestamps
```

**Constraints:**

- Unique `[round_contest_id, user_id]` — one entry per player per contest hole.
- Commissioner creates contests when setting up or editing a round (or from event leaderboard “Add contest” flow).
- Multiple contests per round allowed (e.g. LD on 7, CTP on 12, LD on 15).

### 8.2 Entry UX

- From **round edit** or **event leaderboard → Contests**: commissioner adds contest hole + type.
- On **game day:** contest section on game scorecard or event page shows active contests for that round.
- Players tap their name → enter measurement:
  - **Longest drive:** yards (integer or one decimal).
  - **CTP:** feet and inches, or decimal feet (pick one input style in UI).
- Commissioner can edit/delete any entry.

### 8.3 Leaderboards

**Per contest hole:** rank entries; LD = longest wins; CTP = shortest wins.

**Event totals (aggregate):**

| Aggregation | Rule |
|-------------|------|
| Most contest wins | Count first-place finishes per hole |
| Total LD yards | Sum of winning drives only, or sum of player’s best per hole — **recommend: count wins + show “longest drive of trip”** as separate accolade |
| Longest single drive of trip | `max(measurement)` across all LD contests |
| Closest single CTP of trip | `min(measurement)` across all CTP contests |

### 8.4 Validation

- Measurement must be positive.
- Warn if entry submitted for a hole that is not a designated contest (block save).
- Player must be an event member who played that round (has GTP on a game for that round).

---

## 9. Feature: Summary stats & accolades

**User story:** “At the banquet, hand out funny awards and show trip stats.”

Split into **computed accolades** (automatic) and **commissioner prizes** (manual).

### 9.1 Computed accolades (v1)

Derived from hole scores and game results already in the DB:

| Accolade | Calculation |
|----------|-------------|
| **Tournament champion** | Leader of §6 cumulative board (if complete; else leader thru current play) |
| **Low round of the trip** | Leader of §7 |
| **Most birdies** | Count holes where net score < par |
| **Most pars** | Net == par |
| **Most bogeys** | Net == par + 1 |
| **Eagle alert** | List players with any eagle (net ≤ par − 2) |
| **Blow-up hole** | Worst single-hole net to par (e.g. quadruple bogey) |
| **Mr. Consistent** | Smallest std deviation of hole net-to-par (min 36 holes played) |
| **Comeback kid** | Largest improvement R1→R4 total to par among players in all 4 rounds |
| **Format kings** | Team game wins: count #1 leaderboard finishes per game (see §9.3) |
| **Vegas wash leader** | Most match points / best wash total in Vegas games |
| **40 Score specialist** | Best competition vs par in 40 Score games |
| **Longest drive / closest pin** | From §8 |

Display as cards on **Awards** tab with icon, title, winner name(s), and supporting stat.

### 9.2 Commissioner-defined prizes (v1)

Lightweight model for custom trip prizes:

```
EventAward
  event_id
  title            # "Closest to pool without going in"
  description      # optional
  winner_user_id   # nullable until assigned
  awarded_at
```

Commissioner creates titles before/during trip; assigns winner after. Shown alongside computed accolades. Avoid building a full betting/ledger system.

### 9.3 Format standings rollup (optional v1.1)

Team formats do not map cleanly to stroke play. Optional secondary board:

| Format | Suggested rollup |
|--------|------------------|
| Best Ball | Team rank → players on team get points (1st=10, 2nd=8, …) or simply count wins |
| Cha-Cha-Cha | Same |
| 40 Score | Use competition vs par as comparable score |
| Vegas | Sum wash points across matches |

**Recommendation:** Ship **stroke-play tournament + contests + accolades** for trip v1; add format points if time permits.

---

## 10. Architecture

### 10.1 Component diagram

```
events#show ──► link to Event Leaderboard
                      │
                      ▼
              Events::LeaderboardController#show
                      │
        ┌─────────────┼─────────────┬──────────────┐
        ▼             ▼             ▼              ▼
 EventTournament   EventLowRound   EventContests   EventAccolades
 Leaderboard       Leaderboard     Leaderboard     (aggregator)
        │             │             │              │
        └─────────────┴─────────────┴──────────────┘
                      │
              EventRoundScore (per user per round)
                      │
              HoleScore / GameTeamPlayer / Round
```

### 10.2 Shared scoring module

Extract from `BestBallScorecard`:

```ruby
# app/services/handicap_scoring.rb
module HandicapScoring
  def course_handicap(hi, round); end
  def playing_handicap(ch, allowance_percent); end
  def strokes_on_hole(ph, hole_number, round); end
  def net_strokes(gross, ph, hole_number, round); end
end
```

`EventRoundScore` includes `HandicapScoring` with `allowance_percent = 100`.

Refactor existing scorecard services to use the module in a follow-up or same PR if low risk.

### 10.3 Controllers & routes

```ruby
# config/routes.rb (nested under events)
resource :leaderboard, only: [:show], controller: "events/leaderboards"

resources :round_contests, only: [:create, :destroy]
resources :round_contest_entries, only: [:create, :update, :destroy]
resources :event_awards, only: [:create, :update, :destroy]
```

Keep contest CRUD near rounds; entries may live under `Events::RoundContestEntriesController`.

### 10.4 Views

- `app/views/events/leaderboards/show.html.erb` — tabbed layout.
- Partials: `_tournament_table`, `_low_rounds`, `_contests`, `_awards`.
- Reuse Tailwind patterns from `pool_tournaments/show` and game leaderboard partials.

### 10.5 Performance

For a 12-player, 4-round trip, computing from hole scores on each page load is fine. If needed later: cache `EventRoundScore` JSON on `events` table or Rails.cache keyed by `event.updated_at` max timestamp.

---

## 11. UX on event show page

Today `events#show` lists members, rounds, and games. Proposed change:

1. Add prominent **“Leaderboard”** button next to event title (members only).
2. Optional: embed a **mini tournament top-5** widget on `events#show` once any round has scores.
3. Games list remains — each game still has its own format-specific scorecard.

Do **not** remove per-game leaderboards; the event board is additive.

---

## 12. Edge cases

| Case | Behavior |
|------|----------|
| Round 4: 8 players only | 4 players show — for all rounds; no penalty |
| Player joins event mid-trip | Only rounds played count |
| Handicap updated after lineup | Event board uses **snapshot** from GTP |
| Incomplete game / round | Partial scores in tournament; excluded from low-round board |
| Different tees same round | v1: assume same tees per round (trip norm). Flag if course rating differs across games on same round (shouldn’t happen) |
| Commissioner deletes round | Cascade delete contests; leaderboard recalculates |
| Ad hoc game (no event) | Event leaderboard N/A — out of scope |

---

## 13. Implementation phases

Prioritized for **~1 month before trip**:

### Phase 1 — Tournament board (MVP for trip)

- [ ] `HandicapScoring` module + `EventRoundScore`
- [ ] `EventTournamentLeaderboard` service
- [ ] `Events::LeaderboardsController#show` with tournament tab
- [ ] Link from `events#show`
- [ ] Service specs with golden fixtures (reuse trip simulator players)
- [ ] Request spec: event with 2 rounds, 3 games, assert cumulative totals

**Estimate:** 2–3 days

### Phase 2 — Low rounds + accolades (core)

- [ ] `EventLowRoundLeaderboard` service
- [ ] `EventAccolades` service (birdies, eagles, format wins subset)
- [ ] Awards tab UI (computed only)
- [ ] Specs for low-round eligibility (incomplete excluded)

**Estimate:** 1–2 days

### Phase 3 — Contests (LD / CTP)

- [ ] Migrations: `round_contests`, `round_contest_entries`
- [ ] Commissioner UI to designate holes
- [ ] Player entry UI
- [ ] `EventContestsLeaderboard` service
- [ ] Specs for ranking LD vs CTP direction

**Estimate:** 2–3 days

### Phase 4 — Commissioner prizes + polish

- [ ] `EventAward` model + CRUD
- [ ] Top-5 widget on event show
- [ ] Refactor scorecards to `HandicapScoring` (if not done in Phase 1)
- [ ] Update `trip:simulate` manifest to include expected event leaderboard

**Estimate:** 1–2 days

### Phase 5 — Format standings (post-trip or if time)

- [ ] Points config per game type
- [ ] `EventFormatStandings` service

---

## 14. Testing strategy

| Layer | What |
|-------|------|
| Unit | `EventRoundScore`, `EventTournamentLeaderboard`, contest ranking |
| Golden | Extend `spec/fixtures/golden_trips/` with event-level expected totals |
| Journey | Full trip simulator → assert leaderboard URL in manifest |
| Manual | Trip checklist: enter scores in game → event board updates on refresh |

Add to pre-trip manual checklist (§Layer 4 of testing plan):

- [ ] Event leaderboard shows correct cumulative to-par after round 1
- [ ] Sat-out round shows —
- [ ] LD contest: designate hole, enter distances, verify winner
- [ ] Low round board excludes 9-hole incomplete card

---

## 15. Open questions

| # | Question | Recommendation |
|---|----------|----------------|
| 1 | **100% CH** for event board vs 85%? | **100%** for individual stroke play comparability |
| 2 | **Separate round scorecard** entry vs derive from games? | **Derive from games** for v1; add `RoundPlayer` later if double-entry becomes painful |
| 3 | **CTP input** format? | Feet + inches in UI; store canonical decimal feet |
| 4 | **Contest entry location** — game scorecard vs event page? | Both: banner on game scorecard when round has active contests |
| 5 | **Include gross leaderboard**? | Optional tab v1.1; net is primary for trip |
| 6 | **Stableford / points** for tournament? | Defer; stroke play matches “PGA tournament” ask |

---

## 16. Future enhancements (out of scope for trip v1)

- **Countback** tie-breaking for tournament
- **Round-level canonical scorecard** (`RoundPlayer` / `RoundHoleScore`) so players enter gross once per round regardless of game count
- **Skins** game type with event rollup
- **Live updates** (Turbo Stream refresh when any game score saves)
- **Export / print** banquet sheet PDF
- **Photo upload** for LD/CTP proof
- **Side bets** with dollar tracking

---

## 17. Summary

The event leaderboard is a **read-mostly aggregation layer** over data already captured in foursome games, plus a small **contest** sub-domain for LD/CTP. The flagship view is a **PGA-style cumulative net score-to-par board** with per-round columns, supported by **low round honors**, **contest leaderboards**, and **auto/computed awards** for trip banter.

Recommended build order: **tournament board → low rounds & accolades → contests → commissioner prizes**, aligned with Phase 1–4 above so the trip has meaningful stroke-play standings even if contests slip to week-of.

---

## Changelog

| Date | Change |
|------|--------|
| 2026-06-10 | Initial design draft from trip planning conversation |

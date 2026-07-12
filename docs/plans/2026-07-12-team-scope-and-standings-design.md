# Team scope & round/trip standings — Design

**Date:** 2026-07-12  
**Status:** Approved for implementation  
**Related:** [On-course games design](2026-05-06-on-course-games-design.md), [Trip rounds nest games](2026-07-12-trip-rounds-nest-games-design.md), [Event leaderboard](2026-06-10-event-leaderboard-design.md), [Michigan trip](../trip/2026-07-michigan-golf-trip.md)

## Problem

Team setup always shows **two** team slots. That fits Vegas and classic 2v2 Best Ball, but not trip play for Best Ball, Cha-Cha-Cha, and 40 Score — where each foursome is **one cooperative team** and three groups compete across the round.

Two product dimensions were being conflated:

1. **Scoring format** — how a team score is computed  
2. **Competition scope** — who those scores are compared against (inside one game vs across groups on a round)

## Goals

1. Fix setup UX so trip-style field games are the natural path for CCC / 40 / trip BB.
2. Keep classic **match** Best Ball (2v2, etc.) possible via “Add team.”
3. Define a standings read model that ranks field teams at **round** level and rolls up cleanly to a **trip** index later.
4. Preserve scorekeeping isolation: players open their foursome’s game and only edit their team (+ commissioner).

## Non-goals

- New `competition` / `scope` DB column (scope is derived).
- Individual stroke-play event leaderboard (separate design).
- WebSocket / polling live updates (recompute on read is enough).
- Blocking mixed field + match games on the same round (optional soft warning later).
- Changing Vegas rules or CCC / 40 / BB scoring math.

---

## Concepts

### Format vs scope

| Dimension | Meaning | Storage |
|-----------|---------|---------|
| **Format** | `game_type` scoring rules | Existing `games.game_type` |
| **Scope** | Match (intra-game) vs field (across sibling games on a round) | **Derived** from team count + format rules — no new column |

### Derived scope

| Condition | Scope |
|-----------|--------|
| Vegas | Always **match** |
| Cha-Cha-Cha or 40 Score | Always **field** (exactly one team) |
| Best Ball with **1** team | **field** |
| Best Ball with **2+** teams | **match** |

**Field** = this team’s result is ranked with other **field** teams from games that share `round_id` + `game_type`.  
**Match** = competition lives on this game’s own leaderboard; do not mix into the round field board.

### Trip shape (Michigan)

One round + three games of the same format, each with **one** team of four → three field results → one round field standings board.

Vegas remains separate matches (2×2 per game); round view lists match results, not a stroke field board.

---

## Setup UX

### Defaults by format

| Format | Initial slots | Add team? | Size rules |
|--------|---------------|-----------|------------|
| Best Ball | **1** | Yes | 1–4 per team |
| Cha-Cha-Cha | **1** | No | 3–4 |
| 40 Score | **1** | No | 3–4 |
| Vegas | **2** (fixed) | No | Exactly 2 per team |

### Copy

**Best Ball:**

> **One team:** your group’s score competes against other groups in this round.  
> **Add a team:** play head-to-head inside this game (e.g. 2v2).

**Cha-Cha-Cha / 40 Score:**

> This group’s score competes against other groups in this round.

**Vegas:** keep existing 2v2 requirements copy.

### Behavior

- Prefill team name as today (`Team A`, or trip group letter if already used).
- Empty slots with no name and no players are skipped on save (existing behavior).
- Enforce format team-size rules after save (existing CCC / 40 / Vegas enforcements).
- For CCC / 40, reject saving **more than one** non-empty team (new guard).

### Why CCC / 40 have no “Add team”

- **40 Score** is one group pick budget and one team total.  
- **Cha-Cha-Cha** needs 3–4 players on the counting side; 2v2 is invalid, and multi-team-on-one-game is just field competition without scorekeeping isolation.

Best Ball alone commonly needs both field (trip) and match (2v2).

---

## Standings read model

No new persistence. Build results from existing scorecard services.

### `TeamResult` (in-memory / PORO)

Logical shape:

```ruby
{
  game_id:,
  team_id:,
  team_name:,
  round_id:,
  event_id:,      # nullable for ad hoc
  game_type:,
  scope:,         # :field | :match
  metric_key:,    # :total_net_strokes | :competition_vs_par | :wash_margin (etc.)
  metric_value:,  # numeric or nil if incomplete
  complete:,      # boolean
}
```

Populate via `BestBallScorecard` / `ChaChaChaScorecard` / `FortyScoreScorecard` / `VegasScorecard`.

### Round standings

**Field board** (BB / CCC / 40):

1. Load games for `round_id` with the chosen `game_type` (or all field-capable types if UI is per-format tabs).
2. Emit `TeamResult`s with `scope == :field` only (one team per game for CCC/40; BB only when `game.game_teams.size == 1`).
3. Rank complete results by metric (lower is better for net / vs-par). Same ordinal + `T` tie display as game leaderboards.
4. Incomplete teams listed without rank.

**Match list** (optional section on same page):

- BB games with 2+ teams → show that game’s in-game leaderboard summary / link.  
- Vegas games → wash summary per match.

### Live vs completed

Recompute on read from hole scores. No requirement that games be `completed` for round standings — “live peek” works when scores exist. Trip MVP may still highlight completed rounds first; do not block live field boards.

### Trip standings (MVP)

**Index of round standings** for the event: for each round (and format played), link or embed the same field board / match list.

Later (not required now): format points, “format kings,” etc. consume the same `TeamResult` shape — see [Event leaderboard §9.3](2026-06-10-event-leaderboard-design.md). Do not invent a second rollup vocabulary.

Individual stroke-play tournament board remains a **separate** concern (gross/net per player at 100% CH).

---

## Architecture (implementation hints)

```
edit_teams (format-aware slots)
        │
Game + GameTeams
        │
Scorecard services ──► TeamResult builder
        │
RoundStandings (service) ──► round standings UI
        │
EventStandings index (MVP) ──► list round boards
```

Suggested touch points:

| Area | Likely files |
|------|----------------|
| Team setup UI | `app/views/games/edit_teams.html.erb` |
| Team save guards | `app/controllers/games_controller.rb` |
| Scope helper | e.g. `Game#field_scope?` / `Game#match_scope?` on `Game` |
| Results | new PORO/service under `app/services/` (e.g. `TeamResult`, `RoundFormatStandings`) |
| Round UI | round show or nested partial on event/round |
| Trip UI | event page section or `/events/:token/standings` stub that indexes rounds |
| Specs | request specs for team slot rules; service specs for field ranking |

---

## Phased delivery

### Phase 1 — Setup UX (ship first; unblocks trip dry-run)

- Format-aware team slot count (1 / 1 / 1 / 2).  
- BB: Add team control + helper copy.  
- CCC / 40: single-team only + helper; reject >1 team.  
- Specs for save paths.

### Phase 2 — Round field standings

- `TeamResult` + round standings service for BB / CCC / 40 field games.  
- UI on round (or trip nested under round): ranked groups.  
- Match/Vegas as secondary list or links only.

### Phase 3 — Trip index

- Event-level page/section listing each round’s standings (same components).  
- No new metrics beyond composing Phase 2.

---

## Success criteria

1. Creating Cha-Cha-Cha / 40 Score / trip Best Ball shows **one** team slot by default; leaving a phantom Team 2 is unnecessary.  
2. Best Ball can still add a second team for 2v2 match play.  
3. Michigan-style setup (3 games × 1 team on one round) produces a round field board with three ranked teams.  
4. Score entry remains per-game / per-team; players are not forced through other groups’ cards to keep score.  
5. Trip standings MVP reuses round standings without a parallel data model.

## Open follow-ups (later)

- Soft warning when a round mixes field and match BB games.  
- Richer trip format points / awards.  
- Align “Format kings” in the event-leaderboard design to **round field #1** (not single-team game leaderboards).

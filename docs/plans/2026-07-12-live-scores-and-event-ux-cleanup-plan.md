# Live scores & event UX cleanup — Plan

**Date:** 2026-07-12  
**Status:** Implemented 2026-07-12  
**Related:** [Team scope & standings](2026-07-12-team-scope-and-standings-design.md), [Event leaderboard](2026-06-10-event-leaderboard-design.md)

## Problem

1. **No live team score mid-round** for Best Ball, Cha-Cha-Cha, or 40 Score — totals stay blank until the card is “complete” (18 holes / full pick budget). Vegas already shows a live wash. Round/event standings inherit the same blankness.
2. **UX cleanup** after field-style games (1 team per game) and standings shipped.

## Goals

1. Show **live partial** team scores in-game and on round/event standings.
2. User-facing copy uses **Event** (not Trip), except where noted.
3. Slimmer event → round UI: no redundant copy or duplicate game lists.
4. Distinct default team names across a round’s field games.
5. Hide meaningless single-team in-game leaderboards for field formats.

## Non-goals

- WebSockets / polling (recompute on read / existing Turbo updates is enough).
- Individual stroke-play event leaderboard (separate design).
- Changing final scoring math for completed rounds.
- Renaming the `Event` model, routes, or `trip:simulate` rake internals (code/API can keep current names).

---

## Part A — Live scores

### Principle

| Scope | Live surface |
|-------|----------------|
| **Match** (Vegas; multi-team BB) | In-game summary (wash / match leaderboard) — already largely works for Vegas |
| **Field** (CCC, 40, one-team BB) | In-game team total **and** round/event standings, using the same partial metric |

Emit a value whenever there is something to show; use `complete: false` until the final rule is satisfied. Standings rank **all** teams that have a live metric (including incomplete), with complete teams preferred only for “final” labeling — not for hiding scores.

### Metrics (locked)

#### Best Ball (field or match)

- **Live:** sum of best-ball nets on holes that have a team score (at least one player net entered → hole counts).
- **Display (in-game total / standings):** prefer **net to par thru N**, e.g. `+3 (6)` = 3 over par through 6 holes with a BB score.
  - `thru` = count of holes with a non-nil best-ball net.
  - `vs_par` = Σ(best_ball_net − hole_par) over those holes.
- **Complete:** thru == 18 → same number is the final total-to-par (standings can still sort on vs_par; keep raw total net available if needed for golden fixtures).

*Fallback if to-par is awkward in an existing total column:* show `72 (6)` as strokes thru 6 — but **to-par + thru** is preferred for standings readability next to 40 Score / CCC.

#### Cha-Cha-Cha

- **Live:** same idea on holes with a countable team net (enough player nets for that hole’s 1/2/3 rule).
- **Display:** e.g. `+5 (7)` — net to par through 7 holes.
- **Complete:** 18 holes with team nets.

#### 40 Score

- **Live:** vs-par on **selected** holes only, even before hitting 30/40 picks.
  - `actual_vs_par_so_far` = Σ(net − par) on picked holes with a net.
  - For threesomes, **scaled** competition line can still apply only when target is reached (keep current final rule); live display uses **actual** vs-par + pick progress until complete.
- **Display:** e.g. `-3 (14/40)` or `-3 (11/30)` for a threesome.
- **Complete:** `selected_count == target_pick_count` → today’s `competition_vs_par` (scaled for threesomes) is the ranking metric.

#### Vegas

- Unchanged: running wash / “X leads by N”.

### Scorecard service changes

Extend team hashes (and leaderboard / `TeamResult` rows) with live fields, e.g.:

```ruby
{
  # existing …
  total_net_strokes:,          # final only (nil until complete) — keep for fixtures if needed
  live_vs_par:,                # BB / CCC / 40 actual
  live_thru_holes:,            # BB / CCC
  live_picks:, live_pick_target:,  # 40 only
  live_label:,                 # preformatted "+5 (7)" / "-3 (14/40)"
  complete:
}
```

**Ranking for round standings (field):**

- Sort by `live_vs_par` ascending (lower better), then name.
- Incomplete and complete share one board (live peek). Optional: subtle “thru N” / “14/40” in the metric column via `live_label`.
- When all field teams on a format are complete, labels can drop the thru/picks suffix if desired (cosmetic).

**In-game UI:**

- BB / CCC: total row / mobile header uses `live_label` (not blank `—`).
- 40: team header / mobile already near pick counts — show live vs-par + `selected/target`.
- Field formats: **remove** the bottom per-game leaderboard when `field_scope?` (always for CCC/40; BB with one team). Match BB (2+ teams) and Vegas keep in-game competition UI.

### Round / event standings

`RoundFormatStandings` already ranks field `TeamResult`s — switch metric source to live fields so mid-round boards populate. Display `live_label` (or structured vs_par + progress) instead of only final totals.

---

## Part B — UX cleanup

### 1. “Trip” → “Event” in user-facing copy

Use **Event** in nav, buttons, empty states, and back-links.

| Today (examples) | Change to |
|------------------|-----------|
| Nav “Trips” | “Events” |
| “Plan a trip” | “Create event” / “Plan an event” |
| “Back to trip” | “Back to event” |
| “Trip: …” on game lists | “Event: …” |
| Admin column “Trip” | “Event” |
| Standings “trip” phrasing | “event” |

**Keep “trip” where it still makes sense:**

- Real-world outing docs under `docs/trip/` (Michigan golf trip).
- Internal tools: `trip:simulate`, `TripConfig`, dry-run emails — code/ops names, not product chrome.
- Model/route `Event` stays `Event` (already correct).

Sweep `app/views`, flash/alert strings, and admin UI. Do not mass-rewrite historical plan docs unless we touch them anyway.

### 2. Remove “games nest under each round” helper text

On `events/show`, drop the line:

`commissioner-managed · games nest under each round`

(and any similar “commissioner-managed” chrome that only restates the layout). Keep round metadata (date, course, tee).

### 3. Deduplicate games on the event round card

Today each round shows:

1. Numbered list of games, and  
2. Format standings (which already links each team/game).

**Remove the numbered game list.** The standings board is the list of games/groups.  

Commissioner actions stay on the round header (**Add game**, Edit, Delete).

If a round has games but no standings rows yet (e.g. Vegas-only with no teams), show a short empty state or the match list section only — still no duplicate numbered list.

### 4. Default team names across a round

**Bug:** every new field game defaults blank → save as `Team A`, so three 40 Score groups all become “Team A”.

**Rule:**

| Situation | Default team name |
|-----------|-------------------|
| Field game (CCC / 40 / one-team BB) | `Group {letter}` matching the game’s group letter (same letter as `Forty Score · A` → **Group A**) |
| Match BB / Vegas slot 0, 1, … | `Team A`, `Team B`, … within that game (unchanged) |

Implement by deriving letter from `Game.default_trip_name` / `next_group_letter` already used at game create, or parse the `· X` suffix from `game.name`. Prefill the team name input on `edit_teams`; on save, if name blank, apply the same default (not always `Team A` by index alone for field games).

### 5. Hide in-game leaderboard for field formats

When `game.field_scope?`:

- Do not render `_leaderboard_best_ball`, `_leaderboard_cha_cha_cha`, `_leaderboard_forty_score`, or the mobile standings block that only lists one team.
- Still show the **team’s own live score** (Part A) on the scorecard / mobile header.
- Round/event standings remain the place to compare groups.

When `game.match_scope?` (Vegas, multi-team BB): keep in-game leaderboard / wash.

---

## Implementation order

1. **Quick UX cleanup (B2, B3, B1, B4, B5)** — high user friction, small diffs.  
2. **Live metrics in scorecard services + specs** (Part A).  
3. **Wire live labels** into scorecard/mobile totals and `RoundFormatStandings` display/ranking.  
4. Regression: golden fixtures for *completed* rounds stay stable; add examples for mid-round live labels.

## Success criteria

1. On hole 6 of a field BB/CCC game, the UI shows a live score like `+2 (6)`, not `—`.  
2. 40 Score shows something like `-3 (14/40)` before picks are full; final ranking still uses full-target competition vs par.  
3. Round/event standings update as scores are entered (same live metrics).  
4. Event UI says Event, not Trip (product chrome).  
5. Event round card: no nest-under copy; no duplicate numbered game list.  
6. Three field games on a round get Group A / B / C (or equivalent distinct defaults), not three “Team A”s.  
7. Field game scorecards have no one-row “leaderboard”; match games unchanged.

## Open choices (defaults if implementing without another pass)

- BB/CCC live ranking metric: **vs_par thru N** (not cumulative strokes).  
- 40 Score live ranking: **actual vs_par** until complete, then **competition_vs_par**.  
- Incomplete teams: **included** in standings sort (not parked at the bottom without a number), with progress in the label.

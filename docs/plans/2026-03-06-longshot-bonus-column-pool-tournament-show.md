# LongShot Bonus Column on Pool Tournament Show

**Goal:** Once the cut is made (typically after Round 2), show a **Bonus** column at the end of the picks table on the pool tournament show page. For each golfer who made the cut, display their LongShot bonus (capped at 10% of tournament prize pool). Golfers who missed the cut show "—" or "MC" in the Bonus column.

**Context:** The pool tournament show (`/pools/:pool_token/pool_tournaments/:id`) already shows Golfer (with odds), R1–R4, and Total. Pool scoring uses `TournamentResult#made_cut?` (prize_money present and positive) and `Pool#capped_odds_bonus(tournament, american_odds)` for the LongShot bonus. There is no separate "cut" API; results are synced post-tournament via `BallDontLie::SyncTournamentResults`.

---

## Scope and options

**When to show the Bonus column**

- **Option A (simplest):** Show the Bonus column only when the tournament has **completed** (or when results have been synced). For each picked golfer, if a `TournamentResult` exists and `made_cut?` is true, display the capped LongShot bonus; otherwise show "—" or "MC". No live "after cut" state—bonus appears only after tournament results are in.
- **Option B (live after cut):** Show the Bonus column once the cut is deemed made (e.g. after Round 2 is complete or Round 3 has started). "Made cut" would need to be inferred from live round data (e.g. golfer has completed 36 holes and has round 3 data, or a cut list from an API if available). Bonus would then be computed the same way (capped 20× odds) and displayed during the tournament. This requires defining "cut made" from round/scorecard data and may depend on balldontlie API behavior.

Recommendation: implement **Option A** first (Bonus column when results exist + made_cut). Option B can be a follow-up if you want in-tournament bonus visibility.

---

## Task 1: Add Bonus column (Option A — post-results)

**Assumption:** Bonus column is shown when we have tournament results (or when tournament is completed and we’re okay showing 0/MC for unsynced golfers). Alternatively, show the column only when `@tournament.completed?` or when any `TournamentResult` exists for the tournament.

**Step 1: Controller**

- In `PoolTournamentsController#show`, ensure we have:
  - `@pool_tournament`, `@tournament`, `@pool`, `@picks_by_user`, `@round_results`, `@current_round` (already present).
- No strict need to pass new instance variables if we compute bonus in the view from existing data (see Step 2). If you prefer to keep view logic thin, add a helper or a method on `PoolTournament` / `Tournament` that, given a golfer, returns the LongShot bonus amount if the golfer made the cut, else `nil`.

**Step 2: Bonus calculation in one place**

- Reuse the same rule as `Pool#total_points_for`: bonus = `capped_odds_bonus(tournament, american_odds)` when the golfer made the cut; otherwise 0 / no bonus.
- `TournamentResult#made_cut?` is already defined (prize_money present and positive).
- Options:
  - **Helper:** e.g. `longshot_bonus_for_golfer(pool_tournament, golfer)` in `ApplicationHelper` or `PoolTournamentsHelper` that finds `PoolTournamentOdds` and `TournamentResult` for that golfer/tournament and returns the capped bonus or `nil` if no odds or didn’t make cut.
  - **Model:** Add `PoolTournament#longshot_bonus_for(golfer)` (or on `Tournament`) that does the same. Call from the view or from the controller and pass a hash `@golfer_bonuses = { golfer_id => bonus_value }` to avoid N+1.

**Step 3: View**

- In `app/views/pool_tournaments/show.html.erb`:
  - Add a table header: `<th class="...">Bonus</th>` (or "LongShot bonus") after the **Total** column.
  - For each golfer row, add a `<td>` that:
    - If the golfer has made the cut and has locked odds: show the bonus formatted as currency (e.g. `number_to_currency(bonus, precision: 0)` or `number_with_delimiter(bonus)` with a "$" prefix).
    - If the golfer did not make the cut (or no result): show "—" or "MC".
    - If no odds: show "—".
- Only show the Bonus column when it’s meaningful: e.g. when `@tournament.started?` (or `@tournament.completed?` if you prefer to show it only after the event). That way before the tournament you don’t show an empty column.

**Step 4: N+1 and performance**

- Preload `TournamentResult` and `PoolTournamentOdds` for the tournament and picked golfers so the view/helper doesn’t do a query per golfer. For example in the controller: load all `TournamentResult` for `@tournament` and all `PoolTournamentOdds` for `@pool_tournament`, then in the helper or view look up by golfer id.

**Step 5: Specs**

- Request spec for pool_tournaments#show: with a completed tournament and synced results, for a golfer who made the cut and has PoolTournamentOdds, the page should contain the expected bonus value in the Bonus column. For a golfer who missed the cut, the Bonus cell should show "—" or "MC".
- Optional: unit test for the helper or `PoolTournament#longshot_bonus_for(golfer)` with made_cut / missed_cut / no odds.

---

## Task 2 (Optional): Show Bonus column during tournament once cut is made (Option B)

**Only if you want bonus visible before results are synced.**

- Define "cut made": e.g. tournament has started and `current_round_number >= 3` (from live round results), meaning Round 2 is complete.
- Define "golfer made cut": either
  - (a) They have a `TournamentResult` with `made_cut?` (same as now), or  
  - (b) Infer from `@round_results`: e.g. golfer has round 2 with `last_hole_completed == 18` and has round 3 data (or is present in round 3). This depends on how balldontlie exposes round-by-round data and whether "made cut" can be inferred without an explicit cut list.
- When both conditions hold, show the Bonus column and compute bonus the same way (capped 20× odds). Display "—" or "MC" for golfers who didn’t make the cut (e.g. have only round 1–2 and no round 3).
- Document the inference rule (e.g. "we consider a golfer as made cut if they have completed round 2 and have round 3 data in @round_results") and add a spec that after round 2 completion (mocked), the Bonus column appears and shows correct amounts for golfers with round 3 data.

---

## Summary

| Item | Action |
|------|--------|
| 1. Odds +/– | Done in this session: pool tournament show uses `format_american_odds` so odds display as (+700) or (-200). |
| 2. "LongShot bonus" naming | Done in this session: landing, rules, picks views, pool model comments, and pool spec descriptions updated. |
| 3. Bonus column | **Plan above:** Implement Option A (Bonus column when results exist, using `TournamentResult#made_cut?` and existing capped bonus logic). Option B is optional for live post-cut display. |

**Implemented (Option A):** Bonus column always displays with the scoring table. No result / no odds → "—". Result synced and made cut with odds → bonus amount (e.g. $10,000). Result synced and missed cut → "MC". `Tournament#capped_longshot_bonus` added; controller builds `@golfer_bonus_display` with preloaded results and odds. Request specs cover —, bonus amount, and MC.

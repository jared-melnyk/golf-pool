# Live Earnings Projection (Hybrid) — Design Specification

**Status:** Approved design, ready for implementation planning.  
**Project:** `long_shot` (single Rails app, one deploy).  
**Date:** 2026-06-01  

**Related:** [Live cut status plan](2026-05-30-live-cut-status-plan.md) (live leaderboard + cut/bonus display), [CMB fallback design](2026-05-13-cut-made-bonus-fallback-design.md) (effective purse).

---

## 1. Purpose

Pool tournament scoring is **prize money + Cut Made Bonus** (top 3 of 4 per pick). During a live event, the API provides **leaderboard position** but not **earnings** until the tournament is complete. A prior approach projected Counted/Dropped using **bonus only**, which systematically mis-ranks picks when a long-shot’s bonus exceeds a contender’s eventual prize (e.g. Matsuyama vs Theegala at Charles Schwab).

This document defines a **hybrid** live projection system:

1. **Prefer** an empirical payout curve from **last year’s same-named event** (position → share of purse).
2. **Else** use a small set of **static payout profiles** (standard PGA cut, 20% winner variant, US Open, etc.).
3. **Else** **hide projection** — show honest TBD for total earnings and Counted/Dropped until final results (current shipped behavior).

The goal is accurate enough projection for **popular** weeks (majors, signatures, Players) without pretending one formula fits every event.

---

## 2. Problem analysis

### 2.1 What the API provides

| Field | Endpoint | Live | Final |
|-------|----------|------|-------|
| `position`, `position_numeric` | `tournament_results` | Yes | Yes |
| `earnings` | `tournament_results` | **null** | Yes |
| `purse` | `tournaments` | Yes (sometimes `$0`) | Yes |
| Payout % table | — | **No** | **No** |
| Event type (major / signature) | — | **No** | **No** |

LongShot already syncs live positions via `BallDontLie::SyncLiveLeaderboard` and final money via `BallDontLie::SyncTournamentResults`. Projection must be **derived**, not read from the API.

### 2.2 Why “one standard PGA table” is insufficient

| Bucket | Examples | Standard 18% ladder |
|--------|----------|---------------------|
| Regular + most signatures | Charles Schwab, RBC Heritage, Truist | **Good fit** (Tour publishes identical tie tables) |
| Player-hosted signatures | Genesis, Arnold Palmer, Memorial | **Needs 20% winner** redistribution |
| Masters, PGA Championship | Majors | **Mostly close** to standard |
| U.S. Open | Major | **Poor fit** — USGA-specific curve (~20% winner, different mid-pack) |
| Open Championship | Major | **Needs own curve** (R&A) |
| No-cut signatures | Some elevated events | **Different** — full-field pay; not position-cut logic |
| Tour Championship | Playoffs finale | **Special** (e.g. 25% to winner) — suppress or dedicated profile |

**Implication:** Popular events are not uniformly “non-standard”; the failure mode is applying **bonus-only** projection, not using *any* prize model. A **hybrid** avoids both extremes.

### 2.3 Current display baseline (hidden projection)

Until this feature ships, `PoolTournamentScoringDisplay` intentionally:

- Shows **Cut Made Bonus** and **MC** after cut when known.
- Shows **—** for Prize Money and Total Earnings while in progress.
- Shows **Counted/Dropped** only when `tournament.completed?`.
- Sorts live rows by **score-to-par**, not bogus bonus totals.

That is the **hidden-projection fallback** when no trustworthy curve exists.

---

## 3. Goals & non-goals

### Goals

- Project **prize money** from live **position** + **effective purse** when a payout curve is available.
- Project **total earnings** = projected prize + cut-made bonus (MC → $0 total).
- Rank **Counted/Dropped** (top 3 of 4) on projected total when projection is **enabled**.
- Prefer **prior-year empirical** curves for same `tournament.name` (exact normalized match).
- Fall back to **static profiles** when empirical data is missing.
- Fall back to **hidden projection** (TBD, no badges) when neither is available.
- Label projected values clearly; never imply final PGA accounting.
- Support **one-time production backfill** of prior-season results so empirical curves exist before first live use.

### Non-goals

- Changing pool **standings** / `Pool#points_for_pool_tournament` until complete (display-only live).
- Live **API earnings** (unavailable).
- Fuzzy tournament-name matching in v1 (same normalized name as CMB fallback).
- Scraping PGA Tour media tie sheets at runtime.
- Projecting for **no-cut** signature fields with the same position model (suppress or bonus-only for those events).

---

## 4. Strategy overview

```text
                    ┌─────────────────────────┐
                    │ Live position + purse   │
                    └───────────┬─────────────┘
                                │
                    ┌───────────▼─────────────┐
                    │ PayoutCurveResolver     │
                    │ (per tournament)        │
                    └───────────┬─────────────┘
                                │
         ┌──────────────────────┼──────────────────────┐
         │                      │                      │
         ▼                      ▼                      ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│ Empirical       │  │ Static profile  │  │ :hidden         │
│ (prior year     │  │ (standard_cut,  │  │ no projection   │
│  same name)     │  │  us_open, …)    │  │ (TBD UI)        │
└────────┬────────┘  └────────┬────────┘  └────────┬────────┘
         │                      │                      │
         └──────────────────────┴──────────────────────┘
                                │
                    ┌───────────▼─────────────┐
                    │ ProjectedPrizeMoney     │
                    │ + bonus → total         │
                    └───────────┬─────────────┘
                                │
                    ┌───────────▼─────────────┐
                    │ UI: badges + $ only if  │
                    │ projection_enabled?     │
                    └─────────────────────────┘
```

---

## 5. Payout curve resolution

### 5.1 Name normalization

Reuse the same rule as `BallDontLie::SyncTournaments#previous_season_purse_for`:

```ruby
key = tournament.name.to_s.downcase.strip
```

Match prior-year `Tournament` rows on `key` equality. No fuzzy match in v1.

### 5.2 Empirical curve (preferred)

**Source:** Completed prior-year tournament with the same normalized name.

**Build once** (at backfill or lazily on first use):

1. Load all `TournamentResult` for prior tournament where `position` is present and `prize_money > 0` (or include `0` for MC rows if needed for cut modeling — prize projection for MC is always `0`).
2. Let `P` = prior tournament `effective_prize_pool` (must be positive).
3. For each integer position `k` (handle ties separately), compute `share(k) = prize_money / P`.
4. For tied positions (same `position` / `position_display` like `T5`), store **average share** across tied players (mirrors PGA tie pooling).

**Storage (locked):** Persist on the **current** `tournaments` row (server-side DB, not browser caching):

- `payout_curve_source` — `empirical` | `static` | `hidden`
- `payout_curve` — JSON (position → share of purse, plus metadata: prior-year tournament id, built_at)
- `payout_curve_built_at` — optional timestamp

Populate when:

1. Prior-year results are backfilled or a season completes (build empirical curve from that year’s `TournamentResult` rows), and/or
2. `PayoutCurveResolver` falls back to static and snapshots that profile into JSON for the current event.

At runtime the scoreboard **reads the stored curve**; it does not re-scan all prior-year result rows on every page view. Rebuild the curve when prior-year results sync updates (idempotent job or hook after `SyncTournamentResults`).

**Use at runtime:** Given live `position_numeric` (or parsed from `position_display`), `projected_prize = effective_prize_pool * share(position)` with tie averaging when display is `T*`.

**Quality gate:** Require ≥ N paid positions (e.g. 50) in prior year before trusting empirical curve; else fall through to static profile.

### 5.3 Static profiles (fallback)

| Profile | When to use | Notes |
|---------|-------------|-------|
| `standard_cut` | Default | PGA 1–65/70 ladder + tie pool (18% / 10.8% / 6.8% / …) |
| `winner_20_cut` | Name allowlist: Genesis, Arnold Palmer, Memorial | 20% to winner; rest from published redistribution |
| `us_open` | Name matches `U.S. Open` | Embedded USGA percentage table |
| `open_championship` | Name matches `Open Championship` / `The Open` | Embedded R&A table |
| `no_cut_field` | Name allowlist + product flag | **Resolver returns `:hidden`** for prize projection |
| `tour_championship` | Name matches `Tour Championship` | **`:hidden`** or dedicated table (defer if low pool usage) |

Allowlist lives in code (`config/payout_profiles.yml` or `lib/pga_payout_profiles.rb`) for easy diff review.

### 5.4 Resolver outcome

```ruby
# Pseudocode
PayoutCurveResolver#resolve(tournament) =>
  :empirical, curve          # best
  :static, profile_id, curve  # good
  :hidden                     # show TBD (current behavior)
```

`PoolTournamentScoringDisplay#projection_enabled?` → true only for `:empirical` or `:static`.

---

## 6. Projection math

### 6.1 Projected prize money

```ruby
def projected_prize_money_for(golfer)
  return nil unless projection_enabled?
  position = live_position_for(golfer)  # TournamentResult from live sync
  return 0.to_d if position_missed_cut?(position)
  curve.amount_for(position, purse: tournament.effective_prize_pool)
end
```

**Position priority:**

1. `TournamentResult#position` / `#position_display` from live leaderboard sync.
2. Optional: infer from `@round_results` rank among made-cut picks only if no row (rare).

### 6.2 Projected total earnings

```ruby
def projected_total_earnings_for(golfer)
  return nil unless projection_enabled?
  prize = projected_prize_money_for(golfer)
  return nil if prize.nil?
  bonus = bonus_for(golfer)  # existing cut/MC logic
  return 0.to_d if bonus == :mc
  prize + (bonus.is_a?(Numeric) ? bonus : 0.to_d)
end
```

### 6.3 Counted / Dropped

When `projection_enabled?` and `cut_posted?`:

- Rank pick’s golfers by `projected_total_earnings_for` descending.
- Top 3 → Counted (projected); bottom → Dropped (projected).

When `tournament.completed?`:

- Use final `total_earnings_for` (actual prize + bonus); badges without “projected”.

When `:hidden`:

- No badges; total earnings `—`; footer explains waiting for final money.

### 6.4 Display contract (locked)

| Phase | Cut Made Bonus | Prize Money | Total Earnings | Counted/Dropped |
|-------|----------------|-------------|----------------|-----------------|
| Before cut | — | — | — | Hidden |
| After cut, projection **on** | Bonus / MC (normal) | **Projected** $ (greyed) | **Projected** $ (greyed) | Projected top 3 |
| After cut, projection **off** | Bonus / MC | — | — | Hidden |
| Complete | Final (normal) | Final (normal) | Final (normal) | Final top 3 |

**Projected styling (not a heavy lift):** When `projection_enabled?` and tournament is not complete:

- Show dollar amounts in **Prize Money** and **Total Earnings** (not `—`), using projected values.
- Style: `text-gray-400` (or similar) for the amount; optional small **“Projected”** pill on the golfer row (same badge slot as Counted/Dropped) or a column header hint: “Prize Money (projected)”.
- **Cut Made Bonus** stays full contrast — that value is known from cut + odds, not estimated from position.
- **Dropped** row: projected amounts greyed; if dropped, keep existing strikethrough on total.
- **Total row:** sum projected prize / projected total for counted golfers only, same grey treatment.

After completion, switch to normal `text-gray-700` / `font-semibold` with no “Projected” label (same cells, final API money).

**Copy (footer when projected):**  
“Grey amounts are projected from live position and last year’s payout pattern (or a standard Tour table). Final prize money and Counted/Dropped are official after the tournament ends.”

**Copy (footer when hidden):**  
“Total earnings and Counted/Dropped are shown after final prize money is posted. Cut Made Bonus reflects make-cut status only while play is in progress.”

---

## 7. Prior-year backfill (production)

### 7.1 Can we populate bespoke events with a one-time command?

**Yes.** The API exposes historical seasons; LongShot already has the building blocks:

| Step | Existing tool | What it writes |
|------|----------------|----------------|
| Import tournament metadata | `rake ball_dont_lie:tournaments SEASON=2025` | `tournaments` rows: `name`, `external_id`, `total_prize_pool`, dates |
| Import final leaderboard + earnings | `rake ball_dont_lie:tournament_results TOURNAMENT_ID=<id\|external_id>` | `tournament_results` with `position`, `prize_money`; sets `champion_golfer_id` when API status is `COMPLETED` |

Tournaments **do not** need to be in a pool to exist in the DB. `SyncTournaments` upserts **all** API tournaments for that season (same as picks-page sync).

**Recommended:** Add a dedicated rake task so operators do not run 40+ manual commands:

```bash
# Dry run: list what would sync
bundle exec rake ball_dont_lie:backfill_season_results SEASON=2025 DRY_RUN=1

# Full season (respects rate limit; may take ~30–60+ min)
bundle exec rake ball_dont_lie:backfill_season_results SEASON=2025

# Only events pools care about
bundle exec rake ball_dont_lie:backfill_season_results SEASON=2025 \
  NAMES="Masters Tournament,U.S. Open,Charles Schwab Challenge,The Players Championship"
```

**Task behavior (to implement):**

1. `BallDontLie::SyncTournaments.new(season: SEASON).call`
2. Select `Tournament.where` season matches year from `starts_at` (or all with `external_id` from that sync).
3. Optional `NAMES` filter (normalized comma-separated, same matching as purse fallback).
4. Skip if `champion_golfer_id` present and `tournament_results` count > 0 and earnings look complete (idempotent).
5. Else `BallDontLie::SyncTournamentResults.new(tournament: t).call`
6. Log summary: synced / skipped / failed; sleep between tournaments for `RATE_LIMIT_DELAY`.

**Console equivalent (today, without new rake):**

```ruby
season = 2025
BallDontLie::SyncTournaments.new(season: season).call

names = [
  "Masters Tournament",
  "PGA Championship",
  "U.S. Open",
  "Open Championship",
  "the Memorial Tournament presented by Workday",
  "Charles Schwab Challenge",
  "THE PLAYERS Championship"
]

names.each do |name|
  t = Tournament.find_by("LOWER(name) = ?", name.downcase.strip)
  next puts "MISSING: #{name}" unless t
  next puts "SKIP (complete): #{name}" if t.champion_golfer_id.present? && t.tournament_results.where("prize_money > 0").exists?
  result = BallDontLie::SyncTournamentResults.new(tournament: t).call
  puts "#{name}: #{result.inspect}"
  sleep 1.2  # stay under ALL-STAR 60/min
end
```

### 7.2 API tier & rate limits

- `tournament_results` requires **ALL-STAR** (already used in production).
- Client sleeps ~1.1s between paginated requests; budget **~1 request per tournament** minimum (often more for full fields).
- Backfill **2025** once before **2026** majors/signatures go live; re-run single events if API corrections occur.

### 7.3 Validation after backfill

```ruby
# Example checks in rails console
t = Tournament.find_by("LOWER(name) LIKE ?", "%charles schwab%")
t.tournament_results.where("prize_money > 0").count  # expect ~65–70
t.champion_golfer_id.present?
t.effective_prize_pool.positive?

prior = Tournament.where("LOWER(name) = ?", t.name.downcase.strip)
  .where("starts_at < ?", t.starts_at).order(starts_at: :desc).first
# prior should exist for 2025 after backfill
```

### 7.4 Ongoing maintenance

- After each event completes in production, `SyncTournamentResults` already runs via `RefreshLiveResultsJob` — that **becomes next year’s empirical source** automatically.
- New renamed events: no prior year → static profile until one completion is stored.

---

## 8. Confidence & safety

- **Never** use bonus-only as projected total (removed permanently).
- Show `(projected)` on money columns and badges when `projection_enabled?`.
- If live `position` missing for a picked golfer, treat as unknown share (`—` for that golfer’s projected prize; do not guess from bonus).
- If `effective_prize_pool` is estimated (`prize_pool_known?` false), still allow projection but append “(estimated)” in footer next to purse disclosure (reuse `max_cut_made_bonus_label` pattern).
- Log resolver path (`empirical` / `static` / `hidden`) at debug level for support.

---

## 9. Testing strategy

| Layer | Cases |
|-------|--------|
| `PayoutCurve` | Tie at T5; MC → $0; position 1 vs 18 monotonicity |
| `PayoutCurveResolver` | Prior year present → empirical; missing → static; unlisted major → `us_open`; unknown → hidden |
| `PoolTournamentScoringDisplay` | Schwab-style: high prize rank beats high bonus rank when projected; hidden when no curve |
| Request | Footer copy; no `Counted` badge when hidden; projected badges when enabled |
| Backfill rake | Dry run; idempotent skip; one tournament mock |

**Fixture:** Matsuyama / Theegala-style four-golfer pick with positions and prior-year curve loaded.

---

## 10. Implementation sequencing (suggested)

1. ~~**Backfill rake** + run `SEASON=2025` in production~~ — done manually in prod; optional rake still useful for replays.
2. **Migration** — `payout_curve_source`, `payout_curve` (jsonb), `payout_curve_built_at` on `tournaments`.
3. **`PayoutCurveBuilder`** — build empirical JSON from prior-year `TournamentResult`; call after backfill / on season sync.
4. **`PgaPayoutProfiles`** static tables + **`PayoutCurveResolver`** (writes DB curve or `hidden`).
5. **`ProjectedPrizeMoney`** + wire **`PoolTournamentScoringDisplay`** (`projection_enabled?`, projected prize/total, Counted/Dropped).
6. **View** — grey projected prize + total, Projected badges/headers, footers.
7. **Tests** — resolver, builder, Matsuyama/Theegala request spec.

---

## 11. Locked product & technical decisions

| Topic | Decision |
|-------|----------|
| **Curve storage (Q1)** | **Yes — in Postgres** on `tournaments` (`payout_curve_source` + JSON `payout_curve`). Server-side persistence, not client/browser caching. Rebuild when prior-year results change. |
| **2024 fallback (Q2)** | **Out of scope for v1.** Use 2025 empirical → static profile → hidden. |
| **The Players (Q3)** | **Empirical** when 2025 `THE PLAYERS Championship` has paid results (confirmed in prod backfill). |
| **Live money columns (Q4)** | Show **both** projected Prize Money and projected Total Earnings while in progress, **greyed** + “Projected” indicator; final values at completion. |
| **Bonus-only projection** | Never. |
| **Prior-year matching** | Exact normalized `tournament.name` + prior calendar year (`starts_at`). |
| **Open Championship name** | `The Open Championship` (not `Open Championship`). |

---

## 12. References

- BallDontLie PGA OpenAPI: `https://www.balldontlie.io/openapi/pga.yml` (`PGATournamentResult.earnings`, `PGATournament.purse`)
- PGA standard distribution (regular / most signatures): e.g. [Golf News Net purse table](https://thegolfnewsnet.com/ryan_ballengee/2024/01/28/pga-tour-purse-payout-percentages-distribution-102486/)
- Signature tie table example: [Truist Championship](https://www.pgatour.com/article/news/latest/2025/05/05/purse-breakdown-prize-money-truist-championship-philadelphia-cricket-club-wissahickon-signature-event-fedexcup)
- U.S. Open payout shape: [2024 breakdown](https://www.sportingnews.com/us/golf/news/us-open-2024-purse-payout-prize-money-winner/914e346f08a46e607199e96f)

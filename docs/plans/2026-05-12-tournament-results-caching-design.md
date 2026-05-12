# Tournament Results Caching & Performance — Design Specification

**Status:** Approved design, ready for implementation planning.
**Project:** `long_shot` (single Rails app, one deploy).
**Date:** 2026-05-12

---

## 1. Purpose

The "View Results" page for a tournament inside a pool (`PoolTournamentsController#show`) currently takes **>10s for live tournaments** and re-pays a significant API cost even when viewing **completed tournaments** that haven't changed in months. This document captures the agreed design to fix both, by:

1. **Persisting round-by-round scores** in the DB so completed tournaments never need to call the API.
2. Replacing per-request API calls with a **per-tournament background refresh** for live data, debounced to ~30s, so users always read from local data and the API is called at most ~2/min per live tournament regardless of viewer count.
3. **Trimming the API client's overhead** (drop unnecessary pre-call sleep; fetch only the current round's scorecards).

Out of scope: changes to scoring rules, UI/UX of the results table, or the pool-listing page beyond what's necessary to read from the new data source.

---

## 2. Problem analysis (current state)

`PoolTournamentsController#show` does the following on **every request**, regardless of whether the tournament is in progress or completed:

1. Conditionally runs `BallDontLie::SyncTournamentResults` (paginated `tournament_results` API call) if `results_synced_since_completion?` is false or earnings look incomplete.
2. Runs `client.fetch_all_player_round_results(...)` — paginated `player_round_results` API call. This is the source of the R1–R4 score-to-par data.
3. If `tournament.started?`, runs `client.fetch_all_player_scorecards(...)` — paginated `player_scorecards` API call for **all rounds** (current code does not pass `round_number`).
4. Constructs a `PlayerRoundResultsFormatter` and merges scorecards into round results.

Two compounding cost issues in `BallDontLie::Client#fetch_all`:

- `sleep RATE_LIMIT_DELAY` (~1.1s) executes **before every page**, including the **first** — so even a one-page response pays ~1.1s of pure sleep before the HTTP call.
- For live data, the scorecards call fetches all 4 rounds when only the current round contains new information; the others were captured by `player_round_results` already.

Net result: a live load is typically two paginated chains × (sleep + network) = 5–15s. A completed-tournament load still pays a 2–4s `player_round_results` round-trip even though the underlying data hasn't changed since the event ended.

There is **no shared state** across pools or users — five pools viewing the same tournament cause five independent API fetches.

Per-round scores are **not persisted** today. Only `TournamentResult` (final position + prize money) is in the DB.

The app uses `solid_cache_store` and Solid Queue in production, so both a durable cache and a recurring/concurrent-limited job framework are already available.

---

## 3. Goals & non-goals

### Goals

- Completed-tournament page loads: **<100ms**, **no API calls**.
- Live-tournament page loads: **<100ms** when a snapshot exists; the request path never blocks on the BallDontLie API after the very first viewer.
- Live data freshness: **≤30s stale** under normal viewer activity.
- API usage scales with **user activity** (not page loads × pools × users), and stays comfortably under the **60 req/min ALL-STAR rate limit**.
- The view template's data contract (`@round_results`, `@current_round`, etc.) is preserved so the existing ERB does not change.

### Non-goals

- Real-time push updates (Turbo Streams / ActionCable). Page refresh is still required to see newer data.
- Backfilling historical completed tournaments via a one-shot rake task — backfill happens **lazily**, on first view.
- Replacing the BallDontLie API or changing what data we display.
- Changing scoring logic, Cut Made Bonus, or no-cut handling.

---

## 4. Strategy

### 4.1 Live tournaments — view-triggered debounced background refresh

When someone opens the View Results page for a live tournament:

1. The controller reads the latest **persisted snapshot** from the DB and renders immediately.
2. If `live_results_synced_at` is `nil` or older than **30 seconds**, the controller **enqueues** `RefreshLiveResultsJob(tournament_id)`. The page does not wait for it.
3. The job runs (Solid Queue), fetches from the API, upserts `tournament_round_results` rows, and updates `live_results_synced_at`. The **next** viewer sees fresh data.
4. Solid Queue concurrency limits prevent duplicate refreshes for the same tournament (`limits_concurrency to: 1, key: "tournament_<id>"`).

If there is **no snapshot at all** (first viewer ever for this tournament after the change ships, or first viewer of any tournament before any data has been synced), the controller falls back to a **synchronous** refresh for that one request, then renders. Every subsequent load is async.

### 4.2 Completed tournaments — DB-only, lazy backfill

- After completion, the persisted `tournament_round_results` rows become the permanent round-by-round source of truth. `TournamentResult` (final position + prize money) is already persisted.
- If a completed tournament has **no** persisted `tournament_round_results` (because it ended before this change shipped), the **first viewer** triggers a synchronous one-time sync. All viewers after that hit the DB only.
- We do **not** run any background refresh job for completed tournaments. They're frozen.

### 4.3 API client improvements (independent of caching)

These reduce per-call latency for both the background job and the synchronous-fallback path.

- In `BallDontLie::Client#fetch_all`: do **not** sleep before the first page. Sleep only between subsequent pages. Saves ~1.1s on every call.
- When the background job fetches live scorecards, pass `round_number: current_round` so the API returns only the in-progress round's hole-by-hole data. Completed rounds are already captured by `player_round_results`.

### 4.4 Tighten the synchronous `SyncTournamentResults` auto-call

The current controller auto-runs `SyncTournamentResults` whenever `results_synced_since_completion?` is false — which is true for **every tournament that doesn't yet have a champion**, including ones that haven't started. That's a stray API call on every page load.

After this change, the auto-call runs **only when the tournament has a champion but earnings are incomplete** (the rare, short-lived window between detecting the winner and the API populating prize money). For live tournaments, `RefreshLiveResultsJob` already calls `SyncTournamentResults` once it detects completion, so the controller doesn't need to do it inline.

---

## 5. Data model

### 5.1 New table: `tournament_round_results`

| Column | Type | Notes |
|---|---|---|
| `id` | bigint PK | |
| `tournament_id` | bigint FK → `tournaments` | not null |
| `golfer_id` | bigint FK → `golfers` | not null |
| `round_number` | integer | 1..4, not null |
| `score_to_par` | integer | nullable (round hasn't started or no data) |
| `last_hole_completed` | integer | nullable; 1..18; `18` (or full hole count) sentinel for "F" |
| `created_at`, `updated_at` | datetime | |

Indexes:

- Unique: `(tournament_id, golfer_id, round_number)`
- For aggregate reads on the page: an index on `(tournament_id, golfer_id)` is implied by the unique index prefix.

This shape mirrors the data the `PlayerRoundResultsFormatter` produces today (`score_to_par`, `last_hole_completed`), so the controller can rebuild the same `@round_results` hash from these rows trivially. `par_relative` ("E"/"+3"/"-2") is **computed on read** from `score_to_par` to avoid duplication.

Bulk-write style: upserts keyed on `(tournament_id, golfer_id, round_number)`.

### 5.2 New column on `tournaments`

- `live_results_synced_at :datetime` — last successful live refresh timestamp.

We intentionally do **not** reuse `results_synced_at`. That column reflects the most recent **official** `tournament_results` (final positions/earnings) sync. Live snapshot freshness is a separate concept; mixing them would couple the two cadences and obscure when to enqueue refreshes.

---

## 6. Components

### 6.1 `TournamentRoundResult` model
- `belongs_to :tournament`, `belongs_to :golfer`
- Validations: `round_number` in 1..4; uniqueness scoped to `tournament_id, golfer_id`.
- Helper: `par_relative` — formats `score_to_par` as `"E" | "+N" | "-N" | nil`.

### 6.2 `BallDontLie::SyncRoundResults` service

(Named symmetrically with the existing `BallDontLie::SyncTournamentResults`, which syncs final positions + earnings into `tournament_results`. This one syncs per-round score-to-par into `tournament_round_results`. It's used both by the background job for live tournaments and by the synchronous cold-start fallback for completed tournaments.)

A thin orchestration service. Takes a `Tournament`, fetches:
- `player_round_results` for that tournament across the golfers we care about (the union of all picked golfers for any pool linked to the tournament, plus — for completed no-cut events — the persisted field).
- `player_scorecards` only for the current round, only if the tournament is live.

Then:
- Uses the existing `PlayerRoundResultsFormatter` logic (still useful for merging scorecard hole-by-hole rows into per-round totals).
- Upserts `TournamentRoundResult` rows.
- Sets `tournament.live_results_synced_at = Time.current`.

Idempotent and safe to call from a job or synchronously.

### 6.3 `RefreshLiveResultsJob`
- Thin wrapper around `BallDontLie::SyncRoundResults`.
- Solid Queue concurrency: `limits_concurrency to: 1, key: ->(args) { "tournament_#{args.first}" }`.
- If, after the sync, the tournament's API state indicates final results, also runs `BallDontLie::SyncTournamentResults` so champion / earnings get populated promptly.
- On error: retries with Solid Queue's default backoff. `live_results_synced_at` is **not** updated on failure, so the next viewer will re-enqueue.

### 6.4 `PoolTournamentsController#show` (rewritten request path)

Pseudocode:

```ruby
# Load persisted state
results_by_golfer = TournamentResult.where(tournament: @tournament, golfer_id: golfer_ids).index_by(&:golfer_id)
round_rows       = TournamentRoundResult.where(tournament: @tournament, golfer_id: golfer_ids)

# Cold-start fallback (no snapshot yet for relevant golfers)
if round_rows.empty? && @tournament.external_id.present? && (@tournament.started? || @tournament.completed?)
  BallDontLie::SyncRoundResults.new(tournament: @tournament).call
  round_rows = TournamentRoundResult.where(tournament: @tournament, golfer_id: golfer_ids)
end

@round_results  = build_round_results_hash(round_rows)   # matches today's shape
@current_round  = round_rows.maximum(:round_number)

# Async refresh for live tournaments with stale snapshot
if @tournament.started? && !@tournament.completed?
  stale = @tournament.live_results_synced_at.nil? || @tournament.live_results_synced_at < 30.seconds.ago
  RefreshLiveResultsJob.perform_later(@tournament.id) if stale
end

# Auto-sync final results only when the tournament looks completed but data is missing.
# (Was: ran for every non-completed tournament on every page load — wasted ~1 API call/load.)
# For live tournaments, RefreshLiveResultsJob handles SyncTournamentResults itself when the
# tournament transitions to completed.
if @tournament.external_id.present? && @tournament.completed? && @tournament.tournament_results_earnings_incomplete?
  BallDontLie::SyncTournamentResults.new(tournament: @tournament).call rescue log_and_continue
end
```

The view template (`app/views/pool_tournaments/show.html.erb`) is **not** modified — it still consumes `@round_results`, `@current_round`, `@golfer_prize_money`, `@golfer_bonus_display`, `@synthetic_cut_marginal_total_to_par`. The data shape is preserved.

### 6.5 `BallDontLie::Client` changes
- `fetch_all`: skip the leading `sleep` on the first iteration only.
- No new endpoints; existing `player_scorecards` already accepts `round_number`.

---

## 7. Data flow per scenario

| Scenario | DB reads | API calls | Job enqueued | Latency |
|---|---|---|---|---|
| Not started | TR (empty), TRR (empty) | none | no | <100ms |
| Live, fresh snapshot (≤30s) | TR, TRR | none | no | <100ms |
| Live, stale snapshot (>30s) | TR, TRR | none (in request) | yes | <100ms |
| Live, no snapshot yet | TR, TRR (empty) → sync → TR, TRR | yes (synchronous fallback, once) | no | 2–5s once, then <100ms |
| Completed, persisted | TR, TRR | none | no | <100ms |
| Completed, no TRR (lazy backfill) | TR, TRR (empty) → sync → TR, TRR | yes (synchronous fallback, once) | no | 2–5s once, then <100ms |

`TR` = `TournamentResult`; `TRR` = `TournamentRoundResult`.

---

## 8. Rate-limit analysis

ALL-STAR tier: **60 req/min**.

Per-tournament refresh cost = `player_round_results` pages (~1–2) + `player_scorecards` current-round pages (~1–2) ≈ **2–5 API requests** per refresh.

At a 30-second debounce and 4 simultaneous live PGA events: `2 × 4 × 5 = ~40 req/min` peak (worst case, all events constantly being viewed). Normal usage is well below that.

The existing 429 retry-with-backoff in `BallDontLie::Client#get` remains a safety net.

---

## 9. Error handling

- **Background job failure** (API down, 429s exceeding retries, transient bugs): `live_results_synced_at` is not updated → next viewer re-enqueues. Solid Queue retries with backoff. Last good snapshot continues to render.
- **Synchronous fallback failure** (cold start): re-raise via `rescue` to logging; render the page with empty `@round_results`. The existing "Live scores are temporarily unavailable" banner in the view template covers this case (preserved as-is).
- **`SyncTournamentResults` failure**: matches today's behavior (logged, swallowed, render continues).
- **Concurrent refresh enqueues**: prevented by Solid Queue concurrency limit per `tournament_<id>` key.

---

## 10. Testing strategy

Unit tests:
- `BallDontLie::SyncRoundResults`: with a mocked client, asserts upsert of `tournament_round_results` rows for new+existing rounds; asserts `live_results_synced_at` is updated; asserts current-round-only scorecard request.
- `BallDontLie::Client#fetch_all`: asserts no leading sleep before page 1; asserts sleep between subsequent pages.

Job test:
- `RefreshLiveResultsJob`: invokes `SyncRoundResults`; respects Solid Queue concurrency key; runs `SyncTournamentResults` when champion/final state is reached.

Controller / request tests for `PoolTournamentsController#show`:
- Completed tournament with persisted TRR: no API calls; renders.
- Live tournament with fresh snapshot: no API calls, no job enqueued.
- Live tournament with stale snapshot: no API calls in request path; job is enqueued.
- Live tournament with no snapshot: synchronous fallback runs once; renders.
- Completed tournament with no persisted TRR (lazy backfill): synchronous fallback runs once; subsequent loads are DB-only.

Light integration test confirming the view template still renders against the new data path (snapshot built from TRR rows).

---

## 11. Rollout

1. Schema migration: add `tournament_round_results` table; add `tournaments.live_results_synced_at`.
2. Add model, service, and job.
3. Cut over `PoolTournamentsController#show` to read from DB + use synchronous fallback + enqueue background refresh.
4. Client tweaks (`fetch_all` sleep, `round_number` for live scorecards).
5. Deploy. First viewer of each live or already-completed tournament pays a one-time sync; thereafter everything is fast.

No data migration is required; the lazy backfill model handles already-completed tournaments and any active tournaments at deploy time.

---

## 12. Open questions / future work

- **Real-time updates** during live tournaments via Turbo Streams could be layered on top of this design later (the snapshot in DB is already shared state, so broadcasting on `RefreshLiveResultsJob` completion is straightforward).
- **Optional UI affordance**: showing "Last updated 12s ago" near the live indicator. Easy follow-up using `live_results_synced_at`.
- **Pruning**: `tournament_round_results` grows unbounded. Not a real concern at current scale (a few rows per golfer per tournament, dozens of tournaments per year), but worth tracking.

---

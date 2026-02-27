# Golf Pool Pool Features Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement pool behaviors so that tournaments auto-sync fields on add, only eligible tournaments can be added, picks are visible and lock correctly around tournament start, duplicate golfers are disallowed, and the existing dashboard views remain consistent.

**Architecture:** Build on existing `Pool`, `PoolTournament`, `Pick`, and sync services. Use a lightweight background job for tournament field sync, enforce constraints at both UI and model levels, and reuse `pool_picks#index` as the primary “pool dashboard” surface.

**Tech Stack:** Ruby on Rails app (controllers, models, ERB views), BALLDONTLIE PGA API client.

---

### Task 1: Auto-sync tournament field when adding to pool

**Files:**
- Modify: `app/models/pool_tournament.rb`
- Create: `app/jobs/sync_tournament_field_job.rb` (or similar)

**Steps:**
1. Add an `after_create_commit` callback to `PoolTournament` that enqueues a background job with the tournament id.
2. Create an `ApplicationJob` subclass (e.g. `SyncTournamentFieldJob`) that calls `BallDontLie::SyncTournamentField.new(tournament: tournament).call`.
3. Handle and log errors in the job (but don’t block pool creation).

### Task 2: Restrict added tournaments to not-yet-completed

**Files:**
- Modify: `app/models/pool_tournament.rb`
- Modify: `app/views/pools/show.html.erb`

**Steps:**
1. Add a validation on `PoolTournament` to prevent linking tournaments that are completed (based on `status` and/or dates on `Tournament`).
2. Update the tournament select on the pool show page so it only offers tournaments that are not completed and not already in the pool.
3. Ensure an appropriate validation error surfaces to the user if they somehow attempt to add an ineligible tournament.

### Task 3: Show picks clearly after save (My picks view)

**Files:**
- Modify: `app/controllers/picks_controller.rb`
- Modify: `app/views/picks/index.html.erb`

**Steps:**
1. Confirm `PicksController#index` loads `@standings` and `@tournaments` for the pool.
2. Keep the existing standings list, but ensure the tournaments list clearly shows the current user’s picks (already mostly implemented).
3. Make small UX tweaks if needed so that, after saving picks, redirecting to `pool_picks_path(@pool)` gives a clear view of “my picks per tournament”.

### Task 4: Lock picks once tournament starts, with a pre-check

**Files:**
- Modify: `app/controllers/picks_controller.rb`
- Optionally modify: `app/services/ball_dont_lie/sync_tournaments.rb` or introduce a small service helper

**Steps:**
1. Add a private helper on `PicksController` to determine whether a tournament is locked (e.g. `locked?` when `starts_at <= Time.current` or status indicates started/completed).
2. Add a `before_action` for `new`, `create`, `edit`, and `update` that:
   - Ensures the tournament record is up-to-date (initially, use local data; later, can plug in a lightweight API refresh).
   - If locked, redirect back to `pool_picks_path(@pool)` with a clear alert that picks are locked because the tournament has started.
3. Verify that users can still view existing picks from the dashboard even when they can no longer edit them.

### Task 5: Prevent duplicate golfers in a pick

**Files:**
- Modify: `app/models/pick.rb`
- Modify: `app/controllers/picks_controller.rb`
- Modify: `app/views/picks/new.html.erb`
- Modify: `app/views/picks/edit.html.erb`

**Steps:**
1. Add a custom validation on `Pick` that checks `pick_golfers` for duplicate `golfer_id`s (ignoring blanks and destroyed records) and adds a user-friendly error if duplicates are present.
2. In `PicksController#create` and `update`, when `@pick.save` fails, set a `flash.now[:alert]` message to highlight the duplicate-golfer issue if present.
3. Ensure the new/edit pick forms render model errors in a visible place so users can correct their selections.

### Task 6: (Future) Odds snapshot and scoring bonus

**Files (future work):**
- New model and migration: e.g. `PoolTournamentOdds`
- New job: e.g. `LockOddsJob`
- Modifications to `Pool#standings` and `Pick#total_prize_money` or a new `Pick#score`

**Outline:**
1. Introduce a `pool_tournament_odds` table keyed by `pool_tournament_id` and `golfer_id`, storing `american_odds`, `vendor`, and `locked_at`.
2. For each `PoolTournament`, schedule a job at `tournament.starts_at - 15.minutes` that calls the PGA futures endpoint and populates this table.
3. Replace or augment `total_prize_money` in the standings calculation to include an odds-based bonus derived from the locked `american_odds`.


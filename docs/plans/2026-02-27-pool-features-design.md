# Golf Pool Pool Features Design

**Goal:** Make pools fully operable: auto-manage tournament fields, constrain eligible tournaments, let users see and manage their picks with proper locking, and surface a simple dashboard/standings.

**Key behaviors:**
- Auto-sync a tournament’s field when it’s added to a pool (no manual “sync field” button required in the pool flow).
- Only allow not-yet-completed tournaments to be added to a pool.
- Let each user see and edit their picks per tournament, and view them from a “My picks”/pool dashboard page.
- Lock picks once a tournament starts; before showing the pick form, ensure our local tournament data is refreshed from the API.
- Provide a pool dashboard that shows tournaments in the pool and per-user totals.
- Prevent selecting the same golfer multiple times in a single tournament pick.

**Architecture (current vs new):**
- Current:
  - `Pool` ↔ `PoolTournament` ↔ `Tournament`
  - `Pool` ↔ `PoolUser` ↔ `User`
  - `Pick` belongs to `user` and `tournament`, and has many `pick_golfers` (5 slots) pointing to `Golfer`.
  - `Pool#standings` uses `Pick#total_prize_money` (sum of `TournamentResult.prize_money`) for dashboard-like output on the pool show page.
  - Sync services under `BallDontLie::Sync*` handle tournaments, players, tournament field, and tournament results.
- New:
  - Extend `PoolTournament` so that creating a record automatically triggers a background job to sync the tournament field (GOAT tier endpoint).
  - Add domain rules:
    - Prevent adding completed tournaments (UI filter + model-level validation).
    - Allow pick creation/update only when the tournament has not started (based on `starts_at` / status).
  - Treat `pool_picks#index` as the “pool dashboard”:
    - Show standings (per-user total prize money / score).
    - Show tournaments in the pool and, for each tournament, the current user’s picks or a link to make picks.
  - Add a model-level validation on `Pick` to disallow duplicate golfers per pick.

**Scoring direction:**
- Initial implementation keeps scoring as “sum of prize money” via `Pool#standings` and `Pick#total_prize_money`.
- Next step (planned but not yet implemented here) is to introduce an odds snapshot table per `(pool_tournament, golfer)` using PGA futures:
  - Schedule a job for each `PoolTournament` at `tournament.starts_at - 15.minutes` to snapshot `american_odds` from the futures endpoint.
  - Compute score per pick as `prize_money + odds_bonus(american_odds)` from that snapshot, so all users share the same locked odds.

**Testing strategy (high level, even without a test suite):**
- Exercise flows manually:
  - Add tournament to pool → confirm field sync job enqueued and golfers list populated (or at least available).
  - Attempt to add a completed tournament → ensure the request fails with a clear error.
  - Create/edit picks before tournament start → success; after start → redirected with an explanatory message.
  - Try to pick the same golfer twice → see validation error and can fix selections.
  - View pool page and `My picks` page to verify standings and picks display.


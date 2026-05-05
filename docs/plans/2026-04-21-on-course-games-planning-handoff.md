# On-Course Games Planning Handoff

Date: 2026-04-21  
Project: `long_shot` (single Rails app, extend existing hosting/deploy setup)

## Why this doc exists

This is a restart-friendly summary of what has been decided so far for the new on-course games product area, what is still open, and what to do first when work resumes.

## Current direction (confirmed)

- Keep one app/deploy (`long_shot`) and add a separate on-course domain, rather than creating a second app.
- Keep the existing hosting stack (Render + existing PostgreSQL + Green Geeks DNS); this is viable for v1.
- Position two top-level product areas in navigation:
  - `Pools` (existing PGA pools)
  - `On-Course` (new event-based games)
- Use a generic top-level model name: `Event` (not trip/pool terminology).
- Users can belong to multiple events.
- Roles in v1: two-role model only:
  - `commissioner`
  - `player`
- Multiple commissioners per event are required from day 1 (no separate co-commissioner role yet).
- Event join flow should use tokenized invite links, similar to the current pool mechanism.
- Handicap entry in v1 is manual/honor system:
  - each user manages their own GHIN handicap index on profile.
- First game to ship:
  - `Best Ball` only (team net stroke play using best 1 net ball per hole).
- Team sizing should be rule-driven by game type, not globally fixed.
  - For Best Ball: team size 1-4, and up to 10 teams (subject to participant count).
- `Best 2` is planned as a follow-up game type after Best Ball is live.

## Hosting and platform viability notes

- Existing Render setup supports this approach without architecture changes:
  - single web service Rails app
  - existing PostgreSQL
  - env-var based configuration
- Existing domain/subdomain setup remains compatible.
- No hard blocker identified for expected v1 usage (small private groups, e.g. ~12 golfers).

## Data/API notes decided so far

- Course data source target: `golfcourseapi.com`.
- API key should be stored in environment variables (server-side only), never hardcoded.
- Rounds should snapshot critical course/tee fields used in handicap calculation (slope/rating/par) to preserve historical scoring integrity if source data changes later.

## Open design items (next conversation)

These still need explicit confirmation before implementation:

1. **Score-entry permissions**
   - player enters own hole scores vs commissioner enters for everyone vs event-level toggle.
2. **Round/game lock behavior**
   - when edits become immutable (setup lock, per-hole lock, finalization rules).
3. **Handicap formula details**
   - exact course handicap formula/rounding conventions to apply.
4. **Tie handling**
   - tie display and ranking behavior for Best Ball.
5. **Live updates**
   - manual refresh only for v1 or lightweight auto-refresh cadence.
6. **Event lifecycle**
   - draft/active/completed states and transition permissions.

## Proposed initial model outline (working draft)

This is a draft structure discussed and pending final sign-off:

- `Event`
- `EventMembership` (`role: commissioner|player`)
- `Round` (with course/tee snapshot fields)
- `Game` (`game_type: best_ball` initially)
- `GameTeam`
- `GameTeamPlayer` (store snapshot course handicap at lock/finalize)
- player hole-level score records for gross input, with net and team totals derived
- `User` enhancement: `ghin_handicap_index`

## Security note

An external API key for `golfcourseapi.com` was shared in chat. Treat it as sensitive and rotate/regenerate as needed. Going forward, store it in Render environment variables only (e.g., `GOLF_COURSE_API_KEY`).

## Recommended first steps tomorrow

1. Finalize the remaining open design items above.
2. Write the full design spec doc for this feature set under `docs/plans/`.
3. Break implementation into phases:
   - Phase 1: event shell + memberships + invite links + profile handicap field
   - Phase 2: round creation + golfcourseapi integration + tee/course snapshot
   - Phase 3: Best Ball setup, team assignment, score entry, leaderboard
   - Phase 4: hardening/tests/polish
4. Start implementation with migrations and permission guardrails first.

## Resume prompt suggestion

When resuming, start with:

"Continue from `docs/plans/2026-04-21-on-course-games-planning-handoff.md` and help me finalize the remaining design decisions, then produce the implementation plan."

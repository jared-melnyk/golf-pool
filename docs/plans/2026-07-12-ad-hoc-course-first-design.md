# Ad hoc games — course-first, no draft

**Date:** 2026-07-12  
**Status:** Approved for implementation  
**Related:** `docs/plans/2026-07-12-trip-rounds-nest-games-design.md`

## Goal

Ad hoc (non-trip) games skip draft and naming friction. Course search is the hard part — put it first; create an active game in one shot.

## Flow

1. **New game** (`/games/new`): date + course/tee search + format (no name field)
2. **Create**: Round (`event_id` null) + active Game with auto name `{Format} · {Course} · {Mon D}` + host membership
3. Redirect to invite setup (then teams), same as trip games after create

Bail mid-form = nothing saved.

## Non-goals

- Changing trip round-nested create
- Migrating existing draft ad hoc games
- Keeping multi-step course→format wizard for new ad hoc creates (legacy drafts may still hit setup if they exist)

# Mobile scorecard CTA + game member scoring

**Date:** 2026-07-14  
**Status:** Approved for planning  
**Context:** Michigan trip Jul 16–17. On-course testers mistook the black **Finalize scores** button for “submit this hole,” which exited the scorecard and forced a return to the next hole.

## Problem

On the mobile hole-by-hole scorecard, the strongest CTA is **Finalize scores** at the bottom of the page. During play, the primary job is enter scores → advance hole. Finalize locks the whole round and should not compete with that flow.

Separately:

1. Manager chrome (**Invite players**, **Edit teams**, **Delete game**) sits above the scorecard and pushes scoring down. **Invite** is a filled emerald button — the wrong primary CTA once a game is in progress.
2. Scoring and lock/unlock are gated to teammates / managers. In practice one person often keeps score for a whole foursome (including 2v2), so any game member should be able to score any team and lock/unlock.

## Goals

1. Make **Next hole** the primary mobile CTA while playing; expose **Lock scorecard** only on hole 18.
2. Remove competing mid-round finalize UI from the mobile scoring path.
3. Simplify permissions: any game member can score any team and lock/reopen that game.
4. Move manager admin actions below the scorecard once the game is active/completed; demote Invite to outline.

## Non-goals

- Nine-hole rounds or dynamic hole counts.
- Moving hole nav to a sticky footer.
- Changing who can invite / edit teams / delete (still managers only).
- Changing draft → active transition (still happens when setup finishes).
- Redesigning desktop full-table scorecards beyond lock visibility for members.

## Design

### 1. Mobile hole navigation (`games/mobile/_arena`)

**Remove** the 1–18 hole chip row (jumping holes is rare; back/next is enough).

**Header:**

| Control | Holes 1–17 (active) | Hole 18 (active) | Hole 18 (completed) |
|---------|---------------------|------------------|---------------------|
| Back | Outline; previous hole | Outline; previous hole | Outline; previous hole |
| Title | `Hole N` (no “of 18”) | `Hole 18` | `Hole 18` |
| Forward | Filled primary **Next** (or labeled Next); advances stepper | Filled **Lock scorecard**; confirm + `complete` | **Reopen scorecard**; confirm + `reopen` |

- Keep nav at the top (no scroll required).
- Remove the always-visible finalize card from the mobile path (do not render `scorecard_lock` under the mobile arena in a way that mid-round players hit it while scoring). Desktop keeps a quiet lock/reopen under the full table for any member so locking isn’t mobile-only.

**Copy:** Prefer **Lock scorecard** / **Reopen scorecard** over “Finalize scores” so it does not sound like submitting the current hole.

### 2. Permissions

While the game is **active** and the user is a **game member**:

- Enter/edit gross scores (and related controls, e.g. 40 Score picks) for **any** team on that game.
- **Lock** (`complete`) and **reopen** the scorecard.

When the game is **completed**, scores remain read-only until reopened (unchanged).

**Still managers only:** Invite, Edit teams, Delete game, Continue setup, and other setup/admin actions.

**Implementation targets:**

- Helpers: `scorecard_can_edit?`, `scorecard_can_edit_gross?` (and forty-pick helper) → member of game + not completed (drop teammate-only / manager override specialization for scoring).
- `HoleScoresController` auth → any game member (not only teammate/manager).
- `GamesController#complete` / `#reopen` → drop `require_game_manager!`; require game membership / existing game access.
- UI: show lock/reopen to members, not only `can_manage?`.
- Update request specs that assert manager-only finalize or own-team-only scoring.

### 3. Manager chrome on game show

| Status | Placement | Invite style |
|--------|-----------|--------------|
| `draft` | Top (current) | Filled emerald OK (setup is the job; with Continue setup) |
| `active` or `completed` | **Bottom** (after scorecard, before back-to-event/games link) | Outline (same weight as Edit teams) |

No new “started” flag — use existing `draft?` / `active?` / `completed?`.

Managers can still invite, edit teams, and delete from the bottom after the game is active.

### 4. Status reminder (no new UI)

| Status | How it happens |
|--------|----------------|
| `draft` | New game / unfinished setup |
| `active` | Finishing game setup (pick format) |
| `completed` | Lock scorecard |
| back to `active` | Reopen scorecard |

## Testing

- Mobile arena: chips gone; title is `Hole N`; Next filled on 1–17; Lock on 18 when active; Reopen on 18 when completed.
- Member (non-manager) can POST scores for another team and complete/reopen.
- Non-member still cannot.
- Manager-only actions remain gated.
- Active/completed show: admin row at bottom; Invite outline.
- Draft show: admin row at top unchanged.
- Existing turbo confirm on lock/reopen preserved.

## Out of scope follow-ups

- Sticky bottom nav / thumb-zone Next.
- Hiding admin links behind a “Manage” disclosure.
- Auto-advance to next hole after all scores entered on the current hole.

# Game-only guest players

**Date:** 2026-07-12  
**Status:** Approved for planning

## Problem

A signed-in host wants to set up a quick game and add other players by name (e.g. Jon, Stu, Kathy) without those people registering or signing in. Today every roster participant must be a `User`, and team assignment is checkboxes over registered roster users only.

## What already exists

- **Ad-hoc games:** `Game` with `event_id: null`; host gets `GameMembership`; others join via invite link after signing in.
- **Trip games:** roster pool is `event.users`; commissioners assign teams via Edit teams.
- **Set up teams:** `edit_teams` / `update_teams` — destroy/recreate teams, attach selected `user_ids` from `Game#roster_users`. Unchecked people sit out.
- **Scoring:** `HoleScore` → `GameTeamPlayer` → `User`; HI snapshotted onto `GameTeamPlayer` at create.
- **History:** `Game.visible_to` includes games via membership, event membership, or team player `user_id`. Ad-hoc hosts already retain access via host membership.

## Goals

1. Managers can add **game-only guests** by **name + required handicap index** (no default; host must enter an index).
2. **Same UI** for ad-hoc and trip/event games: pick from the existing registered roster **or** add a guest.
3. Guests can be assigned to teams, scored, and shown on scorecards like registered players.
4. Guests are scoped to a single game (not reusable across games, not event members).

## Non-goals

- Friends graph or browsing all users in the DB.
- Add registered user by email.
- Claiming a guest into a real account later.
- Guest authentication or guest game history.
- Putting guests on `EventMembership` / trip roster.
- Fake `User` records for guests.

## Decisions (locked)

| Topic | Decision |
|-------|----------|
| Lifetime | Game-only `GameGuest`; destroyed with the game |
| Handicap | Required on create; no pre-filled default |
| Association | Dual FKs on `GameTeamPlayer`: `user_id` **or** `game_guest_id` (XOR), not Rails polymorphic |
| Where to add | Set up teams page — same for all game types |
| Registered roster | Unchanged: ad-hoc = game members; trip = event members |
| Invite link | Unchanged for people who do register |
| History for host | Unchanged — host membership already covers it |
| Who can manage guests | Same as teams today: `Game#can_manage?` |

## Design

### Data model

**`game_guests`**

| Column | Notes |
|--------|--------|
| `game_id` | required, FK, cascade destroy with game |
| `name` | required |
| `handicap_index` | required, decimal (same spirit as user GHIN HI) |
| timestamps | |

**`game_team_players` changes**

- `user_id` becomes nullable.
- Add nullable `game_guest_id` (FK to `game_guests`).
- Validation: exactly one of `user_id` / `game_guest_id`.
- Uniqueness: one user per team; one guest per team; a given guest appears on at most one team in the game.
- `before_create` snapshot: `user.ghin_handicap_index` or `guest.handicap_index`.

**Helpers**

- `GameTeamPlayer#display_name` → user or guest name.
- Scorecard / views that assume `gtp.user` use `display_name` and existing `snapshot_handicap_index`.

### UI / flow (Set up teams)

1. **Roster checkboxes** under each team list `roster_users` plus this game’s `game_guests`. Show name and HI; mark guests lightly (e.g. “Guest”).
2. **Add guest** — separate form on the same page (name + HI required). Creates `GameGuest`, redirects/reloads so the guest appears in checkbox lists. Does not run full `update_teams` (avoids wiping in-progress team edits).
3. **Save teams** — extend `update_teams` to accept `guest_ids` alongside `user_ids`. Unchecked guests remain on the game roster but sit out (same as unchecked members).
4. **Remove guest** — manager-only. If assigned to a team, remove from team(s) then destroy the guest.
5. **Scoring** — managers enter scores for guest `GameTeamPlayer`s like any other player; no login required for the guest.

### Permissions & history

- No change to `Game.visible_to` for registered users.
- Guests never authenticate and do not appear in anyone’s “my games” as actors.
- Ad-hoc creator continues to see results via existing host `GameMembership`.

### Errors

- Blank name or HI → validation errors on add-guest form.
- Invalid team sizes → existing forty-score / cha-cha-cha / vegas enforcements after save.
- Guest delete while assigned → detach from teams, then destroy.

## Testing (acceptance)

1. Ad-hoc host can add guests with name + HI and assign them to teams; scorecard shows guest names.
2. Trip commissioner can do the same on an event-linked game; event members still appear in the picker.
3. Add guest rejects missing HI.
4. Saving teams with a mix of users and guests works; unchecked guests sit out and remain available.
5. Removing a guest cleans team assignment and removes them from the roster.
6. Host still sees the completed ad-hoc game in game history with only guests on the other team slots.

## Implementation notes

- Follow existing Edit teams patterns (Tailwind form controls, manager `before_action`s).
- Prefer dual FKs + XOR validation over polymorphic `player`.
- Touch scorecard services/views only where they dereference `gtp.user` for name/display.

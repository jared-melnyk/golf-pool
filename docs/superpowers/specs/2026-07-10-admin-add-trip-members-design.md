# Admin add trip members

**Date:** 2026-07-10  
**Status:** Approved for planning

## Problem

Before a golf trip, an admin needs to put existing users onto a trip (event) without relying on each person clicking the invite link. Once someone is on the trip, commissioners already assign them to game teams via Edit teams.

## What already exists

- **Join via invite link:** `POST /events/:token/join` creates an `EventMembership` with role `player`.
- **Commissioner member management (public trip page):** promote player → commissioner; remove players; members can leave. Commissioners cannot remove other commissioners; the last commissioner cannot leave until another is promoted.
- **Game team roster for trip games:** `Game#roster_users` returns `event.users`. Commissioners (`Game#can_manage?`) use Edit teams to assign any trip member to teams. No separate “add to game” step is required for event-linked games.

## Goals

1. Admins can add any user in the database to a given trip as a **player**.
2. Keep “add anyone in the DB” off the public trip page (safer; invite-link join remains the non-admin path).
3. Do not change commissioner game-team setup (already sufficient).

## Non-goals

- Admin remove from trip (commissioners / self-leave already cover this).
- Choosing role on add (always `player`; promote later on the trip page).
- Bulk add or search-as-you-type (single select is enough for current scale).
- Changing invite-link join or public trip membership UI.
- Ad-hoc (non-event) game membership flows.

## Design

### Approach

Admin → Events area: list events, open one, add non-members one at a time via a dropdown.

### Routes

Under `namespace :admin`:

| Method | Path | Action |
|--------|------|--------|
| GET | `/admin/events` | Index all events |
| GET | `/admin/events/:token` | Show event + members + add form |
| POST | `/admin/events/:event_token/event_memberships` | Create membership |

Use event `token` as the param (same as public events), not numeric id.

### Controllers

- `Admin::EventsController` — `index`, `show`; `before_action :require_admin`.
- `Admin::EventMembershipsController` — `create`; `before_action :require_admin`.
  - Load event by `params[:event_token]`.
  - Load user by permitted `user_id`.
  - Create `EventMembership` with `role: "player"` (ignore any client-supplied role).
  - Redirect to admin event show with notice or alert.

### Authorization

Same pattern as `Admin::UsersController` / `Admin::GamesController`: `require_admin`. Non-admins are redirected away.

### UI

- Sidebar Admin section: add **Events** link next to Games / Users.
- **Index:** table consistent with Admin Users (event name, status, member count, link to manage).
- **Show:**
  - Read-only member list (name, role).
  - Form: `<select>` of users not already on the event, `User.order(:name)`, option text like `"Name (email)"`.
  - Submit: **Add**.
  - If no candidates: message “All users are already on this trip” (no empty submit).

### Data / validation

- Reuse `EventMembership` model (`role` in `commissioner` \| `player`; uniqueness on `[event_id, user_id]`).
- On duplicate or missing user: redirect with alert; do not raise uncaught.
- Success notice includes the added user’s name.

### Error handling

| Case | Behavior |
|------|----------|
| Non-admin | Blocked by `require_admin` |
| Unknown event token | 404 |
| Blank / unknown `user_id` | Alert, stay on show |
| User already a member | Alert (friendly), no duplicate row |
| Success | Notice, member listed, dropdown excludes them |

### Testing

Request specs covering:

1. Admin can list events and view show.
2. Admin can add a non-member; membership role is `player`.
3. Non-admin cannot access index/show/create.
4. Adding an existing member fails gracefully.
5. Create ignores attempted non-player role from params (always `player`).

## Out of scope follow-ups (optional later)

- Bulk multi-select add.
- Typeahead search for large user lists.
- Admin remove (if needed when no commissioner is available).

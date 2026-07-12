# Trip rounds nest games (hard round-first)

**Date:** 2026-07-12  
**Status:** Approved for planning

## Problem

On a trip (Event) page, Rounds and Games appear as two flat lists. A Game already belongs to a Round via `games.round_id`, and the setup wizard already has a round picker — but after setup the parent/child relationship is easy to miss (trip Games list shows only a date; Rounds list shows no games).

Commissioners also have to invent names for rounds, games, and teams. That friction is unnecessary when course/date/format already define identity.

Real-world trip usage (e.g. Michigan 2026): one session at a course = **one Round**; each foursome = **one Game** sharing that Round (e.g. 1 Round + 3 Best Ball games).

## What already exists

| Concept | Meaning | Relationship |
|---------|---------|--------------|
| **Event** (Trip in UX) | Multi-round outing | `has_many :rounds`, `has_many :games` |
| **Round** | Where/when — course, tee, date, hole pars/handicaps | `belongs_to :event` (optional); `has_many :games` |
| **Game** | Format + scorecard (typically one foursome) | `belongs_to :event` (optional); `belongs_to :round` (optional until active) |

- Active games must have `round_id` and `game_type`.
- Setup wizard steps: `course` → `format` → `invite`. `next_step` already skips `course` when `@game.round.present?`.
- Event game create today: name only → draft with `event_id`, no `round_id` → wizard course step (pick existing event round or create new round).
- Ad hoc games: `event_id` null; course step creates a round with `event_id` null.
- Round delete is blocked if any games reference it.
- `Game#suggested_name` builds `{Format} · {course} · {date}` after round + format exist (not used as default at create for trip games today).

## Goals

1. On the trip page, **Round is the parent** and **Game is the child** — visually and in the create entrypoint.
2. **Add game** lives on a specific round (round is known at create; no trip-level Create game).
3. Trip game setup **skips the course/round step** when `round_id` is already set.
4. Reduce naming friction with sensible defaults for rounds, games, and teams.
5. Leave ad hoc (On-Course **New game**) working as a separate non-trip flow.

## Non-goals

- Schema changes (keep nullable `event_id` / `round_id` as-is).
- Ad hoc UX overhaul beyond light naming defaults if convenient.
- Auto-syncing game name from team names.
- Animal / fun team-name library.
- Event leaderboard implementation.
- Automatic rename/migration of existing trip data.
- “Change round” or “create new round” inside trip game setup (hard round-first).

## Design

### Approach

**Hard round-first for trips:** commissioners create rounds on the trip, then add games to a round. Ad hoc remains the only flow that creates a round inside the game wizard.

### Trip page structure

Replace separate Rounds + Games sections with one **Rounds** section:

- Each round shows name, date, course, tee summary (as today), Edit / Delete.
- Nested under each round: that round’s games (name, format, draft/active/completed) linking to the game.
- Per-round commissioner CTA: **Add game**.
- Empty trip: prompt to create a round (no game CTA until a round exists).
- Round with no games: show **Add game** only.
- Remove trip-level **Create game**.

### Naming defaults

| Object | Default | Editable? |
|--------|---------|-----------|
| **Round** | `{course_name} · {Mon D}` e.g. `Wolf River Golf Park · Jul 16` | Prefill on create/edit; do not force a blank invent-a-name field |
| **Game** (trip) | `{Format} · Group {Letter}` e.g. `Vegas · A`, `Vegas · B` | Yes after create; not required at create |
| **Team** | `Team A`, `Team B` prefilled in team form | Yes |

**Group letters:** Next letter among **all** games on that round (not per-format): 1st → A, 2nd → B, …. Renaming a game does not renumber siblings. Letters match foursome labels on trip sheets better than incrementing numbers (which read like rankings).

**Rejected:** Game name = `{format} - {team name}` with live updates when teams rename. A game has two teams; picking one team as the game identity is awkward. Syncing would need an auto-vs-manual name flag for little gain.

### Trip — Add game flow

1. Commissioner clicks **Add game** on a round.
2. Short form: **format only** (required).
3. Create `Game` with `event_id`, `round_id`, `game_type`, auto `name` (`{Format} · Group {Letter}`), status progressing to `active` once format is saved (same rules as today’s format step: active requires round + game_type).
4. Redirect into setup at **invite** (course step skipped because round is set). Wizard after create is effectively invite → teams.

Suggested route shape (implementation may nest under round or pass `round_id`):

| Method | Path (illustrative) | Action |
|--------|---------------------|--------|
| GET | `/events/:token/rounds/:round_id/games/new` | Format picker |
| POST | `/events/:token/rounds/:round_id/games` | Create with round preset |

Remove or stop linking `GET/POST /events/:token/games` as the trip create entrypoint (keep only if needed for redirects/compat; no UI CTA).

### Trip — Create / edit round

- Course search + tee + date unchanged.
- Name prefilled from course + date when course/tee selected; user may edit before save.

### Ad hoc — New game

- Entry: On-Course **New game** (unchanged).
- Flow: name (can stay required or lighten later) → course (creates round) → format → invite.
- No trip nesting; course step remains.

### Game setup wizard (trip)

| Situation | Course step |
|-----------|-------------|
| Trip game created from a round (`round_id` set) | Skip; land on invite (format already chosen) |
| Legacy draft trip game with blank `round_id` | Show course step: **pick existing event round only** — no “create new round” for event games |
| Ad hoc game | Course step creates/updates round as today |

Hard rules for event games in the wizard:

- No “create new round” from the course step.
- No “change round” after create from a round.

### Visibility outside the nested list

- Game show (and any game list rows that still appear elsewhere): show parent **round name** (and link back to the trip) so the relationship stays visible off the trip page.
- Trip nested list is the primary place to browse games by round.

### Teams

- Prefill team name inputs with `Team A` / `Team B` when empty.
- No animal-name library in this change.

### Permissions

Unchanged: create round / add game = event commissioner; game management = existing `can_manage?` rules.

### Data model

No migrations. Continue using `games.round_id` and `games.event_id`. Round-first is enforced in UX and create paths for trips, not by making `round_id` non-null at insert for all games (ad hoc drafts still create round later).

## Success criteria

1. On a trip, a commissioner cannot create a game without choosing a round (Add game is on a round).
2. Michigan-style setup is: create 4 rounds → Add game × N per round with format only → invite/teams.
3. Nested trip UI makes round → games obvious without opening setup.
4. Ad hoc pickup games still work from On-Course.
5. Defaults remove the need to invent round/game/team names for the common path.

## Implementation notes (for planning)

- Prefer reusing existing `GamesController` create with `round_id` + `game_type` over a large new controller surface.
- `GameSetupsController#next_step` already skips course when round present — wire create to set `round_id` (and format) so that path is hit.
- Cover request specs: add game from round; trip page nests games; no trip-level create CTA; ad hoc course step unchanged; event wizard cannot create a new round.
- Existing Michigan / dry-run data may keep old names until manually recreated; no mandatory data migration.

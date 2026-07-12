# Trip rounds nest games — Implementation Plan

> **For agentic workers:** Implement task-by-task with TDD. Steps use checkbox syntax.

**Goal:** Nest trip games under rounds, create games from a round with format-only, and add naming defaults.

**Architecture:** Reuse `GamesController` with nested round routes; set `round_id` + `game_type` at create so setup skips course. No schema changes.

**Tech Stack:** Rails, RSpec request/model specs, ERB

**Design:** `docs/plans/2026-07-12-trip-rounds-nest-games-design.md`

---

### Task 1: Game naming helpers

**Files:** `app/models/game.rb`, `spec/models/game_spec.rb`

- [x] `Game.next_group_letter(round)` → A, B, C…
- [x] `Game.default_trip_name(round, game_type)` → `"Vegas · A"`
- [x] Specs for letter increment and labels

### Task 2: Nested create from round

**Files:** `config/routes.rb`, `app/controllers/games_controller.rb`, `app/views/games/new.html.erb`, `spec/requests/games_spec.rb`

- [x] Nest `games#new/create` under `events/:token/rounds/:round_id`
- [x] Format-only form; create active game with auto name; redirect to invite setup
- [x] Remove trip-level games new/create routes (or leave unused)

### Task 3: Trip page nesting

**Files:** `app/views/events/show.html.erb`, `spec/requests/events_spec.rb` (or games)

- [x] Nest games under each round; Add game CTA per round
- [x] Remove top-level Create game / Games section

### Task 4: Round default name with date

**Files:** `round_snapshot_buildable.rb`, related specs

- [x] Default `{course} · {Mon D}` using played_on when available

### Task 5: Event wizard — existing rounds only

**Files:** `game_setups` views/controller, `spec/requests/game_setups_spec.rb`

- [x] Event games: pick existing round only; link to create round if none
- [x] No create-new-round in event game course step

### Task 6: Team defaults + game show round link

**Files:** `edit_teams.html.erb`, `games/show.html.erb`, specs

- [x] Prefill Team A / Team B
- [x] Show round name + link to trip on game show

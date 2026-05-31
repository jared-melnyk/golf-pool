# Cha-Cha-Cha (1-2-3) Implementation Plan

> **Status:** Implemented 2026-05-30

**Goal:** Add Cha-Cha-Cha (1-2-3) as an on-course game: net stroke play with a repeating 1-2-3 count of lowest net scores per hole, 3–4 players per group, 85% handicap allowance.

**Architecture:** `ChaChaCha` rules module + `ChaChaChaScorecard` service (forked from Best Ball). No DB migration.

## Rules (locked)

| Topic | Decision |
|-------|----------|
| Team size | 3 or 4 players |
| Scoring | Net stroke play; sum lowest N nets per hole |
| N per hole | `((hole - 1) % 3) + 1` → 1, 2, 3, 1, 2, 3… |
| Handicap | 85% playing handicap |
| Incomplete hole | Fewer than N nets → hole nil; any nil hole → total nil |
| Stableford | Deferred (cross-game `scoring_basis` later) |
| Display name | Cha-Cha-Cha (1-2-3) |

## Files

- `lib/cha_cha_cha.rb`, `app/services/cha_cha_cha_scorecard.rb`
- `app/helpers/games_helper.rb` — `game_type_label`
- Views: `_scorecard_cha_cha_cha`, `_cha_cha_hole_cell`, `_leaderboard_cha_cha_cha`
- Wired: `Game`, `GameScorecardBuilder`, `GamesController`, Turbo stream

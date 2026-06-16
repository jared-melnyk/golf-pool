# Vegas — Design Specification

**Status:** Approved design, ready for implementation planning.  
**Project:** `long_shot` (On-Course games)  
**Date:** 2026-06-10  

**Related:** [Golf trip pre-trip plan](2026-06-10-golf-trip-pre-trip-testing-plan.md), [On-Course Games design](2026-05-06-on-course-games-design.md), [Cha-Cha-Cha plan](2026-05-30-cha-cha-cha-plan.md)

---

## 1. Purpose

Add **Vegas** as an on-course game format: **2v2 within a single foursome**, where each team combines its two **net scores** into a two-digit number, the lower number wins the hole, and **hole points** accumulate on a **wash** basis until one side is “up” at the end.

This document locks rules agreed 2026-06-10 and defines implementation shape for Phase 0 of the golf-trip plan.

---

## 2. Product overview

### 2.1 Scope of one game

| Concept | Rule |
|---------|------|
| Players per game | **4** (one foursome) |
| Teams per game | **2** |
| Players per team | **2** |
| Multiple foursomes | **Separate games** — 12 golfers in three groups → **3 Vegas games**, each with its own wash total |
| Event / round | Games link to a `Round` and optional `Event` like other formats |

Vegas does **not** combine scores across foursomes. There is no event-wide Vegas leaderboard in v1.

### 2.2 Display name

- **UI label:** `Vegas`
- **`game_type` string:** `vegas`

### 2.3 Non-goals (v1)

- Presses / auto-presses / side bets
- Skins, barkies, sandies
- Twosomes or three-team Vegas
- Cross-foursome or stroke-play leaderboard across >2 teams
- Stableford variant

---

## 3. Rules (locked)

### 3.1 Handicap

| Topic | Decision |
|-------|----------|
| Allowance | **100%** — Playing Handicap = Course Handicap (no 85% reduction) |
| Course handicap | WHS: `round(HI × (slope/113) + (rating − par))` |
| Stroke allocation | Same per-hole distribution as other on-course games (PH strokes on stroke indices 1…PH; PH > 18 repeats SI order) |
| Net score | `gross_score − strokes_received` on that hole |

### 3.2 Net cap before pairing

| Topic | Decision |
|-------|----------|
| Cap | **9** — any net score **greater than 9** is treated as **9** before building the team number (10, 11, 12, … all cap to 9; 9 and below unchanged) |
| Rationale | Vegas uses two decimal digits; values above 9 cannot form a standard pairing |

### 3.3 Team number (default pairing)

For a team’s two capped net scores on a hole:

1. Let **L** = lower net, **H** = higher net (if equal, L = H).
2. **Team number** = `L × 10 + H` (tens = lower, ones = higher).

**Examples:**

| Net scores (after cap) | Team number |
|------------------------|-------------|
| 3, 4 | 34 |
| 4, 6 | 46 |
| 4, 4 | 44 |
| 8, 10 (10 caps to 9) | 89 |
| 9, 10 (10 caps to 9) | 99 |
| 9, 11 (11 caps to 9) | 99 |

### 3.4 Birdie flip

| Topic | Decision |
|-------|----------|
| Trigger | **Either** player on a team has **net birdie or better** on the hole (`net ≤ par − 1`) |
| Eagle / better | Same as birdie — triggers opponent flip only |
| Effect | Flip the **opponent** team’s digit order: **higher net → tens**, **lower → ones** |
| Both teams birdie | **Both teams flip** — each team’s birdie-or-better flips the **opponent’s** digits; when both teams birdie on the same hole, **both** flips apply |

**Example (birdie flip):**

- Team A: net 4, net 5 → default **45**
- Team B: one net birdie (3), other net 5 → default **35**
- Team B birdied → flip **Team A**: **54** (not 45)
- Team B stays **35**
- Team B wins hole: 54 − 35 = **19** points to Team B

### 3.5 Hole winner and points

| Topic | Decision |
|-------|----------|
| Winner | Team with the **lower** team number after flips |
| Tie | Same team number (e.g. 44 vs 44) → **0** hole points |
| Points | `opponent_team_number − your_team_number`, awarded to the winning team |

Using the introductory example (no flips):

- Team A: 3, 4 → **34**
- Team B: 4, 6 → **46**
- Team A wins: 46 − 34 = **12** points to Team A

### 3.6 Wash (running total)

| Topic | Decision |
|-------|----------|
| Accumulation | Sum hole points from a fixed **reference team** perspective (see §4.2) |
| Display | **Wash basis** — only one side is “up” at any time |
| All square | Running total = 0 → “All square” |
| Leader up | “{Team name} leads by {N}” |

**Example:**

| Hole | Points to A | Running wash (A perspective) |
|------|-------------|----------------------------|
| 1 | +12 | A leads by 12 |
| 2 | −8 | A leads by 4 |
| 3 | 0 | A leads by 4 |

### 3.7 Incomplete holes

| Topic | Decision |
|-------|----------|
| Requirement | All **four** players must have a gross score on a hole to score that hole |
| Missing score | Hole contributes **no** points; running wash unchanged for that hole |
| Game total | Wash total reflects only **completed** holes; label as in-progress if any hole 1–18 is incomplete |

### 3.8 Team setup validation

| Topic | Decision |
|-------|----------|
| Teams | Exactly **2** `GameTeam` records |
| Roster | Exactly **2** `GameTeamPlayer` per team |
| Save | Reject team save with clear error if not 2×2 |

---

## 4. Technical design

### 4.1 Architecture

Follow Cha-Cha-Cha / 40 Score pattern:

- **`lib/vegas.rb`** — pure rule helpers (cap, team number, birdie check, flip, hole points)
- **`app/services/vegas_scorecard.rb`** — builds scorecard hash from `Game` + associations
- **No DB migration** — reuse `Game`, `GameTeam`, `GameTeamPlayer`, `HoleScore`

### 4.2 Scorecard computation

**Reference team:** First team by `game_teams.id` ascending (stable). All wash math is from this team’s perspective:

- Reference team wins hole → add positive points to running wash
- Reference team loses → subtract (opponent wins)

**Per hole algorithm:**

```
1. Load capped net scores for all 4 players (nil if gross missing → hole incomplete)
2. Build default team numbers for Team A and Team B
3. For each team with birdie-or-better on hole, mark opponent for flip
4. Apply flips to opponent team numbers
5. If both numbers present:
     - If equal → hole_points = 0
     - Else → winner gets (loser_number - winner_number); update running wash from reference team POV
6. Emit hole row: team numbers, flip flags, points, running_wash
```

### 4.3 Scorecard hash shape

```ruby
{
  reference_team_id: Integer,
  teams: [
    {
      id:, name:,
      players: [
        { name:, course_handicap:, playing_handicap:,
          hole_scores: [{ hole_number:, gross_score:, net_score:, strokes_received:, capped_net: }] }
      ]
    }
  ],
  holes: [
    {
      hole_number:,
      par:,
      team_numbers: { team_id => Integer },      # after flips
      flipped_team_ids: [team_id],               # teams whose pairing was flipped
      birdie_team_ids: [team_id],                # teams that triggered a flip
      hole_points: Integer | nil,                # signed from reference team (+ = ref won)
      running_wash: Integer | nil,               # nil if hole incomplete
      complete: Boolean
    }
  ],
  wash: {
    margin: Integer | nil,                       # from reference team; nil if no complete holes
    leader_team_id: Integer | nil,               # nil if margin 0 or nil
    leader_name: String | nil,
    label: String                                # "All square", "Team A leads by 12", etc.
  }
}
```

**Note:** Vegas has exactly two teams, so there is no multi-team ordinal leaderboard like Best Ball. The `wash` object is the primary result. Optional `leaderboard` key is **not** required for v1 unless a partial needs it; prefer `wash` + hole table.

### 4.4 `lib/vegas.rb` API (proposed)

```ruby
module Vegas
  VALID_TEAM_COUNT = 2
  VALID_PLAYERS_PER_TEAM = 2
  NET_CAP = 9

  def self.cap_net(net) ... end
  def self.team_number(net_a, net_b, flipped: false) ... end
  def self.birdie_or_better?(net, par) ... end
  def self.hole_points(reference_number, opponent_number) ... end  # +N if reference wins, -N if loses, 0 tie
  def self.valid_game_roster?(teams) ... end  # 2 teams, 2 players each
end
```

### 4.5 Model / controller changes

| File | Change |
|------|--------|
| `app/models/game.rb` | Add `vegas` to `GAME_TYPES`; `vegas?`; `playing_handicap_allowance_percent` → 100 for `vegas` |
| `app/controllers/concerns/game_scorecard_builder.rb` | Branch to `VegasScorecard` |
| `app/controllers/games_controller.rb` | `enforce_vegas_team_sizes!` on `update_teams` |
| `app/views/games/show.html.erb` | Render `_scorecard_vegas` |
| `app/views/games/edit_teams.html.erb` | Copy: “2 teams of 2 players”; default 2 team name fields |
| `app/views/game_setups/show.html.erb` | Include `vegas` in format step |
| `app/views/hole_scores/update.turbo_stream.erb` | Turbo refresh for Vegas scorecard + wash |
| `app/helpers/games_helper.rb` | Label via `Game.type_label` |

### 4.6 UI sketch

**Help banner:**

> Combine each team’s two net scores into a two-digit number (lower digit tens, higher ones). Lower team number wins the hole. Net birdie or better flips the other team’s digits. Points accumulate on a wash basis.

**Scorecard table (per hole):**

| Hole | Par | Team A nets | Team A # | Team B nets | Team B # | Points | Wash |
|------|-----|-------------|----------|-------------|----------|--------|------|

- Show flip indicator (e.g. ↕) when a team number was flipped
- Highlight birdie cells optionally

**Summary card:**

> **Team A leads by 12** (after 14 holes)

### 4.7 Score entry

Unchanged from other formats: gross score per player per hole via existing `HoleScoresController` + Turbo. No format-specific fields on `HoleScore`.

---

## 5. Worked examples

### 5.1 Basic hole (no flip)

| | Player 1 | Player 2 | Team # |
|---|----------|----------|--------|
| Team A | net 3 | net 4 | **34** |
| Team B | net 4 | net 6 | **46** |

Points to A: 46 − 34 = **12**

### 5.2 Tie

| | Team # |
|---|--------|
| Team A | 44 |
| Team B | 44 |

Points: **0**

### 5.3 Net cap

Any net **> 9** caps to 9 (including **10**).

| | Raw net → capped | Team # |
|---|------------------|--------|
| Team A | 8, 10→9 | **89** |
| Team B | 5, 6 | **56** |

Points to B: 89 − 56 = **33**

### 5.4 Both teams birdie (both flips)

| | Raw nets | Default # | After flip |
|---|----------|-----------|------------|
| Team A (birdie) | 3, 5 | 35 | — |
| Team B (birdie) | 3, 4 | 34 | A flipped → **53**; B flipped → **43** |

Winner: B (43 < 53). Points to B: 53 − 43 = **10**

---

## 6. Testing requirements

Implementation is not complete until:

| Layer | Spec |
|-------|------|
| Unit | `spec/lib/vegas_spec.rb` — cap, team_number, flip, birdie, hole_points, roster validation |
| Service | `spec/services/vegas_scorecard_spec.rb` — examples in §5, running wash, incomplete holes |
| Request | Create Vegas game, save 2×2 teams, enter scores, GET scorecard |
| Teams | Reject 1 team, 3 teams, 3 players on a team |

Golden scenarios for trip testing (Phase A) should include: `vegas_hole_win`, `vegas_birdie_flip`, `vegas_both_birdie`, `vegas_net_cap`, `vegas_wash_accumulation`.

---

## 7. Edge cases checklist

| Case | Expected behavior |
|------|-------------------|
| Net 10 | Capped to 9 before pairing |
| Net 11+ | Capped to 9 before pairing |
| Both nets 9 | Team number 99 |
| One player missing gross | Hole incomplete; no points |
| Both teams birdie | Both teams flip (each side’s birdie flips the opponent) |
| Eagle | Same as birdie (opponent flip) |
| Tie on hole | 0 points |
| PH = 0 | Net = gross |
| Game has 1 or 3 teams | Validation error on team save |
| Team has 1 or 3 players | Validation error on team save |
| Completed game | Scores locked (existing `status` flow) |

---

## 8. Open items (non-blocking)

1. **Default team names** on `edit_teams` — e.g. “Team A” / “Team B” vs player surnames (cosmetic).
2. **Birdie highlight** in UI — nice-to-have visual cue on score cells.
3. **Trip simulator** — which round gets Vegas is demo config only ([trip plan](2026-06-10-golf-trip-pre-trip-testing-plan.md) §2).

---

## 9. Implementation sequence

1. `lib/vegas.rb` + `spec/lib/vegas_spec.rb`
2. `VegasScorecard` + `spec/services/vegas_scorecard_spec.rb`
3. Wire `Game`, `GameScorecardBuilder`, team enforcement
4. Views + Turbo stream
5. Game setup format step
6. Manual smoke in dev
7. Proceed to trip testing Phase A ([trip plan](2026-06-10-golf-trip-pre-trip-testing-plan.md))

---

## 10. Resume pointer

**Next action:** Write `docs/plans/2026-06-10-vegas-plan.md` (task-by-task implementation plan) or begin implementation at §9 step 1.

**Reference code:**

- `lib/cha_cha_cha.rb` / `app/services/cha_cha_cha_scorecard.rb`
- `app/controllers/games_controller.rb` — `enforce_cha_cha_cha_team_sizes!`
- `app/views/games/_scorecard_cha_cha_cha.html.erb`

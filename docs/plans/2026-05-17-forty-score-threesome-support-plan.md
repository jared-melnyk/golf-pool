# 40 Score — Threesome Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow 40 Score teams of **3 or 4** players in one game, with **30 or 40** counted net scores respectively, **competition vs par** scaled to a 40-hole-equivalent total (×4/3 for threesomes, rounded to nearest whole stroke), while showing **actual** vs par alongside **competition** vs par. **Twosomes remain blocked.**

**Architecture:** Centralize roster-size rules in a small `FortyScore` module (`target_pick_count`, `competition_multiplier`, `team_size_valid?`) used by `GameTeam`, `HoleScore`, `FortyScoreScorecard`, and `GamesController`. Scorecard computes `actual_vs_par` when `selected_count == target_pick_count`; `competition_vs_par = (actual_vs_par * multiplier).round` (integer). Leaderboard ranks on `competition_vs_par`. No DB migration required.

**Tech Stack:** Rails 8.1, existing On-Course models (`Game`, `GameTeam`, `HoleScore`), RSpec.

**Product reference:** [Fried Egg — 40 Score](https://www.thefriedegg.com/articles/how-to-play-golf-game-40-score) (classic game is foursome + 40 picks; threesome rules are LongShot extensions documented in this plan).

---

## Rules (locked)

| Players | Counted scores (target picks) | Actual vs par | Competition vs par (leaderboard) |
|--------:|------------------------------:|---------------|----------------------------------|
| 4 | 40 | Σ(par − net) on counted holes | Same as actual |
| 3 | 30 | Σ(par − net) on counted holes | `(actual_vs_par × 4/3).round` |
| 2 | — | **Not allowed** | — |

- **Vs par sign:** positive = under par (matches current `FortyScoreScorecard#net_under_par`).
- **Completion:** Totals and competition score are `nil` until `selected_count == target_pick_count` with gross on every counted hole.
- **Pick cap:** Cannot toggle more than `target_pick_count` included scores per team.
- **Mixed event:** Team A (4) and Team B (3) in the same `Game` is supported; each team uses its own target and multiplier.

---

## File Structure

**Create:**
- `lib/forty_score.rb` — `FortyScore` module (autoloaded via `config.autoload_lib`).
- `spec/lib/forty_score_spec.rb` — unit tests for pick count, multiplier, validation.

**Modify:**
- `app/models/game_team.rb` — optional helper delegating to `FortyScore` (player count).
- `app/models/hole_score.rb` — dynamic pick cap via `FortyScore.target_pick_count`.
- `app/controllers/games_controller.rb` — `enforce_forty_score_team_sizes!` → allow 3–4 only.
- `app/services/forty_score_scorecard.rb` — target picks, `actual_vs_par`, `competition_vs_par`, leaderboard sort key.
- `app/views/games/_scorecard_forty_score.html.erb` — dynamic X/target, actual + competition labels, leaderboard columns.
- `app/views/games/edit_teams.html.erb` — copy for forty_score: “3–4 players per group”.
- `spec/services/forty_score_scorecard_spec.rb` — threesome scenarios, competition rounding.
- `spec/models/hole_score_spec.rb` — cap at 30 for 3-player team.
- `spec/requests/games_spec.rb` — accept 3-player save; reject 2-player.
- `docs/plans/2026-05-06-on-course-games-design.md` — short appendix for 40 Score threesome rules (optional but recommended).

**Untouched:**
- `db/schema.rb` — no migration.
- Best Ball paths (`BestBallScorecard`, `_scorecard.html.erb`).
- `HoleScoresController` — pick toggle logic unchanged; validations move via model.

---

## Conventions

- **RSpec:** mirror `spec/services/forty_score_scorecard_spec.rb` and `spec/requests/games_spec.rb` patterns.
- **Lib autoload:** `lib/forty_score.rb` should be required by Zeitwerk; verify with `bin/rails runner 'FortyScore.target_pick_count(3)'`.
- **Naming in scorecard hash:** prefer `actual_vs_par` and `competition_vs_par` in new code; keep `net_under_par` as alias only if needed for a single release (prefer rename in scorecard + partial in one PR).

---

## Task 1: `FortyScore` module (pure rules)

**Files:**
- Create: `lib/forty_score.rb`
- Create: `spec/lib/forty_score_spec.rb`

- [ ] **Step 1: Write failing specs**

```ruby
# spec/lib/forty_score_spec.rb
RSpec.describe FortyScore do
  describe ".target_pick_count" do
    it { expect(described_class.target_pick_count(3)).to eq(30) }
    it { expect(described_class.target_pick_count(4)).to eq(40) }
  end

  describe ".competition_multiplier" do
    it { expect(described_class.competition_multiplier(3)).to eq(4.0 / 3.0) }
    it { expect(described_class.competition_multiplier(4)).to eq(1.0 }
  end

  describe ".competition_vs_par" do
    it "rounds threesome actual to nearest whole stroke" do
      expect(described_class.competition_vs_par(actual_vs_par: 8, player_count: 3)).to eq(11)
    end

    it "returns actual unchanged for foursomes" do
      expect(described_class.competition_vs_par(actual_vs_par: 8, player_count: 4)).to eq(8)
    end
  end

  describe ".valid_team_size?" do
    it { expect(described_class.valid_team_size?(3)).to be true }
    it { expect(described_class.valid_team_size?(4)).to be true }
    it { expect(described_class.valid_team_size?(2)).to be false }
  end
end
```

- [ ] **Step 2: Run specs — expect failure**

Run: `bundle exec rspec spec/lib/forty_score_spec.rb`

- [ ] **Step 3: Implement module**

```ruby
# lib/forty_score.rb
module FortyScore
  BASE_PICK_COUNT = 40
  BASE_PLAYER_COUNT = 4
  VALID_TEAM_SIZES = (3..4).freeze

  module_function

  def target_pick_count(player_count)
    (BASE_PICK_COUNT * player_count.to_f / BASE_PLAYER_COUNT).round
  end

  def competition_multiplier(player_count)
    BASE_PLAYER_COUNT.to_f / player_count
  end

  def competition_vs_par(actual_vs_par:, player_count:)
    return nil if actual_vs_par.nil?

    (actual_vs_par * competition_multiplier(player_count)).round
  end

  def valid_team_size?(player_count)
    VALID_TEAM_SIZES.cover?(player_count)
  end
end
```

- [ ] **Step 4: Run specs — expect pass**

Run: `bundle exec rspec spec/lib/forty_score_spec.rb`

- [ ] **Step 5: Commit**

```bash
git add lib/forty_score.rb spec/lib/forty_score_spec.rb
git commit -m "feat: add FortyScore rules module for 3/4 player groups"
```

---

## Task 2: Team size validation (3–4 players)

**Files:**
- Modify: `app/controllers/games_controller.rb` (`enforce_forty_score_team_sizes!`)
- Modify: `spec/requests/games_spec.rb`

- [ ] **Step 1: Update request spec — allow 3, reject 2**

In `spec/requests/games_spec.rb`, under `when game type is forty_score`:

- Change existing “rejects … without exactly four” example to use **2** players → expect `422`.
- Add example: **3** players on one team → redirect success, `game_team_players.size == 3`.

- [ ] **Step 2: Run request spec — expect failure**

Run: `bundle exec rspec spec/requests/games_spec.rb`

- [ ] **Step 3: Update controller**

Replace `next if n == 4` with:

```ruby
next if FortyScore.valid_team_size?(n)

team.errors.add(
  :base,
  "40 Score requires 3 or 4 players per group (#{team.name} has #{n})."
)
```

- [ ] **Step 4: Run request spec — expect pass**

- [ ] **Step 5: Commit**

```bash
git add app/controllers/games_controller.rb spec/requests/games_spec.rb
git commit -m "feat: allow 3–4 player groups for 40 Score team setup"
```

---

## Task 3: Dynamic pick cap on `HoleScore`

**Files:**
- Modify: `app/models/hole_score.rb`
- Modify: `spec/models/hole_score_spec.rb`

- [ ] **Step 1: Add failing spec for 30-pick cap**

In `forty_score pick rules` context, add example with **3** players and **30** picks already selected; 31st toggle fails with updated message referencing group limit (not hard-coded “40”).

- [ ] **Step 2: Run spec — expect failure**

- [ ] **Step 3: Implement**

```ruby
def forty_pick_team_cap
  team = game_team_player.game_team
  player_count = team.game_team_players.count
  limit = FortyScore.target_pick_count(player_count)
  # ... existing tally logic ...
  return if tally <= limit

  errors.add(:included_in_forty_score, "would exceed the #{limit}-count limit for this group")
end
```

- [ ] **Step 4: Run hole_score specs — expect pass**

- [ ] **Step 5: Commit**

---

## Task 4: `FortyScoreScorecard` — actual + competition scores

**Files:**
- Modify: `app/services/forty_score_scorecard.rb`
- Modify: `spec/services/forty_score_scorecard_spec.rb`

- [ ] **Step 1: Add failing specs**

1. **Threesome with 30 picks:** `actual_vs_par == 8`, `competition_vs_par == 11`, `target_pick_count == 30`.
2. **Threesome incomplete (29 picks):** both vs par `nil`.
3. **Leaderboard:** 3-player team with better **competition** score ranks above 4-player team with lower competition score (construct fixture similar to existing birdie test but with mixed sizes).
4. **Foursome:** `competition_vs_par == actual_vs_par`.

- [ ] **Step 2: Run service specs — expect failure**

- [ ] **Step 3: Refactor `build_team`**

```ruby
player_count = team.game_team_players.size
target = FortyScore.target_pick_count(player_count)

# ... sum selected_count, total_selected_net, total_selected_par ...

actual_vs_par =
  if selected_count == target
    total_selected_par - total_selected_net
  end

competition_vs_par = FortyScore.competition_vs_par(
  actual_vs_par: actual_vs_par,
  player_count: player_count
)

{
  # ...
  player_count: player_count,
  target_pick_count: target,
  selected_count: selected_count,
  actual_vs_par: actual_vs_par,
  competition_vs_par: competition_vs_par,
  # deprecate net_under_par in hash OR set net_under_par: competition_vs_par for one release
}
```

- [ ] **Step 4: Update `build_leaderboard`**

- Sort complete teams by `competition_vs_par` descending (higher under par wins).
- Tie-break: same ordinal pattern as today (`T1`, `T2`, …) on `competition_vs_par`.
- Row keys: `team_name`, `player_count`, `target_pick_count`, `actual_vs_par`, `competition_vs_par`, `total_selected_net`, `total_selected_par`, `rank`.

- [ ] **Step 5: Run service specs — expect pass**

- [ ] **Step 6: Commit**

---

## Task 5: Scorecard UI

**Files:**
- Modify: `app/views/games/_scorecard_forty_score.html.erb`
- Modify: `app/views/games/edit_teams.html.erb` (conditional copy when `@game.forty_score?`)

- [ ] **Step 1: Help banner**

Replace fixed “40 counted net scores” with:

- Foursome: 40 picks; threesome: 30 picks.
- Leaderboard uses **competition** vs par (40-hole equivalent for threesomes).
- Link to Fried Egg article unchanged.

- [ ] **Step 2: Per-team header**

```erb
<%= team[:selected_count] %> / <%= team[:target_pick_count] %> picks
<% if team[:actual_vs_par] %>
  · Actual <%= "%+d" % team[:actual_vs_par] %>
  · Competition <%= "%+d" % team[:competition_vs_par] %>
<% end %>
```

- [ ] **Step 3: Leaderboard table**

| Pos | Team | Players | Picks | Actual vs par | Competition vs par |
|-----|------|---------|-------|---------------|-------------------|

Sort/display **Competition** as primary; show “—” until team completes `target_pick_count`.

- [ ] **Step 4: Edit teams**

When `@game.forty_score?`, change label from “select 1–4” to **“select 3–4”** and add one-line note under heading.

- [ ] **Step 5: Manual smoke test**

1. Create forty_score game, save team with 3 players.
2. Enter grosses, select 30 picks, confirm competition line appears.
3. Save team with 2 players → error.

- [ ] **Step 6: Commit**

---

## Task 6: Documentation + full CI

**Files:**
- Modify: `docs/plans/2026-05-06-on-course-games-design.md` (§ appendix)

- [ ] **Step 1: Add design appendix (short)**

Under On-Course games, document 3/4 player 40 Score, 30/40 picks, competition scaling, no pairs.

- [ ] **Step 2: Run full relevant test suite**

```bash
bundle exec rspec spec/lib/forty_score_spec.rb \
  spec/models/hole_score_spec.rb \
  spec/services/forty_score_scorecard_spec.rb \
  spec/requests/games_spec.rb spec/requests/hole_scores_spec.rb
```

- [ ] **Step 3: Run CI-local checks**

```bash
bin/bundler-audit
bin/rubocop
```

- [ ] **Step 4: Commit**

```bash
git add docs/plans/2026-05-06-on-course-games-design.md
git commit -m "docs: document 40 Score threesome competition scoring"
```

---

## Edge cases checklist

| Case | Expected behavior |
|------|-------------------|
| Team has 3 players, 29 picks | No actual/competition totals; leaderboard rank nil |
| Team has 3 players, 30 picks, +8 actual | Competition **+11** |
| Team has 4 players, 40 picks, +8 actual | Competition **+8** |
| Try 41st pick (4-player) | Validation error |
| Try 31st pick (3-player) | Validation error |
| Toggle pick without gross | Error (unchanged) |
| 2-player team save | `422` with clear message |
| 5+ players (if UI allows) | Reject in `enforce_forty_score_team_sizes!` (only 3–4 valid) |
| Negative actual (over par) | Competition scales linearly (e.g. +6 actual → +8 competition for 3) |

---

## Fairness note (for help copy, optional)

Threesomes have fewer score slots (54 vs 72), so pick strategy differs slightly from a foursome; the **4/3** adjustment aligns **totals** for leaderboard comparison, not every strategic edge case. No code change required—optional sentence in the help banner.

---

## Out of scope

- Twosomes (20 picks × 2 multiplier).
- Skins / money pot tracking.
- Per-hole max picks (0–4 per hole) — still honor system / not enforced in app.
- Changing Best Ball team sizing.

---

## Verification before merge

- [ ] All new and updated specs green.
- [ ] Commissioner can save 3- and 4-player forty_score teams.
- [ ] Leaderboard orders by **competition** vs par.
- [ ] Scorecard shows **actual** and **competition** for complete teams only.

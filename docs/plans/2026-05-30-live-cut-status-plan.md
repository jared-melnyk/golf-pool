# Live Cut Status & Projected Pool Scoring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show accurate cut-made / missed-cut state, Cut Made Bonus, and projected Counted/Dropped badges on the pool tournament scoreboard as soon as the API posts the cut (after R2), instead of waiting for R3 round scores or tournament completion.

**Architecture:** BallDontLie `tournament_results` already exposes `position: "CUT"` mid-event while `earnings` stay `null`. Add `position_display` on `TournamentResult`, sync leaderboard rows during live play via a new `BallDontLie::SyncLiveLeaderboard` service (no champion assignment), and centralize cut/bonus/projected-earnings rules on `TournamentResult` + `Tournament#cut_posted?`. Keep final prize money + champion sync gated on API `COMPLETED`. Round-3 presence remains a fallback only when leaderboard sync has not run yet.

**Tech Stack:** Rails 8.1, RSpec (model + service + job + request specs), Solid Queue (`RefreshLiveResultsJob`), BallDontLie PGA API v1.

**Background (Charles Schwab Challenge, tournament id 28, day 3):** 56 players had `position: "CUT"`, 76 made cut, all `earnings: null`, zero players had R3 in `player_round_results` before R3 teed off. Tee times are not available on `tournament_field`.

---

## File Structure

**Create:**
- `db/migrate/YYYYMMDDHHMMSS_add_position_display_to_tournament_results.rb`
- `db/migrate/YYYYMMDDHHMMSS_add_leaderboard_synced_at_to_tournaments.rb`
- `app/services/ball_dont_lie/sync_live_leaderboard.rb`
- `spec/services/ball_dont_lie/sync_live_leaderboard_spec.rb`
- `app/services/pool_tournament_scoring_display.rb` (optional but recommended — keeps controller thin)
- `spec/services/pool_tournament_scoring_display_spec.rb`

**Modify:**
- `app/models/tournament_result.rb` — `missed_cut?`, `made_cut_for_bonus?`, constants for API position tokens
- `app/models/tournament.rb` — `cut_posted?`, update `bonus_cut_eligible_result?` to use new helpers when appropriate
- `app/services/ball_dont_lie/sync_tournament_results.rb` — store `position_display`; champion only when API complete
- `app/jobs/refresh_live_results_job.rb` — call `SyncLiveLeaderboard` after round sync for in-progress tournaments
- `app/controllers/pool_tournaments_controller.rb` — use `PoolTournamentScoringDisplay` (or inline equivalent)
- `app/views/pool_tournaments/show.html.erb` — projected badges, `$0` for MC post-cut, hide badges pre-cut
- `app/helpers/tournaments_helper.rb` — delegate `missed_cut?` to model when possible
- `spec/models/tournament_result_spec.rb` (create if missing)
- `spec/models/tournament_spec.rb` — `cut_posted?`
- `spec/services/ball_dont_lie/sync_tournament_results_spec.rb` — `position_display`, champion guard
- `spec/jobs/refresh_live_results_job_spec.rb` — live leaderboard sync
- `spec/requests/pool_tournaments_show_spec.rb` — CUT/MC/projected badge cases

**Untouched (by design):**
- `app/models/pool.rb` — pool standings / `points_for_pool_tournament` stay final-results-only (prize money + completed bonus rules). Live scoreboard is display-only until the event completes.
- `app/services/ball_dont_lie/sync_round_results.rb` — still the source for R1–R4 cells.

---

## Domain Rules (product contract)

| Phase | Cut Made Bonus column | Prize Money column | Total Earnings | Counted/Dropped badges |
|-------|----------------------|-------------------|----------------|------------------------|
| Before cut (R1–R2, no `CUT` rows) | `—` | `—` | `—` | Hidden |
| After cut posted | Capped bonus if made cut + odds | `—` (until complete) | Bonus only if made cut; **`$0` if MC** | Shown, label **Projected**, top 3 by projected total |
| Tournament complete | Bonus or MC (final) | Actual prize | Prize + bonus (or `$0`) | Shown, no “Projected” label |

**Missed cut tokens from API:** `CUT`, `WD`, `DQ`, `MDF` (store raw string in `position_display`; treat all as MC for bonus).

**Made cut:** any synced `TournamentResult` with `position_display` present and not in missed-cut tokens, once `Tournament#cut_posted?` is true.

**Fallback:** If cut is posted but a picked golfer has no `TournamentResult` row yet, keep round-3 inference (`round_numbers.any? { |r| r >= 3 }`) for that golfer only.

---

## Conventions

- **Test framework:** RSpec; `let` + `create!` patterns from `spec/requests/pool_tournaments_show_spec.rb`.
- **Client mocking:** `instance_double(BallDontLie::Client, ...)`.
- **Migrations:** `ActiveRecord::Migration[8.1]`.
- **Run tests:** `bundle exec rspec <path>`

---

## Task 1: Migration — `position_display` and `leaderboard_synced_at`

**Files:**
- Create: `db/migrate/YYYYMMDDHHMMSS_add_position_display_to_tournament_results.rb`
- Create: `db/migrate/YYYYMMDDHHMMSS_add_leaderboard_synced_at_to_tournaments.rb`

- [ ] **Step 1: Write migrations**

```ruby
# db/migrate/..._add_position_display_to_tournament_results.rb
class AddPositionDisplayToTournamentResults < ActiveRecord::Migration[8.1]
  def change
    add_column :tournament_results, :position_display, :string
    add_index :tournament_results, :position_display
  end
end
```

```ruby
# db/migrate/..._add_leaderboard_synced_at_to_tournaments.rb
class AddLeaderboardSyncedAtToTournaments < ActiveRecord::Migration[8.1]
  def change
    add_column :tournaments, :leaderboard_synced_at, :datetime
  end
end
```

- [ ] **Step 2: Migrate**

Run: `bin/rails db:migrate && bin/rails db:test:prepare`

Expected: schema includes `tournament_results.position_display` and `tournaments.leaderboard_synced_at`.

- [ ] **Step 3: Commit**

```bash
git add db/migrate db/schema.rb
git commit -m "feat: add position_display and leaderboard_synced_at for live cut sync"
```

---

## Task 2: `TournamentResult` cut helpers

**Files:**
- Modify: `app/models/tournament_result.rb`
- Create: `spec/models/tournament_result_spec.rb`

- [ ] **Step 1: Write failing specs**

Create `spec/models/tournament_result_spec.rb`:

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe TournamentResult do
  let(:tournament) { Tournament.create!(name: "Test", starts_at: 1.day.ago) }
  let(:golfer) { Golfer.create!(name: "Player", external_id: "1") }
  let(:result) { described_class.new(tournament: tournament, golfer: golfer) }

  describe "MISSED_CUT_POSITIONS" do
    it "includes CUT and WD" do
      expect(described_class::MISSED_CUT_POSITIONS).to include("CUT", "WD")
    end
  end

  describe "#missed_cut?" do
    it "returns true when position_display is CUT" do
      result.position_display = "CUT"
      expect(result.missed_cut?).to be true
    end

    it "returns true when position_display is WD" do
      result.position_display = "WD"
      expect(result.missed_cut?).to be true
    end

    it "returns false when position_display is T18" do
      result.position_display = "T18"
      expect(result.missed_cut?).to be false
    end

    it "falls back to prize_money when position_display is blank" do
      result.position_display = nil
      result.prize_money = 0
      expect(result.missed_cut?).to be true
    end

    it "returns false when position_display blank and prize_money positive" do
      result.position_display = nil
      result.prize_money = 50_000
      expect(result.missed_cut?).to be false
    end
  end

  describe "#made_cut_for_bonus?" do
    it "returns false when missed cut" do
      result.position_display = "CUT"
      expect(result.made_cut_for_bonus?).to be false
    end

    it "returns true when position_display indicates made cut" do
      result.position_display = "T42"
      expect(result.made_cut_for_bonus?).to be true
    end

    it "returns false when position_display blank and prize_money zero" do
      result.position_display = nil
      result.prize_money = 0
      expect(result.made_cut_for_bonus?).to be false
    end

    it "returns true when position_display blank and prize_money positive" do
      result.position_display = nil
      result.prize_money = 10_000
      expect(result.made_cut_for_bonus?).to be true
    end
  end
end
```

- [ ] **Step 2: Run specs (fail)**

Run: `bundle exec rspec spec/models/tournament_result_spec.rb`
Expected: FAIL — constants/methods missing.

- [ ] **Step 3: Implement model**

```ruby
# app/models/tournament_result.rb
class TournamentResult < ApplicationRecord
  MISSED_CUT_POSITIONS = %w[CUT WD DQ MDF].freeze

  belongs_to :tournament
  belongs_to :golfer

  validates :tournament_id, uniqueness: { scope: :golfer_id }
  validates :prize_money, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  def missed_cut?
    if position_display.present?
      return MISSED_CUT_POSITIONS.include?(position_display.to_s.upcase)
    end

    prize_money.nil? || prize_money.to_d.zero?
  end

  def made_cut_for_bonus?
    !missed_cut?
  end

  # Backwards-compatible alias used by Pool and Tournament#bonus_cut_eligible_result?
  def made_cut?
    made_cut_for_bonus?
  end
end
```

- [ ] **Step 4: Run specs (pass)**

Run: `bundle exec rspec spec/models/tournament_result_spec.rb`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/models/tournament_result.rb spec/models/tournament_result_spec.rb
git commit -m "feat: derive cut status from position_display on tournament results"
```

---

## Task 3: `Tournament#cut_posted?`

**Files:**
- Modify: `app/models/tournament.rb`
- Modify: `spec/models/tournament_spec.rb`

- [ ] **Step 1: Write failing spec**

Add to `spec/models/tournament_spec.rb`:

```ruby
describe "#cut_posted?" do
  let(:tournament) { Tournament.create!(name: "Live", starts_at: 1.day.ago, external_id: "28") }
  let(:golfer) { Golfer.create!(name: "MC", external_id: "99") }

  it "returns false when no CUT rows exist" do
    expect(tournament.cut_posted?).to be false
  end

  it "returns true when at least one result has position_display CUT" do
    TournamentResult.create!(tournament: tournament, golfer: golfer, position_display: "CUT")
    expect(tournament.cut_posted?).to be true
  end

  it "returns false for completed no-cut events with only numeric positions" do
    tournament.update!(champion_golfer: golfer)
    5.times do |i|
      g = Golfer.create!(name: "F#{i}", external_id: "f#{i}")
      TournamentResult.create!(tournament: tournament, golfer: g, position: i + 1, position_display: (i + 1).to_s, prize_money: 1000)
    end
    expect(tournament.cut_posted?).to be false
  end
end
```

- [ ] **Step 2: Run spec (fail)**

Run: `bundle exec rspec spec/models/tournament_spec.rb -e cut_posted`
Expected: FAIL

- [ ] **Step 3: Implement**

```ruby
# app/models/tournament.rb
def cut_posted?
  return false unless started?
  return false if completed? && no_cut_event?

  tournament_results.where(position_display: TournamentResult::MISSED_CUT_POSITIONS).exists?
end
```

- [ ] **Step 4: Run spec (pass)**

- [ ] **Step 5: Commit**

```bash
git add app/models/tournament.rb spec/models/tournament_spec.rb
git commit -m "feat: detect when API cut line is posted on tournament results"
```

---

## Task 4: `BallDontLie::SyncLiveLeaderboard`

**Files:**
- Create: `app/services/ball_dont_lie/sync_live_leaderboard.rb`
- Create: `spec/services/ball_dont_lie/sync_live_leaderboard_spec.rb`

- [ ] **Step 1: Write failing service spec**

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe BallDontLie::SyncLiveLeaderboard do
  let(:tournament) { Tournament.create!(name: "Schwab", starts_at: 1.day.ago, external_id: "28") }
  let(:client) { instance_double(BallDontLie::Client, fetch_all_tournament_results: api_rows) }
  let(:api_rows) { [] }

  before { allow(BallDontLie::Client).to receive(:new).and_return(client) }

  describe "#call" do
    context "with CUT and made-cut rows" do
      let(:api_rows) do
        [
          {
            "player" => { "id" => 100, "display_name" => "Made Cut" },
            "position" => "T18",
            "position_numeric" => 18,
            "earnings" => nil
          },
          {
            "player" => { "id" => 200, "display_name" => "Missed" },
            "position" => "CUT",
            "position_numeric" => nil,
            "earnings" => nil
          }
        ]
      end

      it "upserts golfers and results with position_display, without prize_money or champion" do
        result = described_class.new(tournament: tournament, client: client).call

        expect(result[:total]).to eq(2)
        mc = tournament.tournament_results.joins(:golfer).find_by(golfers: { external_id: "200" })
        expect(mc.position_display).to eq("CUT")
        expect(mc.position).to be_nil
        expect(mc.prize_money).to be_nil

        made = tournament.tournament_results.joins(:golfer).find_by(golfers: { external_id: "100" })
        expect(made.position_display).to eq("T18")
        expect(made.position).to eq(18)

        expect(tournament.reload.champion_golfer_id).to be_nil
        expect(tournament.leaderboard_synced_at).to be_within(5.seconds).of(Time.current)
      end
    end

    context "when tournament has no external_id" do
      let(:tournament) { Tournament.create!(name: "Local", starts_at: 1.day.from_now, external_id: nil) }

      it "raises ArgumentError" do
        expect { described_class.new(tournament: tournament, client: client).call }
          .to raise_error(ArgumentError, /external_id/)
      end
    end
  end
end
```

**Implementation note:** For `position`, prefer `position_numeric` when present; for `CUT`/`WD`, leave `position` nil (do not use `"CUT".to_i` → 0).

- [ ] **Step 2: Run spec (fail)**

Run: `bundle exec rspec spec/services/ball_dont_lie/sync_live_leaderboard_spec.rb`

- [ ] **Step 3: Implement service**

```ruby
# frozen_string_literal: true

module BallDontLie
  class SyncLiveLeaderboard
    def initialize(tournament:, client: nil)
      @tournament = tournament.is_a?(Tournament) ? tournament : Tournament.find(tournament)
      @client = client || Client.new
    end

    def call
      external_id = @tournament.external_id.presence
      raise ArgumentError, "Tournament has no external_id (API id)" if external_id.blank?

      api_results = @client.fetch_all_tournament_results(tournament_ids: [ external_id.to_i ])
      created = updated = 0

      api_results.each do |r|
        player = r["player"]
        next if player.blank?

        golfer = Golfer.find_or_initialize_by(external_id: player["id"].to_s)
        golfer.name = player["display_name"].presence || [ player["first_name"], player["last_name"] ].compact.join(" ")
        golfer.save! if golfer.new_record? || golfer.changed?

        display = r["position"].presence&.to_s
        numeric = r["position_numeric"]
        numeric = numeric.to_i if numeric.present?
        numeric = nil if display.present? && TournamentResult::MISSED_CUT_POSITIONS.include?(display.upcase)

        row = TournamentResult.find_or_initialize_by(tournament: @tournament, golfer: golfer)
        row.position_display = display
        row.position = numeric
        # Do not write earnings during live sync — prize money arrives at completion.
        if row.new_record?
          row.save!
          created += 1
        elsif row.changed?
          row.save!
          updated += 1
        end
      end

      @tournament.update_column(:leaderboard_synced_at, Time.current)
      { created: created, updated: updated, total: api_results.size }
    end
  end
end
```

- [ ] **Step 4: Run spec (pass)**

- [ ] **Step 5: Commit**

```bash
git add app/services/ball_dont_lie/sync_live_leaderboard.rb spec/services/ball_dont_lie/sync_live_leaderboard_spec.rb
git commit -m "feat: sync live leaderboard positions without setting champion"
```

---

## Task 5: Harden `SyncTournamentResults` (final sync only)

**Files:**
- Modify: `app/services/ball_dont_lie/sync_tournament_results.rb`
- Modify: `spec/services/ball_dont_lie/sync_tournament_results_spec.rb`

- [ ] **Step 1: Write failing specs**

Add examples:

```ruby
it "stores position_display from API position string" do
  api_results = [
    {
      "player" => { "id" => 200, "display_name" => "Missed" },
      "position" => "CUT",
      "position_numeric" => nil,
      "earnings" => 0
    }
  ]
  # ... existing setup ...
  tr = tournament.tournament_results.joins(:golfer).find_by(golfers: { external_id: "200" })
  expect(tr.position_display).to eq("CUT")
  expect(tr.position).to be_nil
end

it "does not set champion when API tournament status is not COMPLETED" do
  allow(client).to receive(:tournament_completed?).and_return(false)
  api_results = [
    {
      "player" => { "id" => 185, "display_name" => "Leader" },
      "position" => "1",
      "position_numeric" => 1,
      "earnings" => nil,
      "tournament" => { "status" => "IN_PROGRESS" }
    }
  ]
  described_class.new(tournament: tournament, client: client).call
  expect(tournament.reload.champion_golfer_id).to be_nil
end

it "sets champion when API reports COMPLETED and position 1 exists" do
  allow(client).to receive(:tournament_completed?).and_return(true)
  # ... earnings populated, position 1 ...
  expect(tournament.reload.champion_golfer_id).to eq(scottie.id)
end
```

- [ ] **Step 2: Run specs (fail)**

- [ ] **Step 3: Update `SyncTournamentResults`**

Changes:
1. Set `result.position_display = r["position"].presence&.to_s` on every row.
2. Set `result.position` using same numeric rules as `SyncLiveLeaderboard` (no `"CUT".to_i`).
3. Inject `client` and call `client.tournament_completed?(external_id)` before champion assignment.
4. Only `update_column(:champion_golfer_id, ...)` when `tournament_completed?` is true.

```ruby
display = r["position"].presence&.to_s
numeric = r["position_numeric"]
numeric = numeric.present? ? numeric.to_i : nil
numeric = nil if display.present? && TournamentResult::MISSED_CUT_POSITIONS.include?(display.upcase)

result.position_display = display
result.position = numeric
result.prize_money = r["earnings"]
# ... save ...

if @client.tournament_completed?(external_id)
  winner_result = @tournament.tournament_results.find_by(position: 1)
  @tournament.update_column(:champion_golfer_id, winner_result.golfer_id) if winner_result
end
```

- [ ] **Step 4: Run specs (pass)**

Run: `bundle exec rspec spec/services/ball_dont_lie/sync_tournament_results_spec.rb`

- [ ] **Step 5: Commit**

```bash
git add app/services/ball_dont_lie/sync_tournament_results.rb spec/services/ball_dont_lie/sync_tournament_results_spec.rb
git commit -m "fix: persist position_display and only set champion when API is complete"
```

---

## Task 6: Wire live leaderboard sync into `RefreshLiveResultsJob`

**Files:**
- Modify: `app/jobs/refresh_live_results_job.rb`
- Modify: `spec/jobs/refresh_live_results_job_spec.rb`

- [ ] **Step 1: Write failing job spec**

```ruby
context "when the tournament is in progress" do
  before { tournament.update!(starts_at: 1.day.ago) }

  it "runs SyncLiveLeaderboard after SyncRoundResults" do
    round_svc = instance_double(BallDontLie::SyncRoundResults, call: {})
    leaderboard_svc = instance_double(BallDontLie::SyncLiveLeaderboard, call: { total: 0 })
    allow(BallDontLie::SyncRoundResults).to receive(:new).and_return(round_svc)
    expect(BallDontLie::SyncLiveLeaderboard).to receive(:new).with(tournament: tournament).and_return(leaderboard_svc)

    described_class.perform_now(tournament.id)
  end
end
```

- [ ] **Step 2: Run spec (fail)**

- [ ] **Step 3: Implement job**

```ruby
def perform(tournament_id)
  tournament = Tournament.find_by(id: tournament_id)
  return if tournament.nil? || tournament.external_id.blank?

  BallDontLie::SyncRoundResults.new(tournament: tournament).call

  if tournament.reload.started? && !tournament.completed?
    BallDontLie::SyncLiveLeaderboard.new(tournament: tournament).call
  end

  sync_final_results_if_needed!(tournament)
rescue => e
  # ...
end
```

- [ ] **Step 4: Run job specs (pass)**

- [ ] **Step 5: Commit**

```bash
git add app/jobs/refresh_live_results_job.rb spec/jobs/refresh_live_results_job_spec.rb
git commit -m "feat: refresh live leaderboard during in-progress tournaments"
```

---

## Task 7: `PoolTournamentScoringDisplay` service

**Files:**
- Create: `app/services/pool_tournament_scoring_display.rb`
- Create: `spec/services/pool_tournament_scoring_display_spec.rb`
- Modify: `app/controllers/pool_tournaments_controller.rb`

- [ ] **Step 1: Write failing unit specs**

Cover:
- Pre-cut: all bonuses nil, no projected totals forcing badges
- Post-cut with `position_display: "CUT"`: bonus `:mc`, projected earnings `0`
- Post-cut made cut with odds: numeric bonus
- Fallback R3 when no `TournamentResult` row
- Completed tournament uses prize_money + final rules (existing behavior)

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe PoolTournamentScoringDisplay do
  let(:tournament) { Tournament.create!(name: "Live", starts_at: 1.day.ago, external_id: "28", total_prize_pool: 10_000_000) }
  let(:pool_tournament) { PoolTournament.create!(pool: Pool.create!(name: "P", creator: User.create!(email: "a@a.com", name: "A", password: "x")), tournament: tournament) }
  let(:golfer) { Golfer.create!(name: "G", external_id: "100") }
  let(:odds_by_golfer) { { golfer.id => PoolTournamentOdds.create!(pool_tournament: pool_tournament, golfer: golfer, american_odds: 500, vendor: "dk", locked_at: Time.current) } }

  describe "#bonus_for" do
    it "returns :mc when cut posted and result is CUT" do
      TournamentResult.create!(tournament: tournament, golfer: golfer, position_display: "CUT")
      display = described_class.new(
        tournament: tournament,
        results_by_golfer: TournamentResult.where(tournament: tournament).index_by(&:golfer_id),
        odds_by_golfer: odds_by_golfer,
        round_results: {},
        current_round: 2
      )
      expect(display.bonus_for(golfer)).to eq(:mc)
    end
  end
end
```

Expand with `projected_total_for`, `show_counted_dropped_badges?`, `prize_money_for` in the same file.

- [ ] **Step 2: Implement service**

```ruby
# app/services/pool_tournament_scoring_display.rb
class PoolTournamentScoringDisplay
  def initialize(tournament:, results_by_golfer:, odds_by_golfer:, round_results:, current_round:)
    @tournament = tournament
    @results_by_golfer = results_by_golfer
    @odds_by_golfer = odds_by_golfer
    @round_results = round_results
    @current_round = current_round
  end

  def cut_posted?
    @tournament.cut_posted?
  end

  def show_counted_dropped_badges?
    @tournament.completed? || cut_posted?
  end

  def badges_projected?
    cut_posted? && !@tournament.completed?
  end

  def bonus_for(golfer)
    result = @results_by_golfer[golfer.id]
    odds_row = @odds_by_golfer[golfer.id]

    if @tournament.completed?
      return :mc unless result && @tournament.bonus_cut_eligible_result?(result) && odds_row
      return @tournament.capped_cut_made_bonus(odds_row.american_odds)
    end

    if result && cut_posted?
      return :mc if result.missed_cut?
      return @tournament.capped_cut_made_bonus(odds_row.american_odds) if odds_row
      return nil
    end

    infer_bonus_from_rounds(golfer, odds_row)
  end

  def prize_money_for(golfer)
    return nil unless @tournament.completed?
    result = @results_by_golfer[golfer.id]
    result ? (result.prize_money.to_d || 0) : nil
  end

  def projected_total_for(golfer)
    bonus_val = bonus_for(golfer)
    return nil if bonus_val.nil?
    return 0.to_d if bonus_val == :mc
    bonus_val.to_d
  end

  def total_earnings_for(golfer)
    prize = prize_money_for(golfer)
    bonus_val = bonus_for(golfer)
    return nil if prize.nil? && !bonus_val.is_a?(Numeric) && bonus_val != :mc
    return 0.to_d if bonus_val == :mc && prize.nil?
    prize.to_d + (bonus_val.is_a?(Numeric) ? bonus_val.to_d : 0.to_d)
  end

  private

  def infer_bonus_from_rounds(golfer, odds_row)
    player_result = @round_results[golfer.external_id&.to_i] || {}
    round_numbers = (player_result[:rounds] || {}).keys
    made_cut = round_numbers.any? { |r| r >= 3 }
    cut_known = @current_round.present? && @current_round >= 3
    missed_cut = cut_known && round_numbers.any? && !made_cut

    return @tournament.capped_cut_made_bonus(odds_row.american_odds) if made_cut && odds_row
    return :mc if missed_cut
    nil
  end
end
```

- [ ] **Step 3: Refactor controller**

Replace inline `@golfer_bonus_display` / `@golfer_prize_money` loops with:

```ruby
@scoring_display = PoolTournamentScoringDisplay.new(
  tournament: @tournament,
  results_by_golfer: results_by_golfer,
  odds_by_golfer: odds_by_golfer,
  round_results: @round_results,
  current_round: @current_round
)
@golfer_bonus_display = golfer_ids.index_with { |gid| @scoring_display.bonus_for(golfers_by_id[gid]) }
@golfer_prize_money = golfer_ids.index_with { |gid| @scoring_display.prize_money_for(golfers_by_id[gid]) }
@show_counted_dropped_badges = @scoring_display.show_counted_dropped_badges?
@badges_projected = @scoring_display.badges_projected?
```

Also enqueue live leaderboard on cold start (optional but recommended): after synchronous `SyncRoundResults`, call `SyncLiveLeaderboard` when `started? && !completed?`, then reload `results_by_golfer`.

- [ ] **Step 4: Run specs**

Run: `bundle exec rspec spec/services/pool_tournament_scoring_display_spec.rb spec/requests/pool_tournaments_show_spec.rb`

- [ ] **Step 5: Commit**

```bash
git add app/services/pool_tournament_scoring_display.rb spec/services/pool_tournament_scoring_display_spec.rb app/controllers/pool_tournaments_controller.rb
git commit -m "feat: centralize projected cut/bonus display logic for pool scoreboard"
```

---

## Task 8: View updates — badges, `$0`, projected label

**Files:**
- Modify: `app/views/pool_tournaments/show.html.erb`

- [ ] **Step 1: Update counted/dropped logic**

Use `@scoring_display.projected_total_for(g)` (or precompute `@counted_golfer_ids` in controller) only when `@show_counted_dropped_badges`:

```erb
<% if @show_counted_dropped_badges %>
  <% golfer_totals = pick.golfers.map { |g| [ g.id, @scoring_display.projected_total_for(g) || 0.to_d ] } %>
  <% counted_golfer_ids = golfer_totals.sort_by { |(_, total)| -total }.first(3).map(&:first) %>
<% else %>
  <% counted_golfer_ids = [] %>
<% end %>
```

- [ ] **Step 2: Badge markup**

```erb
<% if @show_counted_dropped_badges && counted_golfer_ids.include?(golfer.id) %>
  <span class="...">Counted<%= " (projected)" if @badges_projected %></span>
<% elsif @show_counted_dropped_badges %>
  <span class="...">Dropped<%= " (projected)" if @badges_projected %></span>
<% end %>
```

- [ ] **Step 3: Total earnings for MC post-cut**

```erb
<% total_earnings = @scoring_display.total_earnings_for(golfer) %>
...
<% if total_earnings.nil? %>
  —
<% elsif total_earnings.zero? %>
  $0
<% else %>
  ...
<% end %>
```

- [ ] **Step 4: Footnote copy**

Update footer when `@badges_projected`:

> Projected Counted/Dropped uses Cut Made Bonus only until final prize money is posted. Excluded golfers do not count toward the Total row.

- [ ] **Step 5: Commit**

```bash
git add app/views/pool_tournaments/show.html.erb
git commit -m "feat: show projected counted/dropped badges and zero earnings for MC after cut"
```

---

## Task 9: Request specs — end-to-end pool show behavior

**Files:**
- Modify: `spec/requests/pool_tournaments_show_spec.rb`

- [ ] **Step 1: Add post-cut live spec**

```ruby
it "shows MC and $0 total earnings when cut posted via position_display" do
  tournament.update!(total_prize_pool: 10_000_000)
  golfer = Golfer.create!(name: "Rory", external_id: "282")
  Pick.create!(user: member, pool_tournament: pool_tournament).tap { |p| PickGolfer.create!(pick: p, golfer: golfer, slot: 1) }
  PoolTournamentOdds.create!(pool_tournament: pool_tournament, golfer: golfer, american_odds: 400, vendor: "dk", locked_at: Time.current)
  TournamentResult.create!(tournament: tournament, golfer: golfer, position_display: "CUT")
  TournamentRoundResult.create!(tournament: tournament, golfer: golfer, round_number: 1, score_to_par: 1, last_hole_completed: 18)
  TournamentRoundResult.create!(tournament: tournament, golfer: golfer, round_number: 2, score_to_par: 2, last_hole_completed: 18)

  get pool_pool_tournament_path(pool, pool_tournament)

  expect(response.body).to include("MC")
  expect(response.body).to include("$0")
  expect(response.body).to include("projected")
  expect(response.body).not_to include("Dropped") # only one golfer — or adjust pick count
end
```

Add a four-golfer pick example asserting 3 Counted (projected) + 1 Dropped (projected) with known bonus ordering.

- [ ] **Step 2: Update existing spec**

`shows dash instead of MC when tournament is in progress and only provisional results exist` — change fixture to use `position: 80, prize_money: 0` **without** `position_display: "CUT"` (legacy incomplete row). With `position_display: "CUT"`, expect MC.

- [ ] **Step 3: Run request specs**

Run: `bundle exec rspec spec/requests/pool_tournaments_show_spec.rb`

- [ ] **Step 4: Commit**

```bash
git add spec/requests/pool_tournaments_show_spec.rb
git commit -m "test: cover live cut status on pool tournament scoreboard"
```

---

## Task 10: Admin tournament page safety

**Files:**
- Modify: `app/controllers/tournaments_controller.rb`
- Modify: `app/helpers/tournaments_helper.rb`

- [ ] **Step 1: Use `position_display` in `display_place`**

```ruby
def display_place(result, results)
  return result.position_display if result.position_display.present? && TournamentResult::MISSED_CUT_POSITIONS.include?(result.position_display.upcase)
  return "MC" if missed_cut?(result)
  # ... existing tie logic using numeric position ...
end
```

- [ ] **Step 2: Admin auto-sync**

In `auto_sync_field_and_results`, for in-progress tournaments call `SyncLiveLeaderboard` instead of full `SyncTournamentResults` unless `tournament_completed?` or earnings incomplete after champion exists.

- [ ] **Step 3: Manual smoke**

1. Start dev server, open a live pool tournament with picks.
2. Confirm badges hidden R1–R2 (no CUT rows in DB).
3. Run `BallDontLie::SyncLiveLeaderboard.new(tournament: t).call` in console for Charles Schwab (`external_id: 28`).
4. Reload scoreboard — CUT picks show MC + $0; made-cut picks show bonus; projected badges visible.

- [ ] **Step 4: Commit**

```bash
git add app/controllers/tournaments_controller.rb app/helpers/tournaments_helper.rb
git commit -m "fix: admin results sync uses live leaderboard without marking champion early"
```

---

## Task 11: Full regression

- [ ] **Step 1: Run targeted suites**

```bash
bundle exec rspec spec/models/tournament_result_spec.rb spec/models/tournament_spec.rb \
  spec/services/ball_dont_lie/sync_live_leaderboard_spec.rb \
  spec/services/ball_dont_lie/sync_tournament_results_spec.rb \
  spec/jobs/refresh_live_results_job_spec.rb \
  spec/services/pool_tournament_scoring_display_spec.rb \
  spec/requests/pool_tournaments_show_spec.rb spec/models/pool_spec.rb
```

- [ ] **Step 2: Run full suite (optional)**

`bundle exec rspec`

---

## Rollout & ops

- **No backfill required** for old tournaments; live behavior activates on next `RefreshLiveResultsJob` cycle (~30s debounce on page view).
- **API rate limit:** one extra `fetch_all_tournament_results` per refresh while in progress (~132 rows). Acceptable on ALL-STAR tier with existing 1.1s inter-page delay.
- **Champion safety:** verify no production tournament has `champion_golfer_id` set while `tournament_results` rows have null earnings — if any exist from admin sync, clear champion and re-sync after deploy.

---

## Out of scope (follow-ups)

- Pool **standings** column showing live projected points (would need product decision).
- Tee-time-based cut inference (API does not expose tee times).
- Showing leaderboard position `(T18)` in the scoreboard Total column from synced `position_display` (nice-to-have).

---

## Self-review (spec coverage)

| Requirement | Task |
|-------------|------|
| API `position: CUT` mid-tournament | Task 4–6 |
| Do not use earnings before complete | Tasks 4–5, 7 |
| Do not set champion early | Task 5 |
| MC + $0 after cut | Tasks 7–9 |
| Projected Counted/Dropped | Tasks 7–8 |
| Hide badges pre-cut | Tasks 7–8 |
| R3 round fallback | Task 7 |
| Admin sync safety | Task 10 |

**Plan complete and saved to `docs/plans/2026-05-30-live-cut-status-plan.md`.**

Two execution options:

1. **Subagent-Driven (recommended)** — fresh subagent per task, review between tasks  
2. **Inline Execution** — run tasks in this session with executing-plans checkpoints

Which approach do you want?

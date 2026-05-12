# Tournament Results Caching & Performance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the View Results page (`PoolTournamentsController#show`) load in <100ms for both live and completed tournaments by persisting per-round scores in the DB and replacing per-request API calls with a debounced background-refresh job.

**Architecture:** New `tournament_round_results` table is the read source for the page. A background `RefreshLiveResultsJob` (Solid Queue, concurrency-limited per tournament) writes to it via a new `BallDontLie::SyncRoundResults` service. The controller reads from the table, falls back to a synchronous one-shot sync if no rows exist yet, and enqueues the background job when the cached snapshot is older than 30s.

**Tech Stack:** Rails 8.1, RSpec (request + service + job specs), Solid Queue (already configured as production `queue_adapter`), Solid Cache (already configured as cache store but unused by this plan — DB is the source of truth).

**Reference design doc:** `docs/plans/2026-05-12-tournament-results-caching-design.md`

---

## File Structure

**Create:**
- `db/migrate/YYYYMMDDHHMMSS_create_tournament_round_results.rb` — schema migration; also adds `live_results_synced_at` to `tournaments` in the same migration.
- `app/models/tournament_round_result.rb` — AR model; validations; `par_relative` helper.
- `app/services/ball_dont_lie/sync_round_results.rb` — orchestration service for fetching round + scorecard data and upserting `tournament_round_results`.
- `app/jobs/refresh_live_results_job.rb` — thin Solid Queue job wrapping the service.
- `spec/models/tournament_round_result_spec.rb`
- `spec/services/ball_dont_lie/sync_round_results_spec.rb`
- `spec/jobs/refresh_live_results_job_spec.rb`

**Modify:**
- `app/services/ball_dont_lie/client.rb` — drop the leading `sleep` in `fetch_all` (sleep only between subsequent pages).
- `app/controllers/pool_tournaments_controller.rb` — rewrite `#show` request path to read from `TournamentRoundResult`, do synchronous fallback, enqueue background refresh.
- `app/models/tournament.rb` — add `has_many :tournament_round_results, dependent: :destroy`.
- `spec/requests/pool_tournaments_show_spec.rb` — add new request specs for: completed-with-persisted-TRR, live-fresh, live-stale, live-cold-start, completed-lazy-backfill.

**Untouched (verified):**
- `app/views/pool_tournaments/show.html.erb` — data contract preserved (`@round_results`, `@current_round`, etc.); no template changes.
- `app/services/ball_dont_lie/player_round_results_formatter.rb` — still used **inside** `SyncRoundResults` to merge scorecard hole-by-hole rows into per-round totals.
- `app/services/ball_dont_lie/sync_tournament_results.rb` — still used for final positions + earnings.

---

## Conventions

- **Test framework:** RSpec. Plain ActiveRecord setup with `let` (matches existing patterns in `spec/services/ball_dont_lie/`).
- **Client mocking:** `instance_double(BallDontLie::Client, ...)` + `allow(BallDontLie::Client).to receive(:new).and_return(client)`.
- **Job enqueue assertions:** `expect { ... }.to have_enqueued_job(RefreshLiveResultsJob).with(tournament.id)`.
- **Migrations:** Rails 8 `ActiveRecord::Migration[8.1]`, mirroring existing migrations.
- **Test DB:** `bin/rails db:migrate` runs against dev; `bin/rails db:test:prepare` (or `db:migrate RAILS_ENV=test`) prepares test DB. `maintain_test_schema!` in `rails_helper.rb` will keep test schema in sync.

---

## Task 1: Drop the leading sleep in `BallDontLie::Client#fetch_all`

**Files:**
- Modify: `app/services/ball_dont_lie/client.rb` (the `fetch_all` private method, lines 123–136)
- Test: there is currently no `spec/services/ball_dont_lie/client_spec.rb`. Create one.

- [ ] **Step 1: Write the failing test**

Create `spec/services/ball_dont_lie/client_spec.rb`:

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe BallDontLie::Client do
  let(:api_key) { "test-key" }

  before do
    stub_const("ENV", ENV.to_hash.merge("BALLDONTLIE_API_KEY" => api_key))
  end

  describe "#fetch_all (private; exercised via fetch_all_player_round_results)" do
    let(:client) { described_class.new(api_key: api_key) }

    it "does not sleep before fetching the first page" do
      page1 = { "data" => [ { "x" => 1 } ], "meta" => { "next_cursor" => nil, "per_page" => 100 } }
      allow(client).to receive(:player_round_results).and_return(page1)
      expect(client).not_to receive(:sleep)
      client.fetch_all_player_round_results(tournament_ids: [ 1 ], player_ids: [ 1 ])
    end

    it "sleeps between subsequent pages" do
      page1 = { "data" => Array.new(100, { "x" => 1 }), "meta" => { "next_cursor" => "abc", "per_page" => 100 } }
      page2 = { "data" => [ { "x" => 2 } ], "meta" => { "next_cursor" => nil, "per_page" => 100 } }
      allow(client).to receive(:player_round_results).and_return(page1, page2)
      expect(client).to receive(:sleep).once.with(BallDontLie::Client::RATE_LIMIT_DELAY)
      client.fetch_all_player_round_results(tournament_ids: [ 1 ], player_ids: [ 1 ])
    end
  end
end
```

Note on the constant: `RATE_LIMIT_DELAY` is private-ish (defined under `private` but as a top-level constant inside the class — `BallDontLie::Client::RATE_LIMIT_DELAY` works either way). Verify before running.

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/services/ball_dont_lie/client_spec.rb`
Expected: the "does not sleep before fetching the first page" test FAILS (current code calls `sleep` before each iteration including the first).

- [ ] **Step 3: Modify `fetch_all` to skip leading sleep**

In `app/services/ball_dont_lie/client.rb`, change the `fetch_all` method:

```ruby
def fetch_all(key, **opts)
  all = []
  cursor = nil
  first_page = true
  loop do
    sleep RATE_LIMIT_DELAY unless first_page
    first_page = false
    resp = yield cursor
    data = resp["data"] || []
    all.concat(data)
    meta = resp["meta"] || {}
    cursor = meta["next_cursor"]
    break if cursor.blank? || data.size < (meta["per_page"] || 100)
  end
  all
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/services/ball_dont_lie/client_spec.rb`
Expected: PASS (both specs green).

- [ ] **Step 5: Run the full test suite to confirm no regressions**

Run: `bundle exec rspec`
Expected: all green (or the same baseline as before this task).

- [ ] **Step 6: Commit**

```bash
git add app/services/ball_dont_lie/client.rb spec/services/ball_dont_lie/client_spec.rb
git commit -m "perf(ball_dont_lie): skip leading sleep before first page in fetch_all"
```

---

## Task 2: Migration — `tournament_round_results` table + `live_results_synced_at` column

**Files:**
- Create: `db/migrate/<timestamp>_create_tournament_round_results.rb`

- [ ] **Step 1: Generate the migration file**

Run: `bin/rails generate migration CreateTournamentRoundResults`
This produces an empty migration at `db/migrate/<timestamp>_create_tournament_round_results.rb`.

- [ ] **Step 2: Write the migration body**

Replace the generated file's contents with:

```ruby
class CreateTournamentRoundResults < ActiveRecord::Migration[8.1]
  def change
    create_table :tournament_round_results do |t|
      t.references :tournament, null: false, foreign_key: true
      t.references :golfer, null: false, foreign_key: true
      t.integer :round_number, null: false
      t.integer :score_to_par
      t.integer :last_hole_completed

      t.timestamps
    end
    add_index :tournament_round_results,
              [ :tournament_id, :golfer_id, :round_number ],
              unique: true,
              name: "idx_trr_tournament_golfer_round"

    add_column :tournaments, :live_results_synced_at, :datetime
  end
end
```

- [ ] **Step 3: Run the migration against dev and test**

Run: `bin/rails db:migrate`
Run: `bin/rails db:migrate RAILS_ENV=test`

Expected: both succeed with no errors; `db/schema.rb` is updated.

- [ ] **Step 4: Verify schema**

Run: `bin/rails runner 'p TournamentRoundResult rescue p Tournament.columns_hash["live_results_synced_at"]&.type'`
Expected: `:datetime` printed (the `TournamentRoundResult` class doesn't exist yet, so the `rescue` falls through and prints the column type).

Or just inspect `db/schema.rb` for both:
- `create_table "tournament_round_results"` with the listed columns and unique index
- `t.datetime "live_results_synced_at"` on `tournaments`

- [ ] **Step 5: Commit**

```bash
git add db/migrate db/schema.rb
git commit -m "feat: add tournament_round_results table and live_results_synced_at column"
```

---

## Task 3: `TournamentRoundResult` model

**Files:**
- Create: `app/models/tournament_round_result.rb`
- Modify: `app/models/tournament.rb` — add `has_many :tournament_round_results, dependent: :destroy`
- Test: `spec/models/tournament_round_result_spec.rb`

- [ ] **Step 1: Write the failing model spec**

Create `spec/models/tournament_round_result_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe TournamentRoundResult, type: :model do
  let(:tournament) { Tournament.create!(name: "Masters", starts_at: 1.day.ago, ends_at: 1.day.from_now, external_id: "20") }
  let(:golfer) { Golfer.create!(name: "Scottie", external_id: "185") }

  describe "validations" do
    it "requires tournament, golfer, and round_number" do
      trr = described_class.new
      expect(trr).not_to be_valid
      expect(trr.errors[:tournament]).to be_present
      expect(trr.errors[:golfer]).to be_present
      expect(trr.errors[:round_number]).to be_present
    end

    it "validates round_number is between 1 and 4" do
      [ 0, 5, -1 ].each do |bad|
        trr = described_class.new(tournament: tournament, golfer: golfer, round_number: bad)
        expect(trr).not_to be_valid, "expected round_number=#{bad} to be invalid"
        expect(trr.errors[:round_number]).to be_present
      end
      (1..4).each do |good|
        trr = described_class.new(tournament: tournament, golfer: golfer, round_number: good)
        expect(trr).to be_valid, "expected round_number=#{good} to be valid"
      end
    end

    it "enforces uniqueness on (tournament_id, golfer_id, round_number)" do
      described_class.create!(tournament: tournament, golfer: golfer, round_number: 1)
      dup = described_class.new(tournament: tournament, golfer: golfer, round_number: 1)
      expect(dup).not_to be_valid
      expect(dup.errors[:round_number]).to be_present
    end
  end

  describe "#par_relative" do
    it "formats score_to_par as +N / -N / E / nil" do
      expect(described_class.new(score_to_par: 0).par_relative).to eq("E")
      expect(described_class.new(score_to_par: 3).par_relative).to eq("+3")
      expect(described_class.new(score_to_par: -2).par_relative).to eq("-2")
      expect(described_class.new(score_to_par: nil).par_relative).to be_nil
    end
  end
end
```

- [ ] **Step 2: Run the spec to verify it fails**

Run: `bundle exec rspec spec/models/tournament_round_result_spec.rb`
Expected: FAIL — `TournamentRoundResult` is uninitialized constant.

- [ ] **Step 3: Create the model**

Create `app/models/tournament_round_result.rb`:

```ruby
class TournamentRoundResult < ApplicationRecord
  belongs_to :tournament
  belongs_to :golfer

  validates :round_number, presence: true,
                           inclusion: { in: 1..4, message: "must be between 1 and 4" },
                           uniqueness: { scope: [ :tournament_id, :golfer_id ] }

  def par_relative
    return nil if score_to_par.nil?
    v = score_to_par.to_i
    return "E" if v.zero?
    v.positive? ? "+#{v}" : v.to_s
  end
end
```

- [ ] **Step 4: Add the has_many association on Tournament**

In `app/models/tournament.rb`, add the association alongside the existing `has_many` declarations:

```ruby
has_many :tournament_round_results, dependent: :destroy
```

(Insert near the other `has_many` lines, e.g. after `has_many :tournament_results, dependent: :destroy`.)

- [ ] **Step 5: Run the model spec to verify it passes**

Run: `bundle exec rspec spec/models/tournament_round_result_spec.rb`
Expected: PASS.

- [ ] **Step 6: Run the full suite for sanity**

Run: `bundle exec rspec`
Expected: all green.

- [ ] **Step 7: Commit**

```bash
git add app/models/tournament_round_result.rb app/models/tournament.rb spec/models/tournament_round_result_spec.rb
git commit -m "feat: add TournamentRoundResult model"
```

---

## Task 4: `BallDontLie::SyncRoundResults` service

**Files:**
- Create: `app/services/ball_dont_lie/sync_round_results.rb`
- Test: `spec/services/ball_dont_lie/sync_round_results_spec.rb`

**Service contract:**
- `initialize(tournament:, player_ids: nil, client: nil)`
  - `player_ids` is optional. When nil, the service derives the union of:
    - All picked golfers' external_ids across every `Pick` for this tournament, and
    - For completed no-cut events, the persisted field golfers' external_ids.
  - Passing `player_ids` explicitly is used by the controller's synchronous-fallback path so it never re-derives.
- `call` performs:
  1. Validates `tournament.external_id.present?`.
  2. Fetches `client.fetch_all_player_round_results(tournament_ids:, player_ids:)`.
  3. Uses `PlayerRoundResultsFormatter.new(raw)` to build the per-player/per-round hash.
  4. If `tournament.started? && !tournament.completed?`, fetches `client.fetch_all_player_scorecards(tournament_ids:, player_ids:, round_number: formatter.current_round_number)` (current round only). Then `formatter.merge_scorecard_live!(scorecards)`.
  5. Upserts `TournamentRoundResult` rows from `formatter.by_player_id` (one row per player × round with non-nil data).
  6. Sets `tournament.update_column(:live_results_synced_at, Time.current)`.
  7. Returns a small summary hash `{ created:, updated:, rounds_seen: }`.

- [ ] **Step 1: Write the failing service spec**

Create `spec/services/ball_dont_lie/sync_round_results_spec.rb`:

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe BallDontLie::SyncRoundResults do
  let(:tournament) { Tournament.create!(name: "Masters", starts_at: 1.day.ago, ends_at: 1.day.from_now, external_id: "20") }
  let(:scottie) { Golfer.create!(name: "Scottie", external_id: "185") }
  let(:rory) { Golfer.create!(name: "Rory", external_id: "282") }

  let(:client) do
    instance_double(BallDontLie::Client,
                    fetch_all_player_round_results: round_results_payload,
                    fetch_all_player_scorecards: scorecards_payload)
  end
  let(:round_results_payload) { [] }
  let(:scorecards_payload) { [] }

  describe "#call" do
    context "when tournament has no external_id" do
      let(:tournament) { Tournament.create!(name: "Local", starts_at: 1.day.from_now, ends_at: 4.days.from_now, external_id: nil) }

      it "raises ArgumentError" do
        expect {
          described_class.new(tournament: tournament, player_ids: [ 1 ], client: client).call
        }.to raise_error(ArgumentError, /external_id/)
      end
    end

    context "with completed-round data only" do
      let(:round_results_payload) do
        [
          { "player" => { "id" => 185 }, "round_number" => 1, "par_relative_score" => -2 },
          { "player" => { "id" => 185 }, "round_number" => 2, "par_relative_score" => 1 }
        ]
      end

      it "creates TournamentRoundResult rows for each (player, round)" do
        scottie # touch to create the golfer
        result = described_class.new(tournament: tournament, player_ids: [ 185 ], client: client).call

        rows = tournament.tournament_round_results.order(:round_number)
        expect(rows.size).to eq(2)
        expect(rows.map(&:round_number)).to eq([ 1, 2 ])
        expect(rows.map(&:score_to_par)).to eq([ -2, 1 ])
        expect(rows.map(&:last_hole_completed)).to eq([ 18, 18 ])
        expect(result[:created]).to eq(2)
        expect(result[:updated]).to eq(0)
      end

      it "updates live_results_synced_at" do
        scottie
        described_class.new(tournament: tournament, player_ids: [ 185 ], client: client).call
        expect(tournament.reload.live_results_synced_at).to be_within(5.seconds).of(Time.current)
      end

      it "does not fetch scorecards when the tournament is completed" do
        scottie
        winner = Golfer.create!(name: "Winner", external_id: "9991")
        tournament.update!(champion_golfer: winner)

        expect(client).not_to receive(:fetch_all_player_scorecards)
        described_class.new(tournament: tournament, player_ids: [ 185 ], client: client).call
      end
    end

    context "when the tournament is live and a round is in progress" do
      let(:round_results_payload) do
        [ { "player" => { "id" => 185 }, "round_number" => 1, "par_relative_score" => -2 } ]
      end
      let(:scorecards_payload) do
        # Round 2 hole-by-hole, player 185 played 9 holes at -3 vs par
        (1..9).map do |hole|
          { "player" => { "id" => 185 }, "round_number" => 2, "hole_number" => hole, "score" => 3, "par" => (hole == 1 ? 4 : 3) }
        end
      end

      it "fetches the current round's scorecards and persists the in-progress round" do
        scottie
        expect(client).to receive(:fetch_all_player_scorecards)
          .with(hash_including(tournament_ids: [ 20 ], player_ids: [ 185 ], round_number: 1))
          .and_return(scorecards_payload)
        # Note: current_round_number from formatter = 1 (only round in the payload), so we ask for round_number: 1.

        described_class.new(tournament: tournament, player_ids: [ 185 ], client: client).call

        live_row = tournament.tournament_round_results.find_by(round_number: 2)
        expect(live_row).to be_present
        expect(live_row.score_to_par).to be_a(Integer)
        expect(live_row.last_hole_completed).to eq(9)
      end
    end

    context "when called twice (idempotent upsert)" do
      let(:round_results_payload) do
        [ { "player" => { "id" => 185 }, "round_number" => 1, "par_relative_score" => -2 } ]
      end

      it "does not create duplicate rows" do
        scottie
        svc = described_class.new(tournament: tournament, player_ids: [ 185 ], client: client)
        svc.call
        expect { svc.call }.not_to change { TournamentRoundResult.count }
      end
    end

    context "when player_ids is omitted" do
      let(:pool) { Pool.create!(name: "P", creator: User.create!(email: "u@e.com", name: "U", password: "password")) }
      let(:pool_tournament) { PoolTournament.create!(pool: pool, tournament: tournament) }

      before do
        pick = Pick.create!(user: pool.creator, pool_tournament: pool_tournament)
        PickGolfer.create!(pick: pick, golfer: scottie, slot: 1)
        PickGolfer.create!(pick: pick, golfer: rory, slot: 2)
      end

      it "derives player_ids from picks for the tournament" do
        expect(client).to receive(:fetch_all_player_round_results)
          .with(hash_including(tournament_ids: [ 20 ], player_ids: a_collection_including(185, 282)))
          .and_return([])

        described_class.new(tournament: tournament, client: client).call
      end
    end
  end
end
```

- [ ] **Step 2: Run the spec to verify it fails**

Run: `bundle exec rspec spec/services/ball_dont_lie/sync_round_results_spec.rb`
Expected: FAIL — `BallDontLie::SyncRoundResults` is uninitialized constant.

- [ ] **Step 3: Implement the service**

Create `app/services/ball_dont_lie/sync_round_results.rb`:

```ruby
# frozen_string_literal: true

module BallDontLie
  class SyncRoundResults
    def initialize(tournament:, player_ids: nil, client: nil)
      @tournament = tournament.is_a?(Tournament) ? tournament : Tournament.find(tournament)
      @player_ids = player_ids
      @client = client || Client.new
    end

    def call
      external_id = @tournament.external_id.presence
      raise ArgumentError, "Tournament has no external_id (API id)" if external_id.blank?

      pids = (@player_ids || derive_player_ids).uniq.reject { |id| id.to_i.zero? }
      tournament_ids = [ external_id.to_i ]

      raw = @client.fetch_all_player_round_results(tournament_ids: tournament_ids, player_ids: pids)
      formatter = PlayerRoundResultsFormatter.new(raw)

      if @tournament.started? && !@tournament.completed?
        current_round = formatter.current_round_number
        if current_round.present?
          cards = @client.fetch_all_player_scorecards(
            tournament_ids: tournament_ids,
            player_ids: pids,
            round_number: current_round
          )
          formatter.merge_scorecard_live!(cards) if cards.present?
        end
      end

      stats = upsert_rows(formatter.by_player_id)
      @tournament.update_column(:live_results_synced_at, Time.current)
      stats
    end

    private

    def derive_player_ids
      ids = Pick
              .joins(pick_golfers: :golfer)
              .where(pool_tournament: PoolTournament.where(tournament_id: @tournament.id))
              .pluck("golfers.external_id")
              .compact
              .map(&:to_i)

      if @tournament.completed? && @tournament.no_cut_event?
        field_ids = @tournament.tournament_fields.joins(:golfer).pluck("golfers.external_id").compact.map(&:to_i)
        ids = (ids + field_ids)
      end

      ids.uniq
    end

    def upsert_rows(by_player_id)
      created = 0
      updated = 0
      golfer_id_cache = {}

      by_player_id.each do |player_id, payload|
        golfer_id = (golfer_id_cache[player_id] ||= Golfer.where(external_id: player_id.to_s).pick(:id))
        next if golfer_id.nil? # if we don't have the golfer locally yet, skip; field-sync owns golfer creation

        payload[:rounds].each do |round_number, round_data|
          row = TournamentRoundResult.find_or_initialize_by(
            tournament_id: @tournament.id,
            golfer_id: golfer_id,
            round_number: round_number
          )
          row.score_to_par = round_data[:score_to_par]
          row.last_hole_completed = round_data[:last_hole_completed]
          if row.new_record?
            row.save!
            created += 1
          elsif row.changed?
            row.save!
            updated += 1
          end
        end
      end

      { created: created, updated: updated, rounds_seen: by_player_id.values.sum { |p| p[:rounds].size } }
    end
  end
end
```

Notes for the engineer:
- `player_round_results_formatter.rb` already exposes `by_player_id`, `current_round_number`, and `merge_scorecard_live!` (see `app/services/ball_dont_lie/player_round_results_formatter.rb`). We deliberately reuse that logic so existing formatter tests cover the parsing math.
- The `Golfer.where(external_id: ...).pick(:id)` lookup avoids loading the AR object. If the golfer doesn't exist locally (rare; should already be present from `SyncTournamentField` or earlier picks), we skip it; the existing field-sync job is responsible for creating golfers.
- `update_column` is intentional — it skips validations and the `updated_at` bump that would happen with `update!` on the tournament. We only care about that one column.

- [ ] **Step 4: Run the spec to verify it passes**

Run: `bundle exec rspec spec/services/ball_dont_lie/sync_round_results_spec.rb`
Expected: PASS (all contexts green).

If the "live and a round is in progress" test fails because `formatter.current_round_number` returns 1 (only round_number in payload) but the scorecards payload has round 2, you need to either: (a) include a round 2 entry in the payload so formatter sees it, or (b) accept that the formatter's current-round logic targets the highest round seen in `player_round_results`. The cleaner fix is to make the test mirror real API data: `player_round_results` includes round 2 stub too. **Update the test fixture** to include a round 2 entry in `round_results_payload` if needed, then re-run.

- [ ] **Step 5: Run the full suite**

Run: `bundle exec rspec`
Expected: all green.

- [ ] **Step 6: Commit**

```bash
git add app/services/ball_dont_lie/sync_round_results.rb spec/services/ball_dont_lie/sync_round_results_spec.rb
git commit -m "feat: add BallDontLie::SyncRoundResults service"
```

---

## Task 5: `RefreshLiveResultsJob`

**Files:**
- Create: `app/jobs/refresh_live_results_job.rb`
- Test: `spec/jobs/refresh_live_results_job_spec.rb`

**Behavior:**
- `perform(tournament_id)`:
  1. Loads the tournament; no-op if missing or no `external_id`.
  2. Invokes `BallDontLie::SyncRoundResults.new(tournament:).call`.
  3. If, after sync, the tournament appears completed (`champion_golfer_id` present) but results are incomplete (`tournament_results_earnings_incomplete?`), also invokes `BallDontLie::SyncTournamentResults.new(tournament:).call`.
  4. Logs and swallows exceptions to avoid hot-looping Solid Queue retries on permanent data issues (matches `SyncTournamentFieldJob`'s pattern). Transient errors will get re-enqueued on the next stale page view anyway.
- Concurrency: `limits_concurrency to: 1, key: ->(tournament_id) { "tournament_#{tournament_id}" }`. This prevents Solid Queue from running two refreshes for the same tournament concurrently.

- [ ] **Step 1: Write the failing job spec**

Create `spec/jobs/refresh_live_results_job_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe RefreshLiveResultsJob, type: :job do
  let(:tournament) { Tournament.create!(name: "Masters", starts_at: 1.day.ago, ends_at: 1.day.from_now, external_id: "20") }

  it "invokes BallDontLie::SyncRoundResults for the tournament" do
    svc = instance_double(BallDontLie::SyncRoundResults, call: { created: 0, updated: 0, rounds_seen: 0 })
    expect(BallDontLie::SyncRoundResults).to receive(:new).with(tournament: tournament).and_return(svc)
    described_class.perform_now(tournament.id)
  end

  it "no-ops gracefully when the tournament does not exist" do
    expect(BallDontLie::SyncRoundResults).not_to receive(:new)
    expect { described_class.perform_now(0) }.not_to raise_error
  end

  it "no-ops when tournament has no external_id" do
    t = Tournament.create!(name: "Local", starts_at: 1.day.from_now, ends_at: 4.days.from_now, external_id: nil)
    expect(BallDontLie::SyncRoundResults).not_to receive(:new)
    described_class.perform_now(t.id)
  end

  it "logs and swallows service errors" do
    svc = instance_double(BallDontLie::SyncRoundResults)
    allow(BallDontLie::SyncRoundResults).to receive(:new).and_return(svc)
    allow(svc).to receive(:call).and_raise("boom")
    expect(Rails.logger).to receive(:error).with(/RefreshLiveResultsJob.*boom/)
    expect { described_class.perform_now(tournament.id) }.not_to raise_error
  end

  context "when the tournament has a champion but earnings are incomplete after the round sync" do
    let!(:winner) { Golfer.create!(name: "Winner", external_id: "9991") }

    before do
      tournament.update!(champion_golfer: winner)
      TournamentResult.create!(tournament: tournament, golfer: winner, position: 1, prize_money: 0)
    end

    it "runs SyncTournamentResults after the round sync" do
      round_svc = instance_double(BallDontLie::SyncRoundResults, call: {})
      final_svc = instance_double(BallDontLie::SyncTournamentResults, call: {})
      allow(BallDontLie::SyncRoundResults).to receive(:new).and_return(round_svc)
      expect(BallDontLie::SyncTournamentResults).to receive(:new).with(tournament: tournament).and_return(final_svc)

      described_class.perform_now(tournament.id)
    end
  end
end
```

- [ ] **Step 2: Run the spec to verify it fails**

Run: `bundle exec rspec spec/jobs/refresh_live_results_job_spec.rb`
Expected: FAIL — `RefreshLiveResultsJob` is uninitialized constant.

- [ ] **Step 3: Implement the job**

Create `app/jobs/refresh_live_results_job.rb`:

```ruby
class RefreshLiveResultsJob < ApplicationJob
  queue_as :default

  limits_concurrency to: 1, key: ->(tournament_id) { "tournament_#{tournament_id}" }

  def perform(tournament_id)
    tournament = Tournament.find_by(id: tournament_id)
    return if tournament.nil? || tournament.external_id.blank?

    BallDontLie::SyncRoundResults.new(tournament: tournament).call

    tournament.reload
    if tournament.champion_golfer_id.present? && tournament.tournament_results_earnings_incomplete?
      BallDontLie::SyncTournamentResults.new(tournament: tournament).call
    end
  rescue => e
    Rails.logger.error("RefreshLiveResultsJob failed for tournament #{tournament_id}: #{e.class}: #{e.message}")
  end
end
```

Note on `limits_concurrency`: it's provided by Solid Queue's `ConcurrencyControls` mixin, included automatically when `ActiveJob::QueueAdapters::SolidQueueAdapter` is the adapter. In `test` env the default adapter is `:test`, so `limits_concurrency` may be a no-op there — that's fine, we don't test enforcement, only the call to the service. If the `limits_concurrency` macro is not recognized in test (NoMethodError on class load), wrap it:

```ruby
limits_concurrency(to: 1, key: ->(tournament_id) { "tournament_#{tournament_id}" }) if respond_to?(:limits_concurrency)
```

Try the unconditional form first; only add the guard if class loading fails in test.

- [ ] **Step 4: Run the spec to verify it passes**

Run: `bundle exec rspec spec/jobs/refresh_live_results_job_spec.rb`
Expected: PASS.

- [ ] **Step 5: Run the full suite**

Run: `bundle exec rspec`
Expected: all green.

- [ ] **Step 6: Commit**

```bash
git add app/jobs/refresh_live_results_job.rb spec/jobs/refresh_live_results_job_spec.rb
git commit -m "feat: add RefreshLiveResultsJob with per-tournament concurrency limit"
```

---

## Task 6: Refactor `PoolTournamentsController#show`

**Files:**
- Modify: `app/controllers/pool_tournaments_controller.rb` (the `#show` action)
- Modify: `spec/requests/pool_tournaments_show_spec.rb` (add new request specs)

**Key behavior changes:**
1. The controller **no longer calls** `client.fetch_all_player_round_results` or `client.fetch_all_player_scorecards` directly.
2. Round-by-round display data comes from `TournamentRoundResult` rows reshaped into the same `@round_results` hash the view expects:

   ```ruby
   {
     player_external_id => {
       rounds: { 1 => { par_relative: "+3", score_to_par: 3, last_hole_completed: 18, score: nil }, ... },
       total_to_par: 5,
       position: nil
     },
     ...
   }
   ```

   Note: `position` is no longer populated from `player_round_results` (the API endpoint we dropped). For live tournaments, position changes hole-by-hole and we never persisted it. For completed tournaments, position lives on `TournamentResult` and is rendered via `@golfer_prize_money` / `@golfer_bonus_display`, not via `@round_results[:position]`. The view file conditionally renders `player_result[:position]` (line 112-114 of `show.html.erb`); a `nil` here renders no parenthetical, which is acceptable. (No template change needed.)
3. Cold-start fallback: if the relevant `TournamentRoundResult` rows are empty AND the tournament has an `external_id` AND the tournament is `started?` (either live or completed), call `BallDontLie::SyncRoundResults.new(tournament:, player_ids: player_ids).call` synchronously, then re-query.
4. Stale-snapshot async refresh: if the tournament is `started? && !completed?` AND (`live_results_synced_at` is nil OR older than 30 seconds), `RefreshLiveResultsJob.perform_later(tournament.id)`. Don't wait.
5. Keep existing behavior for `SyncTournamentResults` (auto-sync final results when `results_synced_since_completion?` is false or earnings are incomplete).

- [ ] **Step 1: Add a private helper for building the @round_results hash from TRR rows**

We can keep this inside the controller since it's small and request-scoped. Plan to add to `PoolTournamentsController`:

```ruby
private

def build_round_results_hash(round_rows_by_player_external_id)
  result = {}
  round_rows_by_player_external_id.each do |player_external_id, rows|
    rounds = {}
    rows.each do |row|
      rounds[row.round_number] = {
        score: nil,
        par_relative: row.par_relative,
        score_to_par: row.score_to_par,
        last_hole_completed: row.last_hole_completed
      }
    end
    total = rounds.values.sum { |r| (r[:score_to_par] || 0).to_i }
    result[player_external_id] = {
      rounds: rounds,
      total_to_par: rounds.any? ? total : nil,
      position: nil
    }
  end
  result
end
```

- [ ] **Step 2: Write failing request specs for the new behavior**

Append to `spec/requests/pool_tournaments_show_spec.rb` (inside the existing `describe "GET /pools/:pool_token/pool_tournaments/:id"` block):

```ruby
context "with persisted TournamentRoundResult rows" do
  let!(:golfer) { Golfer.create!(name: "Scottie", external_id: "185") }
  let!(:pick) do
    Pick.create!(user: member, pool_tournament: pool_tournament).tap do |p|
      PickGolfer.create!(pick: p, golfer: golfer, slot: 1)
    end
  end

  before do
    TournamentRoundResult.create!(tournament: tournament, golfer: golfer, round_number: 1, score_to_par: -3, last_hole_completed: 18)
    TournamentRoundResult.create!(tournament: tournament, golfer: golfer, round_number: 2, score_to_par: -1, last_hole_completed: 18)
    tournament.update_column(:live_results_synced_at, 5.seconds.ago)
  end

  it "renders from DB without calling the API and without enqueuing a refresh" do
    # No mocks: if the controller tries to call BallDontLie::Client.new, this test fails because
    # the API key env var isn't set in the test environment (or because we haven't mocked the call).
    expect(BallDontLie::Client).not_to receive(:new)
    expect {
      get pool_pool_tournament_path(pool, pool_tournament)
    }.not_to have_enqueued_job(RefreshLiveResultsJob)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Scottie")
    expect(response.body).to include("-3")
    expect(response.body).to include("-1")
  end

  it "enqueues RefreshLiveResultsJob when the snapshot is stale" do
    tournament.update_column(:live_results_synced_at, 2.minutes.ago)

    expect {
      get pool_pool_tournament_path(pool, pool_tournament)
    }.to have_enqueued_job(RefreshLiveResultsJob).with(tournament.id)
  end

  it "does not enqueue RefreshLiveResultsJob for a completed tournament" do
    winner = Golfer.create!(name: "Winner", external_id: "9991")
    tournament.update!(champion_golfer: winner)
    # Pre-create a complete winner TournamentResult so `tournament_results_earnings_incomplete?` is false
    # and the synchronous SyncTournamentResults auto-call is skipped (no client mock needed).
    TournamentResult.create!(tournament: tournament, golfer: winner, position: 1, prize_money: 2_000_000)
    tournament.update_column(:live_results_synced_at, 2.minutes.ago)

    expect(BallDontLie::Client).not_to receive(:new)
    expect {
      get pool_pool_tournament_path(pool, pool_tournament)
    }.not_to have_enqueued_job(RefreshLiveResultsJob)
  end
end

context "with no persisted round data (cold start)" do
  let!(:golfer) { Golfer.create!(name: "Scottie", external_id: "185") }
  let!(:pick) do
    Pick.create!(user: member, pool_tournament: pool_tournament).tap do |p|
      PickGolfer.create!(pick: p, golfer: golfer, slot: 1)
    end
  end

  it "runs a synchronous SyncRoundResults and renders the resulting rows" do
    svc = instance_double(BallDontLie::SyncRoundResults)
    expect(BallDontLie::SyncRoundResults).to receive(:new).with(tournament: tournament, player_ids: include(185)).and_return(svc)
    expect(svc).to receive(:call) do
      TournamentRoundResult.create!(tournament: tournament, golfer: golfer, round_number: 1, score_to_par: -2, last_hole_completed: 18)
      tournament.update_column(:live_results_synced_at, Time.current)
      { created: 1, updated: 0, rounds_seen: 1 }
    end

    get pool_pool_tournament_path(pool, pool_tournament)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("-2")
  end
end
```

Also: the **existing** specs in this file (`fetch_all_player_round_results` mocked etc.) still need to pass. Most should continue to work because:
- When picks exist and TRR is empty → controller falls back to synchronous `SyncRoundResults`, which under the hood calls the mocked client.
- The mocked client returns `[]` in the basic case, so `TournamentRoundResult` stays empty and the view shows `—` (which the existing assertions accept).

Two existing tests that **pre-seed `raw_round_results`** to drive UI behavior ("shows Cut Made Bonus from live round data when no TournamentResult yet" and "shows marginal total-to-par on synthetic-cut banner") will still go through the synchronous fallback path; the mocked `fetch_all_player_round_results` returns the configured payload, the service writes TRR rows, the controller reads them, and the view renders. Verify these still pass after the refactor.

- [ ] **Step 3: Run the spec to verify the new tests fail**

Run: `bundle exec rspec spec/requests/pool_tournaments_show_spec.rb`
Expected: the **new** contexts fail (referencing `RefreshLiveResultsJob` enqueue, or expecting no API call). Existing tests may continue to pass.

- [ ] **Step 4: Refactor the controller**

Replace the body of `PoolTournamentsController#show` with this implementation. The action's high-level shape:

```ruby
def show
  @pool_tournament = PoolTournament.includes(:pool_tournament_odds).find(params[:id])
  @pool = @pool_tournament.pool
  @tournament = @pool_tournament.tournament

  unless @pool.users.include?(current_user)
    redirect_to @pool, alert: "You must be a member of this pool to view scores."
    return
  end

  @picks_by_user = Pick
    .includes(:golfers)
    .where(pool_tournament: @pool_tournament)
    .group_by(&:user)

  picked_golfers = @picks_by_user.values.flatten.flat_map(&:golfers).uniq
  player_ids = picked_golfers.map { |g| g.external_id&.to_i }.compact.reject(&:zero?).uniq

  if @tournament.completed? && @tournament.no_cut_event?
    field_ids = @tournament.tournament_results.includes(:golfer).filter_map { |tr| tr.golfer&.external_id&.to_i }
    player_ids = (player_ids + field_ids).uniq.reject(&:zero?)
  end

  @synthetic_cut_marginal_total_to_par = nil
  @round_results = {}
  @current_round = nil

  if @tournament.external_id.present? && player_ids.any?
    relevant_golfer_ids = Golfer.where(external_id: player_ids.map(&:to_s)).pluck(:id)

    rows = TournamentRoundResult
             .where(tournament_id: @tournament.id, golfer_id: relevant_golfer_ids)
             .includes(:golfer)
             .to_a

    if rows.empty? && (@tournament.started? || @tournament.completed?)
      begin
        BallDontLie::SyncRoundResults.new(tournament: @tournament, player_ids: player_ids).call
        rows = TournamentRoundResult
                 .where(tournament_id: @tournament.id, golfer_id: relevant_golfer_ids)
                 .includes(:golfer)
                 .to_a
      rescue => e
        Rails.logger.error("[PoolTournament scores] Synchronous SyncRoundResults failed for tournament #{@tournament.id}: #{e.class}: #{e.message}")
      end
    end

    by_player_external_id = rows.group_by { |r| r.golfer.external_id&.to_i }.compact
    @round_results = build_round_results_hash(by_player_external_id)
    @current_round = rows.map(&:round_number).max if rows.any?

    if @tournament.started? && !@tournament.completed?
      stale = @tournament.live_results_synced_at.nil? || @tournament.live_results_synced_at < 30.seconds.ago
      RefreshLiveResultsJob.perform_later(@tournament.id) if stale
    end

    if @tournament.completed? && @tournament.no_cut_event?
      @synthetic_cut_marginal_total_to_par = @tournament.marginal_bonus_eligible_total_to_par(@round_results)
    end
  end

  if @tournament.external_id.present? &&
      @tournament.completed? &&
      @tournament.tournament_results_earnings_incomplete?
    begin
      BallDontLie::SyncTournamentResults.new(tournament: @tournament).call
      @tournament.reload
    rescue => e
      Rails.logger.error("[PoolTournament scores] Failed to auto-sync results for tournament #{@tournament.id}: #{e.class}: #{e.message}")
    end
  end

  # Bonus and prize-money computation: UNCHANGED from existing implementation.
  golfers_by_id = {}
  @picks_by_user.values.flatten.each { |pick| pick.golfers.each { |g| golfers_by_id[g.id] = g } }
  golfer_ids = golfers_by_id.keys
  results_by_golfer = TournamentResult.where(tournament: @tournament, golfer_id: golfer_ids).index_by(&:golfer_id)
  odds_by_golfer = @pool_tournament.pool_tournament_odds.index_by(&:golfer_id)

  @golfer_bonus_display = {}
  golfer_ids.each do |gid|
    golfer = golfers_by_id[gid]
    result = results_by_golfer[gid]
    odds_row = odds_by_golfer[gid]

    if result && @tournament.completed?
      if @tournament.bonus_cut_eligible_result?(result) && odds_row
        @golfer_bonus_display[gid] = @tournament.capped_cut_made_bonus(odds_row.american_odds)
      else
        @golfer_bonus_display[gid] = :mc
      end
    elsif golfer && @round_results.present?
      player_result = @round_results[golfer.external_id&.to_i] || {}
      round_numbers = (player_result[:rounds] || {}).keys
      made_cut = round_numbers.any? { |r| r >= 3 }
      cut_known = @current_round.present? && @current_round >= 3
      missed_cut = cut_known && round_numbers.any? && !made_cut

      if made_cut && odds_row
        @golfer_bonus_display[gid] = @tournament.capped_cut_made_bonus(odds_row.american_odds)
      elsif missed_cut
        @golfer_bonus_display[gid] = :mc
      else
        @golfer_bonus_display[gid] = nil
      end
    else
      @golfer_bonus_display[gid] = nil
    end
  end

  @golfer_prize_money = {}
  golfer_ids.each do |gid|
    result = results_by_golfer[gid]
    @golfer_prize_money[gid] = @tournament.completed? && result ? (result.prize_money.to_d || 0) : nil
  end
end
```

And add the `build_round_results_hash` private method from Step 1.

Key differences from the existing implementation:
- **Removed:** the inline `client.fetch_all_player_round_results` + `client.fetch_all_player_scorecards` block. That code now lives in `BallDontLie::SyncRoundResults`.
- **Moved:** the `SyncTournamentResults` auto-call from the top of the action to the bottom (so the cheap DB read runs first).
- **Tightened:** the `SyncTournamentResults` auto-call now only runs for tournaments that are `completed?` AND `tournament_results_earnings_incomplete?`. Previously it ran for *every* tournament without a fully-synced final result, including ones that hadn't started, causing a stray API call on every page load. `RefreshLiveResultsJob` covers the "live tournament that just completed" handoff (see Task 5).
- **Added:** the synchronous-fallback block, the stale-check enqueue, and `build_round_results_hash`.
- **Membership check** moved up to short-circuit non-members early (was after the heavy work before; that was a bug worth fixing while we're in here).

- [ ] **Step 5: Run the request specs to verify they pass**

Run: `bundle exec rspec spec/requests/pool_tournaments_show_spec.rb`
Expected: all tests pass (new and existing).

If existing tests fail because of the membership-check reorder (an unrelated test relies on the old order), revert that single change — keep it as a no-op refactor in this task; we can address separately. Otherwise the reorder is a small bonus.

- [ ] **Step 6: Run the full suite**

Run: `bundle exec rspec`
Expected: all green.

- [ ] **Step 7: Manual smoke test (optional but recommended)**

Boot the server (`bin/dev`), log in, and:
1. Open a completed tournament's View Results — should load <100ms (DevTools network: no outbound API call from the request).
2. Open a live tournament's View Results — first load may sync synchronously (~2–5s once); reload within 30s should be instant.
3. Wait >30s, reload — should be instant; Solid Queue should show a `RefreshLiveResultsJob` enqueued and completed.

- [ ] **Step 8: Commit**

```bash
git add app/controllers/pool_tournaments_controller.rb spec/requests/pool_tournaments_show_spec.rb
git commit -m "perf(pool_tournaments): read round results from DB; debounced background refresh"
```

---

## Final checks

- [ ] **Full test suite green:** `bundle exec rspec`
- [ ] **Schema in sync:** `bin/rails db:migrate:status` shows everything `up`; no pending migrations.
- [ ] **No leftover unused code:** `client.fetch_all_player_round_results` and `client.fetch_all_player_scorecards` are still called — just from `SyncRoundResults` instead of the controller. Don't delete them.
- [ ] **No mistakenly committed binaries / large files:** `git status` clean.

---

## Out of scope (do not implement in this plan)

- Turbo Streams / real-time push updates.
- "Last updated Xs ago" UI affordance.
- A one-shot rake task to backfill all historical completed tournaments. (Lazy backfill via the synchronous fallback handles this on first view.)
- Pruning of old `tournament_round_results`.
- Any change to scoring rules, Cut Made Bonus calculation, or no-cut handling.

---

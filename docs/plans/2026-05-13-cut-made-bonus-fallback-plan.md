# Cut Made Bonus Prize Pool Fallback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Always enforce a positive Cut Made Bonus (CMB) cap, even when the BallDontLie API returns a missing or `$0` purse, while still preferring a real positive API purse the moment it arrives.

**Architecture:** Add a `fallback_prize_pool` column to `tournaments`, populated by `BallDontLie::SyncTournaments` from the previous season's same-name purse when the current purse is missing or non-positive. A single `Tournament#effective_prize_pool` helper prefers `total_prize_pool`, then `fallback_prize_pool`, then a `$20M` global default. `Tournament#max_cut_made_bonus` and `Tournament#capped_cut_made_bonus` are updated to consume the effective value, removing the "no cap means raw" footgun. A new `ApplicationHelper#max_cut_made_bonus_label` centralizes the page-level disclosure and appends `(estimated)` when the API purse is not known.

**Tech Stack:** Rails 8.1, ActiveRecord migrations, RSpec (model + service + helper + request specs), existing `BallDontLie::Client` API client.

**Reference design doc:** `docs/plans/2026-05-13-cut-made-bonus-fallback-design.md`

---

## File Structure

**Create:**
- `db/migrate/<timestamp>_add_fallback_prize_pool_to_tournaments.rb` — adds `tournaments.fallback_prize_pool` decimal column.

**Modify:**
- `app/models/tournament.rb` — add `DEFAULT_FALLBACK_PRIZE_POOL`, `prize_pool_known?`, `effective_prize_pool`; rewrite `max_cut_made_bonus`; simplify `capped_cut_made_bonus`.
- `app/services/ball_dont_lie/sync_tournaments.rb` — memoized previous-season fetch; populate `fallback_prize_pool` when current purse is missing or non-positive.
- `app/helpers/application_helper.rb` — add `max_cut_made_bonus_label(tournament)`.
- `app/views/picks/new.html.erb` — replace inline cap rendering with `max_cut_made_bonus_label(@tournament)`.
- `app/views/picks/edit.html.erb` — same.
- `app/views/picks/_tournament_with_picks.html.erb` — same.
- `spec/models/tournament_spec.rb` — add specs for new methods; update the existing "returns 0 when total_prize_pool is nil" expectation since `max_cut_made_bonus` is now always positive.
- `spec/services/ball_dont_lie/sync_tournaments_spec.rb` — add specs for the previous-season fallback behavior.
- `spec/helpers/application_helper_spec.rb` — add specs for `max_cut_made_bonus_label`.

**Untouched (verified):**
- `app/models/pool.rb` — `Pool#capped_cut_made_bonus` and `Pool#capped_odds_bonus` already delegate to `Tournament#capped_cut_made_bonus`; behavior changes through the model layer.
- `app/views/pool_tournaments/show.html.erb` — bonus column already calls `cut_made_bonus_label` and `tournament.capped_cut_made_bonus`; both work with the new effective cap unchanged.
- `app/services/ball_dont_lie/client.rb` — no change; we use the existing `fetch_all_tournaments(season:)` API.

---

## Conventions

- **Test framework:** RSpec, matching existing patterns in `spec/models/tournament_spec.rb`, `spec/services/ball_dont_lie/sync_tournaments_spec.rb`, and `spec/helpers/application_helper_spec.rb`.
- **Client mocking:** `instance_double(BallDontLie::Client, ...)` + `allow(BallDontLie::Client).to receive(:new).and_return(client)`.
- **BigDecimal:** Rails autoloads `bigdecimal/util`, so `nil.to_d == BigDecimal(0)`. The new model code relies on this.
- **Migrations:** Rails 8.1 `ActiveRecord::Migration[8.1]`, mirroring `db/migrate/20260304205453_add_total_prize_pool_to_tournaments.rb`.
- **Test DB:** `bin/rails db:migrate` followed by `bin/rails db:migrate RAILS_ENV=test` after the migration is added.

---

## Task 1: Migration — add `fallback_prize_pool` column

**Files:**
- Create: `db/migrate/<timestamp>_add_fallback_prize_pool_to_tournaments.rb`
- Modify: `db/schema.rb` (auto-updated by `db:migrate`)

- [ ] **Step 1: Generate the migration file**

Run: `bin/rails generate migration AddFallbackPrizePoolToTournaments fallback_prize_pool:decimal`

Expected: a new file at `db/migrate/<timestamp>_add_fallback_prize_pool_to_tournaments.rb` is created.

- [ ] **Step 2: Replace the generated migration body**

Open the new migration file and replace its contents with:

```ruby
class AddFallbackPrizePoolToTournaments < ActiveRecord::Migration[8.1]
  def change
    add_column :tournaments, :fallback_prize_pool, :decimal, precision: 12, scale: 2
  end
end
```

(Match the precision/scale of `total_prize_pool` so the two columns are interchangeable for cap math.)

- [ ] **Step 3: Run the migration in dev and test environments**

Run: `bin/rails db:migrate`
Run: `bin/rails db:migrate RAILS_ENV=test`

Expected: both runs succeed and `db/schema.rb` includes `t.decimal "fallback_prize_pool", precision: 12, scale: 2` on the `tournaments` table.

- [ ] **Step 4: Verify schema**

Run: `bin/rails runner 'p Tournament.columns_hash["fallback_prize_pool"]&.sql_type'`

Expected output: `"decimal(12,2)"`.

- [ ] **Step 5: Commit**

```bash
git add db/migrate db/schema.rb
git commit -m "feat: add Tournament#fallback_prize_pool column"
```

---

## Task 2: `Tournament` model — effective prize pool, predicate, and capping fix

**Files:**
- Modify: `app/models/tournament.rb:55-67` (cap-related methods)
- Modify: `spec/models/tournament_spec.rb` (update one existing expectation, add new specs)

- [ ] **Step 1: Write the failing model specs**

Open `spec/models/tournament_spec.rb` and add (or replace) the following specs.

First, **update** the existing `#max_longshot_bonus` describe block so the nil case reflects the new fallback behavior. Replace this existing block:

```ruby
  describe "#max_longshot_bonus" do
    it "returns 10% of total_prize_pool when set" do
      tournament = Tournament.create!(name: "Rich", total_prize_pool: 10_000_000)
      expect(tournament.max_longshot_bonus).to eq(1_000_000)
    end

    it "returns 0 when total_prize_pool is nil" do
      tournament = Tournament.create!(name: "No purse", total_prize_pool: nil)
      expect(tournament.max_longshot_bonus).to eq(0)
    end
  end
```

with:

```ruby
  describe "#max_longshot_bonus" do
    it "returns 10% of total_prize_pool when set" do
      tournament = Tournament.create!(name: "Rich", total_prize_pool: 10_000_000)
      expect(tournament.max_longshot_bonus).to eq(1_000_000)
    end

    it "falls back to 10% of fallback_prize_pool when total_prize_pool is nil" do
      tournament = Tournament.create!(name: "Estimated", total_prize_pool: nil, fallback_prize_pool: 18_000_000)
      expect(tournament.max_longshot_bonus).to eq(1_800_000)
    end

    it "falls back to 10% of the global default when both purses are nil or zero" do
      tournament = Tournament.create!(name: "Unknown", total_prize_pool: nil, fallback_prize_pool: nil)
      expect(tournament.max_longshot_bonus).to eq(2_000_000)

      tournament.update!(total_prize_pool: 0, fallback_prize_pool: 0)
      expect(tournament.reload.max_longshot_bonus).to eq(2_000_000)
    end
  end
```

Then **add** the following describe blocks alongside the existing ones (anywhere in the file):

```ruby
  describe "#prize_pool_known?" do
    it "is true when total_prize_pool is positive" do
      tournament = Tournament.create!(name: "Known", total_prize_pool: 19_000_000)
      expect(tournament.prize_pool_known?).to be true
    end

    it "is false when total_prize_pool is nil" do
      tournament = Tournament.create!(name: "Unknown", total_prize_pool: nil, fallback_prize_pool: 19_000_000)
      expect(tournament.prize_pool_known?).to be false
    end

    it "is false when total_prize_pool is zero" do
      tournament = Tournament.create!(name: "Zero", total_prize_pool: 0, fallback_prize_pool: 19_000_000)
      expect(tournament.prize_pool_known?).to be false
    end
  end

  describe "#effective_prize_pool" do
    it "prefers total_prize_pool when positive" do
      tournament = Tournament.create!(name: "Real", total_prize_pool: 19_000_000, fallback_prize_pool: 17_000_000)
      expect(tournament.effective_prize_pool).to eq(19_000_000)
    end

    it "uses fallback_prize_pool when total_prize_pool is missing or zero" do
      tournament = Tournament.create!(name: "Fallback", total_prize_pool: 0, fallback_prize_pool: 21_500_000)
      expect(tournament.effective_prize_pool).to eq(21_500_000)
    end

    it "uses the global default when both values are missing or non-positive" do
      tournament = Tournament.create!(name: "Default", total_prize_pool: nil, fallback_prize_pool: nil)
      expect(tournament.effective_prize_pool).to eq(20_000_000)
    end
  end

  describe "#capped_cut_made_bonus with missing purse" do
    it "still caps the bonus when total_prize_pool is nil (no more uncapped fallthrough)" do
      tournament = Tournament.create!(name: "Major TBD", total_prize_pool: nil)
      expect(tournament.capped_cut_made_bonus(500_000)).to eq(2_000_000)
    end

    it "respects fallback_prize_pool when total_prize_pool is zero" do
      tournament = Tournament.create!(name: "Major TBD", total_prize_pool: 0, fallback_prize_pool: 19_000_000)
      expect(tournament.capped_cut_made_bonus(500_000)).to eq(1_900_000)
    end
  end
```

- [ ] **Step 2: Run the new model specs to verify they fail**

Run: `bundle exec rspec spec/models/tournament_spec.rb`

Expected: the new specs and the updated `#max_longshot_bonus` specs FAIL; the rest of the suite still passes. The failure messages should reference missing methods or wrong return values.

- [ ] **Step 3: Implement the model changes**

In `app/models/tournament.rb`, replace the existing cap block (lines around 55–67):

```ruby
  # Maximum Cut Made Bonus per pick: 10% of tournament total prize pool (advertised purse).
  # Prize pool is expected to be set from API or manually and is static; when nil, max bonus is 0.
  def max_cut_made_bonus
    (total_prize_pool.to_d || 0) * 0.10
  end

  # Cut Made Bonus (20 × |american_odds|) capped at max_cut_made_bonus. Used for display and by Pool scoring.
  def capped_cut_made_bonus(american_odds)
    return 0.to_d if american_odds.nil?
    raw = american_odds.to_d.abs * 20
    max_bonus = max_cut_made_bonus
    max_bonus.positive? ? [ raw, max_bonus ].min : raw
  end
```

with:

```ruby
  DEFAULT_FALLBACK_PRIZE_POOL = BigDecimal("20000000")

  # True only when the API has provided a real positive purse for this tournament.
  # When false, the max bonus comes from fallback_prize_pool or the global default,
  # and the UI should disclose that the cap is estimated.
  def prize_pool_known?
    total_prize_pool.to_d.positive?
  end

  # Best available prize pool for cap math. Prefers the real API purse, then the
  # cached previous-year fallback, then a conservative global default. Always positive.
  def effective_prize_pool
    candidate = total_prize_pool.to_d
    return candidate if candidate.positive?

    candidate = fallback_prize_pool.to_d
    return candidate if candidate.positive?

    DEFAULT_FALLBACK_PRIZE_POOL
  end

  # Maximum Cut Made Bonus per pick: 10% of the effective prize pool.
  def max_cut_made_bonus
    effective_prize_pool * 0.10
  end

  # Cut Made Bonus (20 × |american_odds|) capped at max_cut_made_bonus.
  # max_cut_made_bonus is always positive, so the cap is always enforced.
  def capped_cut_made_bonus(american_odds)
    return 0.to_d if american_odds.nil?

    raw = american_odds.to_d.abs * 20
    [ raw, max_cut_made_bonus ].min
  end
```

(Keep the existing `max_longshot_bonus` and `capped_longshot_bonus` aliases below; they delegate to the new methods automatically.)

- [ ] **Step 4: Run model specs to verify they pass**

Run: `bundle exec rspec spec/models/tournament_spec.rb`

Expected: all specs in the file pass.

- [ ] **Step 5: Run the full spec suite to confirm no regressions**

Run: `bundle exec rspec`

Expected: green. Tests in `spec/requests/pool_tournaments_show_spec.rb`, `spec/models/pool_spec.rb`, and `spec/helpers/application_helper_spec.rb` all continue to pass — they either set `total_prize_pool` explicitly or do not assert on cap values when the purse is missing.

- [ ] **Step 6: Commit**

```bash
git add app/models/tournament.rb spec/models/tournament_spec.rb
git commit -m "feat(tournament): add effective_prize_pool and enforce CMB cap when API purse is missing"
```

---

## Task 3: `BallDontLie::SyncTournaments` — populate `fallback_prize_pool` from previous season

**Files:**
- Modify: `app/services/ball_dont_lie/sync_tournaments.rb`
- Modify: `spec/services/ball_dont_lie/sync_tournaments_spec.rb`

### Behavior added

1. For each current-season tournament row, parse the API `purse` as today. Set `total_prize_pool` from that parsed value (no change to authoritative behavior).
2. If the parsed value is nil or non-positive, look up the previous-season same-name purse from a memoized previous-season fetch.
3. If a positive prior-year purse is found, set `fallback_prize_pool`. If not, leave the existing `fallback_prize_pool` alone.
4. Make the previous-season fetch lazy and memoized: a sync run hits the prev-year endpoint at most once, and only if any current-year row needs it.
5. If the previous-season fetch raises, log a warning and proceed as if no prior-year data is available.

### TDD steps

- [ ] **Step 1: Write the failing sync specs**

In `spec/services/ball_dont_lie/sync_tournaments_spec.rb`, add the following inside the existing `describe "#call"` block (after the existing contexts):

```ruby
    context "when current-year API purse is missing or zero and previous year has a positive purse" do
      let(:client) { instance_double(BallDontLie::Client) }
      let(:current_year_rows) do
        [
          { "id" => 26, "name" => "PGA Championship", "start_date" => "2026-05-14", "end_date" => nil, "purse" => "$0" },
          { "id" => 31, "name" => "U.S. Open",        "start_date" => "2026-06-18", "end_date" => nil, "purse" => nil }
        ]
      end
      let(:prev_year_rows) do
        [
          { "id" => 7,  "name" => "PGA Championship", "purse" => "$19,000,000" },
          { "id" => 12, "name" => "U.S. Open",        "purse" => "$21,500,000" }
        ]
      end

      before do
        allow(client).to receive(:fetch_all_tournaments).with(season: 2026).and_return(current_year_rows)
        allow(client).to receive(:fetch_all_tournaments).with(season: 2025).and_return(prev_year_rows)
      end

      it "stores previous-year purse in fallback_prize_pool when current purse is missing or zero" do
        described_class.new(season: 2026, client: client).call

        pga = Tournament.find_by!(external_id: "26")
        uso = Tournament.find_by!(external_id: "31")

        expect(pga.total_prize_pool.to_i).to eq(0)
        expect(pga.fallback_prize_pool).to eq(BigDecimal("19000000"))
        expect(uso.total_prize_pool).to be_nil
        expect(uso.fallback_prize_pool).to eq(BigDecimal("21500000"))
      end

      it "fetches the previous-season list at most once per sync call (memoization)" do
        described_class.new(season: 2026, client: client).call

        expect(client).to have_received(:fetch_all_tournaments).with(season: 2025).once
      end
    end

    context "when previous-year fetch fails" do
      let(:client) { instance_double(BallDontLie::Client) }
      let(:current_year_rows) do
        [
          { "id" => 26, "name" => "PGA Championship", "start_date" => "2026-05-14", "end_date" => nil, "purse" => "$0" }
        ]
      end

      before do
        allow(client).to receive(:fetch_all_tournaments).with(season: 2026).and_return(current_year_rows)
        allow(client).to receive(:fetch_all_tournaments).with(season: 2025).and_raise(StandardError, "boom")
        allow(Rails.logger).to receive(:warn)
      end

      it "logs a warning and proceeds without setting a fallback" do
        expect { described_class.new(season: 2026, client: client).call }.not_to raise_error

        pga = Tournament.find_by!(external_id: "26")
        expect(pga.fallback_prize_pool).to be_nil
        expect(Rails.logger).to have_received(:warn).with(/SyncTournaments.*previous season/)
      end
    end

    context "when current API purse is positive" do
      let(:client) { instance_double(BallDontLie::Client) }
      let(:current_year_rows) do
        [
          { "id" => 17, "name" => "Valspar Championship", "start_date" => "2026-03-19", "end_date" => nil, "purse" => "$8,700,000" }
        ]
      end

      before do
        allow(client).to receive(:fetch_all_tournaments).with(season: 2026).and_return(current_year_rows)
      end

      it "does not call the previous-season endpoint at all" do
        described_class.new(season: 2026, client: client).call

        expect(client).not_to have_received(:fetch_all_tournaments).with(season: 2025)
      end
    end

    context "when an existing record has a fallback and the API returns no usable prev-year match" do
      let(:client) { instance_double(BallDontLie::Client) }
      let(:current_year_rows) do
        [
          { "id" => 26, "name" => "PGA Championship", "start_date" => "2026-05-14", "end_date" => nil, "purse" => "$0" }
        ]
      end

      before do
        Tournament.create!(external_id: "26", name: "PGA Championship", starts_at: Time.zone.parse("2026-05-14"), fallback_prize_pool: 19_000_000)
        allow(client).to receive(:fetch_all_tournaments).with(season: 2026).and_return(current_year_rows)
        allow(client).to receive(:fetch_all_tournaments).with(season: 2025).and_return([])
      end

      it "leaves the existing fallback_prize_pool untouched" do
        described_class.new(season: 2026, client: client).call

        expect(Tournament.find_by!(external_id: "26").fallback_prize_pool).to eq(BigDecimal("19000000"))
      end
    end
```

- [ ] **Step 2: Run the new sync specs to verify they fail**

Run: `bundle exec rspec spec/services/ball_dont_lie/sync_tournaments_spec.rb`

Expected: the four new examples FAIL (current service does not call the prev-year endpoint at all and does not write `fallback_prize_pool`). The two pre-existing examples still pass.

- [ ] **Step 3: Implement the prev-year fallback in `SyncTournaments`**

Replace the contents of `app/services/ball_dont_lie/sync_tournaments.rb` with:

```ruby
# frozen_string_literal: true

module BallDontLie
  class SyncTournaments
    def initialize(season: Date.current.year, client: nil)
      @season = season
      @client = client || Client.new
    end

    def call
      api_tournaments = @client.fetch_all_tournaments(season: @season)
      created = updated = 0
      api_tournaments.each do |t|
        rec = Tournament.find_or_initialize_by(external_id: t["id"].to_s)
        rec.name = t["name"]
        rec.starts_at = parse_date(t["start_date"])
        rec.ends_at = parse_end_date(t["end_date"], rec.starts_at) # may be set to nil if API data is invalid

        parsed_purse = parse_purse(t["purse"])
        rec.total_prize_pool = parsed_purse

        if parsed_purse.nil? || !parsed_purse.positive?
          fallback = previous_season_purse_for(t["name"])
          rec.fallback_prize_pool = fallback if fallback&.positive?
        end

        if rec.new_record?
          rec.save!
          created += 1
        elsif rec.changed?
          rec.save!
          updated += 1
        end
      end
      { created: created, updated: updated, total: api_tournaments.size }
    end

    private

    def parse_date(str)
      return nil if str.blank?
      Time.zone.parse(str.to_s)
    end

    def parse_end_date(str, start_date)
      return nil if str.blank?
      parsed = Time.zone.parse(str.to_s) rescue nil
      return nil if parsed.blank? || start_date.blank?
      # API sometimes returns same as start_date or before; do not persist invalid end date
      return nil if parsed <= start_date
      parsed
    end

    def parse_purse(purse_str)
      return nil if purse_str.blank?
      cleaned = purse_str.to_s.gsub(/[$,]/, "").strip
      return nil if cleaned.blank?
      BigDecimal(cleaned)
    rescue ArgumentError, TypeError
      nil
    end

    # Returns the previous-season parsed purse for a given tournament name, or nil
    # when no positive match exists. The previous-season list is fetched lazily and
    # memoized so we hit the API at most once per sync run.
    def previous_season_purse_for(name)
      key = name.to_s.downcase.strip
      return nil if key.blank?

      previous_season_purse_by_name[key]
    end

    def previous_season_purse_by_name
      @previous_season_purse_by_name ||= load_previous_season_purse_by_name
    end

    def load_previous_season_purse_by_name
      rows = @client.fetch_all_tournaments(season: @season - 1)
      rows.each_with_object({}) do |t, h|
        key = t["name"].to_s.downcase.strip
        next if key.blank?
        purse = parse_purse(t["purse"])
        h[key] = purse if purse&.positive?
      end
    rescue => e
      Rails.logger.warn("[BallDontLie::SyncTournaments] failed to fetch previous season #{@season - 1} for fallback: #{e.class}: #{e.message}")
      {}
    end
  end
end
```

- [ ] **Step 4: Run sync specs to verify they pass**

Run: `bundle exec rspec spec/services/ball_dont_lie/sync_tournaments_spec.rb`

Expected: all examples (old and new) pass.

- [ ] **Step 5: Run the full spec suite to confirm no regressions**

Run: `bundle exec rspec`

Expected: green.

- [ ] **Step 6: Commit**

```bash
git add app/services/ball_dont_lie/sync_tournaments.rb spec/services/ball_dont_lie/sync_tournaments_spec.rb
git commit -m "feat(sync_tournaments): populate fallback_prize_pool from previous season when current purse is missing or zero"
```

---

## Task 4: Helper + view updates — `(estimated)` disclosure

**Files:**
- Modify: `app/helpers/application_helper.rb`
- Modify: `app/views/picks/new.html.erb:3`
- Modify: `app/views/picks/edit.html.erb:3`
- Modify: `app/views/picks/_tournament_with_picks.html.erb:4`
- Modify: `spec/helpers/application_helper_spec.rb`

- [ ] **Step 1: Write the failing helper specs**

In `spec/helpers/application_helper_spec.rb`, add the following describe block (alongside the existing ones):

```ruby
  describe "#max_cut_made_bonus_label" do
    it "renders a plain dollar amount when the API purse is known" do
      tournament = Tournament.new(name: "Known", total_prize_pool: 19_000_000, starts_at: Time.current)
      expect(helper.max_cut_made_bonus_label(tournament)).to eq("$1,900,000")
    end

    it "appends (estimated) when the cap comes from fallback_prize_pool" do
      tournament = Tournament.new(name: "Fallback", total_prize_pool: nil, fallback_prize_pool: 19_000_000, starts_at: Time.current)
      expect(helper.max_cut_made_bonus_label(tournament)).to eq("$1,900,000 (estimated)")
    end

    it "appends (estimated) when the cap comes from the global default" do
      tournament = Tournament.new(name: "Default", total_prize_pool: nil, fallback_prize_pool: nil, starts_at: Time.current)
      expect(helper.max_cut_made_bonus_label(tournament)).to eq("$2,000,000 (estimated)")
    end

    it "appends (estimated) when total_prize_pool is zero (API said \"$0\")" do
      tournament = Tournament.new(name: "Zero purse", total_prize_pool: 0, fallback_prize_pool: 19_000_000, starts_at: Time.current)
      expect(helper.max_cut_made_bonus_label(tournament)).to eq("$1,900,000 (estimated)")
    end
  end
```

- [ ] **Step 2: Run the helper specs to verify they fail**

Run: `bundle exec rspec spec/helpers/application_helper_spec.rb`

Expected: the four new examples FAIL because `max_cut_made_bonus_label` is not defined yet.

- [ ] **Step 3: Implement the helper**

In `app/helpers/application_helper.rb`, add the following method (alongside the existing ones, e.g. just below `cut_made_bonus_label`):

```ruby
  # Page-level label for the maximum Cut Made Bonus on a tournament. Appends
  # "(estimated)" when the cap is derived from fallback_prize_pool or the global
  # default, so users understand the displayed cap may change once the official
  # purse is announced.
  def max_cut_made_bonus_label(tournament)
    max = tournament.max_cut_made_bonus
    amount = "$#{number_with_delimiter(max.to_i)}"
    tournament.prize_pool_known? ? amount : "#{amount} (estimated)"
  end
```

- [ ] **Step 4: Run helper specs to verify they pass**

Run: `bundle exec rspec spec/helpers/application_helper_spec.rb`

Expected: all examples in the file pass.

- [ ] **Step 5: Update `app/views/picks/new.html.erb`**

Replace line 3:

```erb
<p class="text-sm text-gray-500 mb-4">Max Cut Made Bonus: <%= @tournament.max_cut_made_bonus.positive? ? "$#{number_with_delimiter(@tournament.max_cut_made_bonus.to_i)}" : "TBD" %></p>
```

with:

```erb
<p class="text-sm text-gray-500 mb-4">Max Cut Made Bonus: <%= max_cut_made_bonus_label(@tournament) %></p>
```

- [ ] **Step 6: Update `app/views/picks/edit.html.erb`**

Replace line 3:

```erb
<p class="text-sm text-gray-500 mb-4">Max Cut Made Bonus: <%= @tournament.max_cut_made_bonus.positive? ? "$#{number_with_delimiter(@tournament.max_cut_made_bonus.to_i)}" : "TBD" %></p>
```

with:

```erb
<p class="text-sm text-gray-500 mb-4">Max Cut Made Bonus: <%= max_cut_made_bonus_label(@tournament) %></p>
```

- [ ] **Step 7: Update `app/views/picks/_tournament_with_picks.html.erb`**

Replace line 4:

```erb
<div class="text-sm text-gray-500">Max Cut Made Bonus: <%= tournament.max_cut_made_bonus.positive? ? "$#{number_with_delimiter(tournament.max_cut_made_bonus.to_i)}" : "TBD" %></div>
```

with:

```erb
<div class="text-sm text-gray-500">Max Cut Made Bonus: <%= max_cut_made_bonus_label(tournament) %></div>
```

- [ ] **Step 8: Run request and view specs to confirm template integrity**

Run: `bundle exec rspec spec/requests spec/views`

Expected: green. None of the existing request/view specs assert on the literal "TBD" label, so behavior is preserved.

- [ ] **Step 9: Commit**

```bash
git add app/helpers/application_helper.rb spec/helpers/application_helper_spec.rb app/views/picks/new.html.erb app/views/picks/edit.html.erb app/views/picks/_tournament_with_picks.html.erb
git commit -m "feat(views): show (estimated) on Max Cut Made Bonus when prize pool is not yet known"
```

---

## Task 5: Final regression run + production data refresh note

**Files:** none modified

- [ ] **Step 1: Run the full spec suite**

Run: `bundle exec rspec`

Expected: all green.

- [ ] **Step 2: Sanity-check the bug fix in a Rails console**

Run:

```bash
bin/rails runner '
  t = Tournament.find_by(name: "PGA Championship")
  puts "total_prize_pool: #{t&.total_prize_pool.inspect}"
  puts "fallback_prize_pool: #{t&.fallback_prize_pool.inspect}"
  puts "effective_prize_pool: #{t&.effective_prize_pool.inspect}"
  puts "max_cut_made_bonus: #{t&.max_cut_made_bonus.inspect}"
  puts "capped_cut_made_bonus(+50000): #{t&.capped_cut_made_bonus(50_000).inspect}"
'
```

Expected before re-syncing: `effective_prize_pool` is `20000000.0` (the global default) and `capped_cut_made_bonus(+50000)` is `2000000.0` (no longer `1_000_000` × `20` = `20_000_000`).

- [ ] **Step 3: Run the production data refresh**

After deploy, run a `SyncTournaments` pass so that `fallback_prize_pool` is populated for majors from the previous season:

```bash
bin/rails runner 'BallDontLie::SyncTournaments.new.call'
```

Then re-run the console snippet from Step 2 and confirm `fallback_prize_pool` is populated and `effective_prize_pool` reflects the prior-year purse.

- [ ] **Step 4: No-op commit guard**

Run: `git status`

Expected: clean working tree. If anything is uncommitted from previous tasks, commit it now with an appropriate message.

---

## Roll-up Summary

| Task | Action |
|------|--------|
| 1 | Add `tournaments.fallback_prize_pool` column |
| 2 | Add `DEFAULT_FALLBACK_PRIZE_POOL`, `prize_pool_known?`, `effective_prize_pool`; rewrite `max_cut_made_bonus`; simplify `capped_cut_made_bonus` |
| 3 | `BallDontLie::SyncTournaments` populates `fallback_prize_pool` from previous-season same-name purse, memoized + error-tolerant |
| 4 | New `max_cut_made_bonus_label` helper + three picks views display `(estimated)` when fallback or default is in use |
| 5 | Full spec run + production sync to backfill fallback values for majors |

# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tournament, type: :model do
  include ActiveSupport::Testing::TimeHelpers

  describe "#completed?" do
    it "returns true when champion_golfer_id is set" do
      golfer = Golfer.create!(name: "Winner", external_id: "1")
      tournament = Tournament.create!(name: "Done", starts_at: 5.days.ago, champion_golfer_id: golfer.id)
      expect(tournament.completed?).to be true
    end

    it "returns false when champion_golfer_id is nil" do
      tournament = Tournament.create!(name: "Open", starts_at: 1.day.from_now, champion_golfer_id: nil)
      expect(tournament.completed?).to be false
    end
  end

  describe "#results_synced_since_completion?" do
    it "returns true when results_synced_at and champion_golfer_id are set" do
      golfer = Golfer.create!(name: "Winner", external_id: "1")
      tournament = Tournament.create!(name: "Synced", starts_at: 5.days.ago, results_synced_at: 1.day.ago, champion_golfer_id: golfer.id)
      expect(tournament.results_synced_since_completion?).to be true
    end

    it "returns false when results_synced_at is blank" do
      tournament = Tournament.create!(name: "Not synced", starts_at: 5.days.ago, results_synced_at: nil)
      expect(tournament.results_synced_since_completion?).to be false
    end

    it "returns false when champion_golfer_id is nil" do
      tournament = Tournament.create!(name: "No champion yet", starts_at: 5.days.ago, results_synced_at: 1.day.ago, champion_golfer_id: nil)
      expect(tournament.results_synced_since_completion?).to be false
    end
  end

  describe ".addable_to_pool" do
    it "includes tournaments with no champion yet" do
      t = Tournament.create!(name: "Open", starts_at: 1.day.from_now, champion_golfer_id: nil)
      expect(described_class.addable_to_pool).to include(t)
    end

    it "excludes tournaments that have a champion" do
      golfer = Golfer.create!(name: "Winner", external_id: "1")
      t = Tournament.create!(name: "Closed", starts_at: 5.days.ago, champion_golfer_id: golfer.id)
      expect(described_class.addable_to_pool).not_to include(t)
    end
  end

  describe "#picks_open_at" do
    it "returns 4 days before starts_at" do
      starts_at = Time.zone.parse("2026-03-10 12:00:00")
      tournament = Tournament.create!(name: "Event", starts_at: starts_at)

      expect(tournament.picks_open_at).to eq(starts_at - 4.days)
    end

    it "returns nil when starts_at is nil" do
      tournament = Tournament.create!(name: "No start", starts_at: nil)

      expect(tournament.picks_open_at).to be_nil
    end
  end

  describe "#picks_open?" do
    it "is false before picks_open_at" do
      starts_at = Time.zone.parse("2026-03-10 12:00:00")
      tournament = Tournament.create!(name: "Event", starts_at: starts_at)

      travel_to(starts_at - 5.days) do
        expect(tournament.picks_open?).to be false
      end
    end

    it "is true between picks_open_at and start time" do
      starts_at = Time.zone.parse("2026-03-10 12:00:00")
      tournament = Tournament.create!(name: "Event", starts_at: starts_at)

      travel_to(starts_at - 3.days) do
        expect(tournament.picks_open?).to be true
      end
    end

    it "is false after tournament has started" do
      starts_at = Time.zone.parse("2026-03-10 12:00:00")
      tournament = Tournament.create!(name: "Event", starts_at: starts_at)

      travel_to(starts_at + 1.hour) do
        expect(tournament.picks_open?).to be false
      end
    end
  end

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

  describe "#capped_longshot_bonus" do
    it "returns 20 × |american_odds| when below max" do
      tournament = Tournament.create!(name: "Rich", total_prize_pool: 10_000_000)
      expect(tournament.capped_longshot_bonus(500)).to eq(10_000)
      expect(tournament.capped_longshot_bonus(-200)).to eq(4_000)
    end

    it "caps at max_longshot_bonus when raw bonus would exceed" do
      tournament = Tournament.create!(name: "Rich", total_prize_pool: 1_000_000)
      expect(tournament.capped_longshot_bonus(10_000)).to eq(100_000)
    end

    it "returns 0 when american_odds is nil" do
      tournament = Tournament.create!(name: "Rich", total_prize_pool: 10_000_000)
      expect(tournament.capped_longshot_bonus(nil)).to eq(0)
    end
  end

  describe "#picks_locked?" do
    it "is false before midnight Central on the start date" do
      starts_at = Time.zone.parse("2026-03-10 12:00:00")
      tournament = Tournament.create!(name: "Event", starts_at: starts_at)
      # Lock is midnight Central on March 10; in March 2026 Central is CDT = 05:00 UTC
      before_lock = Time.utc(2026, 3, 10, 4, 59, 0)

      travel_to(before_lock) do
        expect(tournament.picks_locked?).to be false
      end
    end

    it "is true once midnight Central on the start date has passed" do
      starts_at = Time.zone.parse("2026-03-10 12:00:00")
      tournament = Tournament.create!(name: "Event", starts_at: starts_at)
      after_lock = Time.utc(2026, 3, 10, 5, 1, 0)

      travel_to(after_lock) do
        expect(tournament.picks_locked?).to be true
      end
    end
  end

  describe "#picks_lock_at" do
    it "returns midnight Central on the start date (we always use this, not the API time)" do
      starts_at = Time.utc(2026, 3, 5, 0, 0, 0)
      tournament = Tournament.create!(name: "Event", starts_at: starts_at)

      lock_at = tournament.picks_lock_at
      central = lock_at.in_time_zone("Central Time (US & Canada)")
      expect(central.strftime("%Y-%m-%d %H:%M")).to eq("2026-03-05 00:00")
    end

    it "uses the date of starts_at only (e.g. 14:30 UTC still locks at midnight Central that day)" do
      starts_at = Time.utc(2026, 3, 10, 14, 30, 0)
      tournament = Tournament.create!(name: "Event", starts_at: starts_at)

      lock_at = tournament.picks_lock_at
      central = lock_at.in_time_zone("Central Time (US & Canada)")
      expect(central.strftime("%Y-%m-%d %H:%M")).to eq("2026-03-10 00:00")
    end
  end
end

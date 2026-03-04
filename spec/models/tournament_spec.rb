# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tournament, type: :model do
  include ActiveSupport::Testing::TimeHelpers

  describe "#completed?" do
    it "returns true when ends_at is in the past" do
      tournament = Tournament.create!(name: "Past", starts_at: 5.days.ago, ends_at: 2.days.ago)
      expect(tournament.completed?).to be true
    end

    it "returns false when ends_at is in the future" do
      tournament = Tournament.create!(name: "Future", starts_at: 1.day.from_now, ends_at: 4.days.from_now)
      expect(tournament.completed?).to be false
    end

    it "returns false when ends_at is nil" do
      tournament = Tournament.create!(name: "No end", starts_at: 1.day.ago, ends_at: nil)
      expect(tournament.completed?).to be false
    end
  end

  describe "#results_synced_since_completion?" do
    it "returns false when tournament is not completed" do
      tournament = Tournament.create!(name: "Future", starts_at: 1.day.from_now, ends_at: 4.days.from_now, results_synced_at: 1.day.from_now)
      expect(tournament.results_synced_since_completion?).to be false
    end

    it "returns false when completed but results_synced_at is blank" do
      tournament = Tournament.create!(name: "Past", starts_at: 5.days.ago, ends_at: 2.days.ago, results_synced_at: nil)
      expect(tournament.results_synced_since_completion?).to be false
    end

    it "returns true when completed and results_synced_at is after ends_at" do
      ends_at = 2.days.ago
      tournament = Tournament.create!(name: "Past", starts_at: 5.days.ago, ends_at: ends_at, results_synced_at: 1.day.ago)
      expect(tournament.results_synced_since_completion?).to be true
    end

    it "returns true when completed and results_synced_at equals ends_at" do
      ends_at = 2.days.ago
      tournament = Tournament.create!(name: "Past", starts_at: 5.days.ago, ends_at: ends_at, results_synced_at: ends_at)
      expect(tournament.results_synced_since_completion?).to be true
    end
  end

  describe ".addable_to_pool" do
    it "includes tournaments with nil ends_at" do
      t = Tournament.create!(name: "No end", starts_at: 1.day.from_now, ends_at: nil)
      expect(described_class.addable_to_pool).to include(t)
    end

    it "includes tournaments ending in the future" do
      t = Tournament.create!(name: "Future", starts_at: 1.day.from_now, ends_at: 3.days.from_now)
      expect(described_class.addable_to_pool).to include(t)
    end

    it "includes tournaments that ended less than 1 day ago" do
      t = Tournament.create!(name: "Just ended", starts_at: 5.days.ago, ends_at: 12.hours.ago)
      expect(described_class.addable_to_pool).to include(t)
    end

    it "excludes tournaments that ended more than 1 day ago" do
      t = Tournament.create!(name: "Past", starts_at: 5.days.ago, ends_at: 2.days.ago)
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

  describe "#picks_locked?" do
    it "is false before tournament starts" do
      starts_at = Time.zone.parse("2026-03-10 12:00:00")
      tournament = Tournament.create!(name: "Event", starts_at: starts_at)

      travel_to(starts_at - 1.hour) do
        expect(tournament.picks_locked?).to be false
      end
    end

    it "is true once tournament has started" do
      starts_at = Time.zone.parse("2026-03-10 12:00:00")
      tournament = Tournament.create!(name: "Event", starts_at: starts_at)

      travel_to(starts_at + 1.minute) do
        expect(tournament.picks_locked?).to be true
      end
    end
  end
end

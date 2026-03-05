require "rails_helper"

RSpec.describe PoolTournament, type: :model do
  include ActiveSupport::Testing::TimeHelpers

  let(:pool) { Pool.create!(name: "Test Pool") }

  describe "validations" do
    it "does not allow linking a completed tournament" do
      past_tournament = Tournament.create!(name: "Past Event", starts_at: 3.days.ago, ends_at: 1.day.ago)

      pt = PoolTournament.new(pool: pool, tournament: past_tournament)

      expect(pt).not_to be_valid
      expect(pt.errors[:tournament]).to include("has already completed")
    end

    it "allows linking a future or ongoing tournament" do
      future_tournament = Tournament.create!(name: "Future Event", starts_at: 1.day.from_now, ends_at: 4.days.from_now)

      pt = PoolTournament.new(pool: pool, tournament: future_tournament)

      expect(pt).to be_valid
    end
  end

  describe "callbacks" do
    it "enqueues a job to sync the tournament field after create" do
      ActiveJob::Base.queue_adapter = :test
      tournament = Tournament.create!(name: "Upcoming Event", starts_at: 1.day.from_now, external_id: "123")

      expect {
        PoolTournament.create!(pool: pool, tournament: tournament)
      }.to have_enqueued_job(SyncTournamentFieldJob).with(tournament.id)
    end
  end

  describe "pick visibility helpers" do
    let(:starts_at) { Time.zone.parse("2026-03-10 12:00:00") }
    let(:tournament) { Tournament.create!(name: "Event", starts_at: starts_at) }
    let(:pool_tournament) { PoolTournament.create!(pool: pool, tournament: tournament) }
    let(:viewer) { User.create!(email: "viewer@example.com", name: "Viewer", password: "password") }
    let(:member) { User.create!(email: "member@example.com", name: "Member", password: "password") }

    describe "#picks_open_for_submission?" do
      it "delegates to tournament.picks_open?" do
        travel_to(starts_at - 3.days) do
          expect(pool_tournament.picks_open_for_submission?).to be true
        end

        travel_to(Time.utc(2026, 3, 10, 5, 1, 0)) do
          expect(pool_tournament.picks_open_for_submission?).to be false
        end
      end
    end

    describe "#can_view_all_picks?" do
      it "is false before midnight Central on the start date" do
        travel_to(Time.utc(2026, 3, 10, 4, 59, 0)) do
          expect(pool_tournament.can_view_all_picks?(viewer)).to be false
        end
      end

      it "is true once midnight Central on the start date has passed" do
        travel_to(Time.utc(2026, 3, 10, 5, 1, 0)) do
          expect(pool_tournament.can_view_all_picks?(viewer)).to be true
        end
      end
    end

    describe "#can_view_member_picks?" do
      it "allows a user to view their own picks at any time" do
        travel_to(starts_at - 5.days) do
          expect(pool_tournament.can_view_member_picks?(viewer, viewer)).to be true
        end
      end

      it "denies viewing other members' picks before picks are locked" do
        travel_to(Time.utc(2026, 3, 10, 4, 59, 0)) do
          expect(pool_tournament.can_view_member_picks?(viewer, member)).to be false
        end
      end

      it "allows viewing other members' picks once picks are locked" do
        travel_to(Time.utc(2026, 3, 10, 5, 1, 0)) do
          expect(pool_tournament.can_view_member_picks?(viewer, member)).to be true
        end
      end
    end
  end
end

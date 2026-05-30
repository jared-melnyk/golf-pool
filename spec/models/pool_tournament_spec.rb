require "rails_helper"

RSpec.describe PoolTournament, type: :model do
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  let(:pool) { Pool.create!(name: "Test Pool") }

  describe "validations" do
    it "does not allow linking a tournament that has a champion" do
      golfer = Golfer.create!(name: "Winner", external_id: "1")
      completed_tournament = Tournament.create!(name: "Past Event", starts_at: 3.days.ago, champion_golfer_id: golfer.id)

      pt = PoolTournament.new(pool: pool, tournament: completed_tournament)

      expect(pt).not_to be_valid
      expect(pt.errors[:tournament]).to include("has already completed")
    end

    it "allows linking a tournament that has no champion yet" do
      open_tournament = Tournament.create!(name: "Future Event", starts_at: 1.day.from_now, champion_golfer_id: nil)

      pt = PoolTournament.new(pool: pool, tournament: open_tournament)

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

    it "schedules odds lock for the pre-start window when added early" do
      ActiveJob::Base.queue_adapter = :test
      starts_at = 2.days.from_now.change(usec: 0)
      tournament = Tournament.create!(name: "Upcoming Event", starts_at: starts_at, external_id: "123")

      expect {
        PoolTournament.create!(pool: pool, tournament: tournament)
      }.to have_enqueued_job(LockOddsJob)
    end

    it "enqueues odds lock immediately when added inside the lock window" do
      ActiveJob::Base.queue_adapter = :test
      starts_at = Time.zone.parse("2026-05-21 12:00:00")
      tournament = Tournament.create!(name: "Byron Nelson", starts_at: starts_at, external_id: "27")

      travel_to(Time.find_zone(Tournament::CENTRAL).parse("2026-05-20 23:50:00")) do
        expect {
          PoolTournament.create!(pool: pool, tournament: tournament)
        }.to have_enqueued_job(LockOddsJob)
      end
    end

    it "does not enqueue odds lock after picks lock" do
      ActiveJob::Base.queue_adapter = :test
      starts_at = Time.zone.parse("2026-05-21 12:00:00")
      tournament = Tournament.create!(name: "Byron Nelson", starts_at: starts_at, external_id: "27")

      travel_to(Time.utc(2026, 5, 21, 6, 0, 0)) do
        expect {
          PoolTournament.create!(pool: pool, tournament: tournament)
        }.not_to have_enqueued_job(LockOddsJob)
      end
    end
  end

  describe "Tournament starts_at updates" do
    it "re-enqueues odds lock when starts_at is set after pool tournament creation" do
      ActiveJob::Base.queue_adapter = :test
      tournament = Tournament.create!(name: "TBD", starts_at: nil, external_id: "27")
      pool_tournament = PoolTournament.create!(pool: pool, tournament: tournament)
      clear_enqueued_jobs

      starts_at = 2.days.from_now.change(usec: 0)
      expect {
        tournament.update!(starts_at: starts_at)
      }.to have_enqueued_job(LockOddsJob).with(pool_tournament.id)
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

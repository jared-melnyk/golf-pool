require "rails_helper"

RSpec.describe PoolTournament, type: :model do
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
end


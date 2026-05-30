# frozen_string_literal: true

require "rails_helper"

RSpec.describe EnsurePoolTournamentOddsLockedJob, type: :job do
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  let(:pool) { Pool.create!(name: "Test Pool") }
  let(:starts_at) { Time.zone.parse("2026-05-21 12:00:00") }
  let(:tournament) { Tournament.create!(name: "Byron Nelson", starts_at: starts_at, external_id: "27") }

  before { ActiveJob::Base.queue_adapter = :test }

  it "enqueues refresh jobs during the pre-lock window" do
    travel_to(Time.find_zone(Tournament::CENTRAL).parse("2026-05-20 23:50:00")) do
      pool_tournament = PoolTournament.create!(pool: pool, tournament: tournament)
      clear_enqueued_jobs

      expect {
        described_class.perform_now
      }.to have_enqueued_job(LockOddsJob).with(pool_tournament.id)
    end
  end

  it "still enqueues refresh jobs when odds were previously snapshotted" do
    travel_to(Time.find_zone(Tournament::CENTRAL).parse("2026-05-20 23:50:00")) do
      pool_tournament = PoolTournament.create!(pool: pool, tournament: tournament)
      pool_tournament.update_column(:odds_locked_at, 1.hour.ago)
      clear_enqueued_jobs

      expect {
        described_class.perform_now
      }.to have_enqueued_job(LockOddsJob).with(pool_tournament.id)
    end
  end

  it "skips pool tournaments before picks open" do
    travel_to(tournament.picks_open_at - 1.hour) do
      PoolTournament.create!(pool: pool, tournament: tournament)

      expect {
        described_class.perform_now
      }.not_to have_enqueued_job(LockOddsJob)
    end
  end
end

# frozen_string_literal: true

# Safety net: keep refreshing stored odds until picks lock (worker downtime,
# transient API failures, or pool tournaments added mid-window).
class EnsurePoolTournamentOddsLockedJob < ApplicationJob
  queue_as :default

  def perform
    PoolTournament.needs_odds_refresh.find_each do |pool_tournament|
      next unless pool_tournament.needs_odds_refresh?

      LockOddsJob.perform_later(pool_tournament.id)
    end
  end
end

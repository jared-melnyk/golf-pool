# frozen_string_literal: true

class LockOddsJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 5
  discard_on PoolTournamentOddsLocker::LockNotAllowedError

  def perform(pool_tournament_id, force: false)
    pool_tournament = PoolTournament.find_by(id: pool_tournament_id)
    return if pool_tournament.nil?

    PoolTournamentOddsLocker.new(pool_tournament: pool_tournament, force: force).call
  end
end

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

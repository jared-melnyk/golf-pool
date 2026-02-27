class SyncTournamentFieldJob < ApplicationJob
  queue_as :default

  def perform(tournament_id)
    tournament = Tournament.find_by(id: tournament_id)
    return if tournament.nil? || tournament.external_id.blank?

    BallDontLie::SyncTournamentField.new(tournament: tournament).call
  rescue => e
    Rails.logger.error("SyncTournamentFieldJob failed for tournament #{tournament_id}: #{e.class}: #{e.message}")
  end
end


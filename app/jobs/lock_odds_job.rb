class LockOddsJob < ApplicationJob
  queue_as :default

  def perform(pool_tournament_id)
    pool_tournament = PoolTournament.find_by(id: pool_tournament_id)
    return if pool_tournament.nil?

    tournament = pool_tournament.tournament
    return if tournament.external_id.blank?

    client = BallDontLie::Client.new
    data = client.fetch_all_futures(tournament_ids: [ tournament.external_id.to_i ], vendors: [ "draftkings" ])

    data.each do |future|
      next unless future["market_type"] == "tournament_winner"

      player = future["player"]
      next if player.blank?

      golfer = Golfer.find_by(external_id: player["id"].to_s)
      next unless golfer

      odds = PoolTournamentOdds.find_or_initialize_by(pool_tournament: pool_tournament, golfer: golfer)
      odds.american_odds = future["american_odds"]
      odds.vendor = future["vendor"]
      odds.locked_at = Time.current
      odds.save!
    end
  rescue => e
    Rails.logger.error("LockOddsJob failed for pool_tournament #{pool_tournament_id}: #{e.class}: #{e.message}")
  end
end

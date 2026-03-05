# frozen_string_literal: true

module BallDontLie
  class SyncTournamentResults
    def initialize(tournament:, client: nil)
      @tournament = tournament.is_a?(Tournament) ? tournament : Tournament.find(tournament)
      @client = client || Client.new
    end

    def call
      external_id = @tournament.external_id.presence
      raise ArgumentError, "Tournament has no external_id (API id)" if external_id.blank?

      api_results = @client.fetch_all_tournament_results(tournament_ids: [ external_id.to_i ])
      created = updated = 0
      api_results.each do |r|
        player = r["player"]
        next if player.blank?
        golfer = Golfer.find_or_initialize_by(external_id: player["id"].to_s)
        golfer.name = player["display_name"].presence || [ player["first_name"], player["last_name"] ].compact.join(" ")
        golfer.save! if golfer.new_record? || golfer.changed?

        result = TournamentResult.find_or_initialize_by(tournament: @tournament, golfer: golfer)
        result.position = r["position_numeric"] || r["position"]&.to_s&.to_i
        result.prize_money = r["earnings"]
        if result.new_record?
          result.save!
          created += 1
        elsif result.changed?
          result.save!
          updated += 1
        end
      end
      @tournament.update_column(:results_synced_at, Time.current)

      # Set champion from winner (position 1); completion is driven by champion, not results_synced_at.
      winner_result = @tournament.tournament_results.find_by(position: 1)
      if winner_result
        @tournament.update_column(:champion_golfer_id, winner_result.golfer_id)
      end

      { created: created, updated: updated, total: api_results.size }
    end
  end
end

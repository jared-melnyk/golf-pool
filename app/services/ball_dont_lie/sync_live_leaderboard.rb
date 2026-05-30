# frozen_string_literal: true

module BallDontLie
  class SyncLiveLeaderboard
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

        row = TournamentResult.find_or_initialize_by(tournament: @tournament, golfer: golfer)
        TournamentResult.assign_leaderboard_from_api(row, r)
        if row.new_record?
          row.save!
          created += 1
        elsif row.changed?
          row.save!
          updated += 1
        end
      end

      @tournament.update_column(:leaderboard_synced_at, Time.current)
      { created: created, updated: updated, total: api_results.size }
    end
  end
end

# frozen_string_literal: true

module BallDontLie
  # Sync golfers from a tournament's field (who is/was in the tournament).
  # Requires GOAT tier for tournament_field endpoint; on ALL-STAR you'll get 401.
  class SyncTournamentField
    def initialize(tournament:, client: nil)
      @tournament = tournament.is_a?(Tournament) ? tournament : Tournament.find(tournament)
      @client = client || Client.new
    end

    def call
      external_id = @tournament.external_id.presence
      raise ArgumentError, "Tournament has no external_id (API id). Sync tournaments from the API first." if external_id.blank?

      api_entries = @client.fetch_all_tournament_field(tournament_id: external_id.to_i)
      created = updated = 0
      field_golfer_ids = []
      api_entries.each do |entry|
        player = entry["player"]
        next if player.blank?
        golfer = Golfer.find_or_initialize_by(external_id: player["id"].to_s)
        golfer.name = player["display_name"].presence || [ player["first_name"], player["last_name"] ].compact.join(" ")
        if golfer.new_record?
          golfer.save!
          created += 1
        elsif golfer.changed?
          golfer.save!
          updated += 1
        end
        field_golfer_ids << golfer.id
      end
      # Replace tournament field atomically so no request can see a partial list
      # (e.g. after destroy_all but only 6–7 create!s committed).
      Tournament.transaction do
        @tournament.tournament_fields.destroy_all
        field_golfer_ids.uniq.each do |golfer_id|
          @tournament.tournament_fields.create!(golfer_id: golfer_id)
        end
      end
      { created: created, updated: updated, total: api_entries.size }
    end
  end
end

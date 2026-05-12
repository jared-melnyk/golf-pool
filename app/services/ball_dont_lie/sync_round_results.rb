# frozen_string_literal: true

module BallDontLie
  class SyncRoundResults
    def initialize(tournament:, player_ids: nil, client: nil)
      @tournament = tournament.is_a?(Tournament) ? tournament : Tournament.find(tournament)
      @player_ids = player_ids
      @client = client || Client.new
    end

    def call
      external_id = @tournament.external_id.presence
      raise ArgumentError, "Tournament has no external_id (API id)" if external_id.blank?

      pids = (@player_ids || derive_player_ids).uniq.reject { |id| id.to_i.zero? }
      tournament_ids = [ external_id.to_i ]

      raw = @client.fetch_all_player_round_results(tournament_ids: tournament_ids, player_ids: pids)
      formatter = PlayerRoundResultsFormatter.new(raw)

      if @tournament.started? && !@tournament.completed?
        current_round = formatter.current_round_number
        if current_round.present?
          cards = @client.fetch_all_player_scorecards(
            tournament_ids: tournament_ids,
            player_ids: pids,
            round_number: current_round
          )
          formatter.merge_scorecard_live!(cards) if cards.present?
        end
      end

      stats = upsert_rows(formatter.by_player_id)
      @tournament.update_column(:live_results_synced_at, Time.current)
      stats
    end

    private

    def derive_player_ids
      ids = Pick
              .joins(pick_golfers: :golfer)
              .where(pool_tournament: PoolTournament.where(tournament_id: @tournament.id))
              .pluck("golfers.external_id")
              .compact
              .map(&:to_i)

      if @tournament.completed? && @tournament.no_cut_event?
        field_ids = @tournament.tournament_fields.joins(:golfer).pluck("golfers.external_id").compact.map(&:to_i)
        ids = (ids + field_ids)
      end

      ids.uniq
    end

    def upsert_rows(by_player_id)
      created = 0
      updated = 0
      golfer_id_cache = {}

      by_player_id.each do |player_id, payload|
        golfer_id = (golfer_id_cache[player_id] ||= Golfer.where(external_id: player_id.to_s).pick(:id))
        next if golfer_id.nil?

        payload[:rounds].each do |round_number, round_data|
          row = TournamentRoundResult.find_or_initialize_by(
            tournament_id: @tournament.id,
            golfer_id: golfer_id,
            round_number: round_number
          )
          row.score_to_par = round_data[:score_to_par]
          row.last_hole_completed = round_data[:last_hole_completed]
          if row.new_record?
            row.save!
            created += 1
          elsif row.changed?
            row.save!
            updated += 1
          end
        end
      end

      { created: created, updated: updated, rounds_seen: by_player_id.values.sum { |p| p[:rounds].size } }
    end
  end
end

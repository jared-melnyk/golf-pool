module BallDontLie
  class PlayerRoundResultsFormatter
    attr_reader :by_player_id

    def initialize(raw_results)
      @by_player_id = build_index(Array(raw_results))
      compute_totals!
    end

    def current_round_number
      rounds = @by_player_id.values.flat_map { |h| h[:rounds].keys }
      rounds.compact.max
    end

    # Merge intra-round (live) scores from player_scorecards API into by_player_id.
    # Scorecard rows are hole-by-hole; we sum (score - par) per player per round and track last hole completed.
    def merge_scorecard_live!(scorecard_rows)
      return if scorecard_rows.blank?

      by_player_round = {}
      last_hole_by_player_round = {}
      scorecard_rows.each do |row|
        player = row["player"]
        next if player.blank?
        player_id = player["id"].to_i
        next if player_id.zero?
        round_number = (row["round_number"] || row["round"]).to_i
        next if round_number <= 0
        hole_num = (row["hole_number"] || row["hole"]).to_i
        score = (row["score"] || row["strokes"]).to_i
        par = row["par"].to_i
        key = [ player_id, round_number ]
        by_player_round[key] ||= 0
        by_player_round[key] += (score - par)
        last_hole_by_player_round[key] = [ (last_hole_by_player_round[key] || 0), hole_num ].max
      end

      by_player_round.each do |(player_id, round_number), to_par|
        player_hash = (@by_player_id[player_id] ||= { rounds: {}, total_to_par: nil, position: nil })
        next if player_hash[:rounds][round_number].present? # keep completed round from API
        last_hole = last_hole_by_player_round[[ player_id, round_number ]]
        player_hash[:rounds][round_number] = {
          score: nil,
          par_relative: format_par_relative(to_par),
          score_to_par: to_par,
          last_hole_completed: last_hole.positive? ? last_hole : nil
        }
      end
      compute_totals!
    end

    private

    def build_index(raw_results)
      index = {}

      raw_results.each do |entry|
        player = entry["player"]
        next if player.blank?

        player_id = player["id"].to_i
        next if player_id.zero?

        round_number = entry["round_number"] || entry["round"]
        round_number = round_number.to_i if round_number.respond_to?(:to_i)
        next if round_number.to_i <= 0

        # API returns par_relative_score and score per round (see balldontlie PGA docs)
        score_to_par = entry["par_relative_score"] || entry["score_to_par"] || entry["to_par"]
        total_to_par = entry["total_to_par"]
        position = entry["position"] || entry["position_display"] || entry["position_numeric"]

        player_hash = (index[player_id] ||= { rounds: {}, total_to_par: nil, position: nil })

        numeric = score_to_par.to_i
        # Completed round from API: no hole-by-hole data, so treat as finished (F)
        player_hash[:rounds][round_number] = {
          score: entry["score"],
          par_relative: format_par_relative(score_to_par),
          score_to_par: numeric,
          last_hole_completed: 18
        }

        player_hash[:total_to_par] = total_to_par unless total_to_par.nil?
        player_hash[:position] = position unless position.nil?
      end

      index
    end

    # Set total_to_par from sum of round score_to_par when API did not provide it.
    def compute_totals!
      @by_player_id.each do |_player_id, player_hash|
        next if player_hash[:total_to_par].present?
        sum = player_hash[:rounds].values.sum { |r| (r[:score_to_par] || 0).to_i }
        player_hash[:total_to_par] = sum if player_hash[:rounds].any?
      end
    end

    def format_par_relative(value)
      return nil if value.nil?
      v = value.to_i
      return "E" if v.zero?
      v.positive? ? "+#{v}" : v.to_s
    end
  end
end

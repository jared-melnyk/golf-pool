module BallDontLie
  class PlayerRoundResultsFormatter
    attr_reader :by_player_id

    def initialize(raw_results)
      @by_player_id = build_index(Array(raw_results))
    end

    def current_round_number
      rounds = @by_player_id.values.flat_map { |h| h[:rounds].keys }
      rounds.compact.max
    end

    # Merge intra-round (live) scores from player_scorecards API into by_player_id.
    # Scorecard rows are hole-by-hole; we sum (score - par) per player per round.
    def merge_scorecard_live!(scorecard_rows)
      return if scorecard_rows.blank?

      by_player_round = {}
      scorecard_rows.each do |row|
        player = row["player"]
        next if player.blank?
        player_id = player["id"].to_i
        next if player_id.zero?
        round_number = (row["round_number"] || row["round"]).to_i
        next if round_number <= 0
        score = row["score"].to_i
        par = row["par"].to_i
        key = [ player_id, round_number ]
        by_player_round[key] ||= 0
        by_player_round[key] += (score - par)
      end

      by_player_round.each do |(player_id, round_number), to_par|
        player_hash = (@by_player_id[player_id] ||= { rounds: {}, total_to_par: nil, position: nil })
        next if player_hash[:rounds][round_number].present? # keep completed round from API
        player_hash[:rounds][round_number] = {
          score: nil,
          par_relative: format_par_relative(to_par)
        }
      end
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

        player_hash[:rounds][round_number] = {
          score: entry["score"],
          par_relative: format_par_relative(score_to_par)
        }

        player_hash[:total_to_par] = total_to_par unless total_to_par.nil?
        player_hash[:position] = position unless position.nil?
      end

      index
    end

    def format_par_relative(value)
      return nil if value.nil?
      v = value.to_i
      return "E" if v.zero?
      v.positive? ? "+#{v}" : v.to_s
    end
  end
end

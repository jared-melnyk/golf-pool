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

    private

    def build_index(raw_results)
      index = {}

      raw_results.each do |entry|
        player = entry["player"]
        next if player.blank?

        player_id = player["id"]
        next if player_id.blank?

        round_number = entry["round_number"] || entry["round"]
        round_number = round_number.to_i if round_number.respond_to?(:to_i)
        next if round_number.to_i <= 0

        score_to_par = entry["score_to_par"] || entry["to_par"]
        total_to_par = entry["total_to_par"]
        position = entry["position"] || entry["position_display"] || entry["position_numeric"]

        player_hash = (index[player_id] ||= { rounds: {}, total_to_par: nil, position: nil })

        player_hash[:rounds][round_number] = {
          score: score_to_par,
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

# frozen_string_literal: true

# All format standings boards for a single round.
class RoundStandings
  def initialize(round)
    @round = round
  end

  def call
    types = @round.games.distinct.order(:game_type).pluck(:game_type)
    formats = types.map do |game_type|
      board = RoundFormatStandings.new(round: @round, game_type: game_type).call
      {
        game_type: game_type,
        label: Game.type_label(game_type),
        field: board[:field],
        matches: board[:matches]
      }
    end

    { round_id: @round.id, round_name: @round.name, formats: formats }
  end
end

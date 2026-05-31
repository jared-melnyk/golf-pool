# frozen_string_literal: true

module GamesHelper
  def game_type_label(game_type)
    Game.type_label(game_type)
  end
end

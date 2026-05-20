# frozen_string_literal: true

module GameTestHelpers
  def create_test_game!(event:, round:, game_type: "best_ball", status: "active", creator: nil, name: nil)
    creator ||= User.create!(name: "Host", email: "host-#{SecureRandom.hex(4)}@test.com", password: "pw")
    name ||= "#{game_type.to_s.tr('_', ' ').titleize} · #{round.course_name}"

    Game.create!(
      event: event,
      round: round,
      game_type: game_type,
      status: status,
      name: name,
      creator: creator
    )
  end
end

RSpec.configure do |config|
  config.include GameTestHelpers
end

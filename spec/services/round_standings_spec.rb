# frozen_string_literal: true

require "rails_helper"

RSpec.describe RoundStandings do
  let(:event) { Event.create!(name: "Trip", status: "active") }
  let(:round) do
    Round.create!(
      event: event, name: "R", played_on: Date.today,
      golf_course_api_course_id: 1, course_name: "C", tee_name: "W",
      tee_gender: "male", course_rating: 72.0, slope_rating: 113, par_total: 72,
      hole_pars: Array.new(18, 4), hole_handicaps: (1..18).to_a
    )
  end

  it "returns a board per game_type on the round" do
    create_test_game!(event: event, round: round, game_type: "best_ball", name: "BB A")
    create_test_game!(event: event, round: round, game_type: "vegas", name: "Vegas A")
    GameTeam.create!(game: Game.find_by!(name: "BB A"), name: "Group A")

    result = described_class.new(round).call

    expect(result[:formats].map { |f| f[:game_type] }).to eq([ "best_ball", "vegas" ])
    expect(result[:formats].first[:label]).to eq("Best Ball")
  end
end

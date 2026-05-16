require "rails_helper"

RSpec.describe Game, type: :model do
  let(:event) { Event.create!(name: "Test Event", status: "active") }
  let(:round) do
    Round.create!(
      event: event,
      name: "Morning round",
      played_on: Date.today,
      golf_course_api_course_id: 1,
      course_name: "Test Course",
      tee_name: "Blue",
      tee_gender: "male",
      course_rating: 72.1,
      slope_rating: 130,
      par_total: 72,
      hole_pars: Array.new(18, 4),
      hole_handicaps: (1..18).to_a
    )
  end

  it "is valid with event, round, and game_type" do
    game = Game.new(event: event, round: round, game_type: "best_ball")
    expect(game).to be_valid
  end

  it "is invalid without game_type" do
    game = Game.new(event: event, round: round, game_type: nil)
    expect(game).not_to be_valid
  end

  it "is invalid with unknown game_type" do
    game = Game.new(event: event, round: round, game_type: "scramble")
    expect(game).not_to be_valid
  end

  it "is valid with forty_score game type" do
    game = Game.new(event: event, round: round, game_type: "forty_score")
    expect(game).to be_valid
  end

  it "uses 100% playing handicap allowance for forty_score" do
    game = Game.new(event: event, round: round, game_type: "forty_score")
    expect(game.playing_handicap_allowance_percent).to eq(100)
  end

  it "defaults submitted to false" do
    game = Game.new(event: event, round: round, game_type: "best_ball")
    expect(game.submitted).to eq(false)
  end
end

require "rails_helper"

RSpec.describe HoleScore, type: :model do
  let(:user) { User.create!(name: "Bob", email: "bob@example.com", password: "password123") }
  let(:event) { Event.create!(name: "E", status: "active") }
  let(:round) do
    Round.create!(
      event: event, name: "R", played_on: Date.today,
      golf_course_api_course_id: 1, course_name: "C", tee_name: "W",
      tee_gender: "male", course_rating: 70.0, slope_rating: 115, par_total: 72,
      hole_pars: Array.new(18, 4), hole_handicaps: (1..18).to_a
    )
  end
  let(:game) { Game.create!(event: event, round: round, game_type: "best_ball") }
  let(:team) { GameTeam.create!(game: game, name: "Team A") }
  let(:gtp) { GameTeamPlayer.create!(game_team: team, user: user) }

  it "is valid for hole 1-18 with a gross score" do
    hs = HoleScore.new(game_team_player: gtp, hole_number: 1, gross_score: 5)
    expect(hs).to be_valid
  end

  it "is invalid for hole 0" do
    hs = HoleScore.new(game_team_player: gtp, hole_number: 0, gross_score: 4)
    expect(hs).not_to be_valid
  end

  it "is invalid for hole 19" do
    hs = HoleScore.new(game_team_player: gtp, hole_number: 19, gross_score: 4)
    expect(hs).not_to be_valid
  end

  it "allows nil gross_score (not yet entered)" do
    hs = HoleScore.new(game_team_player: gtp, hole_number: 3, gross_score: nil)
    expect(hs).to be_valid
  end

  it "enforces uniqueness of hole_number per game_team_player" do
    HoleScore.create!(game_team_player: gtp, hole_number: 5, gross_score: 4)
    dup = HoleScore.new(game_team_player: gtp, hole_number: 5, gross_score: 3)
    expect(dup).not_to be_valid
  end
end

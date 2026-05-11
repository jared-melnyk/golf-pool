require "rails_helper"

RSpec.describe GameTeamPlayer, type: :model do
  let(:user) { User.create!(name: "Alice", email: "alice@example.com", password: "password123", ghin_handicap_index: 14.2) }
  let(:event) { Event.create!(name: "Test Event", status: "active") }
  let(:round) do
    Round.create!(
      event: event, name: "Round", played_on: Date.today,
      golf_course_api_course_id: 1, course_name: "Course", tee_name: "White",
      tee_gender: "male", course_rating: 70.5, slope_rating: 120, par_total: 72,
      hole_pars: Array.new(18, 4), hole_handicaps: (1..18).to_a
    )
  end
  let(:game) { Game.create!(event: event, round: round, game_type: "best_ball") }
  let(:team) { GameTeam.create!(game: game, name: "Team A") }

  it "snapshots the user handicap index on creation" do
    gtp = GameTeamPlayer.create!(game_team: team, user: user)
    expect(gtp.snapshot_handicap_index).to eq(14.2)
  end
end

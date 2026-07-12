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
  let(:game) { create_test_game!(event: event, round: round, game_type: "best_ball") }
  let(:team) { GameTeam.create!(game: game, name: "Team A") }

  it "snapshots the user handicap index on creation" do
    gtp = GameTeamPlayer.create!(game_team: team, user: user)
    expect(gtp.snapshot_handicap_index).to eq(14.2)
  end

  it "snapshots the guest handicap index on creation" do
    guest = GameGuest.create!(game: game, name: "Jon", handicap_index: 18.5)
    gtp = GameTeamPlayer.create!(game_team: team, game_guest: guest)
    expect(gtp.snapshot_handicap_index).to eq(18.5)
    expect(gtp.display_name).to eq("Jon")
  end

  it "requires exactly one of user or game_guest" do
    expect(GameTeamPlayer.new(game_team: team)).not_to be_valid
    guest = GameGuest.create!(game: game, name: "Jon", handicap_index: 10.0)
    expect(GameTeamPlayer.new(game_team: team, user: user, game_guest: guest)).not_to be_valid
  end

  it "returns display_name from the user when present" do
    gtp = GameTeamPlayer.create!(game_team: team, user: user)
    expect(gtp.display_name).to eq("Alice")
  end
end

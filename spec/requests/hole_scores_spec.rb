# frozen_string_literal: true

require "rails_helper"

RSpec.describe "HoleScores (40 Score)", type: :request do
  let(:commissioner) { User.create!(name: "Comm", email: "comm-fs@test.com", password: "pw") }
  let(:event) { Event.create!(name: "Out", status: "active") }
  let!(:commissioner_membership) { EventMembership.create!(event: event, user: commissioner, role: "commissioner") }
  let(:round) do
    Round.create!(
      event: event, name: "R", played_on: Date.today,
      golf_course_api_course_id: 1, course_name: "C", tee_name: "Blue",
      tee_gender: "male", course_rating: 72.0, slope_rating: 113, par_total: 72,
      hole_pars: Array.new(18, 4), hole_handicaps: (1..18).to_a
    )
  end
  let(:game) { Game.create!(event: event, round: round, game_type: "forty_score") }
  let(:team) { GameTeam.create!(game: game, name: "Foursome") }
  let(:alice) { User.create!(name: "Pa", email: "pa@test.com", password: "pw") }
  let(:bob) { User.create!(name: "Pb", email: "pb@test.com", password: "pw") }
  let(:cindy) { User.create!(name: "Pc", email: "pc@test.com", password: "pw") }
  let(:dan) { User.create!(name: "Pd", email: "pd@test.com", password: "pw") }
  let!(:gtp_alice) { GameTeamPlayer.create!(game_team: team, user: alice) }

  before do
    [ alice, bob, cindy, dan ].each do |u|
      EventMembership.create!(event: event, user: u, role: "player")
      GameTeamPlayer.create!(game_team: team, user: u) unless u == alice
    end
    team.reload.game_team_players.each do |gtp|
      HoleScore.find_or_create_by!(game_team_player: gtp, hole_number: 1) { |s| s.gross_score = 4 }
    end
    post login_path, params: { email: bob.email, password: "pw" }
  end

  it "lets a teammate toggle another golfer's forty pick" do
    patch event_game_hole_score_path(event, game, gtp_alice), params: {
      hole_number: 1,
      forty_pick_only: "1",
      included_in_forty_score: "1"
    }

    expect(response).to redirect_to(event_game_path(event, game))
    expect(HoleScore.find_by!(game_team_player_id: gtp_alice.id, hole_number: 1).included_in_forty_score).to be(true)
  end
end

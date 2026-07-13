# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Event standings", type: :request do
  let(:user) { User.create!(email: "u@example.com", name: "Owner", password: "password") }
  let(:event) { Event.create!(name: "Michigan") }
  let(:round) do
    Round.create!(
      event: event, name: "Wolf River", played_on: Date.today,
      golf_course_api_course_id: 1, course_name: "Wolf River", tee_name: "W",
      tee_gender: "male", course_rating: 72.0, slope_rating: 113, par_total: 72,
      hole_pars: Array.new(18, 4), hole_handicaps: (1..18).to_a
    )
  end

  before do
    event.event_memberships.create!(user: user, role: "commissioner")
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
  end

  it "shows trip standings index for members" do
    game = create_test_game!(event: event, round: round, game_type: "best_ball", name: "Best Ball · A")
    team = GameTeam.create!(game: game, name: "Group A")
    player = User.create!(name: "A", email: "a@test.com", password: "pw", ghin_handicap_index: 0)
    event.event_memberships.create!(user: player, role: "player")
    gtp = GameTeamPlayer.create!(game_team: team, user: player)
    (1..18).each { |h| HoleScore.create!(game_team_player: gtp, hole_number: h, gross_score: 4) }

    get event_standings_path(event)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Standings")
    expect(response.body).to include("Overall low net")
    expect(response.body).to include("100% course handicap")
    expect(response.body).to include(">A<")
    expect(response.body).to include("Wolf River")
    expect(response.body).to include("Best Ball standings")
    expect(response.body).to include("Group A")
  end

  it "embeds round standings on the event page" do
    game = create_test_game!(event: event, round: round, game_type: "best_ball", name: "Best Ball · A")
    GameTeam.create!(game: game, name: "Group A")

    get event_path(event)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Standings")
    expect(response.body).to include("Overall low net")
    expect(response.body).to include("Best Ball standings")
    expect(response.body).to include("Group A")
  end
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Legacy game routes", type: :request do
  let(:creator) { User.create!(name: "Comm", email: "comm@test.com", password: "pw") }
  let(:event) { Event.create!(name: "Outing", status: "active") }
  let(:round) do
    Round.create!(
      event: event, name: "Morning", played_on: Date.today,
      golf_course_api_course_id: 1, course_name: "GC", tee_name: "Blue",
      tee_gender: "male", course_rating: 72.0, slope_rating: 128, par_total: 72,
      hole_pars: Array.new(18, 4), hole_handicaps: (1..18).to_a
    )
  end
  let(:game) do
    create_test_game!(event: event, round: round, game_type: "best_ball", creator: creator)
  end

  before { post login_path, params: { email: creator.email, password: "pw" } }

  it "redirects old event-nested game URL to token URL" do
    get "/events/#{event.token}/games/#{game.id}"
    expect(response).to redirect_to(game_path(game))
  end

  it "redirects old edit_teams URL" do
    get "/events/#{event.token}/games/#{game.id}/edit_teams"
    expect(response).to redirect_to("/games/#{game.token}/edit_teams")
  end
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Games", type: :request do
  let(:commissioner) { User.create!(name: "Comm", email: "comm@test.com", password: "pw") }
  let(:event) { Event.create!(name: "Outing", status: "active") }
  let!(:membership) { EventMembership.create!(event: event, user: commissioner, role: "commissioner") }
  let(:round) do
    Round.create!(
      event: event, name: "Morning", played_on: Date.today,
      golf_course_api_course_id: 1, course_name: "GC", tee_name: "Blue",
      tee_gender: "male", course_rating: 72.0, slope_rating: 128, par_total: 72,
      hole_pars: Array.new(18, 4), hole_handicaps: (1..18).to_a
    )
  end

  before { post login_path, params: { email: commissioner.email, password: "pw" } }

  describe "GET /events/:event_token/games/new" do
    it "renders new game form for commissioners" do
      get new_event_game_path(event)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /events/:event_token/games" do
    it "creates a game and redirects to edit_teams" do
      expect {
        post event_games_path(event), params: { game: { round_id: round.id, game_type: "best_ball" } }
      }.to change(Game, :count).by(1)
      expect(response).to redirect_to(edit_teams_event_game_path(event, Game.last))
    end
  end

  describe "GET /events/:event_token/games/:id" do
    let(:game) { Game.create!(event: event, round: round, game_type: "best_ball") }

    it "renders the scorecard page" do
      get event_game_path(event, game)
      expect(response).to have_http_status(:ok)
    end
  end
end

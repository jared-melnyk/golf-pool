# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Tournaments", type: :request do
  let(:user) { User.create!(name: "Test User", email: "test@example.com", password: "password") }

  before { post login_path, params: { email: user.email, password: "password" } }

  describe "GET /tournaments/:id" do
    it "returns success and shows the tournament" do
      tournament = Tournament.create!(name: "Masters", starts_at: 1.day.from_now, ends_at: 4.days.from_now)
      get tournament_path(tournament)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Masters")
      expect(response.body).to include("Results")
    end

    it "shows sync buttons when tournament has external_id" do
      tournament = Tournament.create!(name: "PGA", starts_at: 1.day.from_now, ends_at: 4.days.from_now, external_id: "20")
      get tournament_path(tournament)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Sync field")
      expect(response.body).to include("Sync results")
    end

    it "shows results list when tournament has results" do
      tournament = Tournament.create!(name: "Open", starts_at: 1.day.from_now, ends_at: 4.days.from_now)
      golfer = Golfer.create!(name: "Scottie Scheffler", external_id: "185")
      TournamentResult.create!(tournament: tournament, golfer: golfer, position: 1, prize_money: 1_000_000)
      get tournament_path(tournament)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Scottie Scheffler")
      expect(response.body).to include("1 —")
    end
  end
end

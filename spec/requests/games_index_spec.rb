# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Games index", type: :request do
  let(:user) { User.create!(name: "U", email: "u@test.com", password: "pw") }

  before { post login_path, params: { email: user.email, password: "pw" } }

  it "lists ad hoc games the user hosts" do
    game = Game.create!(name: "My Game", creator: user, status: "draft")
    GameMembership.create!(game: game, user: user, role: "host")
    get games_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("My Game")
  end
end

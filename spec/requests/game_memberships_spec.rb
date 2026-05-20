# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Game memberships", type: :request do
  let(:host) { User.create!(name: "Host", email: "host@test.com", password: "pw") }
  let(:player) { User.create!(name: "Player", email: "player@test.com", password: "pw") }
  let(:game) { Game.create!(name: "Casual", creator: host, status: "draft") }
  let!(:host_membership) { GameMembership.create!(game: game, user: host, role: "host") }
  let!(:player_membership) { GameMembership.create!(game: game, user: player, role: "player") }

  before { post login_path, params: { email: host.email, password: "pw" } }

  it "promotes player to cohost" do
    patch game_game_membership_path(game, player_membership),
          params: { game_membership: { role: "cohost" } }

    expect(response).to redirect_to(game_path(game))
    expect(player_membership.reload.role).to eq("cohost")
  end
end

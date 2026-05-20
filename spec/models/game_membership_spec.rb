require "rails_helper"

RSpec.describe GameMembership, type: :model do
  let(:host) { User.create!(name: "H", email: "h@test.com", password: "pw") }
  let(:game) do
    Game.create!(
      name: "Test",
      creator: host,
      status: "draft",
      token: "tok123",
      game_type: nil,
      round: nil,
      event: nil
    )
  end

  it "is valid with host role" do
    gm = described_class.new(game: game, user: host, role: "host")
    expect(gm).to be_valid
  end

  it "rejects unknown role" do
    gm = described_class.new(game: game, user: host, role: "admin")
    expect(gm).not_to be_valid
  end

  it "enforces unique user per game" do
    described_class.create!(game: game, user: host, role: "host")
    dup = described_class.new(game: game, user: host, role: "player")
    expect(dup).not_to be_valid
  end
end

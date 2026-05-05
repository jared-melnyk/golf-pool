require "rails_helper"

RSpec.describe "picks/_tournament_with_picks", type: :view do
  include ActiveSupport::Testing::TimeHelpers
  let(:pool) { Pool.create!(name: "Test Pool") }
  let(:tournament_starts_at) { 5.days.from_now.change(usec: 0) }
  let(:tournament) { Tournament.create!(name: "Event", starts_at: tournament_starts_at) }

  it "shows picks-open message before picks_open_at" do
    travel_to(tournament.picks_open_at - 1.hour) do
      render partial: "picks/tournament_with_picks", locals: { tournament: tournament, pool: pool, pick: nil }

      expect(rendered).to include("Picks open on")
      expect(rendered).not_to include("Make picks")
    end
  end

  it "shows Make picks as a prominent button when picks are open" do
    travel_to(tournament.picks_open_at + 1.hour) do
      render partial: "picks/tournament_with_picks", locals: { tournament: tournament, pool: pool, pick: nil }

      expect(rendered).to include("Make picks")
      expect(rendered).to include("bg-emerald-600")
    end
  end

  it "hides Edit link once tournament is locked" do
    pool_tournament = PoolTournament.create!(pool: pool, tournament: tournament)
    user = User.create!(email: "user@example.com", name: "User", password: "password")
    pick = Pick.create!(user: user, pool_tournament: pool_tournament)

    travel_to(tournament.starts_at + 1.hour) do
      render partial: "picks/tournament_with_picks", locals: { tournament: tournament, pool: pool, pick: pick }

      expect(rendered).not_to include("Edit")
    end
  end
end

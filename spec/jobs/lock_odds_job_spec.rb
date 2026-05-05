require "rails_helper"

RSpec.describe LockOddsJob, type: :job do
  let(:pool) { Pool.create!(name: "Test Pool") }
  let(:tournament) { Tournament.create!(name: "Masters", starts_at: 1.day.from_now, ends_at: 4.days.from_now, external_id: "20") }
  let(:pool_tournament) { PoolTournament.create!(pool: pool, tournament: tournament) }
  let!(:golfer) { Golfer.create!(name: "Scottie Scheffler", external_id: "185") }

  it "creates odds rows for golfers in the pool tournament based on futures data" do
    client = instance_double(BallDontLie::Client)
    allow(BallDontLie::Client).to receive(:new).and_return(client)
    allow(client).to receive(:fetch_all_futures).and_return(
      [
        {
          "market_type" => "tournament_winner",
          "player" => { "id" => 185, "display_name" => "Scottie Scheffler" },
          "tournament" => { "id" => 20 },
          "american_odds" => 700,
          "vendor" => "draftkings"
        }
      ]
    )

    expect {
      described_class.perform_now(pool_tournament.id)
    }.to change { PoolTournamentOdds.count }.by(1)

    odds = PoolTournamentOdds.last
    expect(odds.pool_tournament).to eq(pool_tournament)
    expect(odds.golfer).to eq(golfer)
    expect(odds.american_odds).to eq(700)
    expect(odds.vendor).to eq("draftkings")
    expect(odds.locked_at).to be_within(5.seconds).of(Time.current)
  end

  it "ignores futures that are not tournament_winner market type" do
    client = instance_double(BallDontLie::Client)
    allow(BallDontLie::Client).to receive(:new).and_return(client)
    allow(client).to receive(:fetch_all_futures).and_return(
      [
        {
          "market_type" => "make_the_cut",
          "player" => { "id" => 185, "display_name" => "Scottie Scheffler" },
          "american_odds" => -240,
          "vendor" => "draftkings"
        }
      ]
    )

    expect { described_class.perform_now(pool_tournament.id) }.not_to change { PoolTournamentOdds.count }
  end
end

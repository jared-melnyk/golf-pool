# frozen_string_literal: true

require "rails_helper"

RSpec.describe BallDontLie::SyncTournamentResults do
  let(:tournament) { Tournament.create!(name: "Masters", starts_at: 1.day.ago, ends_at: 1.day.from_now, external_id: "20") }
  let(:client) { instance_double(BallDontLie::Client, fetch_all_tournament_results: api_results) }
  let(:api_results) { [] }

  before do
    allow(BallDontLie::Client).to receive(:new).and_return(client)
  end

  describe "#call" do
    context "when tournament has no external_id" do
      let(:tournament) { Tournament.create!(name: "Local", starts_at: 1.day.from_now, ends_at: 4.days.from_now, external_id: nil) }

      it "raises ArgumentError" do
        expect { described_class.new(tournament: tournament, client: client).call }.to raise_error(ArgumentError, /external_id/)
      end
    end

    context "with API results" do
      let(:api_results) do
        [
          {
            "player" => { "id" => 185, "display_name" => "Scottie Scheffler" },
            "position_numeric" => 1,
            "earnings" => 2_500_000
          },
          {
            "player" => { "id" => 282, "first_name" => "Rory", "last_name" => "McIlroy" },
            "position" => "2",
            "earnings" => 1_200_000
          }
        ]
      end

      it "creates golfers and tournament results" do
        expect(client).to receive(:fetch_all_tournament_results).with(tournament_ids: [ 20 ]).and_return(api_results)

        result = described_class.new(tournament: tournament, client: client).call

        expect(result).to eq(created: 2, updated: 0, total: 2)
        expect(Golfer.count).to eq(2)
        expect(tournament.tournament_results.count).to eq(2)
        scottie = tournament.tournament_results.joins(:golfer).find_by(golfers: { external_id: "185" })
        expect(scottie.position).to eq(1)
        expect(scottie.prize_money).to eq(2_500_000)
        rory = tournament.tournament_results.joins(:golfer).find_by(golfers: { external_id: "282" })
        expect(rory.golfer.name).to eq("Rory McIlroy")
        expect(rory.position).to eq(2)
        expect(rory.prize_money).to eq(1_200_000)
      end

      it "updates tournament results_synced_at" do
        described_class.new(tournament: tournament, client: client).call
        expect(tournament.reload.results_synced_at).to be_within(5.seconds).of(Time.current)
      end

      it "sets champion_golfer_id to the winner (position 1)" do
        described_class.new(tournament: tournament, client: client).call
        scottie = Golfer.find_by(external_id: "185")
        expect(tournament.reload.champion_golfer_id).to eq(scottie.id)
        expect(tournament.champion_golfer).to eq(scottie)
      end
    end

    context "when result already exists (update)" do
      let(:golfer) { Golfer.create!(name: "Scottie", external_id: "185") }
      let(:api_results) do
        [
          {
            "player" => { "id" => 185, "display_name" => "Scottie Scheffler" },
            "position_numeric" => 1,
            "earnings" => 3_000_000
          }
        ]
      end

      before do
        TournamentResult.create!(tournament: tournament, golfer: golfer, position: 2, prize_money: 1_000_000)
      end

      it "updates existing result and returns updated count" do
        result = described_class.new(tournament: tournament, client: client).call
        expect(result).to eq(created: 0, updated: 1, total: 1)
        tr = tournament.tournament_results.find_by(golfer: golfer)
        expect(tr.position).to eq(1)
        expect(tr.prize_money).to eq(3_000_000)
        expect(golfer.reload.name).to eq("Scottie Scheffler")
      end
    end

    context "when API returns entry with blank player" do
      let(:api_results) do
        [
          { "player" => nil, "position_numeric" => 99, "earnings" => 0 },
          {
            "player" => { "id" => 185, "display_name" => "Scottie Scheffler" },
            "position_numeric" => 1,
            "earnings" => 2_500_000
          }
        ]
      end

      it "skips blank player and still processes the rest" do
        result = described_class.new(tournament: tournament, client: client).call
        expect(result).to eq(created: 1, updated: 0, total: 2)
        expect(tournament.tournament_results.count).to eq(1)
      end
    end
  end
end

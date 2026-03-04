# frozen_string_literal: true

require "rails_helper"

RSpec.describe BallDontLie::SyncTournaments do
  let(:client) { instance_double(BallDontLie::Client, fetch_all_tournaments: api_tournaments) }
  let(:api_tournaments) { [] }

  before do
    allow(BallDontLie::Client).to receive(:new).and_return(client)
  end

  describe "#call" do
    context "when API returns tournament with purse" do
      let(:api_tournaments) do
        [
          {
            "id" => 42,
            "name" => "The Masters",
            "start_date" => "2025-04-10",
            "end_date" => "Apr 10 - 13",
            "purse" => "$8,400,000"
          }
        ]
      end

      it "sets total_prize_pool from parsed purse" do
        result = described_class.new(season: 2025, client: client).call

        expect(result[:created]).to eq(1)
        tournament = Tournament.find_by(external_id: "42")
        expect(tournament).to be_present
        expect(tournament.total_prize_pool).to eq(BigDecimal("8400000"))
      end
    end
  end
end

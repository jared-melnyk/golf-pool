# frozen_string_literal: true

require "rails_helper"

RSpec.describe BallDontLie::Client do
  let(:api_key) { "test-key" }

  before do
    stub_const("ENV", ENV.to_hash.merge("BALLDONTLIE_API_KEY" => api_key))
  end

  describe "#fetch_all (private; exercised via fetch_all_player_round_results)" do
    let(:client) { described_class.new(api_key: api_key) }

    it "does not sleep before fetching the first page" do
      page1 = { "data" => [ { "x" => 1 } ], "meta" => { "next_cursor" => nil, "per_page" => 100 } }
      allow(client).to receive(:player_round_results).and_return(page1)
      expect(client).not_to receive(:sleep)
      client.fetch_all_player_round_results(tournament_ids: [ 1 ], player_ids: [ 1 ])
    end

    it "sleeps between subsequent pages" do
      page1 = { "data" => Array.new(100, { "x" => 1 }), "meta" => { "next_cursor" => "abc", "per_page" => 100 } }
      page2 = { "data" => [ { "x" => 2 } ], "meta" => { "next_cursor" => nil, "per_page" => 100 } }
      allow(client).to receive(:player_round_results).and_return(page1, page2)
      expect(client).to receive(:sleep).once.with(BallDontLie::Client::RATE_LIMIT_DELAY)
      client.fetch_all_player_round_results(tournament_ids: [ 1 ], player_ids: [ 1 ])
    end
  end
end

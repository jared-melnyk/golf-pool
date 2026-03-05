require "rails_helper"

RSpec.describe BallDontLie::PlayerRoundResultsFormatter do
  let(:raw_results) do
    [
      {
        "player" => { "id" => 185, "display_name" => "Scottie Scheffler" },
        "round_number" => 1,
        "score" => 68,
        "par_relative_score" => -3,
        "total_to_par" => -3,
        "position" => "1"
      },
      {
        "player" => { "id" => 185, "display_name" => "Scottie Scheffler" },
        "round_number" => 2,
        "score" => 71,
        "par_relative_score" => 0,
        "total_to_par" => -3,
        "position" => "T2"
      },
      {
        "player" => { "id" => 282, "display_name" => "Rory McIlroy" },
        "round_number" => 1,
        "score" => 72,
        "par_relative_score" => 1,
        "total_to_par" => 1,
        "position" => "T10"
      }
    ]
  end

  it "indexes results by player id with rounds and totals" do
    formatter = described_class.new(raw_results)

    index = formatter.by_player_id
    expect(index.keys).to contain_exactly(185, 282)

    scottie = index[185]
    expect(scottie[:rounds].keys).to contain_exactly(1, 2)
    expect(scottie[:rounds][1][:par_relative]).to eq("-3")
    expect(scottie[:rounds][2][:par_relative]).to eq("E")
    expect(scottie[:total_to_par]).to eq(-3)
    expect(scottie[:position]).to eq("T2")

    rory = index[282]
    expect(rory[:rounds].keys).to contain_exactly(1)
    expect(rory[:rounds][1][:par_relative]).to eq("+1")
    expect(rory[:total_to_par]).to eq(1)
    expect(rory[:position]).to eq("T10")
  end

  it "returns the highest round number as current_round_number" do
    formatter = described_class.new(raw_results)
    expect(formatter.current_round_number).to eq(2)
  end

  describe "#merge_scorecard_live!" do
    it "fills round cells from hole-by-hole scorecard when no completed round result exists" do
      formatter = described_class.new([])
      scorecards = [
        { "player" => { "id" => 100 }, "round_number" => 1, "score" => 3, "par" => 4 },
        { "player" => { "id" => 100 }, "round_number" => 1, "score" => 3, "par" => 4 },
        { "player" => { "id" => 100 }, "round_number" => 1, "score" => 4, "par" => 4 }
      ]
      formatter.merge_scorecard_live!(scorecards)
      expect(formatter.by_player_id[100][:rounds][1][:par_relative]).to eq("-2")
    end

    it "sets total_to_par from sum of rounds when only scorecard data exists (no API total)" do
      formatter = described_class.new([])
      scorecards = [
        { "player" => { "id" => 100 }, "round_number" => 1, "score" => 3, "par" => 4 },
        { "player" => { "id" => 100 }, "round_number" => 1, "score" => 3, "par" => 4 },
        { "player" => { "id" => 100 }, "round_number" => 1, "score" => 4, "par" => 4 }
      ]
      formatter.merge_scorecard_live!(scorecards)
      expect(formatter.by_player_id[100][:total_to_par]).to eq(-2)
    end

    it "does not overwrite completed round data from player_round_results" do
      formatter = described_class.new(raw_results)
      scorecards = [
        { "player" => { "id" => 185 }, "round_number" => 1, "score" => 4, "par" => 4 }
      ]
      formatter.merge_scorecard_live!(scorecards)
      expect(formatter.by_player_id[185][:rounds][1][:par_relative]).to eq("-3")
    end
  end
end

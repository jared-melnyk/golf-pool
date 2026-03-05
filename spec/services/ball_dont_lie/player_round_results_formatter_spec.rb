require "rails_helper"

RSpec.describe BallDontLie::PlayerRoundResultsFormatter do
  let(:raw_results) do
    [
      {
        "player" => { "id" => 185, "display_name" => "Scottie Scheffler" },
        "round_number" => 1,
        "score_to_par" => -3,
        "total_to_par" => -3,
        "position" => "1"
      },
      {
        "player" => { "id" => 185, "display_name" => "Scottie Scheffler" },
        "round_number" => 2,
        "score_to_par" => 0,
        "total_to_par" => -3,
        "position" => "T2"
      },
      {
        "player" => { "id" => 282, "display_name" => "Rory McIlroy" },
        "round_number" => 1,
        "score_to_par" => 1,
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
end

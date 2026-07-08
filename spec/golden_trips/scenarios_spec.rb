# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Golden trip scenarios" do
  FIXTURE_DIR = Rails.root.join("spec/fixtures/golden_trips")

  Dir[FIXTURE_DIR.join("*.yml")].sort.each do |path|
    fixture = YAML.safe_load_file(path)
    id = fixture.fetch("id")

    describe id do
      it fixture.fetch("description") do
        game, = build_golden_game!(fixture)
        scorecard = scorecard_for(fixture, game)
        assert_golden_expectations!(fixture, scorecard)
      end
    end
  end

  describe "fs_over_pick_limit" do
    it "rejects the 41st pick for a foursome" do
      fixture = load_golden_fixture(FIXTURE_DIR.join("fs_foursome_complete.yml"))
      _game, player_gtps = build_golden_game!(fixture)
      gtp = player_gtps.fetch([ "Foursome A", "Doug" ])
      score = HoleScore.find_by!(game_team_player: gtp, hole_number: 1)

      score.included_in_forty_score = true

      expect(score).not_to be_valid
      expect(score.errors[:included_in_forty_score]).to include(/40-count limit/)
    end
  end
end

require "rails_helper"

RSpec.describe Game, type: :model do
  let(:creator) { User.create!(name: "Creator", email: "creator@test.com", password: "pw") }
  let(:event) { Event.create!(name: "Test Event", status: "active") }
  let(:round) do
    Round.create!(
      event: event,
      name: "Morning round",
      played_on: Date.today,
      golf_course_api_course_id: 1,
      course_name: "Test Course",
      tee_name: "Blue",
      tee_gender: "male",
      course_rating: 72.1,
      slope_rating: 130,
      par_total: 72,
      hole_pars: Array.new(18, 4),
      hole_handicaps: (1..18).to_a
    )
  end

  def build_game(**attrs)
    defaults = {
      event: event,
      round: round,
      game_type: "best_ball",
      name: "Best Ball · Test Course · #{Date.today.strftime('%-b %-d')}",
      creator: creator,
      status: "active"
    }
    Game.new(defaults.merge(attrs))
  end

  it "is valid with event, round, and game_type" do
    expect(build_game).to be_valid
  end

  it "allows nil game_type in draft" do
    game = build_game(game_type: nil, round: nil, status: "draft")
    expect(game).to be_valid
  end

  it "is invalid with unknown game_type" do
    game = build_game(game_type: "scramble")
    expect(game).not_to be_valid
  end

  it "is valid with forty_score game type" do
    game = build_game(game_type: "forty_score")
    expect(game).to be_valid
  end

  it "is valid with cha_cha_cha game type" do
    game = build_game(game_type: "cha_cha_cha")
    expect(game).to be_valid
  end

  it "uses 100% playing handicap allowance for forty_score" do
    game = build_game(game_type: "forty_score")
    expect(game.playing_handicap_allowance_percent).to eq(100)
  end

  it "uses 85% playing handicap allowance for cha_cha_cha" do
    game = build_game(game_type: "cha_cha_cha")
    expect(game.playing_handicap_allowance_percent).to eq(85)
  end

  describe "status" do
    it "defaults to draft" do
      game = Game.new(name: "G", creator: creator)
      expect(game.status).to eq("draft")
    end

    it "requires round and game_type to be active" do
      game = Game.create!(name: "G", creator: creator, status: "draft")
      game.status = "active"
      expect(game).not_to be_valid
      expect(game.errors[:base]).to include("Round is required to activate game")
    end
  end

  describe "#completed?" do
    it "is true when status is completed" do
      game = build_game(status: "completed")
      expect(game.completed?).to be true
    end
  end

  describe "#suggested_name" do
    it "builds name from round and game_type" do
      game = build_game(game_type: "forty_score")
      expect(game.suggested_name).to include("Forty Score")
      expect(game.suggested_name).to include(round.course_name)
    end
  end
end

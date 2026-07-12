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

  describe ".next_group_letter" do
    it "returns A when the round has no games" do
      expect(Game.next_group_letter(round)).to eq("A")
    end

    it "returns the next letter among all games on the round" do
      Game.create!(
        name: "Best Ball · A", creator: creator, status: "active",
        event: event, round: round, game_type: "best_ball"
      )
      Game.create!(
        name: "Vegas · B", creator: creator, status: "active",
        event: event, round: round, game_type: "vegas"
      )

      expect(Game.next_group_letter(round)).to eq("C")
    end
  end

  describe ".default_ad_hoc_name" do
    it "combines format, course, and date" do
      expect(Game.default_ad_hoc_name(round, "vegas")).to eq(
        "Vegas · Test Course · #{round.played_on.strftime('%-b %-d')}"
      )
    end
  end

  describe "competition scope" do
    it "treats cha_cha_cha as field" do
      game = build_game(game_type: "cha_cha_cha")
      game.save!
      GameTeam.create!(game: game, name: "Group A")
      expect(game.field_scope?).to be true
      expect(game.match_scope?).to be false
    end

    it "treats forty_score as field" do
      game = build_game(game_type: "forty_score")
      game.save!
      GameTeam.create!(game: game, name: "Group A")
      expect(game.field_scope?).to be true
    end

    it "treats vegas as match" do
      game = build_game(game_type: "vegas")
      game.save!
      2.times { |i| GameTeam.create!(game: game, name: "Team #{i}") }
      expect(game.match_scope?).to be true
      expect(game.field_scope?).to be false
    end

    it "treats best_ball with one team as field" do
      game = build_game(game_type: "best_ball")
      game.save!
      GameTeam.create!(game: game, name: "Group A")
      expect(game.field_scope?).to be true
    end

    it "treats best_ball with two teams as match" do
      game = build_game(game_type: "best_ball")
      game.save!
      GameTeam.create!(game: game, name: "Team A")
      GameTeam.create!(game: game, name: "Team B")
      expect(game.match_scope?).to be true
      expect(game.field_scope?).to be false
    end
  end

  describe "#default_team_slot_count" do
    it "is 1 for best_ball, cha_cha_cha, and forty_score" do
      expect(build_game(game_type: "best_ball").default_team_slot_count).to eq(1)
      expect(build_game(game_type: "cha_cha_cha").default_team_slot_count).to eq(1)
      expect(build_game(game_type: "forty_score").default_team_slot_count).to eq(1)
    end

    it "is 2 for vegas" do
      expect(build_game(game_type: "vegas").default_team_slot_count).to eq(2)
    end
  end

  describe "#team_slot_count" do
    it "honors slots request for best_ball up to 10" do
      game = build_game(game_type: "best_ball")
      game.save!
      expect(game.team_slot_count).to eq(1)
      expect(game.team_slot_count(requested_slots: 2)).to eq(2)
      expect(game.team_slot_count(requested_slots: 99)).to eq(10)
    end

    it "stays at 1 for cha_cha_cha even if slots requested" do
      game = build_game(game_type: "cha_cha_cha")
      game.save!
      expect(game.team_slot_count(requested_slots: 3)).to eq(1)
    end
  end

  describe "#default_team_name" do
    it "uses Group letter for field formats" do
      game = build_game(game_type: "forty_score", name: "Forty Score · C")
      game.save!
      expect(game.default_team_name(0)).to eq("Group C")
    end

    it "uses Team A/B for match best_ball" do
      game = build_game(game_type: "best_ball", name: "Best Ball · A")
      game.save!
      expect(game.default_team_name(0, slot_count: 2)).to eq("Team A")
      expect(game.default_team_name(1, slot_count: 2)).to eq("Team B")
    end
  end
end

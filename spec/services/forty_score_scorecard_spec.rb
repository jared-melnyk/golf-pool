# frozen_string_literal: true

require "rails_helper"

RSpec.describe FortyScoreScorecard do
  let(:event) { Event.create!(name: "E", status: "active") }
  let(:round) do
    Round.create!(
      event: event, name: "R", played_on: Date.today,
      golf_course_api_course_id: 1, course_name: "C", tee_name: "W",
      tee_gender: "male", course_rating: 72.0, slope_rating: 113, par_total: 72,
      hole_pars: Array.new(18, 4),
      hole_handicaps: (1..18).to_a
    )
  end
  let(:game) { Game.create!(event: event, round: round, game_type: "forty_score") }

  let(:alice) { User.create!(name: "Alice", email: "alice@test.com", password: "pw", ghin_handicap_index: 0.0) }
  let(:bob)   { User.create!(name: "Bob",   email: "bob@test.com",   password: "pw", ghin_handicap_index: 0.0) }
  let(:carol) { User.create!(name: "Carol", email: "carol@test.com", password: "pw", ghin_handicap_index: 0.0) }
  let(:doug)  { User.create!(name: "Doug",  email: "doug@test.com",  password: "pw", ghin_handicap_index: 0.0) }

  let(:team) { GameTeam.create!(game: game, name: "Foursome A") }
  let(:gtp_alice) { GameTeamPlayer.create!(game_team: team, user: alice) }
  let(:gtp_bob)   { GameTeamPlayer.create!(game_team: team, user: bob) }
  let(:gtp_carol) { GameTeamPlayer.create!(game_team: team, user: carol) }
  let(:gtp_doug)  { GameTeamPlayer.create!(game_team: team, user: doug) }

  before do
    [ gtp_alice, gtp_bob, gtp_carol, gtp_doug ].each do |gtp|
      (1..18).each do |h|
        HoleScore.create!(game_team_player: gtp, hole_number: h, gross_score: 4)
      end
    end

    (1..18).each { |h| HoleScore.where(game_team_player: gtp_alice, hole_number: h).update_all(included_in_forty_score: true) }
    (1..18).each { |h| HoleScore.where(game_team_player: gtp_bob, hole_number: h).update_all(included_in_forty_score: true) }
    (1..4).each do |h|
      HoleScore.where(game_team_player: gtp_carol, hole_number: h).update_all(included_in_forty_score: true)
    end
    (5..18).each do |h|
      HoleScore.where(game_team_player: gtp_carol, hole_number: h).update_all(included_in_forty_score: false)
    end
    HoleScore.where(game_team_player: gtp_doug).update_all(included_in_forty_score: false)
  end

  subject(:scorecard) { FortyScoreScorecard.new(game).call }

  it "sums par and net for exactly 40 picked scores" do
    t = scorecard[:teams].first
    expect(t[:selected_count]).to eq(40)
    expect(t[:total_selected_net]).to eq(160)
    expect(t[:total_selected_par]).to eq(160)
    expect(t[:net_under_par]).to eq(0)
  end

  it "shows nil vs par until 40 selections are locked in" do
    HoleScore.where(game_team_player: gtp_carol, hole_number: 4).update_all(included_in_forty_score: false)
    game.reload
    card = FortyScoreScorecard.new(game).call
    t = card[:teams].first
    expect(t[:selected_count]).to eq(39)
    expect(t[:net_under_par]).to be_nil
  end

  it "uses full (100%) playing handicap for alice with index 18 vs best ball allowance" do
    alice.update!(ghin_handicap_index: 18.0)
    gtp_alice.update!(snapshot_handicap_index: 18)
    card = FortyScoreScorecard.new(game.reload).call
    alice_row = card[:teams].first[:players].find { |p| p[:name] == "Alice" }
    expect(alice_row[:playing_handicap]).to eq(18)

    bob_row = card[:teams].first[:players].find { |p| p[:name] == "Bob" }
    expect(bob_row[:playing_handicap]).to eq(0)
  end

  it "ranks birdie-heavy second team ahead of even-par forty picks" do
    team_b = GameTeam.create!(game: game, name: "Group B")
    [ "q1", "q2", "q3", "q4" ].each.with_index do |prefix, idx|
      u = User.create!(name: prefix.upcase, email: "#{prefix}@t.com", password: "pw", ghin_handicap_index: 0.0)
      gtp = GameTeamPlayer.create!(game_team: team_b, user: u)
      (1..18).each do |h|
        HoleScore.create!(game_team_player: gtp, hole_number: h, gross_score: 4, included_in_forty_score: false)
      end
    end
    gb_gtps = team_b.reload.game_team_players.order(:id)
    slots = gb_gtps.flat_map { |g| (1..18).map { |h| [ g.id, h ] } }.first(40)
    slots.each do |gid, h|
      HoleScore.find_by!(game_team_player_id: gid, hole_number: h).update!(gross_score: 3, included_in_forty_score: true)
    end

    lbs = FortyScoreScorecard.new(Game.includes(game_teams: { game_team_players: :hole_scores }).find(game.id)).call[:leaderboard]

    gb = lbs.find { |row| row[:team_name] == "Group B" }
    ga = lbs.find { |row| row[:team_name] == "Foursome A" }
    expect(gb[:rank]).to eq(1)
    expect(ga[:rank]).to eq(2)
    expect(gb[:net_under_par]).to eq(40)
    expect(ga[:net_under_par]).to eq(0)
  end
end

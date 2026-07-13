# frozen_string_literal: true

require "rails_helper"

RSpec.describe EventIndividualStandings do
  let(:event) { Event.create!(name: "Trip", status: "active") }
  let(:round) do
    Round.create!(
      event: event, name: "Wolf River", played_on: Date.today,
      golf_course_api_course_id: 1, course_name: "Wolf River", tee_name: "W",
      tee_gender: "male", course_rating: 72.0, slope_rating: 113, par_total: 72,
      hole_pars: Array.new(18, 4),
      hole_handicaps: (1..18).to_a
    )
  end

  def add_member!(name:, hi:)
    user = User.create!(name: name, email: "#{name.parameterize}@test.com", password: "pw", ghin_handicap_index: hi)
    event.event_memberships.create!(user: user, role: "player")
    user
  end

  def add_scores!(user:, game:, gross_by_hole:)
    team = GameTeam.create!(game: game, name: "#{user.name}'s group")
    gtp = GameTeamPlayer.create!(game_team: team, user: user)
    gross_by_hole.each do |hole, gross|
      HoleScore.create!(game_team_player: gtp, hole_number: hole, gross_score: gross)
    end
    gtp
  end

  describe "#call" do
    it "ranks on 100% course handicap net, not format playing handicap" do
      # Best Ball uses 85% PH. Alice HI 18 → CH 18, PH 15.
      # All 5s on par 4s: CH net-to-par E; PH net-to-par +3.
      # Bob HI 0 shoots 74 (+2) — beats Alice on PH, loses on CH.
      alice = add_member!(name: "Alice", hi: 18.0)
      bob = add_member!(name: "Bob", hi: 0.0)
      game = create_test_game!(event: event, round: round, game_type: "best_ball")

      add_scores!(user: alice, game: game, gross_by_hole: (1..18).index_with { 5 })
      add_scores!(user: bob, game: game, gross_by_hole: (1..18).index_with { |h| h <= 16 ? 4 : 5 })

      result = described_class.new(event).call
      ranked = result[:players].select { |p| p[:rank] }

      expect(ranked.map { |p| p[:name] }).to eq(%w[Alice Bob])
      expect(ranked.map { |p| p[:total_vs_par] }).to eq([ 0, 2 ])
      expect(ranked.map { |p| p[:rank] }).to eq([ 1, 2 ])
    end

    it "sums net-to-par across rounds and ignores sit-out rounds" do
      alice = add_member!(name: "Alice", hi: 0.0)
      bob = add_member!(name: "Bob", hi: 0.0)
      round2 = Round.create!(
        event: event, name: "Champion Hill", played_on: Date.tomorrow,
        golf_course_api_course_id: 2, course_name: "Champion Hill", tee_name: "W",
        tee_gender: "male", course_rating: 72.0, slope_rating: 113, par_total: 72,
        hole_pars: Array.new(18, 4),
        hole_handicaps: (1..18).to_a
      )

      g1 = create_test_game!(event: event, round: round, game_type: "best_ball")
      g2 = create_test_game!(event: event, round: round2, game_type: "cha_cha_cha")

      add_scores!(user: alice, game: g1, gross_by_hole: (1..18).index_with { 5 }) # +18
      add_scores!(user: bob, game: g1, gross_by_hole: (1..18).index_with { 4 })   # E
      # Alice sits round 2; Bob shoots +1
      add_scores!(user: bob, game: g2, gross_by_hole: { 1 => 5 }.merge((2..18).index_with { 4 }))

      result = described_class.new(event).call
      by_name = result[:players].index_by { |p| p[:name] }

      expect(by_name["Bob"][:total_vs_par]).to eq(1)
      expect(by_name["Alice"][:total_vs_par]).to eq(18)
      expect(by_name["Bob"][:round_vs_par][round2.id]).to eq(1)
      expect(by_name["Alice"][:round_vs_par][round2.id]).to be_nil
      expect(by_name["Bob"][:rank]).to eq(1)
      expect(by_name["Alice"][:rank]).to eq(2)
    end

    it "includes live partial rounds (holes entered so far)" do
      alice = add_member!(name: "Alice", hi: 0.0)
      game = create_test_game!(event: event, round: round, game_type: "forty_score")
      add_scores!(user: alice, game: game, gross_by_hole: { 1 => 5, 2 => 5 })

      result = described_class.new(event).call
      row = result[:players].find { |p| p[:name] == "Alice" }

      expect(row[:total_vs_par]).to eq(2)
      expect(row[:thru_holes]).to eq(2)
      expect(row[:round_thru][round.id]).to eq(2)
      expect(row[:rank]).to eq(1)
    end

    it "lists members with no scores unranked at the bottom" do
      add_member!(name: "Sitting", hi: 10.0)
      alice = add_member!(name: "Alice", hi: 0.0)
      game = create_test_game!(event: event, round: round, game_type: "best_ball")
      add_scores!(user: alice, game: game, gross_by_hole: { 1 => 4 })

      result = described_class.new(event).call

      expect(result[:players].map { |p| p[:name] }).to eq(%w[Alice Sitting])
      expect(result[:players].last[:rank]).to be_nil
      expect(result[:players].last[:total_vs_par]).to be_nil
    end

    it "exposes round columns in play order" do
      add_member!(name: "Alice", hi: 0.0)
      round # ensure earlier round exists
      Round.create!(
        event: event, name: "Later", played_on: Date.tomorrow,
        golf_course_api_course_id: 2, course_name: "Later", tee_name: "W",
        tee_gender: "male", course_rating: 72.0, slope_rating: 113, par_total: 72,
        hole_pars: Array.new(18, 4),
        hole_handicaps: (1..18).to_a
      )

      result = described_class.new(event).call

      expect(result[:rounds].map { |r| r[:name] }).to eq([ "Wolf River", "Later" ])
    end
    it "ignores Vegas hole scores so early-round sit-outs stay fair" do
      alice = add_member!(name: "Alice", hi: 0.0)
      bob = add_member!(name: "Bob", hi: 0.0)
      vegas = create_test_game!(event: event, round: round, game_type: "vegas")
      field = create_test_game!(
        event: event,
        round: Round.create!(
          event: event, name: "Wolf River PM", played_on: Date.today,
          golf_course_api_course_id: 1, course_name: "Wolf River", tee_name: "W",
          tee_gender: "male", course_rating: 72.0, slope_rating: 113, par_total: 72,
          hole_pars: Array.new(18, 4),
          hole_handicaps: (1..18).to_a
        ),
        game_type: "best_ball"
      )

      add_scores!(user: alice, game: vegas, gross_by_hole: (1..18).index_with { 3 }) # would be -18 if counted
      add_scores!(user: alice, game: field, gross_by_hole: (1..18).index_with { 5 }) # +18
      add_scores!(user: bob, game: field, gross_by_hole: (1..18).index_with { 4 })   # E

      result = described_class.new(event).call
      by_name = result[:players].index_by { |p| p[:name] }

      expect(by_name["Alice"][:total_vs_par]).to eq(18)
      expect(by_name["Bob"][:total_vs_par]).to eq(0)
      expect(by_name["Bob"][:rank]).to eq(1)
    end
  end
end

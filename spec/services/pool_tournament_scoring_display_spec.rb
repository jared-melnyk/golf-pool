# frozen_string_literal: true

require "rails_helper"

RSpec.describe PoolTournamentScoringDisplay do
  let(:creator) { User.create!(email: "c@example.com", name: "C", password: "password") }
  let(:pool) { Pool.create!(name: "P", creator: creator) }
  let(:tournament) { Tournament.create!(name: "Live", starts_at: 1.day.ago, external_id: "28", total_prize_pool: 10_000_000) }
  let(:pool_tournament) { PoolTournament.create!(pool: pool, tournament: tournament) }
  let(:golfer) { Golfer.create!(name: "G", external_id: "100") }
  let(:odds_row) do
    PoolTournamentOdds.create!(
      pool_tournament: pool_tournament,
      golfer: golfer,
      american_odds: 500,
      vendor: "dk",
      locked_at: Time.current
    )
  end
  let(:results_by_golfer) { {} }
  let(:odds_by_golfer) { { golfer.id => odds_row } }

  def build_display(round_results: {}, current_round: 2, payout_curve: nil)
    described_class.new(
      tournament: tournament,
      results_by_golfer: results_by_golfer,
      odds_by_golfer: odds_by_golfer,
      round_results: round_results,
      current_round: current_round,
      payout_curve: payout_curve
    )
  end

  def static_curve
    PayoutCurve.from_stored(PgaPayoutProfiles.curve_payload_for("standard_cut"))
  end

  describe "#bonus_for" do
    it "returns :mc when cut posted and result is CUT" do
      TournamentResult.create!(tournament: tournament, golfer: golfer, position_display: "CUT")
      results = { golfer.id => tournament.tournament_results.find_by(golfer: golfer) }
      display = described_class.new(
        tournament: tournament,
        results_by_golfer: results,
        odds_by_golfer: odds_by_golfer,
        round_results: {},
        current_round: 2
      )
      expect(display.bonus_for(golfer)).to eq(:mc)
    end

    it "returns capped bonus when cut posted and made cut" do
      other = Golfer.create!(name: "Other", external_id: "999")
      TournamentResult.create!(tournament: tournament, golfer: other, position_display: "CUT")
      results = { golfer.id => TournamentResult.create!(tournament: tournament, golfer: golfer, position_display: "T18") }
      display = described_class.new(
        tournament: tournament,
        results_by_golfer: results,
        odds_by_golfer: odds_by_golfer,
        round_results: {},
        current_round: 2
      )
      expect(display.bonus_for(golfer)).to eq(10_000.to_d)
    end
  end

  describe "#projection_enabled?" do
    it "is true with empirical or static curve source" do
      tournament.update!(payout_curve_source: "static", payout_curve: PgaPayoutProfiles.curve_payload_for("standard_cut"))
      display = build_display(payout_curve: static_curve)
      expect(display.projection_enabled?).to be true
    end

    it "is false when payout_curve_source is hidden" do
      tournament.update!(payout_curve_source: "hidden", payout_curve: nil)
      expect(build_display.projection_enabled?).to be false
    end
  end

  describe "#show_counted_dropped_badges?" do
    it "returns false before cut" do
      expect(build_display.show_counted_dropped_badges?).to be false
    end

    it "returns false when cut posted but projection is hidden" do
      tournament.update!(payout_curve_source: "hidden", payout_curve: nil)
      TournamentResult.create!(tournament: tournament, golfer: golfer, position_display: "CUT")
      expect(build_display.show_counted_dropped_badges?).to be false
    end

    it "returns true when cut posted and projection is enabled" do
      tournament.update!(payout_curve_source: "static", payout_curve: PgaPayoutProfiles.curve_payload_for("standard_cut"))
      cut_marker = Golfer.create!(name: "Marker", external_id: "cut-marker")
      TournamentResult.create!(tournament: tournament, golfer: cut_marker, position_display: "CUT")
      TournamentResult.create!(tournament: tournament, golfer: golfer, position_display: "T18")
      display = build_display(payout_curve: static_curve, current_round: 3)
      expect(display.show_counted_dropped_badges?).to be true
    end

    it "returns true when the tournament is completed" do
      pool_tournament
      champion = Golfer.create!(name: "Champ", external_id: "900")
      tournament.update!(champion_golfer: champion)
      expect(build_display.show_counted_dropped_badges?).to be true
    end
  end

  describe "#sort_golfers_for_display" do
    it "orders live golfers by score-to-par with missed cuts last" do
      mc = Golfer.create!(name: "MC", external_id: "401")
      leader = Golfer.create!(name: "Leader", external_id: "402")
      mid = Golfer.create!(name: "Mid", external_id: "403")
      marker = Golfer.create!(name: "Marker", external_id: "404")
      TournamentResult.create!(tournament: tournament, golfer: marker, position_display: "CUT")
      TournamentResult.create!(tournament: tournament, golfer: mc, position_display: "CUT")

      round_results = {
        leader.external_id.to_i => { rounds: {}, total_to_par: -8 },
        mid.external_id.to_i => { rounds: {}, total_to_par: -2 },
        mc.external_id.to_i => { rounds: {}, total_to_par: 5 }
      }
      display = build_display(round_results: round_results, current_round: 3)

      ordered = display.sort_golfers_for_display([ mc, leader, mid ])
      expect(ordered.map(&:name)).to eq([ "Leader", "Mid", "MC" ])
    end

    it "orders completed golfers by total earnings descending with MC last" do
      pool_tournament
      champion = Golfer.create!(name: "Champ", external_id: "900")
      tournament.update!(champion_golfer: champion)
      mc = Golfer.create!(name: "MC", external_id: "411")
      top = Golfer.create!(name: "Top", external_id: "412")
      mid = Golfer.create!(name: "Mid", external_id: "413")

      TournamentResult.create!(tournament: tournament, golfer: mc, position_display: "CUT", prize_money: 0)
      TournamentResult.create!(tournament: tournament, golfer: top, position_display: "T2", prize_money: 100_000)
      TournamentResult.create!(tournament: tournament, golfer: mid, position_display: "T18", prize_money: 50_000)

      [ mc, top, mid ].each do |g|
        PoolTournamentOdds.create!(
          pool_tournament: pool_tournament,
          golfer: g,
          american_odds: 500,
          vendor: "dk",
          locked_at: Time.current
        )
      end

      results = tournament.tournament_results.index_by(&:golfer_id)
      odds = PoolTournamentOdds.where(pool_tournament: pool_tournament).index_by(&:golfer_id)
      display = described_class.new(
        tournament: tournament,
        results_by_golfer: results,
        odds_by_golfer: odds,
        round_results: {},
        current_round: 4
      )

      ordered = display.sort_golfers_for_display([ mc, top, mid ])
      expect(ordered.map(&:name)).to eq([ "Top", "Mid", "MC" ])
    end
  end

  describe "#ranking_total_for_counted_dropped" do
    it "uses prize money plus bonus when the tournament is completed" do
      pool_tournament
      high_prize = Golfer.create!(name: "High Prize", external_id: "501")
      high_bonus = Golfer.create!(name: "High Bonus", external_id: "502")
      # Enough of the field missed the money line so this is not classified as a no-cut event.
      8.times do |i|
        g = Golfer.create!(name: "Field#{i}", external_id: (600 + i).to_s)
        TournamentField.create!(tournament: tournament, golfer: g)
        TournamentResult.create!(tournament: tournament, golfer: g, position: 70 + i, position_display: "CUT", prize_money: 0)
      end
      TournamentResult.create!(tournament: tournament, golfer: high_prize, position: 5, position_display: "T5", prize_money: 800_000)
      TournamentResult.create!(tournament: tournament, golfer: high_bonus, position: 12, position_display: "T12", prize_money: 300_000)
      tournament.update!(champion_golfer: high_prize)

      PoolTournamentOdds.create!(
        pool_tournament: pool_tournament, golfer: high_prize, american_odds: 1_000,
        vendor: "dk", locked_at: Time.current
      )
      PoolTournamentOdds.create!(
        pool_tournament: pool_tournament, golfer: high_bonus, american_odds: 5_000,
        vendor: "dk", locked_at: Time.current
      )

      results = tournament.tournament_results.index_by(&:golfer_id)
      odds = PoolTournamentOdds.where(pool_tournament: pool_tournament).index_by(&:golfer_id)
      display = described_class.new(
        tournament: tournament,
        results_by_golfer: results,
        odds_by_golfer: odds,
        round_results: {},
        current_round: 4
      )

      expect(display.ranking_total_for_counted_dropped(high_prize)).to eq(820_000.to_d)
      expect(display.ranking_total_for_counted_dropped(high_bonus)).to eq(400_000.to_d)
    end
  end

  describe "live projection (Schwab-style)" do
    it "ranks counted/dropped by projected prize plus bonus, not bonus alone" do
      pool_tournament
      tournament.update!(
        payout_curve_source: "static",
        payout_curve: PgaPayoutProfiles.curve_payload_for("standard_cut"),
        total_prize_pool: 10_000_000
      )
      high_prize = Golfer.create!(name: "High Prize", external_id: "501")
      high_bonus = Golfer.create!(name: "High Bonus", external_id: "502")
      g3 = Golfer.create!(name: "G3", external_id: "503")
      g4 = Golfer.create!(name: "G4", external_id: "504")

      cut_marker = Golfer.create!(name: "Marker", external_id: "505")
      TournamentResult.create!(tournament: tournament, golfer: cut_marker, position_display: "CUT")
      TournamentResult.create!(tournament: tournament, golfer: high_prize, position: 5, position_display: "T5")
      TournamentResult.create!(tournament: tournament, golfer: high_bonus, position: 12, position_display: "T12")
      TournamentResult.create!(tournament: tournament, golfer: g3, position: 30, position_display: "T30")
      TournamentResult.create!(tournament: tournament, golfer: g4, position: 50, position_display: "T50")

      [ [ high_prize, 1_000 ], [ high_bonus, 5_000 ], [ g3, 500 ], [ g4, 500 ] ].each do |golfer, odds|
        PoolTournamentOdds.create!(
          pool_tournament: pool_tournament, golfer: golfer, american_odds: odds,
          vendor: "dk", locked_at: Time.current
        )
      end

      results = tournament.tournament_results.index_by(&:golfer_id)
      odds = PoolTournamentOdds.where(pool_tournament: pool_tournament).index_by(&:golfer_id)
      display = described_class.new(
        tournament: tournament,
        results_by_golfer: results,
        odds_by_golfer: odds,
        round_results: {},
        current_round: 3,
        payout_curve: static_curve
      )

      expect(display.ranking_total_for_counted_dropped(high_prize)).to be > display.ranking_total_for_counted_dropped(high_bonus)
      top_three = [ high_prize, high_bonus, g3, g4 ].sort_by { |g| -(display.ranking_total_for_counted_dropped(g) || 0) }.first(3)
      expect(top_three).to include(high_prize)
      expect(top_three).not_to include(g4)
    end
  end

  describe "#total_earnings_for" do
    it "returns nil before cut when projection is enabled" do
      tournament.update!(payout_curve_source: "static", payout_curve: PgaPayoutProfiles.curve_payload_for("standard_cut"))
      results = { golfer.id => TournamentResult.create!(tournament: tournament, golfer: golfer, position_display: "T18") }
      display = described_class.new(
        tournament: tournament,
        results_by_golfer: results,
        odds_by_golfer: odds_by_golfer,
        round_results: {},
        current_round: 2,
        payout_curve: static_curve
      )
      expect(display.total_earnings_for(golfer)).to be_nil
    end

    it "returns projected total after cut when projection is enabled" do
      tournament.update!(
        payout_curve_source: "static",
        payout_curve: PgaPayoutProfiles.curve_payload_for("standard_cut"),
        total_prize_pool: 10_000_000
      )
      cut_marker = Golfer.create!(name: "Marker", external_id: "506")
      TournamentResult.create!(tournament: tournament, golfer: cut_marker, position_display: "CUT")
      results = { golfer.id => TournamentResult.create!(tournament: tournament, golfer: golfer, position: 5, position_display: "T5") }
      display = described_class.new(
        tournament: tournament,
        results_by_golfer: results,
        odds_by_golfer: odds_by_golfer,
        round_results: {},
        current_round: 3,
        payout_curve: static_curve
      )
      expect(display.total_earnings_for(golfer)).to be > 400_000.to_d
    end

    it "returns 0 for MC when the tournament is completed" do
      pool_tournament
      champion = Golfer.create!(name: "Champ", external_id: "901")
      tournament.update!(champion_golfer: champion)
      results = { golfer.id => TournamentResult.create!(tournament: tournament, golfer: golfer, position_display: "CUT", prize_money: 0) }
      display = described_class.new(
        tournament: tournament,
        results_by_golfer: results,
        odds_by_golfer: odds_by_golfer,
        round_results: {},
        current_round: 4
      )
      expect(display.total_earnings_for(golfer)).to eq(0.to_d)
    end
  end
end

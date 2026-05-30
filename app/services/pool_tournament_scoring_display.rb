# frozen_string_literal: true

class PoolTournamentScoringDisplay
  def initialize(tournament:, results_by_golfer:, odds_by_golfer:, round_results:, current_round:)
    @tournament = tournament
    @results_by_golfer = results_by_golfer
    @odds_by_golfer = odds_by_golfer
    @round_results = round_results
    @current_round = current_round
  end

  def cut_posted?
    @tournament.cut_posted?
  end

  def show_counted_dropped_badges?
    @tournament.completed? || cut_posted?
  end

  def badges_projected?
    cut_posted? && !@tournament.completed?
  end

  def bonus_for(golfer)
    result = @results_by_golfer[golfer.id]
    odds_row = @odds_by_golfer[golfer.id]

    if @tournament.completed?
      return :mc unless result && @tournament.bonus_cut_eligible_result?(result) && odds_row
      return @tournament.capped_cut_made_bonus(odds_row.american_odds)
    end

    if result && cut_posted?
      return :mc if result.missed_cut?
      return @tournament.capped_cut_made_bonus(odds_row.american_odds) if odds_row
      return nil
    end

    infer_bonus_from_rounds(golfer, odds_row)
  end

  def prize_money_for(golfer)
    return nil unless @tournament.completed?

    result = @results_by_golfer[golfer.id]
    result ? (result.prize_money.to_d || 0) : nil
  end

  def projected_total_for(golfer)
    bonus_val = bonus_for(golfer)
    return nil if bonus_val.nil?
    return 0.to_d if bonus_val == :mc

    bonus_val.to_d
  end

  def total_earnings_for(golfer)
    prize = prize_money_for(golfer)
    bonus_val = bonus_for(golfer)

    if @tournament.completed?
      return nil if prize.nil? && !bonus_val.is_a?(Numeric) && bonus_val != :mc
      return 0.to_d if bonus_val == :mc && (prize.nil? || prize.zero?)
      return prize.to_d + (bonus_val.is_a?(Numeric) ? bonus_val.to_d : 0.to_d)
    end

    return nil if bonus_val.nil?
    return 0.to_d if bonus_val == :mc
    return bonus_val.to_d if bonus_val.is_a?(Numeric)

    nil
  end

  private

  def infer_bonus_from_rounds(golfer, odds_row)
    player_result = @round_results[golfer.external_id&.to_i] || {}
    round_numbers = (player_result[:rounds] || {}).keys
    made_cut = round_numbers.any? { |r| r >= 3 }
    cut_known = @current_round.present? && @current_round >= 3
    missed_cut = cut_known && round_numbers.any? && !made_cut

    return @tournament.capped_cut_made_bonus(odds_row.american_odds) if made_cut && odds_row
    return :mc if missed_cut

    nil
  end
end

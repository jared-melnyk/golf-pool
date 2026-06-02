# frozen_string_literal: true

class PoolTournamentScoringDisplay
  def initialize(tournament:, results_by_golfer:, odds_by_golfer:, round_results:, current_round:, payout_curve: nil)
    @tournament = tournament
    @results_by_golfer = results_by_golfer
    @odds_by_golfer = odds_by_golfer
    @round_results = round_results
    @current_round = current_round
    @payout_curve = payout_curve
    @projected_prize = ProjectedPrizeMoney.new(tournament: tournament, curve: payout_curve) if payout_curve
  end

  def cut_posted?
    @tournament.cut_posted?
  end

  def projection_enabled?
    @payout_curve.present? && @tournament.payout_curve_source.in?(%w[empirical static])
  end

  def badges_projected?
    projection_enabled? && cut_posted? && !@tournament.completed?
  end

  def show_counted_dropped_badges?
    return true if @tournament.completed?
    return false unless cut_posted?

    projection_enabled?
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
    if @tournament.completed?
      result = @results_by_golfer[golfer.id]
      return result ? (result.prize_money.to_d || 0) : nil
    end

    projected_prize_money_for(golfer)
  end

  def projected_prize_money_for(golfer)
    return nil unless projection_enabled? && cut_posted?

    result = @results_by_golfer[golfer.id]
    @projected_prize.for_result(result)
  end

  def projected_total_earnings_for(golfer)
    return nil unless projection_enabled? && cut_posted?

    prize = projected_prize_money_for(golfer)
    return nil if prize.nil?

    bonus_val = bonus_for(golfer)
    return 0.to_d if bonus_val == :mc

    prize + (bonus_val.is_a?(Numeric) ? bonus_val.to_d : 0.to_d)
  end

  # Total used to rank golfers for Counted/Dropped badges (top 3 of 4 count).
  def ranking_total_for_counted_dropped(golfer)
    if badges_projected?
      projected_total_earnings_for(golfer) || 0.to_d
    else
      total_earnings_for(golfer)
    end
  end

  # Completed: by total earnings. Live: by score-to-par (leaderboard order), MC last after cut.
  def sort_golfers_for_display(golfers)
    golfers.sort_by.with_index do |golfer, idx|
      if @tournament.completed?
        sort_key_by_final_earnings(golfer, idx)
      else
        sort_key_by_live_scoring(golfer, idx)
      end
    end
  end

  def total_earnings_for(golfer)
    if @tournament.completed?
      prize = prize_money_for(golfer)
      bonus_val = bonus_for(golfer)

      return nil if prize.nil? && !bonus_val.is_a?(Numeric) && bonus_val != :mc
      return 0.to_d if bonus_val == :mc && (prize.nil? || prize.zero?)
      return prize.to_d + (bonus_val.is_a?(Numeric) ? bonus_val.to_d : 0.to_d)
    end

    projected_total_earnings_for(golfer)
  end

  private

  def sort_key_by_final_earnings(golfer, idx)
    total = total_earnings_for(golfer)
    if total.nil?
      [ 2, 0, idx ]
    elsif total.zero?
      [ 3, 0, idx ]
    else
      [ 1, -total.to_d, idx ]
    end
  end

  def sort_key_by_live_scoring(golfer, idx)
    result = @results_by_golfer[golfer.id]
    if cut_posted? && result&.missed_cut?
      return [ 3, 0, idx ]
    end

    player_result = @round_results[golfer.external_id&.to_i] || {}
    total_to_par = player_result[:total_to_par]
    if total_to_par.nil?
      [ 2, 0, idx ]
    else
      [ 1, total_to_par.to_i, idx ]
    end
  end

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

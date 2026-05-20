module ApplicationHelper
  include Games::SetupHelper
  include Games::ScorecardHelper
  # True when uncapped bonus (20 * |american_odds|) would be >= max_bonus and max_bonus > 0.
  def at_max_cut_made_bonus?(american_odds, max_bonus)
    return false if max_bonus.blank? || !max_bonus.positive?
    return false if american_odds.nil?

    (american_odds.to_d.abs * 20) >= max_bonus.to_d
  end

  # Returns "Name (Cut Made Bonus: $10,000)" (and "*" when capped). If odds are missing, returns name.
  def golfer_name_with_bonus(name, american_odds, tournament:)
    return name.to_s if name.blank?
    return name.to_s if american_odds.nil?

    bonus = tournament.capped_cut_made_bonus(american_odds).to_i
    base = "#{name} (Cut Made Bonus: $#{number_with_delimiter(bonus)})"
    at_cap = at_max_cut_made_bonus?(american_odds, tournament.max_cut_made_bonus)
    at_cap ? "#{base}*" : base
  end

  def cut_made_bonus_label(american_odds, tournament:)
    return "—" if american_odds.nil?

    bonus = tournament.capped_cut_made_bonus(american_odds).to_i
    base = "Cut Made Bonus: $#{number_with_delimiter(bonus)}"
    at_cap = at_max_cut_made_bonus?(american_odds, tournament.max_cut_made_bonus)
    at_cap ? "#{base}*" : base
  end

  # Page-level label for the maximum Cut Made Bonus on a tournament. Appends
  # "(estimated)" when the cap is derived from fallback_prize_pool or the global
  # default, so users understand the displayed cap may change once the official
  # purse is announced.
  def max_cut_made_bonus_label(tournament)
    max = tournament.max_cut_made_bonus
    amount = "$#{number_with_delimiter(max.to_i)}"
    tournament.prize_pool_known? ? amount : "#{amount} (estimated)"
  end

  def at_max_longshot_bonus?(american_odds, max_bonus)
    at_max_cut_made_bonus?(american_odds, max_bonus)
  end

  # Total score-to-par for display (E / +n / negative), matching pool tournament results table.
  def format_total_to_par(ttp)
    return "—" if ttp.nil?

    v = ttp.to_i
    return "E" if v.zero?

    v.positive? ? "+#{v}" : v.to_s
  end
end

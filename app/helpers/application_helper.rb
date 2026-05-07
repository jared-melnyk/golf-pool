module ApplicationHelper
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

  def at_max_longshot_bonus?(american_odds, max_bonus)
    at_max_cut_made_bonus?(american_odds, max_bonus)
  end
end

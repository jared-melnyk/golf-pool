module ApplicationHelper
  # Formats American odds for display, e.g. +425 => "(+425)", -200 => "(-200)".
  # Returns empty string if odds is nil.
  def format_american_odds(american_odds)
    return "" if american_odds.nil?

    sign = american_odds >= 0 ? "+" : ""
    "(#{sign}#{american_odds})"
  end

  # True when uncapped bonus (20 * |american_odds|) would be >= max_bonus and max_bonus > 0.
  def at_max_longshot_bonus?(american_odds, max_bonus)
    return false if max_bonus.blank? || !max_bonus.positive?
    return false if american_odds.nil?

    (american_odds.to_d.abs * 20) >= max_bonus.to_d
  end

  # Returns "Name (+425)" or "Name (+425)*" when at cap; optional max_bonus for asterisk.
  def golfer_name_with_odds(name, american_odds, max_bonus: nil)
    return name.to_s if name.blank?

    suffix = format_american_odds(american_odds)
    base = suffix.present? ? "#{name} #{suffix}" : name.to_s
    at_cap = at_max_longshot_bonus?(american_odds, max_bonus)
    at_cap ? "#{base}*" : base
  end
end

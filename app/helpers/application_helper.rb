module ApplicationHelper
  # Formats American odds for display, e.g. +425 => "(+425)", -200 => "(-200)".
  # Returns empty string if odds is nil.
  def format_american_odds(american_odds)
    return "" if american_odds.nil?

    sign = american_odds >= 0 ? "+" : ""
    "(#{sign}#{american_odds})"
  end

  # Returns "Name (+425)" or "Name (-200)" when odds present, else just "Name".
  def golfer_name_with_odds(name, american_odds)
    return name.to_s if name.blank?

    suffix = format_american_odds(american_odds)
    suffix.present? ? "#{name} #{suffix}" : name.to_s
  end
end

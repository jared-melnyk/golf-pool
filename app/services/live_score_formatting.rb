# frozen_string_literal: true

# Formats live vs-par labels for on-course scorecards and standings.
module LiveScoreFormatting
  module_function

  def format_vs_par(value)
    return "E" if value.nil? || value.zero?

    value.positive? ? "+#{value}" : value.to_s
  end

  def thru_label(vs_par, thru_holes)
    return nil if thru_holes.to_i.zero?

    "#{format_vs_par(vs_par)} (#{thru_holes})"
  end

  def picks_label(vs_par, picks, target)
    return nil if picks.to_i.zero?

    "#{format_vs_par(vs_par)} (#{picks}/#{target})"
  end
end

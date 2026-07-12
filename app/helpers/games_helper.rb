# frozen_string_literal: true

module GamesHelper
  def game_type_label(game_type)
    Game.type_label(game_type)
  end

  def standings_metric_label(metric_key)
    case metric_key&.to_sym
    when :total_net_strokes then "Total net"
    when :competition_vs_par then "Competition vs par"
    else metric_key.to_s.humanize
    end
  end

  def standings_metric_display(row)
    return "—" if row[:metric_value].nil?

    if row[:metric_key].to_sym == :competition_vs_par
      format_competition_vs_par(row[:metric_value])
    else
      row[:metric_value].to_s
    end
  end

  def format_competition_vs_par(value)
    return "E" if value.zero?

    value.positive? ? "+#{value}" : value.to_s
  end
end

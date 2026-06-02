# frozen_string_literal: true

# Position → share of purse, used for live prize projection.
class PayoutCurve
  def self.from_stored(data)
    return nil if data.blank?

    new(
      shares: data.fetch("shares", {}),
      metadata: data["metadata"] || {}
    )
  end

  attr_reader :metadata

  def initialize(shares:, metadata: {})
    @shares = shares.transform_keys(&:to_s).transform_values { |v| v.to_d }
    @metadata = metadata
    @max_position = @shares.keys.map(&:to_i).max
  end

  def amount_for(position_numeric, purse:, position_display: nil)
    share = share_for(position_numeric, position_display: position_display)
    return nil if share.nil?

    (purse.to_d * share).round(2)
  end

  def share_for(position_numeric, position_display: nil)
    position = resolved_position(position_numeric, position_display)
    return nil if position.nil? || position <= 0

    key = position.to_s
    return @shares[key] if @shares.key?(key)
    return @shares[@max_position.to_s] if @max_position && position > @max_position

    nil
  end

  private

  def resolved_position(position_numeric, position_display)
    return nil if missed_cut_display?(position_display)

    numeric = position_numeric.presence&.to_i
    return numeric if numeric&.positive?

    parse_position_display(position_display)
  end

  def missed_cut_display?(position_display)
    display = position_display.to_s.upcase
    display.present? && TournamentResult::MISSED_CUT_POSITIONS.include?(display)
  end

  def parse_position_display(position_display)
    display = position_display.to_s.strip
    return nil if display.blank?

    if (match = display.match(/\AT(\d+)\z/i))
      return match[1].to_i
    end

    return display.to_i if display.match?(/\A\d+\z/)

    nil
  end
end

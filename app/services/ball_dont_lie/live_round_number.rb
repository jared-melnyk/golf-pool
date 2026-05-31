# frozen_string_literal: true

module BallDontLie
  # Derives the in-progress round from BallDontLie tournament metadata
  # (tournament.rounds[].status from the PGA Tour feed).
  class LiveRoundNumber
    LIVE_STATUSES = %w[IN_PROGRESS SUSPENDED].freeze

    def self.from_api(tournament_payload:, fallback: nil)
      rounds = tournament_payload.is_a?(Hash) ? tournament_payload["rounds"] : nil
      return fallback if rounds.blank?

      live = rounds.find { |r| LIVE_STATUSES.include?(r["status"].to_s.upcase) }
      round_number = live&.dig("round_number")&.to_i
      return round_number if round_number.present? && round_number.positive?

      fallback
    end

    def self.tournament_payload_from(raw_results)
      Array(raw_results).each do |entry|
        tournament = entry["tournament"]
        return tournament if tournament.is_a?(Hash) && tournament["rounds"].present?
      end
      Array(raw_results).first&.dig("tournament")
    end
  end
end

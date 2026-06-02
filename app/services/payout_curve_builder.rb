# frozen_string_literal: true

class PayoutCurveBuilder
  MIN_PAID_POSITIONS = 50

  class << self
    def prior_year_tournament(tournament)
      key = normalized_name(tournament.name)
      return nil if key.blank? || tournament.starts_at.blank?

      Tournament.where("LOWER(TRIM(name)) = ?", key)
        .where("starts_at < ?", tournament.starts_at)
        .order(starts_at: :desc)
        .first
    end

    def build_empirical!(tournament)
      prior = prior_year_tournament(tournament)
      return nil unless prior

      payload = empirical_payload_for(prior)
      return nil unless payload

      tournament.update!(
        payout_curve_source: "empirical",
        payout_curve: payload,
        payout_curve_built_at: Time.current
      )
      payload
    end

    def empirical_payload_for(prior_tournament)
      return nil if prior_tournament.nil?

      paid = prior_tournament.tournament_results.where("prize_money > 0").where.not(position: nil)
      return nil if paid.count < MIN_PAID_POSITIONS

      purse = prior_tournament.effective_prize_pool
      return nil unless purse.positive?

      shares = {}
      paid.group_by(&:position).each do |position, rows|
        avg_prize = rows.sum { |r| r.prize_money.to_d } / rows.size
        shares[position.to_s] = (avg_prize / purse).to_s("F")
      end

      {
        "shares" => shares,
        "metadata" => {
          "prior_tournament_id" => prior_tournament.id,
          "built_at" => Time.current.iso8601
        }
      }
    end

    def refresh_dependent_tournaments!(prior_tournament)
      key = normalized_name(prior_tournament.name)
      return if key.blank?

      Tournament.where("LOWER(TRIM(name)) = ?", key)
        .where("starts_at > ?", prior_tournament.starts_at)
        .find_each do |tournament|
          PayoutCurveResolver.new(tournament).resolve_and_persist!
        end
    end

    private

    def normalized_name(name)
      name.to_s.downcase.strip
    end
  end
end

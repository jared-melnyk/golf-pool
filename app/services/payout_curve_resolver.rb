# frozen_string_literal: true

class PayoutCurveResolver
  def initialize(tournament)
    @tournament = tournament
  end

  def resolve_and_persist!
    if PgaPayoutProfiles.hidden_for_name?(@tournament.name)
      persist_hidden!
      Rails.logger.debug("[PayoutCurveResolver] tournament=#{@tournament.id} path=hidden (suppressed)")
      return :hidden
    end

    if try_empirical!
      Rails.logger.debug("[PayoutCurveResolver] tournament=#{@tournament.id} path=empirical")
      return :empirical
    end

    profile_id = PgaPayoutProfiles.profile_id_for_name(@tournament.name)
    if profile_id
      persist_static!(profile_id)
      Rails.logger.debug("[PayoutCurveResolver] tournament=#{@tournament.id} path=static profile=#{profile_id}")
      return :static
    end

    persist_hidden!
    Rails.logger.debug("[PayoutCurveResolver] tournament=#{@tournament.id} path=hidden")
    :hidden
  end

  def curve
    return nil unless projection_source?

    PayoutCurve.from_stored(@tournament.payout_curve)
  end

  def projection_source?
    @tournament.payout_curve_source.in?(%w[empirical static])
  end

  private

  def try_empirical!
    prior = PayoutCurveBuilder.prior_year_tournament(@tournament)
    return false unless prior

    payload = PayoutCurveBuilder.empirical_payload_for(prior)
    return false unless payload

    @tournament.update!(
      payout_curve_source: "empirical",
      payout_curve: payload,
      payout_curve_built_at: Time.current
    )
    true
  end

  def persist_static!(profile_id)
    @tournament.update!(
      payout_curve_source: "static",
      payout_curve: PgaPayoutProfiles.curve_payload_for(profile_id),
      payout_curve_built_at: Time.current
    )
  end

  def persist_hidden!
    @tournament.update!(
      payout_curve_source: "hidden",
      payout_curve: nil,
      payout_curve_built_at: Time.current
    )
  end
end

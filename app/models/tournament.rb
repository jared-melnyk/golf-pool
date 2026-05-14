class Tournament < ApplicationRecord
  belongs_to :champion_golfer, class_name: "Golfer", optional: true

  has_many :pool_tournaments, dependent: :destroy
  has_many :pools, through: :pool_tournaments
  has_many :picks, dependent: :destroy
  has_many :tournament_results, dependent: :destroy
  has_many :tournament_round_results, dependent: :destroy
  has_many :tournament_fields, dependent: :destroy
  has_many :field_golfers, through: :tournament_fields, source: :golfer

  validates :name, presence: true

  # Picks lock at midnight Central (CST/CDT) on the tournament start date. We always use this
  # instead of the API start time so we don't have to guess if the API time is accurate.
  CENTRAL = "Central Time (US & Canada)"

  # Tournaments that can be added to a pool: no champion yet (tournament not completed).
  # Completion is driven by champion_golfer_id (set when we sync results and get a winner).
  scope :addable_to_pool, -> { where(champion_golfer_id: nil) }

  # Time we use for "tournament started" and locking picks: midnight Central on the start date.
  def picks_lock_at
    return nil if starts_at.blank?

    date_str = starts_at.utc.strftime("%Y-%m-%d")
    Time.find_zone(CENTRAL).parse("#{date_str} 00:00:00")
  end

  def started?
    picks_lock_at.present? && picks_lock_at <= Time.current
  end

  # Tournament is completed when we have a champion (winner from synced results, position 1).
  def completed?
    champion_golfer_id.present?
  end

  def picks_open_at
    return nil if starts_at.blank?

    starts_at - 4.days
  end

  def picks_open?
    return false if starts_at.blank?

    !picks_locked? && Time.current >= picks_open_at
  end

  def picks_locked?
    started?
  end

  DEFAULT_FALLBACK_PRIZE_POOL = BigDecimal("20000000")

  # True only when the API has provided a real positive purse for this tournament.
  # When false, the max bonus comes from fallback_prize_pool or the global default,
  # and the UI should disclose that the cap is estimated.
  def prize_pool_known?
    total_prize_pool.to_d.positive?
  end

  # Best available prize pool for cap math. Prefers the real API purse, then the
  # cached previous-year fallback, then a conservative global default. Always positive.
  def effective_prize_pool
    candidate = total_prize_pool.to_d
    return candidate if candidate.positive?

    candidate = fallback_prize_pool.to_d
    return candidate if candidate.positive?

    DEFAULT_FALLBACK_PRIZE_POOL
  end

  # Maximum Cut Made Bonus per pick: 10% of the effective prize pool.
  def max_cut_made_bonus
    effective_prize_pool * 0.10
  end

  # Cut Made Bonus (20 × |american_odds|) capped at max_cut_made_bonus.
  # max_cut_made_bonus is always positive, so the cap is always enforced.
  def capped_cut_made_bonus(american_odds)
    return 0.to_d if american_odds.nil?

    raw = american_odds.to_d.abs * 20
    [ raw, max_cut_made_bonus ].min
  end

  # Backwards-compatible aliases while transitioning internal terminology.
  def max_longshot_bonus
    max_cut_made_bonus
  end

  def capped_longshot_bonus(american_odds)
    capped_cut_made_bonus(american_odds)
  end

  # A tournament is inferred as no-cut when at least 90% of the field has positive earnings.
  # We infer this only after completion, to avoid volatile mid-tournament classification.
  def no_cut_event?
    return false unless completed?

    field_size = effective_field_size_for_cut
    return false if field_size.zero?

    made_cut_count = tournament_results.where("prize_money > 0").count
    made_cut_count >= (field_size * 0.90).ceil
  end

  # For no-cut events, we create a synthetic cut: top 45% of field, plus ties.
  # Returns the position number at the cut line (e.g. 5 means position <= 5 earns bonus).
  def synthetic_cut_line_position
    return nil unless no_cut_event?

    positions = tournament_results.where.not(position: nil).order(:position).pluck(:position)
    return nil if positions.empty?

    cutoff_index = [ synthetic_cut_count - 1, positions.length - 1 ].min
    positions[cutoff_index]
  end

  # Unified bonus eligibility rule:
  # - normal cut events: use made_cut?
  # - no-cut events: use synthetic cut line position
  def bonus_cut_eligible_result?(result)
    return false if result.nil?

    if no_cut_event?
      cutoff = synthetic_cut_line_position
      cutoff.present? && result.position.present? && result.position <= cutoff
    else
      result.made_cut?
    end
  end

  # For no-cut messaging: among golfers eligible for Cut Made Bonus (position rule), the worst
  # (numerically highest) final total_to_par from round results keyed by API player id, or nil.
  def marginal_bonus_eligible_total_to_par(round_results_by_player_id)
    return nil if round_results_by_player_id.blank?

    max_par = nil
    tournament_results.includes(:golfer).find_each do |result|
      next unless bonus_cut_eligible_result?(result)

      golfer = result.golfer
      next if golfer.blank? || golfer.external_id.blank?

      pid = golfer.external_id.to_i
      next if pid.zero?

      row = round_results_by_player_id[pid]
      ttp = row&.fetch(:total_to_par, nil)
      next if ttp.nil?

      v = ttp.to_i
      max_par = max_par.nil? ? v : [ max_par, v ].max
    end
    max_par
  end

  # True if we have already synced results (no need to sync again). We do not use ends_at.
  def results_synced_since_completion?
    results_synced_at.present? && champion_golfer_id.present?
  end

  # The BallDontLie API can return positions (and set a winner) before earnings are populated.
  # In that case we still mark the tournament completed, but every golfer shows $0 / MC until
  # results are re-synced. Auto-sync must keep trying while the champion row has no real prize.
  def tournament_results_earnings_incomplete?
    return false if champion_golfer_id.blank?

    wr = tournament_results.find_by(golfer_id: champion_golfer_id)
    wr.nil? || wr.prize_money.blank? || wr.prize_money.to_d <= 0
  end

  private

  def effective_field_size_for_cut
    field_count = tournament_fields.count
    return field_count if field_count.positive?

    tournament_results.count
  end

  def synthetic_cut_count
    (effective_field_size_for_cut * 0.45).ceil
  end
end

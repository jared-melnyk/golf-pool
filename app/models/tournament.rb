class Tournament < ApplicationRecord
  belongs_to :champion_golfer, class_name: "Golfer", optional: true

  has_many :pool_tournaments, dependent: :destroy
  has_many :pools, through: :pool_tournaments
  has_many :picks, dependent: :destroy
  has_many :tournament_results, dependent: :destroy
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

  # Maximum longshot bonus per pick: 10% of tournament total prize pool (advertised purse).
  # Prize pool is expected to be set from API or manually and is static; when nil, max bonus is 0.
  def max_longshot_bonus
    (total_prize_pool.to_d || 0) * 0.10
  end

  # True if we have already synced results (no need to sync again). We do not use ends_at.
  def results_synced_since_completion?
    results_synced_at.present?
  end
end

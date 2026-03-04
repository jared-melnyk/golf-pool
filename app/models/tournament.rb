class Tournament < ApplicationRecord
  has_many :pool_tournaments, dependent: :destroy
  has_many :pools, through: :pool_tournaments
  has_many :picks, dependent: :destroy
  has_many :tournament_results, dependent: :destroy
  has_many :tournament_fields, dependent: :destroy
  has_many :field_golfers, through: :tournament_fields, source: :golfer

  validates :name, presence: true

  # Tournaments that can be added to a pool: not yet completed. Started-but-not-finished is OK.
  # Completed = ends_at is at least 1 day ago so the final day of play still counts as addable.
  scope :addable_to_pool, -> { where("ends_at IS NULL OR ends_at >= ?", 1.day.ago) }

  def started?
    starts_at.present? && starts_at <= Time.current
  end

  def completed?
    ends_at.present? && ends_at < Time.current
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

  # True if we have already synced results after the tournament ended (no need to sync again).
  def results_synced_since_completion?
    return false unless completed?
    return false if results_synced_at.blank?

    results_synced_at >= ends_at
  end
end

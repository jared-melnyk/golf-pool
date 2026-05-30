class PoolTournament < ApplicationRecord
  belongs_to :pool
  belongs_to :tournament
  has_many :pool_tournament_odds, class_name: "PoolTournamentOdds", dependent: :destroy

  validate :tournament_not_completed

  after_create_commit :enqueue_sync_field
  after_create_commit :enqueue_odds_lock

  scope :needs_odds_refresh, -> {
    joins(:tournament)
      .where(tournaments: { champion_golfer_id: nil })
      .where.not(tournaments: { external_id: [ nil, "" ] })
      .where.not(tournaments: { starts_at: nil })
  }

  def picks_open_for_submission?
    tournament&.picks_open? || false
  end

  def can_view_all_picks?(_user)
    tournament&.picks_locked? || false
  end

  def can_view_member_picks?(viewer, member)
    return false if viewer.nil? || member.nil?

    viewer == member || can_view_all_picks?(viewer)
  end

  def enqueue_odds_lock
    refresh_starts = odds_refresh_starts_at
    return if refresh_starts.blank?
    return unless odds_lock_eligible?

    if lock_time < refresh_starts
      LockOddsJob.set(wait_until: refresh_starts).perform_later(id)
    else
      LockOddsJob.perform_later(id)
    end
  end

  # Begin refreshing stored odds once picks open (DraftKings lines move until lock).
  def odds_refresh_starts_at
    tournament.picks_open_at
  end

  def odds_lock_eligible?
    tournament.external_id.present? &&
      !tournament.completed? &&
      tournament.picks_lock_at.present? &&
      lock_time < tournament.picks_lock_at
  end

  def needs_odds_refresh?
    refresh_starts = odds_refresh_starts_at
    odds_lock_eligible? &&
      refresh_starts.present? &&
      lock_time >= refresh_starts
  end

  # Picks lock at midnight Central; compare refresh windows in that zone.
  def lock_time
    Time.current.in_time_zone(Tournament::CENTRAL)
  end

  private

  # Block adding a tournament that has a champion (already completed).
  def tournament_not_completed
    return if tournament.blank?
    return if tournament.champion_golfer_id.blank?

    errors.add(:tournament, "has already completed")
  end

  def enqueue_sync_field
    SyncTournamentFieldJob.perform_later(tournament_id)
  end
end

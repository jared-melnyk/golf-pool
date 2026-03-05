class PoolTournament < ApplicationRecord
  belongs_to :pool
  belongs_to :tournament
  has_many :pool_tournament_odds, class_name: "PoolTournamentOdds", dependent: :destroy

  validate :tournament_not_completed

  after_create_commit :enqueue_sync_field
  after_create_commit :schedule_lock_odds

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

  def schedule_lock_odds
    lock_at_time = tournament.picks_lock_at
    return if lock_at_time.blank?

    lock_at = lock_at_time - 15.minutes
    return if lock_at <= Time.current

    LockOddsJob.set(wait_until: lock_at).perform_later(id)
  end
end

class PoolTournament < ApplicationRecord
  belongs_to :pool
  belongs_to :tournament

  validate :tournament_not_completed

  after_create_commit :enqueue_sync_field
  after_create_commit :schedule_lock_odds

  private

  def tournament_not_completed
    return if tournament.blank?
    return if tournament.ends_at.blank? || tournament.ends_at >= Time.current

    errors.add(:tournament, "has already completed")
  end

  def enqueue_sync_field
    SyncTournamentFieldJob.perform_later(tournament_id)
  end

  def schedule_lock_odds
    return if tournament.starts_at.blank?

    lock_at = tournament.starts_at - 15.minutes
    return if lock_at <= Time.current

    LockOddsJob.set(wait_until: lock_at).perform_later(id)
  end
end

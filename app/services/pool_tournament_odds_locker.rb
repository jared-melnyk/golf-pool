# frozen_string_literal: true

# Snapshots DraftKings tournament_winner futures into pool_tournament_odds.
# Refreshes existing rows on every run while picks are still open, then stops
# automatically once picks lock (midnight Central on start day).
class PoolTournamentOddsLocker
  class LockNotAllowedError < StandardError; end

  Result = Struct.new(:created, :updated, :skipped_unmatched, :api_rows, keyword_init: true)

  def initialize(pool_tournament:, client: nil, force: false, locked_at: nil)
    @pool_tournament = pool_tournament
    @tournament = pool_tournament.tournament
    @client = client || BallDontLie::Client.new
    @force = force
    @locked_at = locked_at || Time.current
  end

  def call
    assert_lockable!

    api_rows = @client.fetch_all_futures(
      tournament_ids: [ @tournament.external_id.to_i ],
      vendors: [ "draftkings" ]
    )

    created = updated = skipped_unmatched = 0

    api_rows.each do |future|
      next unless future["market_type"] == "tournament_winner"

      player = future["player"]
      next if player.blank?

      golfer = Golfer.find_by(external_id: player["id"].to_s)
      unless golfer
        skipped_unmatched += 1
        next
      end

      odds = PoolTournamentOdds.find_or_initialize_by(pool_tournament: @pool_tournament, golfer: golfer)
      was_new = odds.new_record?

      odds.assign_attributes(
        american_odds: future["american_odds"],
        vendor: future["vendor"],
        locked_at: @locked_at
      )
      odds.save!

      if was_new
        created += 1
      else
        updated += 1
      end
    end

    mark_refreshed! if created.positive? || updated.positive?

    Result.new(
      created: created,
      updated: updated,
      skipped_unmatched: skipped_unmatched,
      api_rows: api_rows.size
    )
  end

  private

  def assert_lockable!
    raise LockNotAllowedError, "Tournament has no external_id" if @tournament.external_id.blank?
    raise LockNotAllowedError, "Tournament is completed" if @tournament.completed?
    raise LockNotAllowedError, "Tournament has no picks lock time" if @tournament.picks_lock_at.blank?

    if Time.current >= @tournament.picks_lock_at && !@force
      raise LockNotAllowedError, "Picks are locked; refusing automatic odds snapshot"
    end
  end

  def mark_refreshed!
    @pool_tournament.update_column(:odds_locked_at, @locked_at)
  end
end

class PoolTournamentsController < ApplicationController
  before_action :require_login

  def create
    @pool = current_user.pools.find_by!(token: params[:pool_token])
    unless @pool.creator?(current_user)
      redirect_to @pool, alert: "Only the pool creator can add or remove tournaments."
      return
    end
    tournament = Tournament.find(params[:tournament_id])
    pt = @pool.pool_tournaments.find_or_initialize_by(tournament: tournament)
    if pt.save
      redirect_to @pool, notice: "Tournament added."
    else
      redirect_to @pool, alert: pt.errors.full_messages.to_sentence
    end
  end

  def destroy
    pt = PoolTournament.find(params[:id])
    @pool = current_user.pools.find(pt.pool_id)
    unless @pool.creator?(current_user)
      redirect_to @pool, alert: "Only the pool creator can add or remove tournaments."
      return
    end
    pt.destroy!
    redirect_to @pool, notice: "Tournament removed from pool."
  end

  def show
    @pool_tournament = PoolTournament.includes(:pool_tournament_odds).find(params[:id])
    @pool = @pool_tournament.pool
    @tournament = @pool_tournament.tournament

    # If the tournament has an external_id and we haven't synced results since completion
    # (no winner / prize money populated), try to sync them so completion, prize money,
    # and points are up to date when viewing scores from the pool context. We intentionally
    # do NOT rely on ends_at from the API, since it can be unreliable.
    if @tournament.external_id.present? &&
        !@tournament.completed? &&
        !@tournament.results_synced_since_completion?
      begin
        BallDontLie::SyncTournamentResults.new(tournament: @tournament).call
        @tournament.reload
      rescue => e
        Rails.logger.error("[PoolTournament scores] Failed to auto-sync results for tournament #{@tournament.id}: #{e.class}: #{e.message}")
      end
    end

    unless @pool.users.include?(current_user)
      redirect_to @pool, alert: "You must be a member of this pool to view scores."
      return
    end

    @picks_by_user = Pick
      .includes(:golfers)
      .where(pool_tournament: @pool_tournament)
      .group_by(&:user)

    pga_tournament_id = @tournament.external_id&.to_i
    player_ids = @picks_by_user.values.flatten.flat_map { |pick| pick.golfers.map { |g| g.external_id&.to_i } }.compact.uniq

    @round_results = {}
    @current_round = nil

    if pga_tournament_id.present? && player_ids.any?
      client = BallDontLie::Client.new
      raw_data = client.fetch_all_player_round_results(tournament_ids: [ pga_tournament_id ], player_ids: player_ids)
      formatter = BallDontLie::PlayerRoundResultsFormatter.new(raw_data)

      # When the tournament has started, fetch hole-by-hole scorecards so we can show
      # intra-round (live) scores. We always try when started? — merge only fills rounds
      # that don't already have data from player_round_results, so syncing results
      # mid-tournament does not prevent live scores from showing.
      if @tournament.started?
        Rails.logger.warn "[Live scores] Fetching scorecards tournament_id=#{pga_tournament_id} player_count=#{player_ids.size}"
        cards = client.fetch_all_player_scorecards(tournament_ids: [ pga_tournament_id ], player_ids: player_ids)
        if cards.present?
          formatter.merge_scorecard_live!(cards)
          Rails.logger.warn "[Live scores] Merged #{cards.size} scorecard rows for tournament #{pga_tournament_id}"
        else
          Rails.logger.warn "[Live scores] Scorecards API returned 0 rows tournament_id=#{pga_tournament_id} player_ids=#{player_ids.take(5)}#{player_ids.size > 5 ? '...' : ''}"
        end
      end

      @round_results = formatter.by_player_id
      @current_round = formatter.current_round_number
    end

    # Bonus column: use TournamentResult when synced; otherwise infer made cut from live round data (round 3+ = made cut).
    golfers_by_id = {}
    @picks_by_user.values.flatten.each { |pick| pick.golfers.each { |g| golfers_by_id[g.id] = g } }
    golfer_ids = golfers_by_id.keys
    results_by_golfer = TournamentResult.where(tournament: @tournament, golfer_id: golfer_ids).index_by(&:golfer_id)
    odds_by_golfer = @pool_tournament.pool_tournament_odds.index_by(&:golfer_id)

    @golfer_bonus_display = {}
    golfer_ids.each do |gid|
      golfer = golfers_by_id[gid]
      result = results_by_golfer[gid]
      odds_row = odds_by_golfer[gid]

      if result
        # Official result synced: use made_cut? and show bonus or MC
        if result.made_cut? && odds_row
          @golfer_bonus_display[gid] = @tournament.capped_cut_made_bonus(odds_row.american_odds)
        else
          @golfer_bonus_display[gid] = :mc
        end
      elsif golfer && @round_results.present?
        # No result yet: infer from live round data (round 3 or 4 = made cut)
        player_result = @round_results[golfer.external_id&.to_i] || {}
        round_numbers = (player_result[:rounds] || {}).keys
        made_cut = round_numbers.any? { |r| r >= 3 }
        cut_known = @current_round.present? && @current_round >= 3
        missed_cut = cut_known && round_numbers.any? && !made_cut

        if made_cut && odds_row
          @golfer_bonus_display[gid] = @tournament.capped_cut_made_bonus(odds_row.american_odds)
        elsif missed_cut
          @golfer_bonus_display[gid] = :mc
        else
          @golfer_bonus_display[gid] = nil
        end
      else
        @golfer_bonus_display[gid] = nil
      end
    end

    # Prize money: show only when tournament is completed (from TournamentResult).
    @golfer_prize_money = {}
    golfer_ids.each do |gid|
      result = results_by_golfer[gid]
      @golfer_prize_money[gid] = @tournament.completed? && result ? (result.prize_money.to_d || 0) : nil
    end
  end
end

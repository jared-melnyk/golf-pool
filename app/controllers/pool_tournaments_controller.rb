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

    unless @pool.users.include?(current_user)
      redirect_to @pool, alert: "You must be a member of this pool to view scores."
      return
    end

    @picks_by_user = Pick
      .includes(:golfers)
      .where(pool_tournament: @pool_tournament)
      .group_by(&:user)

    picked_golfers = @picks_by_user.values.flatten.flat_map(&:golfers).uniq
    player_ids = picked_golfers.map { |g| g.external_id&.to_i }.compact.reject(&:zero?).uniq

    if @tournament.completed? && @tournament.no_cut_event?
      field_ids = @tournament.tournament_results.includes(:golfer).filter_map { |tr| tr.golfer&.external_id&.to_i }
      player_ids = (player_ids + field_ids).uniq.reject(&:zero?)
    end

    @synthetic_cut_marginal_total_to_par = nil
    @round_results = {}
    @current_round = nil

    if @tournament.external_id.present? && player_ids.any?
      relevant_golfer_ids = Golfer.where(external_id: player_ids.map(&:to_s)).pluck(:id)

      rows = TournamentRoundResult
               .where(tournament_id: @tournament.id, golfer_id: relevant_golfer_ids)
               .includes(:golfer)
               .to_a

      if rows.empty? && (@tournament.started? || @tournament.completed?)
        begin
          BallDontLie::SyncRoundResults.new(tournament: @tournament, player_ids: player_ids).call
          rows = TournamentRoundResult
                   .where(tournament_id: @tournament.id, golfer_id: relevant_golfer_ids)
                   .includes(:golfer)
                   .to_a
          sync_live_leaderboard_if_needed!
        rescue => e
          Rails.logger.error("[PoolTournament scores] Synchronous SyncRoundResults failed for tournament #{@tournament.id}: #{e.class}: #{e.message}")
        end
      elsif @tournament.started? && !@tournament.completed?
        sync_live_leaderboard_if_needed!
      end

      by_player_external_id = rows.group_by { |r| r.golfer.external_id&.to_i }.compact
      @round_results = build_round_results_hash(by_player_external_id)
      @current_round = current_round_for_display(rows)

      if @tournament.started? && !@tournament.completed?
        stale = @tournament.live_results_synced_at.nil? || @tournament.live_results_synced_at < 30.seconds.ago
        RefreshLiveResultsJob.perform_later(@tournament.id) if stale
      end

      if @tournament.completed? && @tournament.no_cut_event?
        @synthetic_cut_marginal_total_to_par = @tournament.marginal_bonus_eligible_total_to_par(@round_results)
      end
    end

    if @tournament.external_id.present? &&
        @tournament.completed? &&
        @tournament.tournament_results_earnings_incomplete?
      begin
        BallDontLie::SyncTournamentResults.new(tournament: @tournament).call
        @tournament.reload
      rescue => e
        Rails.logger.error("[PoolTournament scores] Failed to auto-sync results for tournament #{@tournament.id}: #{e.class}: #{e.message}")
      end
    end

    golfers_by_id = {}
    @picks_by_user.values.flatten.each { |pick| pick.golfers.each { |g| golfers_by_id[g.id] = g } }
    golfer_ids = golfers_by_id.keys
    results_by_golfer = TournamentResult.where(tournament: @tournament, golfer_id: golfer_ids).index_by(&:golfer_id)
    odds_by_golfer = @pool_tournament.pool_tournament_odds.index_by(&:golfer_id)

    PayoutCurveResolver.new(@tournament).resolve_and_persist! unless @tournament.completed?
    @tournament.reload
    payout_curve = PayoutCurveResolver.new(@tournament).curve

    @scoring_display = PoolTournamentScoringDisplay.new(
      tournament: @tournament,
      results_by_golfer: results_by_golfer,
      odds_by_golfer: odds_by_golfer,
      round_results: @round_results,
      current_round: @current_round,
      payout_curve: payout_curve
    )
    @golfer_bonus_display = golfer_ids.index_with { |gid| @scoring_display.bonus_for(golfers_by_id[gid]) }
    @golfer_prize_money = golfer_ids.index_with { |gid| @scoring_display.prize_money_for(golfers_by_id[gid]) }
    @show_counted_dropped_badges = @scoring_display.show_counted_dropped_badges?
    @badges_projected = @scoring_display.badges_projected?
    @projection_enabled = @scoring_display.projection_enabled?
  end

  private

  def sync_live_leaderboard_if_needed!
    return unless @tournament.external_id.present?
    return unless @tournament.started? && !@tournament.completed?

    stale = @tournament.leaderboard_synced_at.nil? || @tournament.leaderboard_synced_at < 30.seconds.ago
    return unless stale

    BallDontLie::SyncLiveLeaderboard.new(tournament: @tournament).call
    @tournament.reload
  rescue => e
    Rails.logger.error("[PoolTournament scores] SyncLiveLeaderboard failed for tournament #{@tournament.id}: #{e.class}: #{e.message}")
  end

  def current_round_for_display(rows)
    return nil if rows.empty?

    if @tournament.started? && !@tournament.completed? && @tournament.live_round_number.present?
      return @tournament.live_round_number
    end

    rows.map(&:round_number).max
  end

  def build_round_results_hash(round_rows_by_player_external_id)
    result = {}
    round_rows_by_player_external_id.each do |player_external_id, rows|
      rounds = {}
      rows.each do |row|
        rounds[row.round_number] = {
          score: nil,
          par_relative: row.par_relative,
          score_to_par: row.score_to_par,
          last_hole_completed: row.last_hole_completed
        }
      end
      total = rounds.values.sum { |r| (r[:score_to_par] || 0).to_i }
      result[player_external_id] = {
        rounds: rounds,
        total_to_par: rounds.any? ? total : nil,
        position: nil
      }
    end
    result
  end
end

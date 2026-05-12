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
        rescue => e
          Rails.logger.error("[PoolTournament scores] Synchronous SyncRoundResults failed for tournament #{@tournament.id}: #{e.class}: #{e.message}")
        end
      end

      by_player_external_id = rows.group_by { |r| r.golfer.external_id&.to_i }.compact
      @round_results = build_round_results_hash(by_player_external_id)
      @current_round = rows.map(&:round_number).max if rows.any?

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

    @golfer_bonus_display = {}
    golfer_ids.each do |gid|
      golfer = golfers_by_id[gid]
      result = results_by_golfer[gid]
      odds_row = odds_by_golfer[gid]

      if result && @tournament.completed?
        if @tournament.bonus_cut_eligible_result?(result) && odds_row
          @golfer_bonus_display[gid] = @tournament.capped_cut_made_bonus(odds_row.american_odds)
        else
          @golfer_bonus_display[gid] = :mc
        end
      elsif golfer && @round_results.present?
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

    @golfer_prize_money = {}
    golfer_ids.each do |gid|
      result = results_by_golfer[gid]
      @golfer_prize_money[gid] = @tournament.completed? && result ? (result.prize_money.to_d || 0) : nil
    end
  end

  private

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

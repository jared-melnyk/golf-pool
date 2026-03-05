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
    if pt.tournament.started?
      redirect_to @pool, alert: "Cannot remove a tournament that has already started."
      return
    end
    pt.destroy!
    redirect_to @pool, notice: "Tournament removed from pool."
  end

  def show
    @pool_tournament = PoolTournament.find(params[:id])
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

    pga_tournament_id = @tournament.external_id&.to_i
    player_ids = @picks_by_user.values.flatten.flat_map { |pick| pick.golfers.map { |g| g.external_id&.to_i } }.compact.uniq

    @round_results = {}
    @current_round = nil

    if pga_tournament_id.present? && player_ids.any?
      client = BallDontLie::Client.new
      raw_data = client.fetch_all_player_round_results(tournament_ids: [ pga_tournament_id ], player_ids: player_ids)
      formatter = BallDontLie::PlayerRoundResultsFormatter.new(raw_data)

      # When the tournament has started but results haven't been synced yet,
      # fetch hole-by-hole scorecards (all rounds) to show intra-round (live) scores.
      if @tournament.started? && @tournament.results_synced_at.blank?
        cards = client.fetch_all_player_scorecards(tournament_ids: [ pga_tournament_id ], player_ids: player_ids)
        if cards.present?
          formatter.merge_scorecard_live!(cards)
          Rails.logger.info "[Live scores] Merged #{cards.size} scorecard rows for tournament #{pga_tournament_id}"
        else
          Rails.logger.warn "[Live scores] Scorecards API returned 0 rows for tournament_id=#{pga_tournament_id} player_ids=#{player_ids.take(5)}#{player_ids.size > 5 ? '...' : ''}. Mid-round scores will not show."
        end
      end

      @round_results = formatter.by_player_id
      @current_round = formatter.current_round_number
    end
  end
end

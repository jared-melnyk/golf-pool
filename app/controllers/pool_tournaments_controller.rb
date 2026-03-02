class PoolTournamentsController < ApplicationController
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
end

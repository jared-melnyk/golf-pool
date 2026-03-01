class PoolTournamentsController < ApplicationController
  def create
    @pool = current_user.pools.find_by!(token: params[:pool_id])
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
    pt.destroy!
    redirect_to @pool, notice: "Tournament removed from pool."
  end
end

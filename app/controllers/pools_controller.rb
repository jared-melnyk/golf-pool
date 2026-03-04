class PoolsController < ApplicationController
  def index
    @pools = current_user.pools
  end

  def show
    @pool = Pool.find_by!(token: params[:token])
    if @pool.users.include?(current_user)
      @pool_tournaments = @pool.pool_tournaments.includes(:pool_tournament_odds)

      @my_picks_by_tournament = Pick
        .joins(:pool_tournament)
        .where(user: current_user, pool_tournaments: { pool_id: @pool.id, tournament_id: @pool.tournaments.ids })
        .includes(pick_golfers: :golfer)
        .index_by(&:tournament_id)

      @picks_by_tournament_and_user = Pick
        .joins(:pool_tournament)
        .where(pool_tournaments: { pool_id: @pool.id, tournament_id: @pool.tournaments.ids })
        .includes(:user, pick_golfers: :golfer)
        .group_by(&:tournament_id)
        .transform_values do |picks|
          picks.index_by(&:user_id)
        end
    else
      render :show_join
    end
  end

  def new
    @pool = Pool.new
  end

  def create
    @pool = Pool.new(pool_params)
    @pool.creator = current_user
    if @pool.save
      @pool.pool_users.create!(user: current_user)
      redirect_to @pool, notice: "Pool created. Add tournaments and invite others."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def join
    @pool = Pool.find_by!(token: params[:token])
    if @pool.pool_users.exists?(user_id: current_user.id)
      redirect_to @pool, notice: "You're already in this pool."
    else
      @pool.pool_users.create!(user: current_user)
      redirect_to @pool, notice: "You joined the pool."
    end
  end

  private

  def pool_params
    params.require(:pool).permit(:name)
  end
end

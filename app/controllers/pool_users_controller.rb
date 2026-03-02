class PoolUsersController < ApplicationController
  def create
    @pool = current_user.pools.find_by!(token: params[:pool_token])
    unless @pool.creator?(current_user)
      redirect_to @pool, alert: "Only the pool creator can add members."
      return
    end
    user = User.find(params[:user_id])
    @pool.pool_users.find_or_create_by!(user: user)
    redirect_to @pool, notice: "Member added."
  end

  def destroy
    pu = PoolUser.find(params[:id])
    @pool = current_user.pools.find(pu.pool_id)
    can_remove = @pool.creator?(current_user) || pu.user_id == current_user.id
    unless can_remove
      redirect_to @pool, alert: "Only the pool creator can remove other members. You can leave the pool using Leave pool."
      return
    end
    pu.destroy!
    if pu.user_id == current_user.id
      redirect_to pools_path, notice: "You left the pool."
    else
      redirect_to @pool, notice: "Member removed."
    end
  end
end

class PoolUsersController < ApplicationController
  def create
    @pool = current_user.pools.find_by!(token: params[:pool_id])
    user = User.find(params[:user_id])
    @pool.pool_users.find_or_create_by!(user: user)
    redirect_to @pool, notice: "Member added."
  end

  def destroy
    pu = PoolUser.find(params[:id])
    @pool = current_user.pools.find(pu.pool_id)
    pu.destroy!
    redirect_to @pool, notice: "Member removed."
  end
end

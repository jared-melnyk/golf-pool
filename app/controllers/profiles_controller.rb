class ProfilesController < ApplicationController
  def edit
    @user = current_user
  end

  def update
    @user = current_user
    if @user.update(profile_params)
      redirect_to edit_profile_path, notice: "Profile updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def profile_params
    p = params.require(:user).permit(:ghin_handicap_index)
    p[:ghin_handicap_index] = nil if p[:ghin_handicap_index].blank?
    p
  end
end

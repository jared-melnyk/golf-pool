class SessionsController < ApplicationController
  skip_before_action :require_login, only: [ :new, :create ]

  def new
  end

  def create
    user = User.find_by(email: params[:email]&.downcase)
    if user&.authenticate(params[:password])
      session[:user_id] = user.id
      remember_user(user)
      redirect_to session.delete(:return_to).presence || root_path, notice: "Signed in."
    else
      flash.now[:alert] = "Invalid email or password."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    forget_remember_user(current_user)
    session.delete(:user_id)
    session.delete(:session_start_recorded)
    redirect_to root_path, notice: "Signed out."
  end
end

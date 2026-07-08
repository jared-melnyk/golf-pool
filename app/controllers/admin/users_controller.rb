# frozen_string_literal: true

module Admin
  class UsersController < ApplicationController
    before_action :require_admin
    before_action :set_user, only: [ :edit, :update ]

    def index
      @users = User.order(Arel.sql("last_login_at DESC NULLS LAST"))
    end

    def new
      @user = User.new
    end

    def create
      @user = User.new(create_params)
      if @user.save
        redirect_to admin_users_path, notice: "User created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @user.update(update_params)
        redirect_to admin_users_path, notice: "User updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def create_params
      normalize_handicap(permitted_user_params)
    end

    def update_params
      attrs = normalize_handicap(permitted_user_params)
      if attrs[:password].blank?
        attrs.delete(:password)
        attrs.delete(:password_confirmation)
      end
      attrs
    end

    def permitted_user_params
      params.require(:user).permit(:name, :email, :password, :password_confirmation, :ghin_handicap_index)
    end

    def normalize_handicap(attrs)
      attrs[:ghin_handicap_index] = nil if attrs[:ghin_handicap_index].blank?
      attrs
    end
  end
end

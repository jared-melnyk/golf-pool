# frozen_string_literal: true

module Admin
  class UsersController < ApplicationController
    before_action :require_admin

    def index
      @users = User.order(Arel.sql("last_login_at DESC NULLS LAST"))
    end
  end
end

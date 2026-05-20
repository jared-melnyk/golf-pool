# frozen_string_literal: true

class GameMembershipsController < ApplicationController
  include GameAuthorizable

  before_action :set_game
  before_action :require_game_manager!

  def update
    membership = @game.game_memberships.find(params[:id])
    unless membership.player?
      redirect_to game_path(@game), alert: "That member is already a cohost or host."
      return
    end

    membership.update!(role: "cohost")
    redirect_to game_path(@game), notice: "#{membership.user.name} is now a cohost."
  end

  def destroy
    membership = @game.game_memberships.find(params[:id])

    if membership.user_id == current_user.id
      if membership.host? && @game.game_memberships.where(role: "host").count <= 1
        redirect_to game_path(@game), alert: "You are the only host. Promote another host before leaving."
        return
      end
      membership.destroy!
      redirect_to games_path, notice: "You left the game."
      return
    end

    membership.destroy!
    redirect_to game_path(@game), notice: "Member removed."
  end
end

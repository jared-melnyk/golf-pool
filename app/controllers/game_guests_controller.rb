# frozen_string_literal: true

class GameGuestsController < ApplicationController
  include GameAuthorizable

  before_action :set_game
  before_action :require_game_manager!
  before_action :require_game_active_for_teams!

  def create
    @guest = @game.game_guests.new(game_guest_params)
    if @guest.save
      redirect_to edit_teams_game_path(@game), notice: "#{@guest.name} added as a guest."
    else
      prepare_edit_teams
      flash.now[:alert] = @guest.errors.full_messages.to_sentence.presence || "Could not add guest."
      render "games/edit_teams", status: :unprocessable_entity
    end
  end

  def destroy
    guest = @game.game_guests.find(params[:id])
    name = guest.name
    guest.destroy!
    redirect_to edit_teams_game_path(@game), notice: "#{name} removed."
  end

  private

  def game_guest_params
    params.require(:game_guest).permit(:name, :handicap_index)
  end

  def require_game_active_for_teams!
    return if @game.active? || @game.completed?

    redirect_to game_setup_path(@game), alert: "Finish game setup before assigning teams."
  end

  def prepare_edit_teams
    @members = @game.roster_users
    @guests = @game.game_guests.order(:name)
    @game_teams = @game.game_teams.includes(game_team_players: [ :user, :game_guest ])
    @guest = @guest || GameGuest.new
  end
end

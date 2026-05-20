# frozen_string_literal: true

module GameAuthorizable
  extend ActiveSupport::Concern

  private

  def set_game
    @game = Game.find_by!(token: params[:token] || params[:game_token])
  end

  def require_game_access!
    return if @game.member?(current_user)

    if controller_name == "games" && action_name == "show"
      render "games/show_join", status: :ok
    else
      redirect_to game_path(@game), alert: "You must be a member of this game."
    end
  end

  def require_game_manager!
    return if @game.can_manage?(current_user)

    redirect_to game_path(@game), alert: "Only hosts can do that."
  end

  def require_game_not_completed!
    return unless @game.completed?

    redirect_to game_path(@game), alert: "Scores are finalized. Reopen the scorecard to make changes."
  end
end

class GamesController < ApplicationController
  include GameScorecardBuilder

  before_action :set_event
  before_action :require_event_member!
  before_action :require_commissioner!, only: [ :new, :create, :edit_teams, :update_teams ]
  before_action :set_game, only: [ :show, :edit_teams, :update_teams ]

  def new
    @game = @event.games.new
    @rounds = @event.rounds.order(:played_on)
  end

  def create
    @game = @event.games.new(game_params)
    if @game.save
      redirect_to edit_teams_event_game_path(@event, @game), notice: "Game created. Now set up teams."
    else
      @rounds = @event.rounds.order(:played_on)
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @scorecard = build_game_scorecard(@game)
  end

  def edit_teams
    @members = @event.users.order(:name)
    @game_teams = @game.game_teams.includes(game_team_players: :user)
  end

  def update_teams
    ApplicationRecord.transaction do
      @game.game_teams.destroy_all
      teams_params.each_value do |team_data|
        next if team_data[:name].blank?

        team = @game.game_teams.create!(name: team_data[:name])
        Array(team_data[:user_ids]).compact_blank.each do |uid|
          user = @event.users.find_by(id: uid)
          GameTeamPlayer.create!(game_team: team, user: user) if user
        end
      end

      enforce_forty_score_team_sizes! if @game.forty_score?
    end
    redirect_to event_game_path(@event, @game), notice: "Teams saved."
  rescue ActiveRecord::RecordInvalid => e
    @members = @event.users.order(:name)
    @game_teams = @game.game_teams.includes(game_team_players: :user)
    flash.now[:alert] = "Could not save teams: #{e.record&.errors&.full_messages&.to_sentence || e.message}"
    render :edit_teams, status: :unprocessable_entity
  end

  private

  def set_event
    @event = Event.find_by!(token: params[:event_token])
  end

  def set_game
    @game = @event.games.find(params[:id])
  end

  def require_event_member!
    return if @event.member?(current_user)

    redirect_to event_path(@event), alert: "You must be a member of this event."
  end

  def require_commissioner!
    return if @event.commissioner?(current_user)

    redirect_to event_path(@event), alert: "Only commissioners can do that."
  end

  def game_params
    params.require(:game).permit(:round_id, :game_type)
  end

  def teams_params
    params.require(:teams).to_unsafe_h.transform_values do |v|
      team_params = v.is_a?(ActionController::Parameters) ? v : ActionController::Parameters.new(v)
      team_params.permit(:name, user_ids: []).to_h.with_indifferent_access
    end
  rescue ActionController::ParameterMissing
    {}
  end

  def enforce_forty_score_team_sizes!
    @game.game_teams.reload.each do |team|
      n = team.game_team_players.size
      next if FortyScore.valid_team_size?(n)

      team.errors.add(
        :base,
        "40 Score requires 3 or 4 players per group (#{team.name} has #{n})."
      )
      raise ActiveRecord::RecordInvalid.new(team)
    end
  end
end

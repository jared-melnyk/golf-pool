# frozen_string_literal: true

class GamesController < ApplicationController
  include GameScorecardBuilder
  include GameAuthorizable

  before_action :set_event, only: [ :new, :create ], if: -> { params[:event_token].present? }
  before_action :require_event_commissioner!, only: [ :new, :create ], if: -> { params[:event_token].present? }
  before_action :set_game, only: [ :show, :edit_teams, :update_teams, :join, :complete, :reopen ]
  before_action :require_game_access!, only: [ :show, :edit_teams, :update_teams, :complete, :reopen ]
  before_action :require_game_manager!, only: [ :edit_teams, :update_teams, :complete, :reopen ]
  before_action :require_game_active_for_teams!, only: [ :edit_teams, :update_teams ]

  def index
    visible_ids = Game.visible_to(current_user).select(:id)
    @games = Game.where(id: visible_ids)
                 .includes(:round, :event)
                 .left_joins(:round)
                 .order(Arel.sql("rounds.played_on DESC NULLS LAST"), created_at: :desc)
  end

  def new
    @game = Game.new
    @event = Event.find_by!(token: params[:event_token]) if params[:event_token].present?
  end

  def create
    if params[:event_token].present?
      create_event_game!
    else
      create_ad_hoc_game!
    end
  end

  def show
    @event = @game.event
    if @game.active? || @game.completed?
      @scorecard = build_game_scorecard(@game)
    end
  end

  def join
    if @game.member?(current_user)
      redirect_to @game, notice: "You're already in this game."
    else
      @game.game_memberships.create!(user: current_user, role: "player")
      redirect_to @game, notice: "You joined the game."
    end
  end

  def edit_teams
    @members = @game.roster_users
    @game_teams = @game.game_teams.includes(game_team_players: :user)
  end

  def update_teams
    ApplicationRecord.transaction do
      @game.game_teams.destroy_all
      teams_params.each_value do |team_data|
        next if team_data[:name].blank?

        team = @game.game_teams.create!(name: team_data[:name])
        Array(team_data[:user_ids]).compact_blank.each do |uid|
          user = @game.roster_users.find_by(id: uid)
          GameTeamPlayer.create!(game_team: team, user: user) if user
        end
      end

      enforce_forty_score_team_sizes! if @game.forty_score?
      enforce_cha_cha_cha_team_sizes! if @game.cha_cha_cha?
      enforce_vegas_team_sizes! if @game.vegas?
    end
    redirect_to game_path(@game), notice: "Teams saved."
  rescue ActiveRecord::RecordInvalid => e
    @members = @game.roster_users
    @game_teams = @game.game_teams.includes(game_team_players: :user)
    flash.now[:alert] = "Could not save teams: #{e.record&.errors&.full_messages&.to_sentence || e.message}"
    render :edit_teams, status: :unprocessable_entity
  end

  def complete
    @game.update!(status: "completed")
    redirect_to game_path(@game), notice: "Scores finalized and locked."
  end

  def reopen
    @game.update!(status: "active")
    redirect_to game_path(@game), notice: "Scores are editable again."
  end

  private

  def set_event
    @event = Event.find_by!(token: params[:event_token])
  end

  def require_event_commissioner!
    return if @event.commissioner?(current_user)

    redirect_to event_path(@event), alert: "Only commissioners can create games."
  end

  def require_game_active_for_teams!
    return if @game.active? || @game.completed?

    redirect_to game_setup_path(@game), alert: "Finish game setup before assigning teams."
  end

  def create_ad_hoc_game!
    @game = Game.new(name: game_params[:name], creator: current_user, status: "draft")
    if @game.save
      @game.game_memberships.create!(user: current_user, role: "host")
      redirect_to game_setup_path(@game), notice: "Game created. Continue setup when ready."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def create_event_game!
    name = game_params[:name].presence || "Game at #{@event.name}"
    @game = @event.games.new(name: name, creator: current_user, status: "draft")
    if @game.save
      @game.game_memberships.create!(user: current_user, role: "host")
      redirect_to game_setup_path(@game), notice: "Game created. Continue setup when ready."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def game_params
    params.fetch(:game, {}).permit(:name, :round_id, :game_type)
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

  def enforce_cha_cha_cha_team_sizes!
    @game.game_teams.reload.each do |team|
      n = team.game_team_players.size
      next if ChaChaCha.valid_team_size?(n)

      team.errors.add(
        :base,
        "Cha-Cha-Cha (1-2-3) requires 3 or 4 players per group (#{team.name} has #{n})."
      )
      raise ActiveRecord::RecordInvalid.new(team)
    end
  end

  def enforce_vegas_team_sizes!
    teams = @game.game_teams.reload.to_a
    unless Vegas.valid_game_roster?(teams.map { |t| t.game_team_players.to_a })
      @game.errors.add(:base, "Vegas requires exactly 2 teams of 2 players each.")
      raise ActiveRecord::RecordInvalid.new(@game)
    end
  end
end

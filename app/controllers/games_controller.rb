# frozen_string_literal: true

class GamesController < ApplicationController
  include GameScorecardBuilder
  include GameAuthorizable
  include RoundSnapshotBuildable
  include CourseSearchActions

  before_action :set_event, only: [ :new, :create ], if: -> { params[:event_token].present? }
  before_action :set_round, only: [ :new, :create ], if: -> { params[:round_id].present? }
  before_action :require_event_commissioner!, only: [ :new, :create ], if: -> { params[:event_token].present? }
  before_action :set_game, only: [ :show, :edit_teams, :update_teams, :join, :complete, :reopen, :destroy ]
  before_action :require_game_access!, only: [ :show, :edit_teams, :update_teams, :complete, :reopen, :destroy ]
  before_action :require_game_manager!, only: [ :edit_teams, :update_teams, :destroy ]
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
    load_ad_hoc_form_state unless @round
  end

  def create
    if params[:round_id].present?
      create_round_game!
    else
      create_ad_hoc_game!
    end
  end

  def select_course
    unless golf_course_api_key_configured?
      return render_course_selection_error(
        partial: "shared/course_searches/selection",
        message: GolfCourseApi::MissingApiKeyError::DEFAULT_MESSAGE
      )
    end

    load_selected_course(params[:course_id].to_i)
    render partial: "shared/course_searches/selection",
           locals: {
             selected_course: @selected_course,
             tee_options: @tee_options,
             selected_tee_selector: @selected_tee_selector,
             error_message: nil
           },
           layout: false
  rescue StandardError => e
    render_course_selection_error(partial: "shared/course_searches/selection", message: e.message)
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
    prepare_edit_teams
  end

  def update_teams
    ApplicationRecord.transaction do
      @game.game_teams.destroy_all
      pending = teams_params.select do |_key, team_data|
        name = team_data[:name].to_s.strip
        user_ids = Array(team_data[:user_ids]).compact_blank
        guest_ids = Array(team_data[:guest_ids]).compact_blank
        name.present? || user_ids.any? || guest_ids.any?
      end
      slot_count = [ pending.size, 1 ].max

      pending.each_with_index do |(_key, team_data), index|
        name = team_data[:name].to_s.strip
        user_ids = Array(team_data[:user_ids]).compact_blank
        guest_ids = Array(team_data[:guest_ids]).compact_blank

        name = @game.default_team_name(index, slot_count: slot_count) if name.blank?
        team = @game.game_teams.create!(name: name)
        user_ids.each do |uid|
          user = @game.roster_users.find_by(id: uid)
          GameTeamPlayer.create!(game_team: team, user: user) if user
        end
        guest_ids.each do |gid|
          guest = @game.game_guests.find_by(id: gid)
          GameTeamPlayer.create!(game_team: team, game_guest: guest) if guest
        end
      end

      enforce_single_team_format! if @game.single_team_format?
      enforce_forty_score_team_sizes! if @game.forty_score?
      enforce_cha_cha_cha_team_sizes! if @game.cha_cha_cha?
      enforce_vegas_team_sizes! if @game.vegas?
    end
    redirect_to game_path(@game), notice: "Teams saved."
  rescue ActiveRecord::RecordInvalid => e
    prepare_edit_teams
    flash.now[:alert] = "Could not save teams: #{e.record&.errors&.full_messages&.to_sentence || e.message}"
    render :edit_teams, status: :unprocessable_entity
  end

  def complete
    @game.update!(status: "completed")
    redirect_to game_path(@game), notice: "Scorecard locked."
  end

  def reopen
    @game.update!(status: "active")
    redirect_to game_path(@game), notice: "Scorecard reopened for editing."
  end

  def destroy
    event = @game.event
    name = @game.name
    @game.destroy!

    if event.present?
      redirect_to event_path(event), notice: "Game deleted."
    else
      redirect_to games_path, notice: "#{name} deleted."
    end
  end

  private

  def set_event
    @event = Event.find_by!(token: params[:event_token])
  end

  def set_round
    @round = @event.rounds.find(params[:round_id])
  end

  def require_event_commissioner!
    return if @event.commissioner?(current_user)

    redirect_to event_path(@event), alert: "Only commissioners can create games."
  end

  def require_game_active_for_teams!
    return if @game.active? || @game.completed?

    redirect_to game_setup_path(@game), alert: "Finish game setup before assigning teams."
  end

  def prepare_edit_teams
    @members = @game.roster_users
    @guests = @game.game_guests.order(:name)
    @game_teams = @game.game_teams.includes(game_team_players: [ :user, :game_guest ])
    @guest = GameGuest.new
    @team_slot_count = @game.team_slot_count(requested_slots: params[:slots])
  end

  def load_ad_hoc_form_state
    @search_query = ""
    @selected_course = nil
    @tee_options = []
    @selected_tee_selector = nil
    @course_selection_error = nil
    @round_played_on = Date.current
  end

  def create_ad_hoc_game!
    game_type = game_params[:game_type]
    snapshot = build_snapshot(
      course_id: ad_hoc_round_params.fetch(:golf_course_api_course_id).to_i,
      tee_selector: ad_hoc_round_params.fetch(:tee_selector)
    )
    played_on = Date.parse(ad_hoc_round_params.fetch(:played_on).to_s)

    ApplicationRecord.transaction do
      round = Round.create!(
        name: default_round_name_for(
          { "course_name" => snapshot[:course_name], "club_name" => snapshot[:club_name] },
          played_on: played_on
        ),
        played_on: played_on,
        golf_course_api_course_id: snapshot[:golf_course_api_course_id],
        course_name: snapshot[:course_name],
        club_name: snapshot[:club_name],
        tee_name: snapshot[:tee_name],
        tee_gender: snapshot[:tee_gender],
        course_rating: snapshot[:course_rating],
        slope_rating: snapshot[:slope_rating],
        par_total: snapshot[:par_total],
        hole_pars: snapshot[:hole_pars],
        hole_handicaps: snapshot[:hole_handicaps],
        course_snapshot: snapshot[:course_snapshot]
      )
      @game = Game.create!(
        name: Game.default_ad_hoc_name(round, game_type),
        creator: current_user,
        status: "active",
        round: round,
        game_type: game_type
      )
      @game.game_memberships.create!(user: current_user, role: "host")
    end

    redirect_to game_setup_path(@game, step: "invite"), notice: "Game created. Invite players when ready."
  rescue StandardError => e
    @game = Game.new(game_type: game_params[:game_type])
    load_ad_hoc_form_state
    @round_played_on = begin
      Date.parse(ad_hoc_round_params[:played_on].to_s)
    rescue StandardError
      Date.current
    end
    @selected_tee_selector = ad_hoc_round_params[:tee_selector]
    flash.now[:alert] = e.message
    render :new, status: :unprocessable_entity
  end

  def create_round_game!
    game_type = game_params[:game_type]
    @game = @event.games.new(
      name: Game.default_trip_name(@round, game_type),
      creator: current_user,
      status: "active",
      round: @round,
      game_type: game_type
    )
    if @game.save
      @game.game_memberships.create!(user: current_user, role: "host")
      redirect_to game_setup_path(@game, step: "invite"), notice: "Game created. Invite players when ready."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def game_params
    params.fetch(:game, {}).permit(:name, :round_id, :game_type)
  end

  def ad_hoc_round_params
    params.require(:round).permit(:played_on, :golf_course_api_course_id, :tee_selector)
  end

  def teams_params
    params.require(:teams).to_unsafe_h.transform_values do |v|
      team_params = v.is_a?(ActionController::Parameters) ? v : ActionController::Parameters.new(v)
      team_params.permit(:name, user_ids: [], guest_ids: []).to_h.with_indifferent_access
    end
  rescue ActionController::ParameterMissing
    {}
  end

  def enforce_single_team_format!
    return if @game.game_teams.reload.size <= 1

    @game.errors.add(:base, "#{Game.type_label(@game.game_type)} uses one team per game (this group’s score competes across the round).")
    raise ActiveRecord::RecordInvalid.new(@game)
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

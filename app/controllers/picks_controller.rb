class PicksController < ApplicationController
  before_action :set_pool
  before_action :set_tournament, only: [ :new, :create ]
  before_action :set_pick, only: [ :edit, :update ]
  before_action :ensure_tournament_unlocked!, only: [ :new, :create, :edit, :update ]

  def index
    @standings = @pool.standings
    @tournaments = @pool.tournaments.order(:starts_at)
  end

  def new
    @pick = Pick.find_or_initialize_by(user: current_user, tournament: @tournament)
    5.times { |i| @pick.pick_golfers.build(slot: i + 1) if @pick.pick_golfers.none? { |pg| pg.slot == i + 1 } }
    @golfers = Golfer.order(:name)
  end

  def create
    @pick = Pick.find_or_initialize_by(user: current_user, tournament: @tournament)
    @pick.pick_golfers.destroy_all if @pick.persisted?
    slot = 1
    (params[:golfer_ids] || []).first(5).each do |golfer_id|
      next if golfer_id.blank?
      @pick.pick_golfers.build(golfer_id: golfer_id, slot: slot)
      slot += 1
    end
    if @pick.save
      redirect_to pool_picks_path(@pool), notice: "Picks saved."
    else
      @golfers = Golfer.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    # @pick and @tournament are set in before_actions
    @golfers = Golfer.order(:name)
  end

  def update
    @pick.pick_golfers.destroy_all
    slot = 1
    (params[:golfer_ids] || []).first(5).each do |golfer_id|
      next if golfer_id.blank?
      @pick.pick_golfers.build(golfer_id: golfer_id, slot: slot)
      slot += 1
    end
    if @pick.save
      redirect_to pool_picks_path(@pool), notice: "Picks updated."
    else
      @tournament = @pick.tournament
      @golfers = Golfer.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_pool
    @pool = current_user.pools.find(params[:pool_id])
  end

  def set_tournament
    @tournament = @pool.tournaments.find(params[:tournament_id])
  end

  def set_pick
    @pick = picks_scope.find(params[:id])
    @tournament = @pick.tournament
  end

  def picks_scope
    Pick.where(user: current_user, tournament: @pool.tournaments)
  end

  def ensure_tournament_unlocked!
    return if @tournament.blank?

    refresh_tournament_from_api(@tournament)
    sync_tournament_field(@tournament)
    @tournament.reload

    if @tournament.starts_at.present? && @tournament.starts_at <= Time.current
      redirect_to pool_picks_path(@pool), alert: "Picks are locked because #{@tournament.name} has already started."
    end
  end

  def refresh_tournament_from_api(tournament)
    return if tournament.external_id.blank?

    season = (tournament.starts_at&.year || Date.current.year)
    BallDontLie::SyncTournaments.new(season: season).call
  rescue => e
    Rails.logger.error("Failed to refresh tournaments from API: #{e.class}: #{e.message}")
  end

  def sync_tournament_field(tournament)
    return if tournament.external_id.blank?

    BallDontLie::SyncTournamentField.new(tournament: tournament).call
  rescue => e
    Rails.logger.error("Failed to sync tournament field from API: #{e.class}: #{e.message}")
  end
end

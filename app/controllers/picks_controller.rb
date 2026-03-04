class PicksController < ApplicationController
  before_action :set_pool
  before_action :set_tournament, only: [ :new, :create ]
  before_action :set_pick, only: [ :edit, :update ]
  before_action :ensure_tournament_unlocked!, only: [ :new, :create, :edit, :update ]

  def index
    @standings = @pool.standings
    @tournaments = @pool.tournaments.order(:starts_at)
    @pool_tournaments_by_tournament = @pool.pool_tournaments.includes(:pool_tournament_odds).index_by(&:tournament_id)
    @picks_by_tournament = Pick
      .joins(:pool_tournament)
      .where(user: current_user, pool_tournaments: { pool_id: @pool.id, tournament_id: @tournaments.ids })
      .includes(pick_golfers: :golfer)
      .index_by(&:tournament_id)
  end

  def new
    @pick = Pick.find_or_initialize_by(user: current_user, pool_tournament: @pool_tournament)
    4.times { |i| @pick.pick_golfers.build(slot: i + 1) if @pick.pick_golfers.none? { |pg| pg.slot == i + 1 } }
    @golfers = @tournament.field_golfers.to_a
    @golfer_odds = current_odds_for_pick_form
    @golfers = @golfers.sort_by { |g| [ @golfer_odds[g.id].nil? ? 1 : 0, @golfer_odds[g.id] || Float::INFINITY, g.name.to_s ] }
  end

  def create
    @pick = Pick.find_or_initialize_by(user: current_user, pool_tournament: @pool_tournament)
    @pick.pick_golfers.destroy_all if @pick.persisted?
    slot = 1
    (params[:golfer_ids] || []).first(4).each do |golfer_id|
      next if golfer_id.blank?
      @pick.pick_golfers.build(golfer_id: golfer_id, slot: slot)
      slot += 1
    end
    if @pick.save
      redirect_to pool_picks_path(@pool), notice: "Picks saved."
    else
      @golfers = @tournament.field_golfers.to_a
      @golfer_odds = current_odds_for_pick_form
      @golfers = @golfers.sort_by { |g| [ @golfer_odds[g.id].nil? ? 1 : 0, @golfer_odds[g.id] || Float::INFINITY, g.name.to_s ] }
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    # @pick and @tournament are set in before_actions. Include field + already-picked so existing picks stay visible.
    field = @tournament.field_golfers.to_a
    picked = @pick.golfers.to_a
    @golfers = (field + picked).uniq
    @golfer_odds = current_odds_for_pick_form
    @golfers = @golfers.sort_by { |g| [ @golfer_odds[g.id].nil? ? 1 : 0, @golfer_odds[g.id] || Float::INFINITY, g.name.to_s ] }
  end

  def update
    @pick.pick_golfers.destroy_all
    slot = 1
    (params[:golfer_ids] || []).first(4).each do |golfer_id|
      next if golfer_id.blank?
      @pick.pick_golfers.build(golfer_id: golfer_id, slot: slot)
      slot += 1
    end
    if @pick.save
      redirect_to pool_picks_path(@pool), notice: "Picks updated."
    else
      @tournament = @pick.tournament
      field = @tournament.field_golfers.to_a
      picked = @pick.golfers.to_a
      @golfers = (field + picked).uniq
      @golfer_odds = current_odds_for_pick_form
      @golfers = @golfers.sort_by { |g| [ @golfer_odds[g.id].nil? ? 1 : 0, @golfer_odds[g.id] || Float::INFINITY, g.name.to_s ] }
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_pool
    @pool = current_user.pools.find_by!(token: params[:pool_token])
  end

  def set_tournament
    @tournament = @pool.tournaments.find(params[:tournament_id])
    @pool_tournament = @pool.pool_tournaments.find_by!(tournament: @tournament)
  end

  def set_pick
    @pick = picks_scope.find(params[:id])
    @tournament = @pick.tournament
  end

  def picks_scope
    Pick.joins(:pool_tournament).where(user: current_user, pool_tournaments: { pool_id: @pool.id })
  end

  def ensure_tournament_unlocked!
    return if @tournament.blank?

    # Avoid expensive sync work on every request. Only refresh basic data
    # when we don't yet know the start time, and only sync the field
    # when no golfers have been loaded or the last sync is older than 4 hours.
    refresh_tournament_from_api(@tournament) if @tournament.starts_at.blank?

    if should_sync_tournament_field?(@tournament)
      sync_tournament_field(@tournament)
      @tournament.reload
      Rails.cache.write(tournament_field_sync_cache_key(@tournament), Time.current, expires_in: 4.hours)
    end

    if @tournament.picks_locked?
      redirect_to pool_picks_path(@pool), alert: "Picks are locked because #{@tournament.name} has already started."
    end
  end

  def should_sync_tournament_field?(tournament)
    return true if tournament.field_golfers.none?

    last_synced_at = Rails.cache.read(tournament_field_sync_cache_key(tournament))
    last_synced_at.blank? || last_synced_at < 4.hours.ago
  end

  def tournament_field_sync_cache_key(tournament)
    "tournament:#{tournament.id}:field_synced_at"
  end

  def refresh_tournament_from_api(tournament)
    return if tournament.external_id.blank?

    season = (tournament.starts_at&.year || Date.current.year)
    BallDontLie::SyncTournaments.new(season: season).call
  rescue => e
    Rails.logger.error("Failed to refresh tournaments from API: #{e.class}: #{e.message}")
  end

  def sync_tournament_field(tournament)
    if tournament.external_id.blank?
      flash.now[:alert] = "This tournament has no external ID yet. Add it to a pool; tournaments are synced when you make picks."
      return
    end

    result = BallDontLie::SyncTournamentField.new(tournament: tournament).call
    if result[:total].to_i > 0
      flash.now[:notice] = "Synced #{result[:total]} players for this tournament."
    else
      flash.now[:alert] = field_not_available_message(tournament)
    end
  rescue => e
    Rails.logger.error("Failed to sync tournament field from API: #{e.class}: #{e.message}")
    flash.now[:alert] = "Could not load tournament field: #{e.message}. Try again later or use the Sync field button on the tournament page."
  end

  def field_not_available_message(tournament)
    msg = "This tournament's field is not yet available."
    if tournament.starts_at.present?
      msg += " Picks will open once the field is released (typically before #{tournament.starts_at.strftime('%B %-d')})."
    end
    msg += " You can try again later or use the Sync field button on the tournament page."
    msg
  end

  # Returns Hash[golfer_id => american_odds] for the current tournament, from the futures API.
  # Used to show odds in the pick form dropdown. Returns {} if API is unavailable.
  def current_odds_for_pick_form
    return {} if @tournament.blank? || @tournament.external_id.blank?

    client = BallDontLie::Client.new
    response = client.futures(tournament_ids: [ @tournament.external_id.to_i ], vendors: [ "draftkings" ], per_page: 100)
    data = response["data"] || []
    data.each_with_object({}) do |future, hash|
      next unless future["market_type"] == "tournament_winner"

      player = future["player"]
      next if player.blank?

      golfer = Golfer.find_by(external_id: player["id"].to_s)
      hash[golfer.id] = future["american_odds"] if golfer
    end
  rescue => e
    Rails.logger.error("Failed to fetch futures for pick form: #{e.class}: #{e.message}")
    {}
  end
end

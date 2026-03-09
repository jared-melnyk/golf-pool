class TournamentsController < ApplicationController
  def index
    @tournaments = Tournament.order(starts_at: :asc)
  end

  def show
    @tournament = Tournament.find(params[:id])
    auto_sync_field_and_results if @tournament.external_id.present?
    @results = sorted_tournament_results
  end

  private

  def auto_sync_field_and_results
    # Sync field if not already loaded
    if @tournament.tournament_fields.empty?
      sync_field
      @tournament.reload
    end

    # Sync results when tournament is not yet completed or has no results, unless we have
    # already synced after completion. We intentionally avoid using ends_at here and rely
    # on whether a champion / results exist.
    if !@tournament.completed? && !@tournament.results_synced_since_completion?
      sync_results
      @tournament.reload
    end
  end

  def sync_field
    result = BallDontLie::SyncTournamentField.new(tournament: @tournament).call
    if result[:total].to_i > 0
      flash.now[:notice] = "Synced #{result[:total]} players for this tournament."
    else
      flash.now[:alert] = field_not_available_message
    end
  rescue => e
    Rails.logger.error("Failed to sync tournament field: #{e.class}: #{e.message}")
    flash.now[:alert] = "Field and results are not available yet. #{e.message} Try again later."
  end

  def sync_results
    result = BallDontLie::SyncTournamentResults.new(tournament: @tournament).call
    if result[:total].to_i > 0
      flash.now[:notice] = (flash.now[:notice].presence ? flash.now[:notice] + " " : "") + "Synced #{result[:total]} results."
    else
      flash.now[:alert] = (flash.now[:alert].presence ? flash.now[:alert] + " " : "") + "Results are not available yet. Try again later."
    end
  rescue => e
    Rails.logger.error("Failed to sync tournament results: #{e.class}: #{e.message}")
    flash.now[:alert] = (flash.now[:alert].presence ? flash.now[:alert] + " " : "") + "Results could not be loaded: #{e.message}"
  end

  def field_not_available_message
    msg = "This tournament's field is not yet available."
    msg += " Picks will open once the field is released (typically before #{@tournament.starts_at.strftime('%B %-d')})." if @tournament.starts_at.present?
    msg += " Try again later or use the Sync field button on this page."
    msg
  end

  def sorted_tournament_results
    rel = @tournament.tournament_results.includes(:golfer)
    if @tournament.completed?
      rel.order(Arel.sql("prize_money DESC NULLS LAST"))
    else
      rel.order(position: :asc)
    end
  end
end

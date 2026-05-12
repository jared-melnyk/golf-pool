# frozen_string_literal: true

class SyncController < ApplicationController
  before_action :require_admin

  def field
    tournament = Tournament.find(params[:tournament_id])
    result = BallDontLie::SyncTournamentField.new(tournament: tournament).call
    redirect_to tournament_path(tournament), notice: "Synced #{result[:total]} players for this tournament."
  rescue => e
    redirect_to tournament_path(params[:tournament_id]), alert: "Sync failed: #{e.message}"
  end

  def tournament_results
    tournament = Tournament.find(params[:tournament_id])
    result = BallDontLie::SyncTournamentResults.new(tournament: tournament).call
    redirect_to tournament_path(tournament), notice: "Synced results: #{result[:created]} created, #{result[:updated]} updated (#{result[:total]} total)."
  rescue => e
    redirect_to tournament_path(params[:tournament_id]), alert: "Sync failed: #{e.message}"
  end
end

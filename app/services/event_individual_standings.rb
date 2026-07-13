# frozen_string_literal: true

# Event-wide individual net standings at 100% course handicap (independent of game format PH).
class EventIndividualStandings
  def initialize(event)
    @event = event
  end

  def call
    rounds = @event.rounds.order(played_on: :asc, created_at: :asc).select { |round| countable_round?(round) }
    members = @event.event_memberships.includes(:user).map(&:user).compact
    players = members.map { |user| build_player_row(user, rounds) }

    {
      rounds: rounds.map { |r| { id: r.id, name: r.name } },
      players: rank_players(players)
    }
  end

  private

  def countable_round?(round)
    games = round.games
    return true if games.none?

    games.where.not(game_type: "vegas").exists?
  end

  def build_player_row(user, rounds)
    round_vs_par = {}
    round_thru = {}
    total = 0
    thru_holes = 0
    scored = false

    rounds.each do |round|
      result = round_net_for(user, round)
      next if result.nil?

      scored = true
      round_vs_par[round.id] = result[:vs_par]
      round_thru[round.id] = result[:thru]
      total += result[:vs_par]
      thru_holes += result[:thru]
    end

    {
      user_id: user.id,
      name: user.name,
      total_vs_par: scored ? total : nil,
      thru_holes: scored ? thru_holes : 0,
      round_vs_par: round_vs_par,
      round_thru: round_thru
    }
  end

  def round_net_for(user, round)
    gtp = game_team_player_for(user, round)
    return nil if gtp.nil?

    scores = gtp.hole_scores.select { |hs| hs.gross_score.present? }
    return nil if scores.empty?

    calc = RoundNetCalculator.new(round)
    ch = calc.course_handicap_for(gtp.snapshot_handicap_index.to_f)
    ph = calc.playing_handicap_for(ch)

    vs_par = scores.sum do |hs|
      strokes = calc.strokes_on_hole(ph, hs.hole_number)
      net = calc.net_for_hole(hs.gross_score, strokes)
      net - round.hole_pars[hs.hole_number - 1]
    end

    { vs_par: vs_par, thru: scores.size }
  end

  def game_team_player_for(user, round)
    candidates = GameTeamPlayer
      .joins(game_team: :game)
      .where(user_id: user.id, games: { round_id: round.id, event_id: @event.id })
      .where.not(games: { game_type: "vegas" })
      .includes(:hole_scores)
      .to_a

    return nil if candidates.empty?
    return candidates.first if candidates.size == 1

    candidates.max_by { |gtp| gtp.hole_scores.count { |hs| hs.gross_score.present? } }
  end

  def rank_players(players)
    with_score = players.select { |p| !p[:total_vs_par].nil? }
    without = players.select { |p| p[:total_vs_par].nil? }
    sorted = with_score.sort_by { |p| [ p[:total_vs_par], p[:name] ] }

    ranked = []
    sorted.each_with_index do |player, idx|
      rank = if idx.positive? && sorted[idx - 1][:total_vs_par] == player[:total_vs_par]
        ranked[idx - 1][:rank]
      else
        idx + 1
      end
      ranked << player.merge(rank: rank)
    end

    ranked + without.map { |p| p.merge(rank: nil) }
  end

  # Thin wrapper so HandicapScoring can run at a fixed 100% allowance per round.
  class RoundNetCalculator
    include HandicapScoring

    def initialize(round)
      @round = round
      @allowance = 100
    end

    def course_handicap_for(hi)
      course_handicap(hi)
    end

    def playing_handicap_for(ch)
      playing_handicap(ch)
    end

    public :strokes_on_hole, :net_for_hole
  end
  private_constant :RoundNetCalculator
end

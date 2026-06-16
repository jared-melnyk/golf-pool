# frozen_string_literal: true

module Vegas
  VALID_TEAM_COUNT = 2
  VALID_PLAYERS_PER_TEAM = 2
  NET_CAP = 9

  module_function

  def cap_net(net)
    return nil if net.nil?

    net > NET_CAP ? NET_CAP : net
  end

  def team_number(net_a, net_b, flipped: false)
    lower, higher = [ net_a, net_b ].minmax
    flipped ? (higher * 10 + lower) : (lower * 10 + higher)
  end

  def birdie_or_better?(net, par)
    return false if net.nil? || par.nil?

    net <= par - 1
  end

  def hole_points(reference_number, opponent_number)
    return 0 if reference_number == opponent_number

    if reference_number < opponent_number
      opponent_number - reference_number
    else
      -(reference_number - opponent_number)
    end
  end

  def valid_game_roster?(teams)
    return false unless teams.size == VALID_TEAM_COUNT

    teams.all? { |team| team.size == VALID_PLAYERS_PER_TEAM }
  end
end

# frozen_string_literal: true

# In-memory team result for round/trip standings.
# See docs/plans/2026-07-12-team-scope-and-standings-design.md
TeamResult = Data.define(
  :game_id,
  :team_id,
  :team_name,
  :round_id,
  :event_id,
  :game_type,
  :scope,
  :metric_key,
  :metric_value,
  :complete
)

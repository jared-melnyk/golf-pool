# frozen_string_literal: true

# Shared WHS course/playing handicap and per-hole stroke allocation for on-course games.
module HandicapScoring
  # Club-style ceiling: PH 36 ⇒ at most 2 strokes on any hole.
  MAX_PLAYING_HANDICAP = 36
  MIN_NET_SCORE = 1

  private

  def net_for_hole(gross, strokes)
    return nil if gross.nil?

    [ gross - strokes, MIN_NET_SCORE ].max
  end

  def course_handicap(hi)
    slope = @round.slope_rating.to_f
    rating = @round.course_rating.to_f
    par = @round.par_total.to_f
    (hi * (slope / 113.0) + (rating - par)).round
  end

  def playing_handicap(ch)
    [ (ch * @allowance / 100.0).round, MAX_PLAYING_HANDICAP ].min
  end

  # PH strokes on stroke indices 1…PH; PH > 18 repeats SI order (capped via MAX_PLAYING_HANDICAP).
  def strokes_on_hole(playing_handicap, hole_number)
    return 0 if playing_handicap <= 0

    si = @round.hole_handicaps[hole_number - 1]
    base = playing_handicap / 18
    return base if si.nil?

    remainder = playing_handicap % 18
    base + (si <= remainder ? 1 : 0)
  end
end

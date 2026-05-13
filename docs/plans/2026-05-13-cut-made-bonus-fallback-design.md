# Cut Made Bonus Prize Pool Fallback - Design Specification

**Status:** Approved design, ready for implementation planning.
**Project:** `long_shot` (single Rails app, one deploy).
**Date:** 2026-05-13

---

## 1. Purpose

Some tournaments, especially majors such as the PGA Championship and U.S. Open, currently arrive from BallDontLie with no usable purse value. The API can return `purse: "$0"` before the official purse is announced. LongShot stores that as no effective cap, so the Cut Made Bonus (CMB) calculation falls back to the raw `20 * |american_odds|` amount. For very long odds this can display and score bonuses around `$10,000,000`, which is far beyond the intended cap.

This document captures the agreed design to enforce a hard CMB cap even when the API purse is missing or zero, while still preferring the real API purse as soon as it becomes available.

---

## 2. Problem Analysis

Current behavior is centered on `Tournament#max_cut_made_bonus` and `Tournament#capped_cut_made_bonus`:

1. `BallDontLie::SyncTournaments` parses the API `purse` field into `tournaments.total_prize_pool`.
2. `Tournament#max_cut_made_bonus` returns `10%` of `total_prize_pool`.
3. `Tournament#capped_cut_made_bonus` computes the raw CMB as `20 * |american_odds|`.
4. If `max_cut_made_bonus` is positive, the raw CMB is capped.
5. If `max_cut_made_bonus` is zero or nil, the method returns the raw CMB.

That last branch is the bug. Missing or zero purse data should not mean "uncapped"; it should mean "use the best available fallback cap."

Observed API behavior:

- 2026 PGA Championship: `purse: "$0"`
- 2026 U.S. Open: `purse: "$0"`
- 2025 PGA Championship: `purse: "$19,000,000"`
- 2025 U.S. Open: `purse: "$21,500,000"`

Local DB currently only has 2026 tournaments, so previous-year fallback data cannot be read from existing local rows unless we explicitly backfill or cache it.

---

## 3. Goals & Non-Goals

### Goals

- Always enforce a positive CMB cap.
- Prefer a real, positive API purse over any fallback.
- Treat API `nil`, blank, unparsable, or `$0` purse values as missing for cap purposes.
- Use the previous year's same tournament purse as the first fallback when available.
- Use a conservative global default purse when no previous-year match is available.
- Keep authoritative API purse data separate from fallback purse data.
- Show users when the displayed max CMB is estimated.
- Route all display and scoring through one model-level effective-prize-pool path.

### Non-Goals

- Changing the CMB formula itself: raw bonus remains `20 * |american_odds|`, cap remains `10%` of the effective prize pool.
- Changing made-cut eligibility, synthetic cut handling, no-cut event rules, or top-3-of-4 scoring.
- Adding fuzzy tournament-name matching in the initial implementation.
- Backfilling historical tournaments into the visible tournament list.

---

## 4. Strategy

### 4.1 Add a cached fallback prize pool

Add a nullable decimal column to `tournaments`:

```ruby
fallback_prize_pool :decimal, precision: 12, scale: 2
```

Semantics:

- `total_prize_pool` remains the authoritative purse from the API.
- `fallback_prize_pool` is the best available fallback, populated from the previous season's same-name tournament when the current API purse is missing or zero.
- The fallback value is not written into `total_prize_pool`.
- A future sync with a real positive API purse should require no migration or manual repair; the app will automatically prefer `total_prize_pool`.

The implementation should not clear a previously populated `fallback_prize_pool` just because a later sync cannot find prior-year data. Keeping the last known fallback is safer than returning to the global default after a transient API issue.

### 4.2 Add a single effective-prize-pool API on `Tournament`

Add a constant and helper methods on `Tournament`:

```ruby
DEFAULT_FALLBACK_PRIZE_POOL = BigDecimal("20000000")

def prize_pool_known?
  total_prize_pool.to_d.positive?
end

def effective_prize_pool
  return total_prize_pool.to_d if total_prize_pool.to_d.positive?
  return fallback_prize_pool.to_d if fallback_prize_pool.to_d.positive?

  DEFAULT_FALLBACK_PRIZE_POOL
end
```

Then update `max_cut_made_bonus` to use the effective prize pool:

```ruby
def max_cut_made_bonus
  effective_prize_pool * 0.10
end
```

`capped_cut_made_bonus` should always cap against `max_cut_made_bonus`:

```ruby
def capped_cut_made_bonus(american_odds)
  return 0.to_d if american_odds.nil?

  raw = american_odds.to_d.abs * 20
  [raw, max_cut_made_bonus].min
end
```

This removes the footgun where a missing cap means "return raw."

### 4.3 Populate fallback during tournament sync

`BallDontLie::SyncTournaments` should continue parsing and storing the current season purse as it does today. It should also populate `fallback_prize_pool` when the parsed current purse is not positive.

Flow for each API tournament row:

1. Parse `t["purse"]`.
2. Set `rec.total_prize_pool` from the parsed value, preserving today's authoritative API behavior.
3. If the parsed value is positive, do not need a fallback for effective-prize-pool purposes.
4. If the parsed value is nil or non-positive, look up the previous season's same-name tournament in the previous-season API response.
5. If the previous-season row has a positive purse, set `rec.fallback_prize_pool` to that value.
6. If no positive previous-year purse is found, leave any existing `rec.fallback_prize_pool` alone and allow `Tournament#effective_prize_pool` to use the global default when needed.

The previous-season API response should be memoized for the duration of `SyncTournaments#call`, so a sync run makes at most one extra paginated `fetch_all_tournaments(season: season - 1)` call regardless of how many current-year tournaments have missing purses.

Initial name matching should be exact and case-insensitive:

```ruby
previous_year_tournaments_by_name[t["name"].to_s.downcase]
```

This is sufficient for stable major names. Tournaments with changed title sponsors can fall back to the global default until a real API purse is available.

### 4.4 Estimated UI treatment

Views that disclose the max CMB at the tournament level should use `max_cut_made_bonus` and append `(estimated)` when `prize_pool_known?` is false.

Apply this treatment to:

- `app/views/picks/new.html.erb`
- `app/views/picks/edit.html.erb`
- `app/views/picks/_tournament_with_picks.html.erb`

Expected labels:

- Known API purse: `Max Cut Made Bonus: $1,900,000`
- Fallback purse: `Max Cut Made Bonus: $1,900,000 (estimated)`

Do not add `(estimated)` to every golfer option or every results-table CMB cell. The page-level disclosure is enough and avoids noisy repeated labels.

When the API later publishes a real positive purse, the next tournament sync updates `total_prize_pool`; `prize_pool_known?` becomes true; the label stops showing `(estimated)`; and all cap calculations automatically use the real purse.

---

## 5. Data Flow

### Current API purse is positive

1. Sync parses `purse: "$19,000,000"`.
2. `total_prize_pool = 19_000_000`.
3. `effective_prize_pool = 19_000_000`.
4. `max_cut_made_bonus = 1_900_000`.
5. UI displays `Max Cut Made Bonus: $1,900,000`.

### Current API purse is zero, previous-year purse exists

1. Sync parses `purse: "$0"`.
2. `total_prize_pool = 0`.
3. Previous-season lookup finds `"$19,000,000"`.
4. `fallback_prize_pool = 19_000_000`.
5. `effective_prize_pool = 19_000_000`.
6. `max_cut_made_bonus = 1_900_000`.
7. UI displays `Max Cut Made Bonus: $1,900,000 (estimated)`.

### Current API purse is zero, no previous-year match exists

1. Sync parses `purse: "$0"`.
2. `total_prize_pool = 0`.
3. Previous-season lookup finds no positive match.
4. `fallback_prize_pool` remains nil.
5. `effective_prize_pool = 20_000_000`.
6. `max_cut_made_bonus = 2_000_000`.
7. UI displays `Max Cut Made Bonus: $2,000,000 (estimated)`.

---

## 6. Testing Plan

### Model specs

Add coverage for `Tournament`:

- `prize_pool_known?` is true only when `total_prize_pool` is positive.
- `effective_prize_pool` prefers positive `total_prize_pool`.
- `effective_prize_pool` uses positive `fallback_prize_pool` when `total_prize_pool` is nil or zero.
- `effective_prize_pool` uses the global default when both values are missing or non-positive.
- `max_cut_made_bonus` uses `effective_prize_pool`.
- `capped_cut_made_bonus` caps long odds even when `total_prize_pool` is nil or zero.

### Sync service specs

Add coverage for `BallDontLie::SyncTournaments`:

- Stores a positive API purse in `total_prize_pool` and does not require fallback.
- Treats `$0` current-year purse as missing for fallback purposes.
- Fetches previous-season tournaments once per sync call when fallback data is needed.
- Stores previous-year same-name positive purse in `fallback_prize_pool`.
- Leaves existing `fallback_prize_pool` unchanged when no previous-year match is available.
- Still allows a later positive current-year API purse to win by storing it in `total_prize_pool`.

### View/helper specs

Add or update coverage for cap disclosure:

- Known purse renders without `(estimated)`.
- Fallback/default purse renders with `(estimated)`.
- Missing odds still render the existing dash behavior.

---

## 7. Rollout Notes

This change is safe to ship without manually backfilling old rows. Existing tournaments with nil or zero `total_prize_pool` immediately get the global default cap through `effective_prize_pool`. The next scheduled or manual `SyncTournaments` run can populate `fallback_prize_pool` from previous-season API data where available.

If desired, after deploy we can run a one-off tournament sync for the current season to populate fallback values for majors before users make picks.

---

## 8. Open Questions

None. The approved initial behavior is:

- Previous-year same-name fallback first.
- `$20,000,000` global default purse second.
- Keep fallback separate from `total_prize_pool`.
- Display `(estimated)` on page-level max CMB labels while fallback/default data is being used.

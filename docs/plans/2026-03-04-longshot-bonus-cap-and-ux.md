# Longshot Bonus Cap and Pick UX Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add an odds note for pick forms, sort the pick dropdown by odds (shortest first, no-odds alphabetically last), cap the long-shot bonus at 10% of the tournament prize pool with an asterisk for players at cap, update rules and show max longshot bonus wherever tournaments are displayed.

**Architecture:** Add optional `total_prize_pool` on Tournament for the advertised purse. It is set from the API when syncing tournaments (`BallDontLie::SyncTournaments`)—the tournaments endpoint returns a `purse` field (e.g. `"$20,000,000"`) which we parse and store. Pool scoring applies `min(raw_bonus, max_longshot_bonus)` per pick. Helper and views show asterisk when uncapped bonus would hit the max. Sort golfers in the pick form by odds then name.

**Tech Stack:** Rails (models, helpers, ERB views), existing BallDontLie client and Pool/Pick/Tournament models.

---

## Task 1: Add Tournament total_prize_pool and max_longshot_bonus

**Files:**
- Create: `db/migrate/YYYYMMDDHHMMSS_add_total_prize_pool_to_tournaments.rb`
- Modify: `app/models/tournament.rb`
- Test: `spec/models/tournament_spec.rb` (create if missing)

**Step 1: Generate migration**

```bash
cd /Users/jaredmelnyk/Code/long_shot && bin/rails generate migration AddTotalPrizePoolToTournaments total_prize_pool:decimal
```

**Step 2: Edit migration to allow null and set precision**

Open the generated migration and set the column to allow null and use a sensible precision (e.g. `precision: 12, scale: 2`). Example:

```ruby
class AddTotalPrizePoolToTournaments < ActiveRecord::Migration[8.1]
  def change
    add_column :tournaments, :total_prize_pool, :decimal, precision: 12, scale: 2
  end
end
```

(No `null: false` so existing tournaments are valid.)

**Step 3: Run migration**

```bash
bin/rails db:migrate
```

Expected: Migration runs without error.

**Step 4: Add Tournament#max_longshot_bonus**

In `app/models/tournament.rb` add:

```ruby
# Maximum longshot bonus per pick: 10% of tournament total prize pool (advertised purse).
# Prize pool is expected to be set from API or manually and is static; when nil, max bonus is 0.
def max_longshot_bonus
  (total_prize_pool.to_d || 0) * 0.10
end
```

No separate `prize_pool` method needed; use `total_prize_pool` directly where the full pool is needed (e.g. display). The migration adds the column, so `total_prize_pool` is an attribute automatically.

**Step 5: Add model specs for Tournament#max_longshot_bonus**

If `spec/models/tournament_spec.rb` exists, add a describe block; otherwise create the file.

Examples:
- When `total_prize_pool` is set to 10_000_000, `max_longshot_bonus` returns 1_000_000.
- When `total_prize_pool` is nil, `max_longshot_bonus` returns 0.

**Step 6: Run specs**

```bash
bundle exec rspec spec/models/tournament_spec.rb
```

Expected: All examples pass.

**Step 7: Commit**

```bash
git add db/migrate/*_add_total_prize_pool_to_tournaments.rb db/schema.rb app/models/tournament.rb spec/models/tournament_spec.rb
git commit -m "feat: add Tournament#total_prize_pool and #max_longshot_bonus"
```

**Step 8: Set total_prize_pool from API in SyncTournaments**

The BallDontLie PGA tournaments API returns a `purse` field per tournament (e.g. `"$20,000,000"`). In `app/services/ball_dont_lie/sync_tournaments.rb`, when building or updating the tournament record from each API item `t`, set:

```ruby
rec.total_prize_pool = parse_purse(t["purse"])
```

Add a private method `parse_purse(purse_str)` that returns a numeric value: strip `$` and `,` from the string and convert to decimal (e.g. `"$20,000,000"` → `20_000_000`). Return `nil` if the string is blank or unparseable so existing behavior is preserved when the API omits or misformats purse.

**Step 9: Add spec for SyncTournaments setting total_prize_pool**

In `spec/services/ball_dont_lie/sync_tournaments_spec.rb` (create if missing), add an example that stubs the client to return a tournament payload including `"purse" => "$8,400,000"`, runs `SyncTournaments.new(season: 2025, client: client).call`, and expects the created/updated Tournament to have `total_prize_pool == 8_400_000` (or `8400000` as BigDecimal). If the spec file does not exist, create it with a minimal describe block and this example.

**Step 10: Commit sync change**

```bash
git add app/services/ball_dont_lie/sync_tournaments.rb spec/services/ball_dont_lie/sync_tournaments_spec.rb
git commit -m "feat: set Tournament total_prize_pool from API purse when syncing tournaments"
```

---

## Task 2: Cap longshot bonus in Pool scoring and add Pool helper for capped bonus

**Files:**
- Modify: `app/models/pool.rb`
- Test: `spec/models/pool_spec.rb`

**Step 1: Add private method for capped bonus in Pool**

In `app/models/pool.rb`, the bonus is currently computed as `odds_bonus(odds_row.american_odds)`. We need to cap it by the tournament’s max_longshot_bonus.

- Add a method that takes `tournament` and `american_odds` and returns `[odds_bonus(american_odds), tournament.max_longshot_bonus].min` (or 0 when no odds / no made cut).
- In `total_points_for`, when computing `bonus`, use this capped value instead of raw `odds_bonus(odds_row.american_odds)`.

Example shape (adapt to existing style):

```ruby
def capped_odds_bonus(tournament, american_odds)
  return 0.to_d if american_odds.nil?
  raw = odds_bonus(american_odds)
  max_bonus = tournament.max_longshot_bonus
  max_bonus.positive? ? [raw, max_bonus].min : raw
end
```

Then in the loop where you have `bonus = (odds_row && result&.made_cut?) ? odds_bonus(odds_row.american_odds) : 0.to_d`, use `capped_odds_bonus(tournament, odds_row&.american_odds)` when `result&.made_cut?` and odds_row present, else 0.

**Step 2: Add specs for cap**

In `spec/models/pool_spec.rb`:
- Add an example where tournament has `total_prize_pool` set so that `max_longshot_bonus` is 100_000, and a pick has odds that would give raw bonus 200_000 (e.g. american_odds 10_000); expect total points to include only 100_000 bonus (capped), not 200_000.
- Add an example where raw bonus is below the cap; expect uncapped bonus to be used.

**Step 3: Run specs**

```bash
bundle exec rspec spec/models/pool_spec.rb
```

Expected: All pass.

**Step 4: Commit**

```bash
git add app/models/pool.rb spec/models/pool_spec.rb
git commit -m "feat: cap longshot bonus at 10% of tournament prize pool"
```

---

## Task 3: Helper for “at max bonus” and optional asterisk in golfer name

**Files:**
- Modify: `app/helpers/application_helper.rb`
- Test: `spec/helpers/application_helper_spec.rb` (create if missing)

**Step 1: Add logic for “would earn max bonus”**

In `app/helpers/application_helper.rb`:
- Add a method that, given `american_odds` and `max_bonus`, returns true when the uncapped bonus (20 * |american_odds|) is >= max_bonus (and max_bonus > 0). E.g. `def at_max_longshot_bonus?(american_odds, max_bonus)`.
- Update `golfer_name_with_odds(name, american_odds, max_bonus: nil)` to accept an optional `max_bonus`. When `max_bonus` is present and `at_max_longshot_bonus?(american_odds, max_bonus)` is true, append `*` **outside** the parenthesis (e.g. "Name (+425)*"). When odds are nil, no asterisk.

**Step 2: Add helper specs**

Examples: `at_max_longshot_bonus?(500, 10_000)` is true (10_000 >= 10_000); `at_max_longshot_bonus?(400, 10_000)` is false; `golfer_name_with_odds("Scottie", 500, max_bonus: 10_000)` includes "*"; without max_bonus, no asterisk.

**Step 3: Run helper specs**

```bash
bundle exec rspec spec/helpers/application_helper_spec.rb
```

Expected: All pass.

**Step 4: Commit**

```bash
git add app/helpers/application_helper.rb spec/helpers/application_helper_spec.rb
git commit -m "feat: helper for at-max longshot bonus and asterisk in golfer name"
```

---

## Task 4: Use asterisk in views (pool show and pick form)

**Files:**
- Modify: `app/views/picks/_tournament_pool_picks.html.erb`
- Modify: `app/views/picks/_tournament_with_picks.html.erb`
- Modify: `app/views/picks/new.html.erb`
- Modify: `app/views/picks/edit.html.erb`

**Step 1: Pass max_bonus into golfer_name_with_odds where players are listed**

- In `_tournament_pool_picks`: you have `pool_tournament` and `tournament`. Compute `max_bonus = tournament.max_longshot_bonus` once (e.g. at top of the table or per row). Call `golfer_name_with_odds(pg.golfer&.name, odds, max_bonus: max_bonus)`.
- In `_tournament_with_picks`: you have `tournament`. Use `tournament.max_longshot_bonus` and pass `max_bonus:` into `golfer_name_with_odds`.
- In `new.html.erb` and `edit.html.erb`: the dropdown option text is built from `golfer_name_with_odds(g.name, @golfer_odds[g.id])`. Add `max_bonus: @tournament.max_longshot_bonus` so that players at cap get the asterisk in the dropdown.

**Step 2: Manual check**

Open pool show (with locked picks and odds) and Make Picks page; confirm asterisk appears only for players whose uncapped bonus would equal or exceed the tournament’s max longshot bonus.

**Step 3: Commit**

```bash
git add app/views/picks/_tournament_pool_picks.html.erb app/views/picks/_tournament_with_picks.html.erb app/views/picks/new.html.erb app/views/picks/edit.html.erb
git commit -m "feat: show asterisk for players at max longshot bonus in picks and pool views"
```

---

## Task 5: Sort pick dropdown by odds (shortest first), then no-odds alphabetically

**Files:**
- Modify: `app/controllers/picks_controller.rb`
- Test: controller or request spec (optional; can verify manually)

**Step 1: Sort @golfers after setting @golfer_odds**

In `new`, `edit`, and in the create/update failure paths where you set `@golfers` and `@golfer_odds`, sort `@golfers` so that:
1. Players with odds come first, sorted by `american_odds` ascending (most negative = favorite first; then ascending positives).
2. Players with no odds (`@golfer_odds[g.id].nil?`) come last, sorted alphabetically by name.

Example: `@golfers = @golfers.sort_by { |g| [@golfer_odds[g.id].nil? ? 1 : 0, @golfer_odds[g.id] || Float::INFINITY, g.name.to_s] }`.

Apply this in:
- `def new` (after `@golfer_odds = current_odds_for_pick_form`)
- `def edit` (after `@golfer_odds = current_odds_for_pick_form`)
- In `create` when rendering `:new` (after setting `@golfer_odds`)
- In `update` when rendering `:edit` (after setting `@golfer_odds`)

**Step 2: Verify**

Load Make Picks and Edit Picks; confirm order is favorites first, then longer odds, then “No odds” group alphabetically.

**Step 3: Commit**

```bash
git add app/controllers/picks_controller.rb
git commit -m "feat: sort pick dropdown by odds (shortest first), no-odds alphabetically last"
```

---

## Task 6: Odds note on Make Picks and Edit Picks pages

**Files:**
- Modify: `app/views/picks/new.html.erb`
- Modify: `app/views/picks/edit.html.erb`

**Step 1: Add note below the title or above the form**

Add one short sentence: “Odds are shown when available from sportsbooks; some players (often long shots) may not have listed odds.” Place it in a `<p class="text-gray-600 text-sm mb-4">` or similar so it’s visible but secondary.

**Step 2: Commit**

```bash
git add app/views/picks/new.html.erb app/views/picks/edit.html.erb
git commit -m "docs: add note about missing odds for some players on pick forms"
```

---

## Task 7: Show max longshot bonus wherever tournaments are shown

**Files:**
- Modify: `app/views/picks/new.html.erb` (Make Picks page)
- Modify: `app/views/picks/edit.html.erb` (Edit Picks page)
- Modify: `app/views/picks/_tournament_with_picks.html.erb` (used on pool show and picks index)
- Optionally: `app/views/picks/index.html.erb` if you want it next to each tournament there too (same partial handles it if you put it in _tournament_with_picks)

**Step 1: Add “Max longshot bonus” line**

- **Make Picks** (`new.html.erb`): Below the title and odds note, show “Max longshot bonus: $X” when `@tournament.max_longshot_bonus.positive?`, using `number_with_delimiter(@tournament.max_longshot_bonus.to_i)`. When zero or nil, show “Max longshot bonus: TBD” or omit the line (your choice; recommend “TBD” for consistency).
- **Edit Picks** (`edit.html.erb`): Same as above using `@tournament.max_longshot_bonus`.
- **_tournament_with_picks**: Next to or below the tournament name/date, add a short line like “Max longshot bonus: $X” or “Max longshot bonus: TBD” so that on pool show and picks index each tournament shows its max bonus.

Use a small, muted style (e.g. `text-sm text-gray-500`) so it doesn’t dominate.

**Step 2: Commit**

```bash
git add app/views/picks/new.html.erb app/views/picks/edit.html.erb app/views/picks/_tournament_with_picks.html.erb
git commit -m "feat: display max longshot bonus (10% of prize pool) on pick forms and tournament list"
```

---

## Task 8: Update rules page for bonus cap and optional asterisk

**Files:**
- Modify: `app/views/landing/rules.html.erb`

**Step 1: Update “How to Win” section**

- In the paragraph that describes “prize money + odds bonus” and “20× the odds”, add a sentence: “The long-shot bonus is capped at 10% of the tournament’s total prize pool.”
- Optionally add: “Players whose odds would hit this cap are marked with an asterisk (*) where picks and results are shown.”

**Step 2: Commit**

```bash
git add app/views/landing/rules.html.erb
git commit -m "docs: rules page mentions longshot bonus cap and asterisk"
```

---

## Task 9: Optional — landing index copy

**Files:**
- Modify: `app/views/landing/index.html.erb`

**Step 1:** If the landing index has a similar “20× the odds” explanation, add one line there too: “The bonus is capped at 10% of the tournament prize pool.” Then commit.

---

## Execution summary

1. Task 1: Migration + Tournament#total_prize_pool and #max_longshot_bonus + set total_prize_pool from API in SyncTournaments.
2. Task 2: Pool cap and specs.
3. Task 3: Helper for at-max bonus and asterisk in name.
4. Task 4: Use asterisk in all pick/pool views.
5. Task 5: Sort dropdown by odds.
6. Task 6: Odds note on new/edit picks.
7. Task 7: Max longshot bonus on Make Picks, Edit Picks, and tournament partial.
8. Task 8: Rules page update.
9. Task 9: Optional landing index line.

Run the full test suite after Task 2 and again at the end: `bundle exec rspec`.

---

**Plan complete and saved to `docs/plans/2026-03-04-longshot-bonus-cap-and-ux.md`. Two execution options:**

**1. Subagent-Driven (this session)** – I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Parallel Session (separate)** – Open a new session with executing-plans, batch execution with checkpoints.

Which approach do you prefer?

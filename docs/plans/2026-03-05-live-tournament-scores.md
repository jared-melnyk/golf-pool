# Live Tournament Scores Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a live/results scores view per pool/tournament that shows each pool member’s golfers’ round-by-round scores using balldontlie PGA, and expose it from the pool show page once a tournament has started or completed. Pool standings remain prize-money/odds-based and only update after tournaments complete as they do today.

**Architecture:** Extend the existing `BallDontLie::Client` to fetch per-golfer round results. Add a nested pool–tournament show route and controller action that, on each request, pulls live/round scores from the API and renders them in a dedicated scoreboard view. Do not persist round scores yet; rely on just-in-time API calls. Keep pool standings logic unchanged (still based on `TournamentResult` and odds), but ensure results sync jobs/flows can be reused as needed when tournaments complete.

**Tech Stack:** Ruby on Rails (models: `Pool`, `PoolTournament`, `Tournament`, `Pick`, `Golfer`, `PoolTournamentOdds`, `TournamentResult`), ERB views with Tailwind-style utility classes, `BallDontLie::Client` HTTP service for balldontlie PGA.

---

I'm using the writing-plans skill to create the implementation plan.

## Scope and constraints

- **In scope**
  - New **pool–tournament show page** that shows **only golfer scores**, not live pool standings.
  - **Navigation** from `pools/show` to this new page via “Live scores” / “Results” links/buttons.
  - **API integration** to balldontlie PGA **player round results** (and any minimal helpers needed to interpret rounds and scores to par).
  - A **per-round, per-golfer table** for each pool member, plus a simple derived “tournament total to par and position” label like `-6 (T4)` for their picks.
- **Out of scope (for now)**
  - Changing how **pool standings** are calculated; they continue to be based on completed tournaments via `TournamentResult` + odds.
  - A **live pool leaderboard** (pool members ranked by in-progress scores). This can be added later on top of the same API integration.
  - Persisting round scores in the database or background-syncing them on a schedule.

## Data model assumptions to verify during implementation

- `Tournament` either already has, or will be given, a **balldontlie PGA tournament identifier** column (e.g. `pga_tournament_id` or generic `external_id`) that maps to `tournament_ids[]` in the PGA API.
- `Golfer` is already mapped to PGA players via some key (e.g. `external_id` or `pga_player_id`). If not, you’ll add it as part of wiring field sync to PGA players.
- `PoolTournament` remains the join object between a `Pool` and a `Tournament` and is the natural anchor for any pool–tournament specific views.

If any of these assumptions are wrong, adjust the specific column names in the tasks below accordingly, but keep the overall structure.

---

## Task 1: Ensure tournaments and golfers are mappable to PGA entities

**Files:**
- Modify (if needed): `app/models/tournament.rb`
- Modify (if needed): `db/schema.rb` via a migration under `db/migrate/*_add_pga_ids.rb`
- Modify (if needed): `app/models/golfer.rb`
- Modify (if needed): any existing PGA sync jobs/services (e.g. `SyncTournamentFieldJob`, tournaments sync job)

**Step 1: Inspect existing mappings**

- Run: `bin/rails console` and inspect `Tournament.columns` and `Golfer.columns` (or check schema) to see if there is already:
  - A PGA tournament id (e.g. `pga_tournament_id` or `external_tournament_id`).
  - A PGA player id for golfers (e.g. `pga_player_id` or `external_player_id`).
- Expected: Either:
  - These columns exist and are already filled in when syncing from PGA, **or**
  - They don’t exist yet and you’ll add them.

**Step 2: Add tournament mapping column if missing**

- Create a migration, e.g.:

```bash
bin/rails generate migration AddPgaTournamentIdToTournaments pga_tournament_id:integer
```

- In the migration, add an index and allow nulls for now:

```ruby
add_column :tournaments, :pga_tournament_id, :integer
add_index  :tournaments, :pga_tournament_id
```

- Run: `bin/rails db:migrate`

**Step 3: Add golfer mapping column if missing**

- Create a migration, e.g.:

```bash
bin/rails generate migration AddPgaPlayerIdToGolfers pga_player_id:integer
```

- In the migration:

```ruby
add_column :golfers, :pga_player_id, :integer
add_index  :golfers, :pga_player_id
```

- Run: `bin/rails db:migrate`

**Step 4: Wire existing sync flows to fill these IDs**

- Locate where tournaments and tournament fields are synced from balldontlie PGA (e.g. `SyncTournamentFieldJob`, any tournament sync job).
- Update those flows so that when you create/update `Tournament` and `Golfer` records, you:
  - Set `tournament.pga_tournament_id` from the PGA `id` field.
  - Set `golfer.pga_player_id` from the PGA player id used in tournament fields.

**Step 5: Quick verification**

- Run a one-off sync (or repeat existing scripts) against a known tournament.
- In console:

```ruby
Tournament.where.not(pga_tournament_id: nil).first
Golfer.where.not(pga_player_id: nil).first
```

- Expected: At least one tournament and some golfers have non-null PGA IDs.

---

## Task 2: Extend BallDontLie::Client for player round results

**Files:**
- Modify: `app/services/ball_dont_lie/client.rb`
- (Optionally) Add: `app/services/ball_dont_lie/player_round_results.rb` helper PORO

**Step 1: Add low-level `player_round_results` method**

- In `BallDontLie::Client`, add:

```ruby
def player_round_results(tournament_ids: nil, player_ids: nil, cursor: nil, per_page: 100)
  params = { cursor: cursor, per_page: per_page }
  params["tournament_ids[]"] = Array(tournament_ids) if tournament_ids.present?
  params["player_ids[]"]     = Array(player_ids)     if player_ids.present?
  get "player_round_results", **params
end
```

**Step 2: Add `fetch_all_player_round_results` helper**

- Still in `BallDontLie::Client`, add:

```ruby
def fetch_all_player_round_results(tournament_ids:, player_ids:)
  fetch_all("player_round_results", tournament_ids: tournament_ids, player_ids: player_ids) do |c|
    player_round_results(tournament_ids: tournament_ids, player_ids: player_ids, cursor: c, per_page: 100)
  end
end
```

**Step 3: Lightweight wrapper object (optional but recommended)**

- Create a small PORO to make the view layer easier, e.g. `app/services/ball_dont_lie/player_round_results_formatter.rb`, that:
  - Takes raw JSON from `fetch_all_player_round_results`.
  - Normalizes it into a structure like:

```ruby
{
  player_id => {
    rounds: {
      1 => { score: -3, par_relative: "-3" },
      2 => { score:  0, par_relative: "E" },
      # ...
    },
    total_to_par: -6,
    position: "T4"
  }
}
```

**Step 4: Quick manual test**

- Open `bin/rails console` and run code to fetch results for a single known tournament and some PGA player IDs.
- Confirm:
  - The HTTP call works (no 401/429 errors given your GOAT tier).
  - The formatter returns the expected hash shape with round scores and total/position fields populated.

---

## Task 3: Add pool–tournament show route and controller action

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/pool_tournaments_controller.rb` (or add a dedicated controller like `PoolTournamentScoresController`)

**Step 1: Add nested route for show**

- In `config/routes.rb`, inside the `resources :pools` block (or equivalent), add a nested route:

```ruby
resources :pools, param: :token do
  resources :pool_tournaments, only: [:create, :destroy, :show]
end
```

- Ensure the `param: :token` for pools matches your existing routing (currently `Pool#to_param` returns `token`).

**Step 2: Add `show` action to `PoolTournamentsController`**

- In `app/controllers/pool_tournaments_controller.rb`, add:

```ruby
def show
  @pool_tournament = PoolTournament.find(params[:id])
  @pool            = @pool_tournament.pool
  @tournament      = @pool_tournament.tournament

  # Basic auth: viewer must be in the pool
  unless @pool.users.include?(current_user)
    redirect_to @pool, alert: "You must be a member of this pool to view scores."
    return
  end

  # Picks and golfers for this pool/tournament
  @picks_by_user = Pick
    .includes(:golfers)
    .where(pool_tournament: @pool_tournament)
    .group_by(&:user)

  # PGA mapping
  pga_tournament_id = @tournament.pga_tournament_id
  player_ids        = @picks_by_user.values.flatten.flat_map { |pick| pick.golfers.map(&:pga_player_id) }.compact.uniq

  @round_results = {}
  @current_round = nil

  if pga_tournament_id.present? && player_ids.any?
    client   = BallDontLie::Client.new
    raw_data = client.fetch_all_player_round_results(tournament_ids: [pga_tournament_id], player_ids: player_ids)
    formatter = BallDontLie::PlayerRoundResultsFormatter.new(raw_data)
    @round_results = formatter.by_player_id
    @current_round = formatter.current_round_number
  end
end
```

- The exact formatter API (`by_player_id`, `current_round_number`) should be implemented in Task 2.

**Step 3: Basic controller tests**

- Add a controller spec or request spec to cover:
  - Non-member trying to hit `GET /pools/:pool_token/pool_tournaments/:id` is redirected.
  - Member can see the page and the controller assigns `@pool`, `@tournament`, and `@picks_by_user`.
  - When `pga_tournament_id` or `player_ids` are missing, the page still renders but without scores.

---

## Task 4: Wire “Live scores” / “Results” links from pool show

**Files:**
- Modify: `app/views/pools/show.html.erb`

**Step 1: Add link next to each tournament row**

- In the `Tournaments in this pool` section, you already have:

```erb
<% @pool.tournaments.order(:starts_at).each do |t| %>
  <% pt = @pool_tournaments.find { |p| p.tournament_id == t.id } %>
  ...
<% end %>
```

- Within that loop, add logic to render a scores link when a `PoolTournament` exists:

```erb
<% if pt %>
  <% if t.started? && !t.completed? %>
    <%= link_to "Live scores",
                pool_pool_tournament_path(@pool, pt),
                class: "inline-flex items-center rounded px-3 py-1 text-sm font-medium bg-blue-50 text-blue-700 hover:bg-blue-100" %>
  <% elsif t.completed? %>
    <%= link_to "Results",
                pool_pool_tournament_path(@pool, pt),
                class: "inline-flex items-center rounded px-3 py-1 text-sm font-medium bg-gray-50 text-gray-700 hover:bg-gray-100" %>
  <% end %>
<% end %>
```

**Step 2: Verify behavior for tournament states**

- Use console or fixtures to create:
  - A not-started tournament (`t.started? == false`).
  - A started-but-not-completed tournament.
  - A completed tournament.
- Visit `pools/:token` and verify:
  - No scores link for not-started tournaments.
  - “Live scores” link for in-progress tournaments.
  - “Results” link for completed tournaments.

---

## Task 5: Build the pool–tournament scores view

**Files:**
- Add: `app/views/pool_tournaments/show.html.erb`

**Step 1: Basic layout and header**

- Create `app/views/pool_tournaments/show.html.erb` with:
  - Pool name and link back to pool.
  - Tournament name, dates, and status (e.g. “In progress”, “Completed”, “Not started”).

Example structure:

```erb
<h1 class="text-2xl font-bold text-gray-900 mb-2"><%= @tournament.name %> — <%= @pool.name %></h1>
<p class="text-gray-600 mb-4">
  <%= @tournament.starts_at&.strftime("%B %d") %> – <%= @tournament.ends_at&.strftime("%B %d, %Y") %>
  <% if @tournament.completed? %>
    · <span class="font-medium text-emerald-700">Completed</span>
  <% elsif @tournament.started? %>
    · <span class="font-medium text-blue-700">In progress</span>
  <% else %>
    · <span class="font-medium text-gray-700">Not started</span>
  <% end %>
</p>

<%= link_to "Back to pool", @pool, class: "text-sm text-emerald-700 hover:text-emerald-800 underline mb-6 inline-block" %>
```

**Step 2: Determine round headers and live round styling**

- In the view, derive the list of rounds (1–4) and which is “live”:

```erb
<% rounds = (1..4).to_a %>
<% current_round = @current_round %>
```

- In your table header, for each round:

```erb
<th class="px-3 py-2 text-left text-xs font-semibold <%= current_round == r ? "text-blue-900" : "text-gray-600" %>">
  R<%= r %><%== current_round == r ? " (Live)" : "" %>
</th>
```

**Step 3: Table body: members and their golfers**

- Iterate over `@picks_by_user`:

```erb
<table class="min-w-full divide-y divide-gray-200 bg-white shadow-sm rounded-lg overflow-hidden">
  <thead class="bg-gray-50">
    <tr>
      <th class="px-3 py-2 text-left text-xs font-semibold text-gray-600">Member</th>
      <% rounds.each do |r| %>
        <th class="px-3 py-2 text-left text-xs font-semibold <%= current_round == r ? "text-blue-900" : "text-gray-600" %>">
          R<%= r %><%= current_round == r ? " (Live)" : "" %>
        </th>
      <% end %>
      <th class="px-3 py-2 text-right text-xs font-semibold text-gray-600">Total</th>
    </tr>
  </thead>
  <tbody class="divide-y divide-gray-100">
    <% @picks_by_user.each do |user, picks| %>
      <% pick = picks.first %>
      <tr class="align-top">
        <td class="px-3 py-3 text-sm font-medium text-gray-900 whitespace-nowrap">
          <%= user.name %>
        </td>
        <% rounds.each do |r| %>
          <% round_cell_classes = "px-3 py-3 text-sm" %>
          <% round_cell_classes << (current_round == r ? " bg-blue-50" : " text-gray-700") %>
          <td class="<%= round_cell_classes %>">
            <% pick.golfers.each do |golfer| %>
              <% player_result = @round_results[golfer.pga_player_id] %>
              <% round_data    = player_result&.dig(:rounds, r) %>
              <div class="flex items-baseline justify-between gap-2 text-xs mb-1">
                <span class="font-medium text-gray-900"><%= golfer.name %></span>
                <span class="text-gray-500">
                  (<%= PoolTournamentOdds.find_by(pool_tournament: @pool_tournament, golfer: golfer)&.american_odds || "—" %>)
                </span>
              </div>
              <div class="text-xs <%= current_round == r ? "text-blue-900 font-semibold" : "text-gray-600" %>">
                <%= round_data ? round_data[:par_relative] : "—" %>
              </div>
            <% end %>
          </td>
        <% end %>
        <%# Total column: sum of picks' tournament totals to par and position label %>
        <% total_to_par = pick.golfers.sum { |g| (@round_results[g.pga_player_id] || {})[:total_to_par].to_i } %>
        <% place_label  = nil # you can derive this later if desired %>
        <td class="px-3 py-3 text-sm text-right whitespace-nowrap">
          <span class="font-semibold text-gray-900">
            <%= total_to_par.positive? ? "+#{total_to_par}" : total_to_par.zero? ? "E" : total_to_par.to_s %>
          </span>
          <% if place_label.present? %>
            <span class="ml-1 text-xs text-gray-500">(<%= place_label %>)</span>
          <% end %>
        </td>
      </tr>
    <% end %>
  </tbody>
</table>
```

**Step 4: Handle loading and error states**

- In the controller, you can optionally set a flag if the API call fails and pass an error message into the view.
- In the view, show a top-of-page alert if there was an error:

```erb
<% if @round_results.blank? && @tournament.started? %>
  <p class="mb-4 text-sm text-yellow-800 bg-yellow-50 border border-yellow-200 rounded px-3 py-2">
    Live scores are temporarily unavailable. Try refreshing in a moment.
  </p>
<% end %>
```

---

## Task 6: Keep pool standings behavior unchanged

**Files:**
- Review: `app/models/pool.rb`
- Review: any jobs or rake tasks that sync `TournamentResult` from PGA

**Step 1: Confirm standings still use completed tournament results**

- Re-read `Pool#standings` and `Pool#total_points_for` to confirm they:
  - Depend on `TournamentResult` and `PoolTournamentOdds`.
  - Don’t attempt to use round-level live data.

**Step 2: Verify standings auto-update once tournaments complete**

- Find the job or script that populates `TournamentResult` from balldontlie PGA (or add one if missing).
- Confirm it runs after tournament completion and:
  - Fills `tournament_results` for that tournament’s golfers.
  - Sets `tournament.results_synced_at` appropriately.

**Step 3: Manual check**

- Create a test pool and tournament; fake a completed tournament by:
  - Setting `tournament.ends_at` in the past.
  - Creating several `TournamentResult` rows with `prize_money` for golfers in members’ picks.
- Visit pool show before and after creating `TournamentResult` rows and confirm:
  - Standings and dollar totals change as expected.

---

## Task 7: Testing and manual verification

**Files:**
- Add/modify: request/controller specs for `PoolTournamentsController#show`
- Add/modify: system tests around pool show and pool–tournament scores navigation

**Step 1: Automated tests**

- Add tests that:
  - Assert routing for `pool_pool_tournament_path(@pool, pt)` hits `PoolTournamentsController#show`.
  - Ensure unauthorized users cannot access the show page.
  - Ensure for a member:
    - The show page renders successfully.
    - The view includes each golfer’s name and shows the right number of rounds columns.
  - Mock `BallDontLie::Client` to:
    - Return a structured fake `player_round_results` response.
    - Confirm the view shows the correct round scores and marks the correct round as “Live”.

**Step 2: Manual QA**

- In development:
  - Configure a real PGA tournament and golfers with proper `pga_tournament_id` and `pga_player_id` values.
  - Create a pool, add that tournament, and create picks for multiple users.
  - Visit:
    - `pools/:token` to confirm the correct “Live scores” / “Results” links appear based on tournament state.
    - `pool_pool_tournament_path(@pool, pt)` to see the per-member, per-round live scores table.
  - During an actual live tournament (or with known historical tournaments still providing data), watch scores change by refreshing the page.

**Step 3: Documentation**

- Append a short “Live scores” section to an existing LongShot README or internal docs, describing:
  - How to configure `BALLDONTLIE_API_KEY` and GOAT tier.
  - The fact that live scoring is per-golfer and that pool standings remain based on completed tournaments only.

---

## Execution handoff

Plan complete and saved to `docs/plans/2026-03-05-live-tournament-scores.md`. Two execution options:

1. **Subagent-Driven (this session)** – Use a subagent to implement each task one by one with code review and tests between tasks.
2. **Parallel Session (separate)** – Open a new session focused on executing this plan using the `superpowers:executing-plans` skill.

Choose whichever matches how you prefer to work; the plan is structured so either approach can follow it step-by-step.


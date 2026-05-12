# Phase 3: Best Ball Game — End-to-End Implementation Plan

**Implementation status:** Done as of 2026-05-11. This file is the original build plan and remains useful for context; the unchecked `- [ ]` steps below were not mass-edited after shipping. The delivered slice lives in migrations `db/migrate/20260511185307_create_games.rb` through `20260511185310_create_hole_scores.rb`, models `Game` / `GameTeam` / `GameTeamPlayer` / `HoleScore`, `app/services/best_ball_scorecard.rb`, `GamesController` and `HoleScoresController`, `app/views/games/*`, the Games section on `app/views/events/show.html.erb`, nested routes under `events`, and specs under `spec/models/`, `spec/services/best_ball_scorecard_spec.rb`, and `spec/requests/games_spec.rb`.

> **For agentic workers:** This plan has already been implemented in the LongShot repo. Use it as a map of the code, not as pending work. If you extend best ball, add a new plan or tasks from here forward. Steps below use checkbox (`- [ ]`) syntax from the original tracking pass.

**Goal:** Build the thin end-to-end slice for a Best Ball game: create a game on a round, set up two teams, enter gross scores per player per hole, and see a net best-ball team leaderboard.

**Architecture:** Three new models (`Game`, `GameTeam`, `GameTeamPlayer`) hang off `Round`+`Event`. A `HoleScore` table stores each player's gross score per hole. A pure-Ruby `BestBallScorecard` service computes course handicap, playing handicap (85%), net scores per hole, team best-ball net totals, and ranked leaderboard. Views follow the existing Tailwind/ERB pattern.

**Tech Stack:** Rails 8.1, PostgreSQL (arrays + jsonb), Turbo/Hotwire, Tailwind CSS, RSpec/FactoryBot

---

## File Map

**New models:**
- `app/models/game.rb` — belongs to round + event; enum game_type; playing_handicap_allowance_percent
- `app/models/game_team.rb` — belongs to game; name
- `app/models/game_team_player.rb` — belongs to game_team + user; snapshotted handicap fields
- `app/models/hole_score.rb` — belongs to game_team_player; hole_number (1-18), gross_score (integer, nullable = not entered)

**New service:**
- `app/services/best_ball_scorecard.rb` — pure-Ruby; takes a game record; returns structured scorecard data (CH, PH, net scores per hole, team totals, leaderboard)

**New migrations:**
- `db/migrate/*_create_games.rb`
- `db/migrate/*_create_game_teams.rb`
- `db/migrate/*_create_game_team_players.rb`
- `db/migrate/*_create_hole_scores.rb`

**New controllers + views:**
- `app/controllers/games_controller.rb` — new, create, show (scorecard + leaderboard), edit_teams (GET), update_teams (PATCH)
- `app/views/games/new.html.erb` — form: game type selector (best_ball only for now), round selector
- `app/views/games/show.html.erb` — scorecard table + leaderboard
- `app/views/games/edit_teams.html.erb` — team builder UI

**Scorecard entry (inline on show):**
- `app/controllers/hole_scores_controller.rb` — upsert a single hole score (PATCH from scorecard)
- (No separate hole score views; inline form on `games/show`)

**Modified files:**
- `config/routes.rb` — add `resources :games` nested under events, and `resources :hole_scores` nested under games
- `app/views/events/show.html.erb` — add "Games" section listing rounds' games + "Create game" link
- `app/models/event.rb` — `has_many :games`
- `app/models/round.rb` — `has_many :games`
- `app/models/user.rb` — `has_many :game_team_players`, `has_many :hole_scores, through: :game_team_players`

**New specs:**
- `spec/models/game_spec.rb`
- `spec/models/game_team_player_spec.rb`
- `spec/models/hole_score_spec.rb`
- `spec/services/best_ball_scorecard_spec.rb`
- `spec/requests/games_spec.rb`

---

## Task 1: Migrations + bare models

**Files:**
- Create: `db/migrate/*_create_games.rb`
- Create: `db/migrate/*_create_game_teams.rb`
- Create: `db/migrate/*_create_game_team_players.rb`
- Create: `db/migrate/*_create_hole_scores.rb`
- Create: `app/models/game.rb`
- Create: `app/models/game_team.rb`
- Create: `app/models/game_team_player.rb`
- Create: `app/models/hole_score.rb`
- Modify: `app/models/event.rb`, `app/models/round.rb`, `app/models/user.rb`

- [ ] **Step 1: Generate migrations**

```bash
cd long_shot
bin/rails generate migration CreateGames event:references round:references game_type:string submitted:boolean
bin/rails generate migration CreateGameTeams game:references name:string
bin/rails generate migration CreateGameTeamPlayers game_team:references user:references
bin/rails generate migration CreateHoleScores game_team_player:references hole_number:integer gross_score:integer
```

- [ ] **Step 2: Edit the CreateGames migration to match the full schema**

Open the generated `db/migrate/*_create_games.rb` and replace its `change` body:

```ruby
def change
  create_table :games do |t|
    t.references :event, null: false, foreign_key: true
    t.references :round, null: false, foreign_key: true
    t.string :game_type, null: false, default: "best_ball"
    t.boolean :submitted, null: false, default: false
    t.timestamps
  end
end
```

- [ ] **Step 3: Edit the CreateGameTeams migration**

```ruby
def change
  create_table :game_teams do |t|
    t.references :game, null: false, foreign_key: true
    t.string :name, null: false
    t.timestamps
  end
end
```

- [ ] **Step 4: Edit the CreateGameTeamPlayers migration**

```ruby
def change
  create_table :game_team_players do |t|
    t.references :game_team, null: false, foreign_key: true
    t.references :user, null: false, foreign_key: true
    t.decimal :snapshot_handicap_index, precision: 5, scale: 1
    t.timestamps
  end
  add_index :game_team_players, [ :game_team_id, :user_id ], unique: true
end
```

- [ ] **Step 5: Edit the CreateHoleScores migration**

```ruby
def change
  create_table :hole_scores do |t|
    t.references :game_team_player, null: false, foreign_key: true
    t.integer :hole_number, null: false
    t.integer :gross_score
    t.timestamps
  end
  add_index :hole_scores, [ :game_team_player_id, :hole_number ], unique: true
end
```

- [ ] **Step 6: Run migrations**

```bash
bin/rails db:migrate
```

Expected output: 4 migration lines each prefixed `--  create_table`

- [ ] **Step 7: Write model specs first (failing)**

Create `spec/models/game_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Game, type: :model do
  let(:event) { Event.create!(name: "Test Event", status: "active") }
  let(:round) do
    Round.create!(
      event: event,
      name: "Morning round",
      played_on: Date.today,
      golf_course_api_course_id: 1,
      course_name: "Test Course",
      tee_name: "Blue",
      tee_gender: "male",
      course_rating: 72.1,
      slope_rating: 130,
      par_total: 72,
      hole_pars: Array.new(18, 4),
      hole_handicaps: (1..18).to_a
    )
  end

  it "is valid with event, round, and game_type" do
    game = Game.new(event: event, round: round, game_type: "best_ball")
    expect(game).to be_valid
  end

  it "is invalid without game_type" do
    game = Game.new(event: event, round: round, game_type: nil)
    expect(game).not_to be_valid
  end

  it "is invalid with unknown game_type" do
    game = Game.new(event: event, round: round, game_type: "scramble")
    expect(game).not_to be_valid
  end

  it "defaults submitted to false" do
    game = Game.new(event: event, round: round, game_type: "best_ball")
    expect(game.submitted).to eq(false)
  end
end
```

Create `spec/models/game_team_player_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe GameTeamPlayer, type: :model do
  let(:user) { User.create!(name: "Alice", email: "alice@example.com", password: "password123", ghin_handicap_index: 14.2) }
  let(:event) { Event.create!(name: "Test Event", status: "active") }
  let(:round) do
    Round.create!(
      event: event, name: "Round", played_on: Date.today,
      golf_course_api_course_id: 1, course_name: "Course", tee_name: "White",
      tee_gender: "male", course_rating: 70.5, slope_rating: 120, par_total: 72,
      hole_pars: Array.new(18, 4), hole_handicaps: (1..18).to_a
    )
  end
  let(:game) { Game.create!(event: event, round: round, game_type: "best_ball") }
  let(:team) { GameTeam.create!(game: game, name: "Team A") }

  it "snapshots the user handicap index on creation" do
    gtp = GameTeamPlayer.create!(game_team: team, user: user)
    expect(gtp.snapshot_handicap_index).to eq(14.2)
  end
end
```

Create `spec/models/hole_score_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe HoleScore, type: :model do
  let(:user) { User.create!(name: "Bob", email: "bob@example.com", password: "password123") }
  let(:event) { Event.create!(name: "E", status: "active") }
  let(:round) do
    Round.create!(
      event: event, name: "R", played_on: Date.today,
      golf_course_api_course_id: 1, course_name: "C", tee_name: "W",
      tee_gender: "male", course_rating: 70.0, slope_rating: 115, par_total: 72,
      hole_pars: Array.new(18, 4), hole_handicaps: (1..18).to_a
    )
  end
  let(:game) { Game.create!(event: event, round: round, game_type: "best_ball") }
  let(:team) { GameTeam.create!(game: game, name: "Team A") }
  let(:gtp) { GameTeamPlayer.create!(game_team: team, user: user) }

  it "is valid for hole 1-18 with a gross score" do
    hs = HoleScore.new(game_team_player: gtp, hole_number: 1, gross_score: 5)
    expect(hs).to be_valid
  end

  it "is invalid for hole 0" do
    hs = HoleScore.new(game_team_player: gtp, hole_number: 0, gross_score: 4)
    expect(hs).not_to be_valid
  end

  it "is invalid for hole 19" do
    hs = HoleScore.new(game_team_player: gtp, hole_number: 19, gross_score: 4)
    expect(hs).not_to be_valid
  end

  it "allows nil gross_score (not yet entered)" do
    hs = HoleScore.new(game_team_player: gtp, hole_number: 3, gross_score: nil)
    expect(hs).to be_valid
  end

  it "enforces uniqueness of hole_number per game_team_player" do
    HoleScore.create!(game_team_player: gtp, hole_number: 5, gross_score: 4)
    dup = HoleScore.new(game_team_player: gtp, hole_number: 5, gross_score: 3)
    expect(dup).not_to be_valid
  end
end
```

- [ ] **Step 8: Run model specs to confirm they fail**

```bash
bin/rspec spec/models/game_spec.rb spec/models/game_team_player_spec.rb spec/models/hole_score_spec.rb --format documentation
```

Expected: multiple failures — models don't exist yet.

- [ ] **Step 9: Write app/models/game.rb**

```ruby
class Game < ApplicationRecord
  GAME_TYPES = %w[best_ball].freeze

  belongs_to :event
  belongs_to :round
  has_many :game_teams, dependent: :destroy
  has_many :game_team_players, through: :game_teams

  validates :game_type, inclusion: { in: GAME_TYPES }

  def playing_handicap_allowance_percent
    case game_type
    when "best_ball" then 85
    else 100
    end
  end
end
```

- [ ] **Step 10: Write app/models/game_team.rb**

```ruby
class GameTeam < ApplicationRecord
  belongs_to :game
  has_many :game_team_players, dependent: :destroy
  has_many :users, through: :game_team_players

  validates :name, presence: true
end
```

- [ ] **Step 11: Write app/models/game_team_player.rb**

```ruby
class GameTeamPlayer < ApplicationRecord
  belongs_to :game_team
  belongs_to :user
  has_many :hole_scores, dependent: :destroy

  validates :user_id, uniqueness: { scope: :game_team_id }

  before_create :snapshot_handicap_index

  private

  def snapshot_handicap_index
    self.snapshot_handicap_index ||= user.ghin_handicap_index
  end
end
```

- [ ] **Step 12: Write app/models/hole_score.rb**

```ruby
class HoleScore < ApplicationRecord
  belongs_to :game_team_player

  validates :hole_number, inclusion: { in: 1..18 }
  validates :gross_score, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :hole_number, uniqueness: { scope: :game_team_player_id }
end
```

- [ ] **Step 13: Update association models**

In `app/models/event.rb` add: `has_many :games, dependent: :destroy`
In `app/models/round.rb` add: `has_many :games, dependent: :destroy`
In `app/models/user.rb` add: `has_many :game_team_players, dependent: :destroy`

- [ ] **Step 14: Run model specs — expect all passing**

```bash
bin/rspec spec/models/game_spec.rb spec/models/game_team_player_spec.rb spec/models/hole_score_spec.rb --format documentation
```

Expected: all green.

- [ ] **Step 15: Commit**

```bash
git add db/migrate app/models/game.rb app/models/game_team.rb app/models/game_team_player.rb app/models/hole_score.rb app/models/event.rb app/models/round.rb app/models/user.rb spec/models/game_spec.rb spec/models/game_team_player_spec.rb spec/models/hole_score_spec.rb
git commit -m "feat: add Game/GameTeam/GameTeamPlayer/HoleScore models with specs"
```

---

## Task 2: BestBallScorecard service

**Files:**
- Create: `app/services/best_ball_scorecard.rb`
- Create: `spec/services/best_ball_scorecard_spec.rb`

This service is pure Ruby — no DB writes. It takes a `Game` (with associations eager-loaded) and returns a structured hash consumed by the scorecard view and leaderboard.

- [ ] **Step 1: Write spec first**

Create `spec/services/best_ball_scorecard_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe BestBallScorecard do
  # Build a minimal game in-memory using persisted records
  let(:event) { Event.create!(name: "E", status: "active") }
  let(:round) do
    Round.create!(
      event: event, name: "R", played_on: Date.today,
      golf_course_api_course_id: 1, course_name: "C", tee_name: "W",
      tee_gender: "male", course_rating: 72.0, slope_rating: 113, par_total: 72,
      hole_pars:      [4,4,4,4,4,4,4,4,4, 4,4,4,4,4,4,4,4,4],
      hole_handicaps: [1,3,5,7,9,11,13,15,17, 2,4,6,8,10,12,14,16,18]
    )
  end
  let(:game) { Game.create!(event: event, round: round, game_type: "best_ball") }

  let(:alice) { User.create!(name: "Alice", email: "alice@test.com", password: "pw", ghin_handicap_index: 18.0) }
  let(:bob)   { User.create!(name: "Bob",   email: "bob@test.com",   password: "pw", ghin_handicap_index: 0.0) }

  let(:team_a) { GameTeam.create!(game: game, name: "Team A") }
  let(:gtp_alice) { GameTeamPlayer.create!(game_team: team_a, user: alice) }
  let(:gtp_bob)   { GameTeamPlayer.create!(game_team: team_a, user: bob) }

  before do
    # Enter gross scores: all 5s for Alice, all 4s for Bob
    (1..18).each do |h|
      HoleScore.create!(game_team_player: gtp_alice, hole_number: h, gross_score: 5)
      HoleScore.create!(game_team_player: gtp_bob,   hole_number: h, gross_score: 4)
    end
  end

  subject(:scorecard) { BestBallScorecard.new(game).call }

  # Alice: HI 18, slope 113, rating 72, par 72
  #   CH = 18 * (113/113) + (72 - 72) = 18
  #   PH = round(18 * 0.85) = round(15.3) = 15
  # Bob: HI 0 → CH 0, PH 0

  it "returns a hash with :teams key" do
    expect(scorecard).to have_key(:teams)
  end

  it "computes Alice's course handicap as 18" do
    alice_data = scorecard[:teams].first[:players].find { |p| p[:name] == "Alice" }
    expect(alice_data[:course_handicap]).to eq(18)
  end

  it "computes Alice's playing handicap as 15 (85% of 18, rounded)" do
    alice_data = scorecard[:teams].first[:players].find { |p| p[:name] == "Alice" }
    expect(alice_data[:playing_handicap]).to eq(15)
  end

  it "Bob's CH and PH are both 0" do
    bob_data = scorecard[:teams].first[:players].find { |p| p[:name] == "Bob" }
    expect(bob_data[:course_handicap]).to eq(0)
    expect(bob_data[:playing_handicap]).to eq(0)
  end

  it "computes net scores for Alice (gross - strokes received per hole)" do
    alice_data = scorecard[:teams].first[:players].find { |p| p[:name] == "Alice" }
    # PH=15: strokes on holes with stroke index 1-15 (first 15 by SI order: holes with SI 1..15)
    # hole 1 has SI 1 → stroke → net = 5-1=4; hole 2 SI 3 → stroke → net 5-1=4
    # hole with SI 16 → no stroke → net 5
    alice_net_h1 = alice_data[:hole_scores].find { |s| s[:hole_number] == 1 }[:net_score]
    expect(alice_net_h1).to eq(4)
  end

  it "computes team best-ball net per hole (min of players' net scores)" do
    team = scorecard[:teams].first
    # Hole 1: Alice net 4, Bob net 4 (no strokes) → best ball = 4
    hole1 = team[:hole_scores].find { |s| s[:hole_number] == 1 }
    expect(hole1[:best_ball_net]).to eq(4)
  end

  it "computes team total net strokes" do
    team = scorecard[:teams].first
    expect(team[:total_net_strokes]).to be_a(Integer)
  end

  it "includes leaderboard with ranked teams" do
    expect(scorecard[:leaderboard]).to be_an(Array)
    expect(scorecard[:leaderboard].first).to have_key(:rank)
    expect(scorecard[:leaderboard].first).to have_key(:team_name)
  end
end
```

- [ ] **Step 2: Run spec to confirm it fails**

```bash
bin/rspec spec/services/best_ball_scorecard_spec.rb --format documentation
```

Expected: `NameError: uninitialized constant BestBallScorecard`

- [ ] **Step 3: Write app/services/best_ball_scorecard.rb**

```ruby
# Computes a Best Ball scorecard for a given Game.
# Returns a structured hash:
#   {
#     teams: [
#       {
#         id: ..., name: ..., total_net_strokes: ...,
#         players: [ { name:, course_handicap:, playing_handicap:, hole_scores: [{ hole_number:, gross_score:, net_score:, strokes_received: }] } ],
#         hole_scores: [ { hole_number:, best_ball_net: } ]
#       }
#     ],
#     leaderboard: [ { rank:, team_name:, total_net_strokes: } ]
#   }
class BestBallScorecard
  def initialize(game)
    @game = game
    @round = game.round
    @allowance = game.playing_handicap_allowance_percent
  end

  def call
    teams_data = @game.game_teams.includes(game_team_players: [:user, :hole_scores]).map do |team|
      build_team(team)
    end

    { teams: teams_data, leaderboard: build_leaderboard(teams_data) }
  end

  private

  def build_team(team)
    players_data = team.game_team_players.map { |gtp| build_player(gtp) }

    hole_scores = (1..18).map do |h|
      nets = players_data.filter_map { |p| p[:hole_scores].find { |s| s[:hole_number] == h }&.dig(:net_score) }
      { hole_number: h, best_ball_net: nets.any? ? nets.min : nil }
    end

    total = hole_scores.sum { |s| s[:best_ball_net].to_i }

    { id: team.id, name: team.name, players: players_data, hole_scores: hole_scores, total_net_strokes: total }
  end

  def build_player(gtp)
    hi = gtp.snapshot_handicap_index.to_f
    ch = course_handicap(hi)
    ph = playing_handicap(ch)
    scores_by_hole = gtp.hole_scores.index_by(&:hole_number)

    hole_scores = (1..18).map do |h|
      strokes = strokes_on_hole(ph, h)
      gross = scores_by_hole[h]&.gross_score
      net = gross ? gross - strokes : nil
      { hole_number: h, gross_score: gross, net_score: net, strokes_received: strokes }
    end

    {
      name: gtp.user.name,
      course_handicap: ch,
      playing_handicap: ph,
      hole_scores: hole_scores
    }
  end

  # WHS formula: HI × (slope ÷ 113) + (course_rating − par)
  def course_handicap(hi)
    slope = @round.slope_rating.to_f
    rating = @round.course_rating.to_f
    par = @round.par_total.to_f
    (hi * (slope / 113.0) + (rating - par)).round
  end

  def playing_handicap(ch)
    (ch * @allowance / 100.0).round
  end

  # Returns number of strokes a player with playing_handicap receives on a given hole.
  # stroke_indices array is 0-indexed (hole 1 = index 0); values are 1–18 (1 = hardest).
  # A player with PH strokes gets a stroke on the PH hardest holes.
  def strokes_on_hole(playing_handicap, hole_number)
    return 0 if playing_handicap <= 0

    si = @round.hole_handicaps[hole_number - 1]
    base = playing_handicap / 18
    remainder = playing_handicap % 18
    base + (si <= remainder ? 1 : 0)
  end

  def build_leaderboard(teams_data)
    teams_with_totals = teams_data.map { |t| { team_name: t[:name], total_net_strokes: t[:total_net_strokes] } }
    sorted = teams_with_totals.sort_by { |t| t[:total_net_strokes] }

    # Competition/ordinal ranking: T1, T3, etc.
    ranked = []
    sorted.each_with_index do |team, idx|
      if idx > 0 && sorted[idx - 1][:total_net_strokes] == team[:total_net_strokes]
        ranked << team.merge(rank: ranked[idx - 1][:rank])
      else
        ranked << team.merge(rank: idx + 1)
      end
    end
    ranked
  end
end
```

- [ ] **Step 4: Run spec to confirm it passes**

```bash
bin/rspec spec/services/best_ball_scorecard_spec.rb --format documentation
```

Expected: all green.

- [ ] **Step 5: Commit**

```bash
git add app/services/best_ball_scorecard.rb spec/services/best_ball_scorecard_spec.rb
git commit -m "feat: BestBallScorecard service — CH/PH/net/team best-ball/leaderboard"
```

---

## Task 3: Routes and GamesController (new + create + show)

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/games_controller.rb`
- Create: `app/views/games/new.html.erb`
- Create: `app/views/games/show.html.erb`
- Create: `spec/requests/games_spec.rb`

- [ ] **Step 1: Add routes**

In `config/routes.rb`, inside the `resources :events` block, add after `resources :rounds`:

```ruby
resources :rounds, only: [ :new, :create ]
resources :games, only: [ :new, :create, :show ] do
  member do
    get  :edit_teams
    patch :update_teams
  end
  resources :hole_scores, only: [ :update ]
end
```

- [ ] **Step 2: Write request spec (failing)**

Create `spec/requests/games_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Games", type: :request do
  let(:commissioner) { User.create!(name: "Comm", email: "comm@test.com", password: "pw") }
  let(:event) { Event.create!(name: "Outing", status: "active") }
  let!(:membership) { EventMembership.create!(event: event, user: commissioner, role: "commissioner") }
  let(:round) do
    Round.create!(
      event: event, name: "Morning", played_on: Date.today,
      golf_course_api_course_id: 1, course_name: "GC", tee_name: "Blue",
      tee_gender: "male", course_rating: 72.0, slope_rating: 128, par_total: 72,
      hole_pars: Array.new(18, 4), hole_handicaps: (1..18).to_a
    )
  end

  before { post login_path, params: { email: commissioner.email, password: "pw" } }

  describe "GET /events/:event_token/games/new" do
    it "renders new game form for commissioners" do
      get new_event_game_path(event)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /events/:event_token/games" do
    it "creates a game and redirects to edit_teams" do
      expect {
        post event_games_path(event), params: { game: { round_id: round.id, game_type: "best_ball" } }
      }.to change(Game, :count).by(1)
      expect(response).to redirect_to(edit_teams_event_game_path(event, Game.last))
    end
  end

  describe "GET /events/:event_token/games/:id" do
    let(:game) { Game.create!(event: event, round: round, game_type: "best_ball") }

    it "renders the scorecard page" do
      get event_game_path(event, game)
      expect(response).to have_http_status(:ok)
    end
  end
end
```

- [ ] **Step 3: Run spec to confirm it fails**

```bash
bin/rspec spec/requests/games_spec.rb --format documentation
```

Expected: routing errors (controller doesn't exist).

- [ ] **Step 4: Write app/controllers/games_controller.rb**

```ruby
class GamesController < ApplicationController
  before_action :set_event
  before_action :require_event_member!
  before_action :require_commissioner!, only: [ :new, :create, :edit_teams, :update_teams ]
  before_action :set_game, only: [ :show, :edit_teams, :update_teams ]

  def new
    @game = @event.games.new
    @rounds = @event.rounds.order(:played_on)
  end

  def create
    @game = @event.games.new(game_params.merge(round_id: game_params[:round_id]))
    if @game.save
      redirect_to edit_teams_event_game_path(@event, @game), notice: "Game created. Now set up teams."
    else
      @rounds = @event.rounds.order(:played_on)
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @scorecard = BestBallScorecard.new(
      @game.reload.tap { |g|
        ActiveRecord::Associations::Preloader.new(
          records: [g],
          associations: { game_teams: { game_team_players: [ :user, :hole_scores ] } }
        ).call
      }
    ).call
  end

  def edit_teams
    @members = @event.users.order(:name)
    @game_teams = @game.game_teams.includes(game_team_players: :user)
  end

  def update_teams
    # teams_params: { "0" => { name: "Team A", user_ids: ["1","2"] }, "1" => ... }
    @game.game_teams.destroy_all
    teams_params.each_value do |team_data|
      next if team_data[:name].blank?

      team = @game.game_teams.create!(name: team_data[:name])
      Array(team_data[:user_ids]).compact_blank.each do |uid|
        user = @event.users.find_by(id: uid)
        GameTeamPlayer.create!(game_team: team, user: user) if user
      end
    end
    redirect_to event_game_path(@event, @game), notice: "Teams saved."
  rescue ActiveRecord::RecordInvalid => e
    @members = @event.users.order(:name)
    @game_teams = @game.game_teams.includes(game_team_players: :user)
    flash.now[:alert] = "Could not save teams: #{e.message}"
    render :edit_teams, status: :unprocessable_entity
  end

  private

  def set_event
    @event = Event.find_by!(token: params[:event_token])
  end

  def set_game
    @game = @event.games.find(params[:id])
  end

  def require_event_member!
    return if @event.member?(current_user)
    redirect_to event_path(@event), alert: "You must be a member of this event."
  end

  def require_commissioner!
    return if @event.commissioner?(current_user)
    redirect_to event_path(@event), alert: "Only commissioners can do that."
  end

  def game_params
    params.require(:game).permit(:round_id, :game_type)
  end

  def teams_params
    params.require(:teams).permit!.to_h
  end
end
```

- [ ] **Step 5: Create app/views/games/new.html.erb**

```erb
<div class="space-y-6">
  <div>
    <h1 class="text-2xl font-bold text-gray-900">Create game</h1>
    <p class="text-sm text-gray-600 mt-1">Choose the round and game type.</p>
  </div>

  <section class="border border-gray-200 rounded-lg p-4 bg-white shadow-sm">
    <%= form_with model: @game, url: event_games_path(@event), method: :post, local: true, class: "space-y-4" do |f| %>
      <% if @game.errors.any? %>
        <ul class="p-4 bg-red-50 border border-red-200 text-red-800 rounded-lg list-disc list-inside">
          <% @game.errors.full_messages.each do |msg| %><li><%= msg %></li><% end %>
        </ul>
      <% end %>

      <div>
        <%= f.label :round_id, "Round", class: "block text-sm font-medium text-gray-700 mb-1" %>
        <%= f.select :round_id,
              @rounds.map { |r| ["#{r.name} · #{r.played_on.strftime("%b %-d")} · #{r.course_name}", r.id] },
              { include_blank: "Select a round" },
              required: true,
              class: "w-full rounded border border-gray-300 px-3 py-2 focus:ring-2 focus:ring-emerald-500" %>
      </div>

      <div>
        <%= f.label :game_type, "Game type", class: "block text-sm font-medium text-gray-700 mb-1" %>
        <%= f.select :game_type,
              Game::GAME_TYPES.map { |t| [t.titleize.gsub("_", " "), t] },
              {},
              required: true,
              class: "w-full rounded border border-gray-300 px-3 py-2 focus:ring-2 focus:ring-emerald-500" %>
      </div>

      <div>
        <%= f.submit "Create game", class: "rounded px-4 py-2 text-sm font-medium bg-emerald-600 text-white hover:bg-emerald-700" %>
      </div>
    <% end %>
  </section>

  <%= link_to "← Back to event", event_path(@event), class: "text-sm text-emerald-700 hover:text-emerald-800 underline" %>
</div>
```

- [ ] **Step 6: Create app/views/games/show.html.erb (initial skeleton — full scorecard in Task 5)**

```erb
<div class="space-y-6">
  <div>
    <h1 class="text-2xl font-bold text-gray-900"><%= @game.round.name %> — <%= @game.game_type.titleize.gsub("_", " ") %></h1>
    <p class="text-sm text-gray-500 mt-1"><%= @game.round.course_name %> · <%= @game.round.played_on.strftime("%b %-d, %Y") %></p>
  </div>

  <% if @scorecard[:teams].empty? %>
    <div class="border border-gray-200 rounded-lg p-4 bg-white shadow-sm">
      <p class="text-gray-600">No teams set up yet.</p>
      <% if @event.commissioner?(current_user) %>
        <%= link_to "Set up teams →", edit_teams_event_game_path(@event, @game), class: "mt-2 inline-block text-emerald-700 hover:underline text-sm" %>
      <% end %>
    </div>
  <% else %>
    <%= render "scorecard", scorecard: @scorecard, game: @game, event: @event %>
  <% end %>

  <%= link_to "← Back to event", event_path(@event), class: "text-sm text-emerald-700 hover:text-emerald-800 underline" %>
</div>
```

Create a placeholder `app/views/games/_scorecard.html.erb`:

```erb
<%# Scorecard partial — filled in Task 5 %>
<p class="text-sm text-gray-400">Scorecard rendering coming in next task.</p>
```

- [ ] **Step 7: Run request spec**

```bash
bin/rspec spec/requests/games_spec.rb --format documentation
```

Expected: all green.

- [ ] **Step 8: Commit**

```bash
git add config/routes.rb app/controllers/games_controller.rb app/views/games/ spec/requests/games_spec.rb
git commit -m "feat: GamesController new/create/show/edit_teams/update_teams + routes"
```

---

## Task 4: Team Builder UI (edit_teams view)

**Files:**
- Create: `app/views/games/edit_teams.html.erb`

- [ ] **Step 1: Create app/views/games/edit_teams.html.erb**

```erb
<div class="space-y-6">
  <div>
    <h1 class="text-2xl font-bold text-gray-900">Set up teams</h1>
    <p class="text-sm text-gray-600 mt-1">
      <%= @game.round.name %> · <%= @game.game_type.gsub("_", " ").titleize %>
    </p>
  </div>

  <%= form_with url: update_teams_event_game_path(@event, @game), method: :patch, local: true, class: "space-y-6" do |f| %>
    <% if flash[:alert] %>
      <p class="p-3 bg-red-50 border border-red-200 text-red-800 rounded"><%= flash[:alert] %></p>
    <% end %>

    <% 2.times do |i| %>
      <% team = @game_teams[i] %>
      <section class="border border-gray-200 rounded-lg p-4 bg-white shadow-sm">
        <h2 class="text-base font-semibold text-gray-900 mb-3">Team <%= i + 1 %></h2>

        <div class="mb-3">
          <label class="block text-sm font-medium text-gray-700 mb-1">Team name</label>
          <input
            type="text"
            name="teams[<%= i %>][name]"
            value="<%= team&.name %>"
            placeholder="e.g. Team A"
            class="w-full rounded border border-gray-300 px-3 py-2 focus:ring-2 focus:ring-emerald-500"
          />
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Players (select 1–4)</label>
          <% current_ids = team&.game_team_players&.map(&:user_id) || [] %>
          <% @members.each do |user| %>
            <label class="flex items-center gap-2 mb-1 text-sm">
              <input
                type="checkbox"
                name="teams[<%= i %>][user_ids][]"
                value="<%= user.id %>"
                <%= "checked" if current_ids.include?(user.id) %>
                class="rounded border-gray-300 text-emerald-600 focus:ring-emerald-500"
              />
              <%= user.name %>
              <% if user.ghin_handicap_index.present? %>
                <span class="text-gray-400 text-xs">(HI <%= user.ghin_handicap_index %>)</span>
              <% end %>
            </label>
          <% end %>
        </div>
      </section>
    <% end %>

    <div>
      <%= f.submit "Save teams", class: "rounded px-4 py-2 text-sm font-medium bg-emerald-600 text-white hover:bg-emerald-700" %>
      <%= link_to "Cancel", event_game_path(@event, @game), class: "ml-3 text-sm text-gray-600 hover:text-gray-800 underline" %>
    </div>
  <% end %>

  <%= link_to "← Back to event", event_path(@event), class: "text-sm text-emerald-700 hover:text-emerald-800 underline" %>
</div>
```

**Note on team count:** This hard-codes 2 teams for v1 (typical best-ball). `@game_teams` may have 0, 1, or 2 records; the form handles nil gracefully. A future task can make team count configurable.

- [ ] **Step 2: Manual smoke test (or run existing specs)**

```bash
bin/rspec spec/requests/games_spec.rb --format documentation
```

Expected: still all green.

- [ ] **Step 3: Commit**

```bash
git add app/views/games/edit_teams.html.erb
git commit -m "feat: team builder UI for edit_teams"
```

---

## Task 5: Scorecard view + HoleScoresController (inline score entry)

**Files:**
- Modify: `app/views/games/_scorecard.html.erb`
- Modify: `app/views/games/show.html.erb`
- Create: `app/controllers/hole_scores_controller.rb`

- [ ] **Step 1: Write HoleScoresController**

Create `app/controllers/hole_scores_controller.rb`:

```ruby
class HoleScoresController < ApplicationController
  before_action :set_event
  before_action :set_game
  before_action :require_event_member!
  before_action :require_score_entry_permitted!

  def update
    gtp = GameTeamPlayer.joins(:game_team).where(game_teams: { game_id: @game.id }).find(params[:id])
    score = gtp.hole_scores.find_or_initialize_by(hole_number: params[:hole_number].to_i)
    gross = params[:gross_score].to_s.strip

    if gross.blank?
      score.destroy if score.persisted?
    else
      score.gross_score = gross.to_i
      score.save!
    end

    redirect_to event_game_path(@event, @game), notice: "Score saved."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to event_game_path(@event, @game), alert: "Invalid score: #{e.message}"
  end

  private

  def set_event
    @event = Event.find_by!(token: params[:event_token])
  end

  def set_game
    @game = @event.games.find(params[:game_id])
  end

  def require_event_member!
    return if @event.member?(current_user)
    redirect_to event_path(@event), alert: "You must be a member of this event."
  end

  def require_score_entry_permitted!
    return if @event.commissioner?(current_user)
    return if @game.game_teams.joins(:game_team_players).where(game_team_players: { user_id: current_user.id }).exists?
    redirect_to event_game_path(@event, @game), alert: "You are not a participant in this game."
  end
end
```

- [ ] **Step 2: Replace _scorecard.html.erb with full scorecard table**

```erb
<%# Renders teams side-by-side scorecard table with inline score entry %>
<% can_edit = !game.submitted && (event.commissioner?(current_user) ||
    game.game_teams.joins(:game_team_players).where(game_team_players: { user_id: current_user.id }).exists?) %>

<% scorecard[:teams].each do |team| %>
  <section class="border border-gray-200 rounded-lg p-4 bg-white shadow-sm overflow-x-auto">
    <h2 class="text-base font-semibold text-gray-900 mb-1"><%= team[:name] %></h2>
    <p class="text-xs text-gray-500 mb-3">
      <%= team[:players].map { |p| "#{p[:name]} (CH #{p[:course_handicap]} · PH #{p[:playing_handicap]})" }.join(" · ") %>
    </p>

    <table class="w-full text-sm">
      <thead>
        <tr class="text-left text-xs font-medium text-gray-500 border-b border-gray-200">
          <th class="pb-2 pr-3">Hole</th>
          <th class="pb-2 pr-3">Par</th>
          <% team[:players].each do |player| %>
            <th class="pb-2 pr-3"><%= player[:name] %></th>
            <th class="pb-2 pr-3 text-gray-400">Net</th>
          <% end %>
          <th class="pb-2 font-semibold text-emerald-700">Best Ball</th>
        </tr>
      </thead>
      <tbody>
        <% (1..18).each do |h| %>
          <% par = game.round.hole_pars[h - 1] %>
          <% team_hole = team[:hole_scores].find { |s| s[:hole_number] == h } %>
          <tr class="border-b border-gray-100 hover:bg-gray-50">
            <td class="py-1 pr-3 font-medium text-gray-700"><%= h %></td>
            <td class="py-1 pr-3 text-gray-500"><%= par %></td>
            <% team[:players].each do |player| %>
              <% player_hole = player[:hole_scores].find { |s| s[:hole_number] == h } %>
              <% gtp = GameTeamPlayer.joins(:game_team, :user)
                          .where(game_teams: { game_id: game.id })
                          .where(users: { name: player[:name] }).first %>
              <td class="py-1 pr-3">
                <% if can_edit %>
                  <%= form_with url: event_game_hole_score_path(event, game, gtp),
                        method: :patch, local: true, class: "inline" do |f| %>
                    <%= hidden_field_tag :hole_number, h %>
                    <%= number_field_tag :gross_score,
                          player_hole[:gross_score],
                          min: 1, max: 15, size: 3,
                          class: "w-12 rounded border border-gray-300 px-1 py-0.5 text-center focus:ring-1 focus:ring-emerald-500",
                          onchange: "this.form.submit()" %>
                  <% end %>
                <% else %>
                  <%= player_hole[:gross_score] || "—" %>
                <% end %>
                <% if player_hole[:strokes_received] > 0 %>
                  <span class="text-xs text-emerald-600 ml-0.5">·</span>
                <% end %>
              </td>
              <td class="py-1 pr-3 text-gray-500"><%= player_hole[:net_score] || "—" %></td>
            <% end %>
            <td class="py-1 font-semibold text-emerald-700">
              <%= team_hole[:best_ball_net] || "—" %>
            </td>
          </tr>
        <% end %>
        <tr class="border-t-2 border-gray-300 font-semibold">
          <td class="pt-2 pr-3">Total</td>
          <td class="pt-2 pr-3 text-gray-500"><%= game.round.par_total %></td>
          <% team[:players].each do %>
            <td class="pt-2 pr-3"></td>
            <td class="pt-2 pr-3"></td>
          <% end %>
          <td class="pt-2 text-emerald-700"><%= team[:total_net_strokes] %></td>
        </tr>
      </tbody>
    </table>
  </section>
<% end %>

<%# Leaderboard %>
<section class="border border-gray-200 rounded-lg p-4 bg-white shadow-sm">
  <h2 class="text-base font-semibold text-gray-900 mb-3">Leaderboard</h2>
  <table class="w-full text-sm">
    <thead>
      <tr class="text-left text-xs font-medium text-gray-500 border-b border-gray-200">
        <th class="pb-2 pr-4">Pos</th>
        <th class="pb-2 pr-4">Team</th>
        <th class="pb-2">Net Strokes</th>
      </tr>
    </thead>
    <tbody>
      <% scorecard[:leaderboard].each do |row| %>
        <tr class="border-b border-gray-100">
          <td class="py-1 pr-4 font-medium">
            T<%= row[:rank] %>
          </td>
          <td class="py-1 pr-4"><%= row[:team_name] %></td>
          <td class="py-1"><%= row[:total_net_strokes] %></td>
        </tr>
      <% end %>
    </tbody>
  </table>
</section>
```

- [ ] **Step 3: Run full spec suite to check for regressions**

```bash
bin/rspec --format documentation 2>&1 | tail -30
```

Expected: all existing specs green plus new ones.

- [ ] **Step 4: Commit**

```bash
git add app/controllers/hole_scores_controller.rb app/views/games/_scorecard.html.erb app/views/games/show.html.erb
git commit -m "feat: scorecard view with inline hole score entry and leaderboard"
```

---

## Task 6: Wire games into Event show page

**Files:**
- Modify: `app/views/events/show.html.erb`

- [ ] **Step 1: Add games section to event show**

In `app/views/events/show.html.erb`, add a new `<section>` after the Rounds section (before the back link):

```erb
<section class="mb-6 border border-gray-200 rounded-lg p-4 bg-white shadow-sm">
  <div class="flex flex-wrap items-center justify-between gap-2 mb-2">
    <h2 class="text-lg font-semibold text-gray-900">Games</h2>
    <% if @event.commissioner?(current_user) && @rounds.any? %>
      <%= link_to "Create game", new_event_game_path(@event),
            class: "rounded px-3 py-1.5 text-sm font-medium bg-emerald-600 text-white hover:bg-emerald-700 no-underline" %>
    <% end %>
  </div>

  <% games = @event.games.includes(:round).order(created_at: :desc) %>
  <% if games.any? %>
    <ol class="list-decimal list-inside space-y-2">
      <% games.each do |game| %>
        <li class="text-gray-800">
          <%= link_to game.round.name, event_game_path(@event, game),
                class: "font-medium text-emerald-700 hover:underline" %>
          <span class="text-sm text-gray-500">
            · <%= game.game_type.gsub("_", " ").titleize %>
            · <%= game.round.played_on.strftime("%b %-d, %Y") %>
            <% if game.submitted? %>
              <span class="ml-1 text-xs text-gray-400">(submitted)</span>
            <% end %>
          </span>
        </li>
      <% end %>
    </ol>
  <% else %>
    <p class="text-gray-600 text-sm">
      No games yet.
      <% if @event.commissioner?(current_user) && @rounds.any? %>
        <%= link_to "Create the first game →", new_event_game_path(@event), class: "text-emerald-700 hover:underline" %>
      <% end %>
    </p>
  <% end %>
</section>
```

- [ ] **Step 2: Run full suite**

```bash
bin/rspec --format progress
```

Expected: all green.

- [ ] **Step 3: Commit**

```bash
git add app/views/events/show.html.erb
git commit -m "feat: add Games section to event show page"
```

---

## Task 7: Final smoke check and cleanup

- [ ] **Step 1: Boot the server and manually walk through the full flow**

```bash
bin/dev
```

Walk through:
1. Create or open an event, add players.
2. Create a round (GolfCourseAPI search → select course + tee → save).
3. Create a game (Best Ball → select round).
4. Set up 2 teams, assign players.
5. Enter gross scores on the scorecard table.
6. Verify CH/PH display and net scores update.
7. Verify leaderboard ranks update.

- [ ] **Step 2: Run the full test suite one final time**

```bash
bin/rspec --format progress
```

Expected: all green.

- [ ] **Step 3: Final commit**

```bash
git add -A
git commit -m "chore: end-to-end best ball game slice complete"
```

---

## Self-Review Against Design Spec

| Spec section | Covered in plan? |
|---|---|
| §3 Domain model: Event/Round/Game/GameTeam/GameTeamPlayer/HoleScores | ✅ Task 1 |
| §5 Score entry permissions (in-game players + commissioners) | ✅ HoleScoresController `require_score_entry_permitted!` |
| §5.2 No per-hole lock during play | ✅ No such lock implemented |
| §5.3/5.4 Submit/lock (v1 stub) | ✅ `submitted` boolean on Game; check in scorecard can_edit; full submit UI is next iteration |
| §6 One shared scorecard per game | ✅ All teams rendered on single show page |
| §7.1–7.3 CH formula, PH 85%, round | ✅ BestBallScorecard service Tasks 2 |
| §7.4 Stroke allocation by SI | ✅ `strokes_on_hole` in service |
| §7.5 `playing_handicap_allowance_percent` on Game | ✅ `game.playing_handicap_allowance_percent` method |
| §8 Leaderboard T1/T3 competition ranking | ✅ `build_leaderboard` in service |
| §9 Course snapshot used for CH/PH | ✅ Service reads from `round` record |
| §10 18-hole only, male tees only | ✅ Inherited from rounds layer |

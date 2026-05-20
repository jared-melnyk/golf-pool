# Ad Hoc Games & Game-First On-Course — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make games the primary On-Course object with ad hoc creation (no event required), a saveable setup wizard, game token invites, host/cohost roles, and complete/reopen score locking — while preserving event-based trip games.

**Architecture:** Extend `Game` with `token`, `name`, `status`, optional `event_id`, and new `GameMembership`. Extract GolfCourseAPI round snapshot logic into a shared concern. Move game routes to top-level `/games/:token`; add `GameSetupsController` for the wizard. Centralize authorization in `GameAuthorizable`. Replace `submitted` boolean with `status` enum.

**Tech Stack:** Rails 8.1, PostgreSQL, Turbo/Hotwire, Tailwind CSS, RSpec.

**Design reference:** [2026-05-18-ad-hoc-games-design.md](2026-05-18-ad-hoc-games-design.md)

---

## File map

**Create:**
- `db/migrate/TIMESTAMP_add_game_first_fields.rb` — columns, nullable FKs, drop `submitted`
- `db/migrate/TIMESTAMP_create_game_memberships.rb`
- `app/models/game_membership.rb`
- `app/controllers/concerns/game_authorizable.rb` — shared auth helpers
- `app/controllers/concerns/round_snapshot_buildable.rb` — extract from `RoundsController`
- `app/controllers/game_setups_controller.rb` — wizard steps
- `app/controllers/game_memberships_controller.rb` — promote cohost, leave
- `app/views/games/index.html.erb` — On-Course home
- `app/views/games/new.html.erb` — name-only create form
- `app/views/games/show_join.html.erb` — non-member join CTA (mirror events)
- `app/views/game_setups/show.html.erb` — multi-step setup (course, format, invite)
- `spec/models/game_membership_spec.rb`
- `spec/requests/game_setups_spec.rb`
- `spec/requests/game_memberships_spec.rb`
- `spec/requests/games_index_spec.rb`

**Modify:**
- `app/models/game.rb` — status, token, optional event, memberships, auth helpers
- `app/models/round.rb` — optional event
- `app/models/user.rb` — `has_many :game_memberships`
- `app/controllers/games_controller.rb` — index, show, teams, complete, reopen; token routes
- `app/controllers/hole_scores_controller.rb` — game-token routes, `completed?` lock
- `app/controllers/rounds_controller.rb` — use `RoundSnapshotBuildable`
- `app/helpers/games/scorecard_helper.rb` — `game.completed?` instead of `submitted`
- `config/routes.rb`
- `app/views/layouts/application.html.erb` — nav: Games + Plan a trip
- `app/views/games/show.html.erb`, `edit_teams.html.erb` — host UX, complete/reopen
- `app/views/events/show.html.erb` — link games by token; “New game under event”
- `spec/models/game_spec.rb`, `spec/requests/games_spec.rb`, `spec/requests/hole_scores_spec.rb`
- `docs/plans/2026-05-06-on-course-games-design.md` — amendment pointer

**Remove / redirect:**
- Nested `resources :games` under events (keep `new`/`create` only for event-scoped wizard entry)
- All path helpers in views/specs: `event_game_path` → `game_path`

---

## Conventions

- **Game URL param:** `params[:token]` via `param: :token` and `Game#to_param`.
- **Status strings:** `draft`, `active`, `completed` — constant `Game::STATUSES`.
- **Roles:** `GameMembership::ROLES = %w[host cohost player]`.
- **RSpec:** mirror `spec/requests/games_spec.rb` login + factory-less `User.create!` style.
- **Run tests:** `cd long_shot && bundle exec rspec spec/path/to/spec.rb`
- **Commit after each task** (user rule: only when asked; plan marks commit steps for implementer).

---

## Task 1: Migrations — game-first schema

**Files:**
- Create: `db/migrate/TIMESTAMP_add_game_first_fields.rb`
- Create: `db/migrate/TIMESTAMP_create_game_memberships.rb`

- [ ] **Step 1: Write migration for game columns and nullable FKs**

```ruby
# db/migrate/TIMESTAMP_add_game_first_fields.rb
class AddGameFirstFields < ActiveRecord::Migration[8.1]
  def up
    add_column :games, :token, :string
    add_column :games, :creator_id, :bigint
    add_column :games, :name, :string
    add_column :games, :status, :string, null: false, default: "draft"

    add_index :games, :token, unique: true
    add_index :games, :creator_id
    add_foreign_key :games, :users, column: :creator_id

    # Backfill before NOT NULL
    execute <<~SQL.squish
      UPDATE games SET token = encode(gen_random_bytes(12), 'base64')
      WHERE token IS NULL
    SQL
    # URL-safe: do in Ruby if preferred — see Step 2 model backfill in seeds/task

    change_column_null :games, :token, false

    # Backfill name from round + game_type
    execute <<~SQL.squish
      UPDATE games g
      SET name = CONCAT(
        INITCAP(REPLACE(g.game_type, '_', ' ')), ' · ',
        r.course_name, ' · ',
        TO_CHAR(r.played_on, 'Mon DD')
      )
      FROM rounds r
      WHERE g.round_id = r.id AND g.name IS NULL
    SQL
    change_column_null :games, :name, false

    # Backfill status from submitted
    execute <<~SQL.squish
      UPDATE games SET status = CASE WHEN submitted = TRUE THEN 'completed' ELSE 'active' END
    SQL

    # Backfill creator_id from first event commissioner
    execute <<~SQL.squish
      UPDATE games g
      SET creator_id = (
        SELECT em.user_id FROM event_memberships em
        WHERE em.event_id = g.event_id AND em.role = 'commissioner'
        ORDER BY em.created_at ASC LIMIT 1
      )
    SQL

    change_column_null :games, :creator_id, false

    change_column_null :games, :event_id, true
    change_column_null :games, :round_id, true
    change_column_null :rounds, :event_id, true

    remove_column :games, :submitted
  end

  def down
    add_column :games, :submitted, :boolean, null: false, default: false
    execute "UPDATE games SET submitted = TRUE WHERE status = 'completed'"

    change_column_null :games, :event_id, false
    change_column_null :games, :round_id, false
    change_column_null :rounds, :event_id, false

    remove_foreign_key :games, column: :creator_id
    remove_index :games, :token
    remove_column :games, :token
    remove_column :games, :creator_id
    remove_column :games, :name
    remove_column :games, :status
  end
end
```

**Note:** Replace `gen_random_bytes` backfill with a Ruby `reversible` block using `SecureRandom.urlsafe_base64(16)` if PostgreSQL extension unavailable in dev. Safer pattern:

```ruby
Game.reset_column_information
Game.where(token: nil).find_each do |game|
  game.update_columns(token: SecureRandom.urlsafe_base64(16))
end
```

Run this in migration via `say_with_time` + model reference (acceptable in Rails migrations for data backfill).

- [ ] **Step 2: Write game_memberships migration**

```ruby
# db/migrate/TIMESTAMP_create_game_memberships.rb
class CreateGameMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :game_memberships do |t|
      t.references :game, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :role, null: false
      t.timestamps
    end
    add_index :game_memberships, [ :game_id, :user_id ], unique: true
  end
end
```

- [ ] **Step 3: Run migrations**

Run: `cd long_shot && bin/rails db:migrate`
Expected: schema updated; existing games have token, name, status, creator_id.

- [ ] **Step 4: Commit**

```bash
git add db/migrate db/schema.rb
git commit -m "feat: add game-first schema (token, status, memberships)"
```

---

## Task 2: GameMembership model

**Files:**
- Create: `app/models/game_membership.rb`
- Create: `spec/models/game_membership_spec.rb`
- Modify: `app/models/user.rb`

- [ ] **Step 1: Write failing spec**

```ruby
# spec/models/game_membership_spec.rb
require "rails_helper"

RSpec.describe GameMembership, type: :model do
  let(:host) { User.create!(name: "H", email: "h@test.com", password: "pw") }
  let(:game) do
    Game.create!(
      name: "Test", creator: host, status: "draft",
      token: "tok123", game_type: nil, round: nil, event: nil
    )
  end

  it "is valid with host role" do
    gm = described_class.new(game: game, user: host, role: "host")
    expect(gm).to be_valid
  end

  it "rejects unknown role" do
    gm = described_class.new(game: game, user: host, role: "admin")
    expect(gm).not_to be_valid
  end

  it "enforces unique user per game" do
    described_class.create!(game: game, user: host, role: "host")
    dup = described_class.new(game: game, user: host, role: "player")
    expect(dup).not_to be_valid
  end
end
```

- [ ] **Step 2: Run spec — expect FAIL**

Run: `bundle exec rspec spec/models/game_membership_spec.rb`
Expected: FAIL — uninitialized constant

- [ ] **Step 3: Implement model**

```ruby
# app/models/game_membership.rb
class GameMembership < ApplicationRecord
  ROLES = %w[host cohost player].freeze

  belongs_to :game
  belongs_to :user

  validates :role, presence: true, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :game_id }

  def host?
    role == "host"
  end

  def cohost?
    role == "cohost"
  end

  def manager?
    host? || cohost?
  end
end
```

Add to `app/models/user.rb`:

```ruby
has_many :game_memberships, dependent: :destroy
has_many :member_games, through: :game_memberships, source: :game
```

- [ ] **Step 4: Run spec — expect PASS**

- [ ] **Step 5: Commit**

---

## Task 3: Game model — status, token, validations

**Files:**
- Modify: `app/models/game.rb`
- Modify: `spec/models/game_spec.rb`

- [ ] **Step 1: Write failing specs for new behavior**

Add to `spec/models/game_spec.rb`:

```ruby
describe "status" do
  it "defaults to draft" do
    game = Game.new(name: "G", creator: User.create!(name: "U", email: "u@t.com", password: "pw"))
    expect(game.status).to eq("draft")
  end

  it "requires round and game_type to transition to active" do
    host = User.create!(name: "H", email: "h2@test.com", password: "pw")
    game = Game.create!(name: "G", creator: host, token: "abc", status: "draft")
    expect(game).to be_valid
    game.status = "active"
    expect(game).not_to be_valid
    expect(game.errors[:base]).to include("Round is required to activate game")
  end
end

describe "#completed?" do
  it "is true when status is completed" do
    game = build_game(status: "completed")
    expect(game.completed?).to be true
  end
end

describe "#suggested_name" do
  it "builds name from round and game_type" do
    game = build_game(game_type: "forty_score", round: round)
    expect(game.suggested_name).to include("Forty Score")
    expect(game.suggested_name).to include(round.course_name)
  end
end
```

Add helper `build_game` in spec file using existing `event`/`round` lets or ad hoc variant.

- [ ] **Step 2: Run spec — expect FAIL**

- [ ] **Step 3: Update Game model**

```ruby
# app/models/game.rb
class Game < ApplicationRecord
  GAME_TYPES = %w[best_ball forty_score].freeze
  STATUSES = %w[draft active completed].freeze

  belongs_to :event, optional: true
  belongs_to :round, optional: true
  belongs_to :creator, class_name: "User"
  has_many :game_memberships, dependent: :destroy
  has_many :members, through: :game_memberships, source: :user
  has_many :game_teams, dependent: :destroy

  before_validation :generate_token, on: :create

  validates :name, presence: true
  validates :token, presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }
  validates :game_type, inclusion: { in: GAME_TYPES }, allow_nil: true
  validate :active_requires_round_and_game_type
  validate :round_event_matches_game_event

  def to_param
    token
  end

  def completed?
    status == "completed"
  end

  def draft?
    status == "draft"
  end

  def active?
    status == "active"
  end

  def ad_hoc?
    event_id.nil?
  end

  def suggested_name
    return nil unless round && game_type.present?
    "#{game_type.gsub('_', ' ').titleize} · #{round.course_name} · #{round.played_on.strftime('%-b %-d')}"
  end

  def host?(user)
    user.present? && game_memberships.exists?(user_id: user.id, role: "host")
  end

  def cohost?(user)
    user.present? && game_memberships.exists?(user_id: user.id, role: "cohost")
  end

  def manager?(user)
    host?(user) || cohost?(user)
  end

  def member?(user)
    return false if user.blank?
    return true if game_memberships.exists?(user_id: user.id)
    return event.member?(user) if event.present?
    game_teams.joins(:game_team_players).exists?(game_team_players: { user_id: user.id })
  end

  def can_manage?(user)
    return event.commissioner?(user) if event.present?
    manager?(user)
  end

  def roster_users
    ad_hoc? ? members.order(:name) : event.users.order(:name)
  end

  def self.visible_to(user)
    from_memberships = GameMembership.where(user_id: user.id).select(:game_id)
    from_events = where(event_id: EventMembership.where(user_id: user.id).select(:event_id)).select(:id)
    from_teams = joins(game_teams: :game_team_players).where(game_team_players: { user_id: user.id }).select(:id)

    where(id: from_memberships).or(where(id: from_events)).or(where(id: from_teams)).distinct
  end

  # ... existing forty_score?, playing_handicap_allowance_percent ...

  private

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(16)
  end

  def active_requires_round_and_game_type
    return unless status == "active" || status == "completed"
    errors.add(:base, "Round is required to activate game") if round.blank?
    errors.add(:base, "Game type is required to activate game") if game_type.blank?
  end

  def round_event_matches_game_event
    return if round.blank? || event_id.blank?
    errors.add(:round, "must belong to the same event") if round.event_id != event_id
  end
end
```

- [ ] **Step 4: Fix existing game_spec examples** — add `name`, `creator`, `token`; replace `submitted` with `status`.

- [ ] **Step 5: Run specs — expect PASS**

Run: `bundle exec rspec spec/models/game_spec.rb`

- [ ] **Step 6: Commit**

---

## Task 4: Round model — optional event

**Files:**
- Modify: `app/models/round.rb`
- Modify: `spec/models/round_spec.rb`

- [ ] **Step 1: Update association**

```ruby
belongs_to :event, optional: true
```

- [ ] **Step 2: Add spec for ad hoc round without event**

```ruby
it "is valid without an event" do
  round = Round.new(
    event: nil, name: "Morning", played_on: Date.today,
    golf_course_api_course_id: 1, course_name: "Test", tee_name: "Blue",
    tee_gender: "male", course_rating: 72.0, slope_rating: 130, par_total: 72,
    hole_pars: Array.new(18, 4), hole_handicaps: (1..18).to_a
  )
  expect(round).to be_valid
end
```

- [ ] **Step 3: Run spec and commit**

---

## Task 5: Extract RoundSnapshotBuildable concern

**Files:**
- Create: `app/controllers/concerns/round_snapshot_buildable.rb`
- Modify: `app/controllers/rounds_controller.rb`

- [ ] **Step 1: Create concern** — move private methods from `RoundsController`: `golf_course_client`, `build_snapshot`, `tee_options_for`, `normalize_course_payload`, `male_tees_for`, `default_round_name_for`, `golf_course_api_key_configured?`.

```ruby
# app/controllers/concerns/round_snapshot_buildable.rb
module RoundSnapshotBuildable
  extend ActiveSupport::Concern

  private

  def golf_course_api_key_configured?
    ENV["GOLF_COURSE_API_KEY"].to_s.strip.present?
  end

  def golf_course_client
    @golf_course_client ||= GolfCourseApi::Client.new
  end

  def tee_options_for(course_payload)
    # copy from RoundsController unchanged
  end

  def build_snapshot(course_id:, tee_selector:)
    # copy from RoundsController unchanged
  end

  # ... remaining helpers ...
end
```

- [ ] **Step 2: Include in RoundsController** — `include RoundSnapshotBuildable`; delete duplicated private methods.

- [ ] **Step 3: Smoke test rounds**

Run: `bundle exec rspec spec/requests/rounds_spec.rb`
Expected: PASS (no behavior change).

- [ ] **Step 4: Commit**

---

## Task 6: Routes

**Files:**
- Modify: `config/routes.rb`

- [ ] **Step 1: Replace nested game routes with top-level**

```ruby
resources :games, param: :token do
  post :join, on: :member
  resource :setup, only: [ :show, :update ], controller: "game_setups"
  member do
    get :edit_teams
    patch :update_teams
    patch :complete
    patch :reopen
  end
  resources :game_memberships, only: [ :destroy, :update ]
  resources :hole_scores, only: [ :update ]
end

resources :events, param: :token do
  post :join, on: :member
  resources :event_memberships, only: [ :destroy, :update ]
  resources :rounds, only: [ :new, :create ]
  resources :games, only: [ :new, :create ]  # event-scoped wizard entry only
end
```

- [ ] **Step 2: Add legacy redirects** (append to `routes.rb`):

```ruby
# Legacy bookmarks: /events/:event_token/games/:id → /games/:token
get "/events/:event_token/games/:id",
    to: redirect { |params, _|
      game = Game.find(params[:id])
      "/games/#{game.token}"
    },
    constraints: { id: /\d+/ }

get "/events/:event_token/games/:id/edit_teams",
    to: redirect { |params, _|
      game = Game.find(params[:id])
      "/games/#{game.token}/edit_teams"
    },
    constraints: { id: /\d+/ }
```

- [ ] **Step 3: Verify routes**

Run: `bin/rails routes | grep games`
Expected: `games`, `game_setup`, `join_game`, `complete_game`, etc.

- [ ] **Step 4: Commit**

---

## Task 7: GameAuthorizable concern + refactor GamesController skeleton

**Files:**
- Create: `app/controllers/concerns/game_authorizable.rb`
- Modify: `app/controllers/games_controller.rb`

- [ ] **Step 1: Create concern**

```ruby
# app/controllers/concerns/game_authorizable.rb
module GameAuthorizable
  extend ActiveSupport::Concern

  private

  def set_game
    @game = Game.find_by!(token: params[:token] || params[:game_token])
  end

  def require_game_access!
    return if @game.member?(current_user)
    render "games/show_join", status: :ok
  end

  def require_game_manager!
    return if @game.can_manage?(current_user)
    redirect_to game_path(@game), alert: "Only hosts can do that."
  end

  def require_game_not_completed!
    return unless @game.completed?
    redirect_to game_path(@game), alert: "This game is completed. Edit scores to make changes."
  end
end
```

- [ ] **Step 2: Rewrite GamesController** — replace `set_event` / `event_token` with `GameAuthorizable`. Update `edit_teams` to use `@game.roster_users`. Update paths to `game_path`, `edit_teams_game_path`.

Key `update_teams` change:

```ruby
Array(team_data[:user_ids]).compact_blank.each do |uid|
  user = @game.roster_users.find_by(id: uid)
  GameTeamPlayer.create!(game_team: team, user: user) if user
end
```

- [ ] **Step 3: Commit** (specs fixed in Task 12)

---

## Task 8: GamesController — index, new, create, complete, reopen

**Files:**
- Modify: `app/controllers/games_controller.rb`
- Create: `app/views/games/index.html.erb`
- Create: `app/views/games/new.html.erb`
- Create: `spec/requests/games_index_spec.rb`

- [ ] **Step 1: Write failing index spec**

```ruby
# spec/requests/games_index_spec.rb
require "rails_helper"

RSpec.describe "Games index", type: :request do
  let(:user) { User.create!(name: "U", email: "u@test.com", password: "pw") }

  before { post login_path, params: { email: user.email, password: "pw" } }

  it "lists ad hoc games the user hosts" do
    game = Game.create!(name: "My Game", creator: user, status: "draft")
    GameMembership.create!(game: game, user: user, role: "host")
    get games_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("My Game")
  end
end
```

- [ ] **Step 2: Implement index, new, create**

```ruby
def index
  @games = Game.visible_to(current_user)
               .includes(:round, :event)
               .left_joins(:round)
               .order(Arel.sql("rounds.played_on DESC NULLS LAST"), created_at: :desc)
end

def new
  @game = Game.new
end

def create
  @game = Game.new(name: game_params[:name], creator: current_user, status: "draft")
  if @game.save
    @game.game_memberships.create!(user: current_user, role: "host")
    redirect_to game_setup_path(@game), notice: "Game created. Continue setup when ready."
  else
    render :new, status: :unprocessable_entity
  end
end

def complete
  require_game_manager!
  @game.update!(status: "completed")
  redirect_to game_path(@game), notice: "Game completed. Scores are locked."
end

def reopen
  require_game_manager!
  @game.update!(status: "active")
  redirect_to game_path(@game), notice: "Scores are editable again."
end
```

- [ ] **Step 3: Build index view**

```erb
<%# app/views/games/index.html.erb %>
<h1 class="text-2xl font-bold text-gray-900 mb-4">On-Course games</h1>
<p class="mb-4 flex flex-wrap gap-3">
  <%= link_to "New game", new_game_path, class: "..." %>
  <%= link_to "Plan a trip", new_event_path, class: "..." %>
</p>
<% @games.each do |game| %>
  <%# name, format · course · date, status badge, event subtitle, Continue setup for draft %>
<% end %>
```

- [ ] **Step 4: Run specs and commit**

---

## Task 9: GameSetupsController — wizard

**Files:**
- Create: `app/controllers/game_setups_controller.rb`
- Create: `app/views/game_setups/show.html.erb`
- Create: `spec/requests/game_setups_spec.rb`

- [ ] **Step 1: Write failing spec for course step save**

```ruby
it "saves course/tee and activates game when format present" do
  game = create_draft_game_for(user)
  # stub GolfCourseApi or use VCR — prefer stubbing build_snapshot via allow_any_instance_of
  patch game_setup_path(game), params: {
    step: "course",
    round: { played_on: Date.today, golf_course_api_course_id: 1, tee_selector: "male:0" }
  }
  expect(game.reload.status).to eq("active") # after format step; adjust per step
end
```

- [ ] **Step 2: Implement controller**

```ruby
class GameSetupsController < ApplicationController
  include GameAuthorizable
  include RoundSnapshotBuildable

  before_action :set_game
  before_action :require_game_manager!

  STEPS = %w[course format invite].freeze

  def show
    @step = params[:step].presence_in(STEPS) || next_step
    load_course_search_state if @step == "course"
  end

  def update
    case params[:step]
    when "course" then save_course!
    when "format" then save_format!
    else redirect_to game_setup_path(@game)
    end
  end

  private

  def next_step
    return "course" if @game.round.blank?
    return "format" if @game.game_type.blank?
    "invite"
  end

  def save_course!
    snapshot = build_snapshot(
      course_id: round_params.fetch(:golf_course_api_course_id).to_i,
      tee_selector: round_params.fetch(:tee_selector)
    )
    round = @game.round || Round.new(event: @game.event)
    round.assign_attributes(
      name: "Round at #{snapshot[:course_name]}",
      played_on: round_params.fetch(:played_on),
      **snapshot.except(:course_snapshot),
      course_snapshot: snapshot[:course_snapshot]
    )
    round.save!
    @game.update!(round: round)
    redirect_to game_setup_path(@game, step: "format")
  rescue StandardError => e
    flash[:alert] = e.message
    redirect_to game_setup_path(@game, step: "course")
  end

  def save_format!
    @game.update!(game_type: params.require(:game).fetch(:game_type), status: "active")
    redirect_to game_setup_path(@game, step: "invite")
  end

  def round_params
    params.require(:round).permit(:played_on, :golf_course_api_course_id, :tee_selector)
  end
end
```

- [ ] **Step 3: Build setup view** — reuse course search markup from `app/views/rounds/new.html.erb`; format radio buttons; invite step with clipboard controller + link to `edit_teams_game_path`.

- [ ] **Step 4: Event-scoped entry** — in `Events::GamesController` or keep action in `GamesController`:

```ruby
# POST /events/:token/games — creates draft game with event_id, host membership, redirects to setup
def create
  @event = Event.find_by!(token: params[:event_token])
  # authorize commissioner
  @game = @event.games.new(name: params[:game][:name], creator: current_user, status: "draft")
  # save + redirect to game_setup_path(@game)
end
```

Split into `EventGamesController` if `GamesController` grows too large.

- [ ] **Step 5: Run specs and commit**

---

## Task 10: Join flow

**Files:**
- Modify: `app/controllers/games_controller.rb` — add `join`, update `show`
- Create: `app/views/games/show_join.html.erb`
- Modify: `spec/requests/games_spec.rb`

- [ ] **Step 1: Write failing join spec**

```ruby
describe "POST /games/:token/join" do
  it "adds player membership to ad hoc game" do
    host = User.create!(name: "H", email: "h@test.com", password: "pw")
    player = User.create!(name: "P", email: "p@test.com", password: "pw")
    game = create_active_ad_hoc_game(host: host)

    post login_path, params: { email: player.email, password: "pw" }
    post join_game_path(game)
    expect(game.members).to include(player)
    expect(response).to redirect_to(game_path(game))
  end
end
```

- [ ] **Step 2: Implement join + show_join**

Mirror `EventsController#join`:

```ruby
def show
  if @game.member?(current_user)
    @scorecard = build_game_scorecard(@game) if @game.active? || @game.completed?
    @event = @game.event
  else
    render :show_join
  end
end

def join
  if @game.member?(current_user)
    redirect_to @game, notice: "You're already in this game."
  else
    @game.game_memberships.create!(user: current_user, role: "player")
    redirect_to @game, notice: "You joined the game."
  end
end
```

- [ ] **Step 3: Run specs and commit**

---

## Task 11: GameMembershipsController — promote cohost

**Files:**
- Create: `app/controllers/game_memberships_controller.rb`
- Create: `spec/requests/game_memberships_spec.rb`

- [ ] **Step 1: Write failing spec**

```ruby
it "promotes player to cohost" do
  # host promotes player
  patch game_game_membership_path(game, membership), params: { game_membership: { role: "cohost" } }
  expect(membership.reload.role).to eq("cohost")
end
```

- [ ] **Step 2: Implement** — mirror `EventMembershipsController#update` with `can_manage?` guard; only `player` → `cohost`.

- [ ] **Step 3: Run specs and commit**

---

## Task 12: HoleScoresController + scorecard helper

**Files:**
- Modify: `app/controllers/hole_scores_controller.rb`
- Modify: `app/helpers/games/scorecard_helper.rb`
- Modify: `spec/requests/hole_scores_spec.rb`

- [ ] **Step 1: Replace event-based before_actions**

```ruby
before_action :set_game
before_action :require_game_access!
before_action :require_game_not_completed!
```

Remove `set_event`; use `@game.event` when needed for partials.

Update `set_game`:

```ruby
def set_game
  @game = Game.find_by!(token: params[:game_token] || params[:token])
end
```

Nested route param under games will be `game_token` from `resources :games, param: :token` — verify with `rails routes`; may be `:game_token` for nested resources.

- [ ] **Step 2: Update scorecard_helper**

```ruby
def scorecard_can_edit?(game, _event = nil)
  return false if game.completed?
  game.can_manage?(current_user) ||
    game.game_teams.joins(:game_team_players).where(game_team_players: { user_id: current_user.id }).exists?
end
```

- [ ] **Step 3: Update all path helpers** in hole score views to `game_path(@game)`.

- [ ] **Step 4: Run hole_scores + games specs; fix failures**

Run: `bundle exec rspec spec/requests/hole_scores_spec.rb spec/requests/games_spec.rb`

- [ ] **Step 5: Commit**

---

## Task 13: Game show UI — complete, reopen, pre-team state

**Files:**
- Modify: `app/views/games/show.html.erb`
- Modify: `app/views/games/edit_teams.html.erb`

- [ ] **Step 1: Add management buttons**

```erb
<% if @game.can_manage?(current_user) && @game.active? %>
  <%= button_to "Complete game", complete_game_path(@game), method: :patch,
        form: { data: { turbo_confirm: "Complete this game and lock scores?" } }, ... %>
<% end %>
<% if @game.can_manage?(current_user) && @game.completed? %>
  <%= button_to "Edit scores", reopen_game_path(@game), method: :patch,
        form: { data: { turbo_confirm: "Reopen scores for editing?" } }, ... %>
<% end %>
```

- [ ] **Step 2: Pre-team waiting state**

When `@game.active?` and user is member but not on a team:

```erb
<p class="text-gray-600">Waiting for teams to be assigned.</p>
```

- [ ] **Step 3: Update back links** — `game_path` / `games_path` instead of event paths.

- [ ] **Step 4: Manual smoke test in browser**

- [ ] **Step 5: Commit**

---

## Task 14: Navigation and events integration

**Files:**
- Modify: `app/views/layouts/application.html.erb`
- Modify: `app/views/events/index.html.erb`
- Modify: `app/views/events/show.html.erb`

- [ ] **Step 1: Update sidebar**

Replace `Events` link with:

```erb
<%= link_to "Games", games_path, class: nav_row.call(on_course_active), ... %>
<%= link_to "Trips", events_path, class: nav_row.call(controller_name == "events"), ... %>
```

Add contextual **This game** section when `@game` is set (like `@pool` / `@event`).

- [ ] **Step 2: Update events/show games list**

```erb
<%= link_to game.name, game_path(game), ... %>
```

Change “Create game” to event-scoped wizard: `new_event_game_path(@event)`.

- [ ] **Step 3: Rename events index title** to “Trips” (optional subtitle: “Multi-round outings”).

- [ ] **Step 4: Commit**

---

## Task 15: Fix all specs and factory-less test helpers

**Files:**
- Modify: `spec/requests/games_spec.rb`
- Modify: `spec/services/forty_score_scorecard_spec.rb`, `spec/services/best_ball_scorecard_spec.rb`
- Add: `spec/support/game_test_helpers.rb`

- [ ] **Step 1: Add test helper**

```ruby
# spec/support/game_test_helpers.rb
module GameTestHelpers
  def create_game!(event:, round:, game_type: "best_ball", status: "active", creator:)
    Game.create!(
      event: event, round: round, game_type: game_type, status: status,
      name: "#{game_type.titleize} at #{round.course_name}",
      creator: creator, token: SecureRandom.urlsafe_base64(16)
    )
  end
end
RSpec.configure { |c| c.include GameTestHelpers }
```

- [ ] **Step 2: Update every `Game.create!` in specs** to include required fields.

- [ ] **Step 3: Replace path helpers throughout specs**

| Old | New |
|-----|-----|
| `event_game_path(event, game)` | `game_path(game)` |
| `edit_teams_event_game_path(event, game)` | `edit_teams_game_path(game)` |
| `event_games_path(event)` | `event_games_path(event)` (create only) |

- [ ] **Step 4: Run full suite**

Run: `bundle exec rspec`
Expected: all green

- [ ] **Step 5: Commit**

---

## Task 16: Legacy redirect request spec

**Files:**
- Create: `spec/requests/legacy_game_routes_spec.rb`

- [ ] **Step 1: Write spec**

```ruby
it "redirects old event-nested game URL to token URL" do
  game = create_game!(...)
  get "/events/#{event.token}/games/#{game.id}"
  expect(response).to redirect_to(game_path(game))
end
```

- [ ] **Step 2: Run and commit**

---

## Task 17: Design doc amendment

**Files:**
- Modify: `docs/plans/2026-05-06-on-course-games-design.md`

- [ ] **Step 1: Add section at top**

```markdown
> **2026-05-18 update:** Game-first and ad hoc flows are specified in
> [2026-05-18-ad-hoc-games-design.md](2026-05-18-ad-hoc-games-design.md).
> Events are now "trips" in UX; games are the primary On-Course entity.
```

- [ ] **Step 2: Commit**

---

## Spec coverage checklist

| Design requirement | Task |
|--------------------|------|
| Nullable event_id | Task 1 |
| Game token + invite | Task 1, 10 |
| GameMembership host/cohost | Task 2, 11 |
| Draft → active wizard | Task 9 |
| Saveable partial setup | Task 9 |
| User-provided name + suggested helper | Task 3, 8, 9 |
| Anyone can create | Task 8 |
| View before team assignment | Task 10, 13 |
| Complete / reopen locking | Task 8, 12, 13 |
| Event games unchanged roster logic | Task 7, 9 |
| Game-centric index | Task 8 |
| Top-level routes + redirects | Task 6, 16 |
| Retire `submitted` | Task 1, 12 |

---

## Suggested implementation order

1. Tasks 1–4 (schema + models) — foundation
2. Task 5–6 (concern + routes)
3. Task 7–8 (controller skeleton + index)
4. Task 9–11 (wizard + join + cohost)
5. Task 12–14 (hole scores + UI + nav)
6. Task 15–17 (spec sweep + docs)

---

## Out of scope (do not implement)

- Promote ad hoc game to event
- Per-game join for event games
- GameMembership sync from event join
- Game deletion / archive

---

## Execution handoff

Plan complete and saved to `docs/plans/2026-05-18-ad-hoc-games-plan.md`.

**Two execution options:**

1. **Subagent-Driven (recommended)** — fresh subagent per task, review between tasks, fast iteration
2. **Inline Execution** — run tasks in this session with checkpoints for review

Which approach do you want?

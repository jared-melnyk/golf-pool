# Admin Add Trip Members Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let admins add any existing user to a trip (event) as a player from Admin → Events, without changing public invite or game-team flows.

**Architecture:** Add `Admin::EventsController` (index/show) and `Admin::EventMembershipsController` (create) under `namespace :admin`, gated by `require_admin`. Reuse `EventMembership` with server-forced `role: "player"`. Sidebar gets an Admin → Events link. Commissioners continue to assign trip members to game teams via existing Edit teams.

**Tech Stack:** Rails 8.1, PostgreSQL, ERB + Tailwind, RSpec request specs.

**Design reference:** [docs/superpowers/specs/2026-07-10-admin-add-trip-members-design.md](../specs/2026-07-10-admin-add-trip-members-design.md)

---

## File map

**Create:**
- `app/controllers/admin/events_controller.rb` — list/show events for admins
- `app/controllers/admin/event_memberships_controller.rb` — add user as player
- `app/views/admin/events/index.html.erb` — events table
- `app/views/admin/events/show.html.erb` — members + add form
- `spec/requests/admin/events_spec.rb` — index/show/auth
- `spec/requests/admin/event_memberships_spec.rb` — create + edge cases

**Modify:**
- `config/routes.rb` — admin events + nested event_memberships
- `app/views/layouts/application.html.erb` — Admin → Events nav link

**Do not change:**
- Public `EventsController` / invite join
- `EventMembershipsController` (promote/remove on trip page)
- `Game#roster_users` / edit teams

---

## Conventions

- Event URL param: `token` via `param: :token` and `Event#to_param` (same as public events).
- Nested create uses `params[:event_token]` (Rails convention when parent `param: :token`).
- Role on admin add is always `"player"` — never take role from params.
- RSpec style: `User.create!` / `Event.create!` / `EventMembership.create!` (no factories); login via `post login_path`.
- Run tests from repo root: `bundle exec rspec path/to/spec.rb`
- Commit after each task when the user has asked you to implement (include commit steps below for the implementer).

---

### Task 1: Routes + failing index/show specs

**Files:**
- Modify: `config/routes.rb`
- Create: `spec/requests/admin/events_spec.rb`

- [ ] **Step 1: Add admin event routes**

In `config/routes.rb`, inside `namespace :admin do`, add events resources (keep existing `games` and `users`):

```ruby
namespace :admin do
  resources :games, only: [ :index ]
  resources :users, only: [ :index, :new, :create, :edit, :update ]
  resources :events, param: :token, only: [ :index, :show ] do
    resources :event_memberships, only: [ :create ]
  end
end
```

- [ ] **Step 2: Write failing request specs for index/show/auth**

Create `spec/requests/admin/events_spec.rb`:

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Events", type: :request do
  let(:admin) { User.create!(name: "Admin", email: "admin@example.com", password: "password", admin: true) }

  before { post login_path, params: { email: admin.email, password: "password" } }

  describe "GET /admin/events" do
    it "returns success for an admin" do
      get admin_events_path
      expect(response).to have_http_status(:ok)
    end

    it "lists events with name, status, and member count" do
      event = Event.create!(name: "Michigan Trip", status: "active")
      player = User.create!(name: "Player", email: "player@example.com", password: "password")
      EventMembership.create!(event: event, user: admin, role: "commissioner")
      EventMembership.create!(event: event, user: player, role: "player")

      get admin_events_path

      expect(response.body).to include("Michigan Trip")
      expect(response.body).to include("Active")
      expect(response.body).to include("2")
    end
  end

  describe "GET /admin/events/:token" do
    it "shows members and an add-member form" do
      event = Event.create!(name: "Michigan Trip", status: "draft")
      EventMembership.create!(event: event, user: admin, role: "commissioner")
      outsider = User.create!(name: "Outsider", email: "out@example.com", password: "password")

      get admin_event_path(event)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Michigan Trip")
      expect(response.body).to include(admin.name)
      expect(response.body).to include("Commissioner")
      expect(response.body).to include(outsider.name)
      expect(response.body).to include("Add")
    end
  end

  describe "authorization" do
    let(:member) { User.create!(name: "Member", email: "member@example.com", password: "password", admin: false) }

    before { post login_path, params: { email: member.email, password: "password" } }

    it "redirects non-admin from events index" do
      get admin_events_path
      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(flash[:alert]).to eq("Not authorized.")
    end

    it "redirects non-admin from event show" do
      event = Event.create!(name: "Trip", status: "draft")
      get admin_event_path(event)
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq("Not authorized.")
    end
  end
end
```

- [ ] **Step 3: Run specs to verify they fail**

Run: `bundle exec rspec spec/requests/admin/events_spec.rb`

Expected: FAIL — missing controller / uninitialized constant `Admin::EventsController` (or routing/helper errors until controller exists).

- [ ] **Step 4: Commit**

```bash
git add config/routes.rb spec/requests/admin/events_spec.rb
git commit -m "$(cat <<'EOF'
Add admin events routes and request specs.

EOF
)"
```

---

### Task 2: Admin events index and show

**Files:**
- Create: `app/controllers/admin/events_controller.rb`
- Create: `app/views/admin/events/index.html.erb`
- Create: `app/views/admin/events/show.html.erb`

- [ ] **Step 1: Implement `Admin::EventsController`**

```ruby
# frozen_string_literal: true

module Admin
  class EventsController < ApplicationController
    before_action :require_admin
    before_action :set_event, only: [ :show ]

    def index
      @events = Event.includes(:event_memberships).order(:name)
    end

    def show
      @memberships = @event.event_memberships.includes(:user).order("users.name")
      @addable_users = User.where.not(id: @event.user_ids).order(:name)
    end

    private

    def set_event
      @event = Event.find_by!(token: params[:token])
    end
  end
end
```

- [ ] **Step 2: Create index view**

Create `app/views/admin/events/index.html.erb` (match Admin Users/Games table styling):

```erb
<div class="border border-gray-200 rounded-lg bg-white shadow-sm overflow-hidden">
  <div class="p-4 border-b border-gray-200">
    <h1 class="text-2xl font-bold text-gray-900">Events</h1>
  </div>

  <% if @events.any? %>
    <div class="overflow-x-auto">
      <table class="min-w-full divide-y divide-gray-200 text-sm">
        <thead class="bg-gray-50">
          <tr>
            <th scope="col" class="px-4 py-3 text-left font-semibold text-gray-700">Name</th>
            <th scope="col" class="px-4 py-3 text-left font-semibold text-gray-700">Status</th>
            <th scope="col" class="px-4 py-3 text-left font-semibold text-gray-700">Members</th>
            <th scope="col" class="px-4 py-3 text-left font-semibold text-gray-700"><span class="sr-only">Actions</span></th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-100 bg-white">
          <% @events.each do |event| %>
            <tr>
              <td class="px-4 py-3 whitespace-nowrap font-medium text-gray-900"><%= event.name %></td>
              <td class="px-4 py-3 whitespace-nowrap text-gray-700"><%= event.status.titleize %></td>
              <td class="px-4 py-3 whitespace-nowrap text-gray-700"><%= event.event_memberships.size %></td>
              <td class="px-4 py-3 whitespace-nowrap text-right">
                <%= link_to "Manage", admin_event_path(event), class: "text-emerald-700 hover:underline text-sm font-medium" %>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
  <% else %>
    <p class="p-4 text-gray-600">No events yet.</p>
  <% end %>
</div>
```

- [ ] **Step 3: Create show view**

Create `app/views/admin/events/show.html.erb`:

```erb
<div class="space-y-6">
  <div>
    <h1 class="text-2xl font-bold text-gray-900"><%= @event.name %></h1>
    <p class="text-sm text-gray-600 mt-1">Status: <%= @event.status.titleize %></p>
  </div>

  <section class="border border-gray-200 rounded-lg p-4 bg-white shadow-sm">
    <h2 class="text-lg font-semibold text-gray-900 mb-3">Members</h2>
    <% if @memberships.any? %>
      <ol class="list-decimal list-inside space-y-2">
        <% @memberships.each do |em| %>
          <li class="text-gray-800">
            <%= em.user.name %>
            <span class="text-sm text-gray-500">— <%= em.role.titleize %></span>
          </li>
        <% end %>
      </ol>
    <% else %>
      <p class="text-sm text-gray-600">No members yet.</p>
    <% end %>
  </section>

  <section class="border border-gray-200 rounded-lg p-4 bg-white shadow-sm">
    <h2 class="text-lg font-semibold text-gray-900 mb-3">Add member</h2>
    <% if @addable_users.any? %>
      <%= form_with url: admin_event_event_memberships_path(@event), method: :post, local: true, class: "flex flex-wrap items-end gap-3" do %>
        <div>
          <label for="user_id" class="block text-sm font-medium text-gray-700 mb-1">User</label>
          <select name="user_id" id="user_id" required
                  class="rounded border border-gray-300 px-3 py-2 focus:ring-2 focus:ring-emerald-500">
            <option value="">Select a user…</option>
            <% @addable_users.each do |user| %>
              <option value="<%= user.id %>"><%= user.name %> (<%= user.email %>)</option>
            <% end %>
          </select>
        </div>
        <div>
          <button type="submit" class="rounded px-4 py-2 text-sm font-medium bg-emerald-600 text-white hover:bg-emerald-700">
            Add
          </button>
        </div>
      <% end %>
    <% else %>
      <p class="text-sm text-gray-600">All users are already on this trip</p>
    <% end %>
  </section>

  <%= link_to "← All events", admin_events_path, class: "text-sm text-emerald-700 hover:text-emerald-800 underline" %>
</div>
```

- [ ] **Step 4: Run specs to verify they pass**

Run: `bundle exec rspec spec/requests/admin/events_spec.rb`

Expected: PASS (all examples).

- [ ] **Step 5: Commit**

```bash
git add app/controllers/admin/events_controller.rb app/views/admin/events/
git commit -m "$(cat <<'EOF'
Add admin events index and show for trip membership.

EOF
)"
```

---

### Task 3: Failing specs for adding members

**Files:**
- Create: `spec/requests/admin/event_memberships_spec.rb`

- [ ] **Step 1: Write failing create specs**

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::EventMemberships", type: :request do
  let(:admin) { User.create!(name: "Admin", email: "admin@example.com", password: "password", admin: true) }
  let(:event) { Event.create!(name: "Michigan Trip", status: "active") }
  let(:golfer) { User.create!(name: "Walker", email: "walker@example.com", password: "password") }

  before { post login_path, params: { email: admin.email, password: "password" } }

  describe "POST /admin/events/:event_token/event_memberships" do
    it "adds the user as a player" do
      expect {
        post admin_event_event_memberships_path(event), params: { user_id: golfer.id }
      }.to change(EventMembership, :count).by(1)

      membership = EventMembership.find_by!(event: event, user: golfer)
      expect(membership.role).to eq("player")
      expect(response).to redirect_to(admin_event_path(event))
      follow_redirect!
      expect(flash[:notice]).to include("Walker")
    end

    it "forces player role even if a different role is submitted" do
      post admin_event_event_memberships_path(event), params: { user_id: golfer.id, role: "commissioner" }

      expect(EventMembership.find_by!(event: event, user: golfer).role).to eq("player")
    end

    it "alerts when user_id is missing" do
      expect {
        post admin_event_event_memberships_path(event), params: { user_id: "" }
      }.not_to change(EventMembership, :count)

      expect(response).to redirect_to(admin_event_path(event))
      expect(flash[:alert]).to be_present
    end

    it "alerts when the user is already a member" do
      EventMembership.create!(event: event, user: golfer, role: "player")

      expect {
        post admin_event_event_memberships_path(event), params: { user_id: golfer.id }
      }.not_to change(EventMembership, :count)

      expect(response).to redirect_to(admin_event_path(event))
      expect(flash[:alert]).to be_present
    end
  end

  describe "authorization" do
    let(:member) { User.create!(name: "Member", email: "member@example.com", password: "password", admin: false) }

    before { post login_path, params: { email: member.email, password: "password" } }

    it "redirects non-admin from create" do
      expect {
        post admin_event_event_memberships_path(event), params: { user_id: golfer.id }
      }.not_to change(EventMembership, :count)

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq("Not authorized.")
    end
  end
end
```

- [ ] **Step 2: Run specs to verify they fail**

Run: `bundle exec rspec spec/requests/admin/event_memberships_spec.rb`

Expected: FAIL — missing `Admin::EventMembershipsController`.

- [ ] **Step 3: Commit**

```bash
git add spec/requests/admin/event_memberships_spec.rb
git commit -m "$(cat <<'EOF'
Add failing specs for admin event membership create.

EOF
)"
```

---

### Task 4: Implement admin event membership create

**Files:**
- Create: `app/controllers/admin/event_memberships_controller.rb`

- [ ] **Step 1: Implement controller**

```ruby
# frozen_string_literal: true

module Admin
  class EventMembershipsController < ApplicationController
    before_action :require_admin
    before_action :set_event

    def create
      user = User.find_by(id: params[:user_id])
      if user.nil?
        redirect_to admin_event_path(@event), alert: "Select a user to add."
        return
      end

      if @event.member?(user)
        redirect_to admin_event_path(@event), alert: "#{user.name} is already on this trip."
        return
      end

      @event.event_memberships.create!(user: user, role: "player")
      redirect_to admin_event_path(@event), notice: "#{user.name} added as a player."
    end

    private

    def set_event
      @event = Event.find_by!(token: params[:event_token])
    end
  end
end
```

- [ ] **Step 2: Run membership specs**

Run: `bundle exec rspec spec/requests/admin/event_memberships_spec.rb`

Expected: PASS.

- [ ] **Step 3: Run admin events + memberships together**

Run: `bundle exec rspec spec/requests/admin/events_spec.rb spec/requests/admin/event_memberships_spec.rb`

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add app/controllers/admin/event_memberships_controller.rb
git commit -m "$(cat <<'EOF'
Allow admins to add users to trips as players.

EOF
)"
```

---

### Task 5: Admin nav link

**Files:**
- Modify: `app/views/layouts/application.html.erb`
- Modify: `spec/requests/admin/events_spec.rb` (optional assertion) or rely on manual check — prefer a small request assertion on a page that includes the layout.

- [ ] **Step 1: Add Events link in Admin sidebar**

Near the existing Admin links (`Tournaments`, `Games`, `Users`), add Events and an active-state variable.

Find:

```erb
<% admin_games_nav_active = controller_path == "admin/games" && action_name == "index" %>
<% admin_users_nav_active = controller_path == "admin/users" && action_name == "index" %>
```

Replace/extend with:

```erb
<% admin_games_nav_active = controller_path == "admin/games" && action_name == "index" %>
<% admin_users_nav_active = controller_path == "admin/users" && action_name == "index" %>
<% admin_events_nav_active = controller_path.start_with?("admin/events") || controller_path == "admin/event_memberships" %>
```

In the Admin nav block, add **Events** after **Games**:

```erb
<%= link_to "Games", admin_games_path, class: nav_row.call(admin_games_nav_active), data: { action: "click->sidebar#close" } %>
<%= link_to "Events", admin_events_path, class: nav_row.call(admin_events_nav_active), data: { action: "click->sidebar#close" } %>
<%= link_to "Users", admin_users_path, class: nav_row.call(admin_users_nav_active), data: { action: "click->sidebar#close" } %>
```

- [ ] **Step 2: Assert nav link appears for admin**

Add to `spec/requests/admin/events_spec.rb` inside the admin `GET /admin/events` describe:

```ruby
it "includes an Admin Events nav link" do
  get admin_events_path
  expect(response.body).to include(admin_events_path)
  expect(response.body).to include(">Events<")
end
```

(If the exact `>Events<` matcher is brittle because of whitespace, assert `href="#{admin_events_path}"` instead.)

- [ ] **Step 3: Run specs**

Run: `bundle exec rspec spec/requests/admin/events_spec.rb spec/requests/admin/event_memberships_spec.rb`

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add app/views/layouts/application.html.erb spec/requests/admin/events_spec.rb
git commit -m "$(cat <<'EOF'
Add Admin Events link to the sidebar.

EOF
)"
```

---

### Task 6: Smoke verification

**Files:** none (manual / full suite)

- [ ] **Step 1: Run the focused admin suite**

Run: `bundle exec rspec spec/requests/admin/`

Expected: PASS (users, games, events, event_memberships).

- [ ] **Step 2: Manual checklist (local server)**

1. Sign in as an admin.
2. Open Admin → Events → a trip.
3. Add a user who is not on the trip → appears as Player.
4. Confirm they show on the public trip page Members list.
5. As commissioner, open a trip game → Edit teams → new user is in the roster checkboxes.
6. Sign in as non-admin → `/admin/events` redirects with “Not authorized.”

- [ ] **Step 3: Final commit only if there are leftover uncommitted fixes**

```bash
git status
# commit any small fixes if needed
```

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| Admin events index | 1–2 |
| Admin event show + dropdown of non-members | 2 |
| POST create membership as player | 3–4 |
| Role forced to player | 3–4 |
| Non-admin blocked | 1, 3–4 |
| Duplicate / missing user alerts | 3–4 |
| Sidebar Admin → Events | 5 |
| No public trip-page DB-wide add | (explicit non-change) |
| Game team roster unchanged | (explicit non-change; smoke in Task 6) |

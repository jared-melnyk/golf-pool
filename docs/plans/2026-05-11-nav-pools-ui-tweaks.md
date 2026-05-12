# Nav, privacy, pool show, and tournament results UI — implementation plan

> **For agentic workers:** Execute tasks in order; use checkboxes for tracking. No separate spec file was written (user asked for a moderate plan only).

**Goal:** Restructure navigation (PGA Pools vs On-Course, admin-only areas), stop exposing member emails in pool UI, show a compact results summary on the pool page for finished tournaments, clarify “dropped” golfer earnings on the tournament results table, and extend the no-cut / synthetic-cut banner with the marginal score-to-par used for bonus eligibility.

**Architecture:** Rails 8 server-rendered ERB + Tailwind; nav lives in `app/views/layouts/application.html.erb` with sidebar Stimulus controller. Admin gating will use a new persisted flag on `users` (recommended) plus `before_action` on admin-only controllers. Pool scoring logic already lives on `Pool`; extract a single-tournament points helper to avoid duplicating the top-3-golfer math.

**Tech stack:** Ruby on Rails, Hotwire/Turbo, Tailwind (via `tailwind` + `app` stylesheets), importmap.

---

## Open questions (answer before or during implementation)

1. **Who is an admin?** The app has no `admin` concept today. This plan assumes a boolean `users.admin` (migration + set your account in console or a one-off seed). If you prefer an env allowlist (e.g. `ADMIN_EMAILS`) with no migration, swap Task 1 accordingly.
2. **Admin nav contents:** This plan puts **Tournaments** (`tournaments#index` / `tournaments#show`) under **Admin** and locks those actions plus **Sync** (`SyncController`) to admins only. If other URLs should be admin-only later, add them to the same `require_admin` helper.

---

## Task 1: Admin flag and authorization

**Files:**

- Create: `db/migrate/XXXXXXXX_add_admin_to_users.rb`
- Modify: `app/models/user.rb` (optional comment; no validation change)
- Modify: `app/controllers/application_controller.rb` — `helper_method :current_user_admin?`, `require_admin`, `before_action` hook pattern
- Modify: `app/controllers/tournaments_controller.rb` — `before_action :require_admin`
- Modify: `app/controllers/sync_controller.rb` — `before_action :require_admin`
- Test: `spec/requests/tournaments_spec.rb`, new `spec/requests/sync_spec.rb` or extend existing request specs — expect 403/redirect for non-admin, 200 for admin

**Steps:**

- [ ] Add migration: `add_column :users, :admin, :boolean, default: false, null: false`.
- [ ] Run `bin/rails db:migrate`.
- [ ] In `ApplicationController` (private): `def current_user_admin?; current_user&.admin?; end` and `def require_admin; redirect_to root_path, alert: "Not authorized." unless current_user_admin?; end` (or `head :forbidden` — pick one and use consistently).
- [ ] `helper_method :current_user_admin?`
- [ ] `TournamentsController` and `SyncController`: `before_action :require_admin`.
- [ ] Request specs: signed-in non-admin cannot GET `tournaments_path` or POST sync paths; signed-in admin can.

**Commit:** `feat: restrict tournaments and sync to admin users`

---

## Task 2: Navigation — PGA Pools, On-Course, Admin; Rules under Pools; header profile link

**Files:**

- Modify: `app/views/layouts/application.html.erb`

**Behavior:**

1. **Header (signed in):** Remove the standalone `Rules` link. Keep **LongShot** logo. Replace plain `<span>` name with `link_to current_user.name, edit_profile_path, class: "..."` (no underline or subtle underline per existing style). Keep **Sign out** as today.
2. **Sidebar:** Replace the flat list of Rules / Pools / On-Course / Tournaments / Profile with:
   - **PGA Pools** (section label or parent row). Children:
     - **My pools** → `pools_path` (rename label from “Pools”).
     - **New pool** → `new_pool_path` if route exists (`resources :pools` → `new_pool_path`).
     - **Rules** → `rules_path` (only in sidebar under PGA Pools, not in header).
   - **On-Course games** (section label). Children:
     - **Events** (or keep **On-Course** label) → `events_path`.
   - **Admin** (visible only if `current_user_admin?`). Children:
     - **Tournaments** → `tournaments_path`.
   - Remove **Profile** from the sidebar.
3. **Active states:** Use `current_page?` / `controller_name` so the correct child highlights when on pools, pool show, picks, rules, events, tournaments, etc. Match existing class pattern from the file.
4. **Pool context block:** Keep the existing “This pool” subsection when `@pool` is set and user is a member; ensure parent **PGA Pools** section looks coherent (optional: highlight PGA Pools when `controller_name` is `pools` or `picks` or `pool_tournaments`).
5. **Event context block:** Keep “This event” when `@event` is set; parent **On-Course** section active when `controller_name == "events"` (and related).

**Implementation note:** For “sub-menu similar to pool show,” use simple **stacked section headings + indented links** (no new Stimulus unless you want expand/collapse later). That matches current sidebar patterns and stays accessible.

**Commit:** `feat: reorganize nav for PGA Pools, on-course, and admin`

---

## Task 3: Hide member emails in pool picks table

**Files:**

- Modify: `app/views/picks/_tournament_pool_picks.html.erb` — remove the `<div class="text-xs text-gray-500"><%= member.email %></div>` line; keep `member.name` only.

**Files (profile display-only email):**

- Modify: `app/views/profiles/edit.html.erb` — above the form, add a read-only line, e.g. “Email: `<%= @user.email %>`” with helper text that it is not editable here (account email is used for sign-in).

**Commit:** `fix: show names in pool picks; show email only on profile`

---

## Task 4: Pool model — points for one tournament (one pick)

**Files:**

- Modify: `app/models/pool.rb`

**Steps:**

- [ ] Extract the per-tournament scoring loop from `total_points_for` into a public method, e.g. `def points_for_pool_tournament(user, pool_tournament)` returning `0.to_d` if no pick, else the same top-3 sum used today for that `pool_tournament` only.
- [ ] Implement `total_points_for` by summing `points_for_pool_tournament(user, pt)` over `pool_tournaments` (preserves behavior; add a model spec if none exists).

**Test:** `spec/models/pool_spec.rb` — example: fixed pick + stubbed `TournamentResult` / odds so `points_for_pool_tournament` matches expected decimal.

**Commit:** `refactor: expose pool points for a single tournament`

---

## Task 5: Pool show — completed tournaments show results summary, not full picks grid

**Files:**

- Modify: `app/views/pools/show.html.erb`
- Create: `app/views/pools/_tournament_completed_summary.html.erb` (or under `picks/` if you prefer cohesion with pick partials)

**Logic:**

- For each tournament row where `pt` is present and `t.completed?` (see `Tournament#completed?`), **do not** render `picks/tournament_pool_picks`.
- Instead render a summary partial: for each pool member (same order as today, e.g. `pool.users.order(:name)`), show:
  - Member **name** (no email).
  - **Picks:** list golfer names for that tournament (same visibility rules as `_tournament_pool_picks`: use `pool_tournament.can_view_all_picks?` / `can_view_member_picks?`; otherwise “Pick submitted” / “No pick”).
  - **Tournament total** (or “Earnings this event”): `$<%= number_with_delimiter(@pool.points_for_pool_tournament(member, pt).to_i) %>` (or keep decimals if you use fractional bonuses — match standings formatting).

- When tournament is **not** completed, keep current behavior: render `_tournament_with_picks` + `_tournament_pool_picks` as now.

**Controller:** No change strictly required if the helper is on `Pool` and `@pool` is set; optionally preload picks the same way to avoid N+1 (already have `@picks_by_tournament_and_user`).

**Test:** `spec/requests/pools_show_spec.rb` — for a completed tournament fixture, response body includes summary labels and does not include the old picks table header text for that state, or use a view/component spec if the project prefers.

**Commit:** `feat: pool show summarizes completed tournaments`

---

## Task 6: Tournament results view — dropped golfer “Total Earnings” visually excluded

**Files:**

- Modify: `app/views/pool_tournaments/show.html.erb`

**Steps:**

- [ ] Where each golfer row renders **Total Earnings** (the rightmost money column), if the golfer is **dropped** (`counted_golfer_ids.exclude?(golfer.id)`), apply classes such as `line-through text-gray-400` (and optionally `decoration-gray-400`) on that cell’s `<span>` wrapping the dollar amount, or on the whole `<td>`.
- [ ] Optional copy tweak: add a tiny footnote under the table: “Dropped golfers do not count toward the total row.”

**Do not** change the numeric total row logic (it already sums only counted golfers).

**Test:** `spec/requests/pool_tournaments_show_spec.rb` or existing file — assert dropped row’s cell includes strikethrough class or assert HTML fragment (if fragile, manual QA only is acceptable for pure CSS).

**Commit:** `style: indicate dropped golfer earnings on pool tournament results`

---

## Task 7: Synthetic cut banner — include marginal score-to-par (“cut line”)

**Context:** `Tournament#no_cut_event?` and `Tournament#synthetic_cut_line_position` define **who** gets Cut Made Bonus (position ≤ synthetic line). `TournamentResult` does **not** store final `total_to_par`; the pool tournament show already loads `BallDontLie::PlayerRoundResultsFormatter` keyed by API player id (`golfer.external_id.to_i`) → `:total_to_par`.

**Definition (product copy):** Bonus eligibility stays **position-based** (`bonus_cut_eligible_result?`). For messaging only: among golfers who are eligible, take the **worst** (numerically **maximum**) final `total_to_par` from round results. That number describes how “high” scores could still be while someone stayed inside the synthetic cut **by leaderboard position** — it is not a second score-based rule.

**Files:**

- Modify: `app/models/tournament.rb` — add e.g. `marginal_bonus_eligible_total_to_par(round_results_by_player_id)` returning `Integer` or `nil` (max `:total_to_par` over eligible results whose golfer appears in the hash with a non-nil total; if none, `nil`).
- Modify: `app/controllers/pool_tournaments_controller.rb` — when building `player_ids` for `fetch_all_player_round_results`, if `@tournament.completed? && @tournament.no_cut_event?`, **union** pick golfers’ ids with **all** `golfers.external_id` from `@tournament.tournament_results` (so the formatter has totals for the whole field, not only pool picks). Reuse one formatter pass; assign `@synthetic_cut_marginal_total_to_par = @tournament.marginal_bonus_eligible_total_to_par(@round_results)` (or compute in a small private method).
- Modify: `app/views/pool_tournaments/show.html.erb` — extend the existing indigo banner (lines ~25–28) to append the formatted score when `@synthetic_cut_marginal_total_to_par` is present, e.g. “… synthetic cut line: top 45% of the field, plus ties. The worst (highest) score-to-par among players eligible for the Cut Made Bonus was **+3**.” (Avoid saying “+3 or better” without defining “better” as lower strokes — the parenthetical is optional.) Use the same E / `+n` / negative formatting as the results table’s total column for consistency (extract a tiny helper in `ApplicationHelper` if needed).
- Test: `spec/requests/pool_tournaments_show_spec.rb` — extend the existing example that hits `"synthetic cut line"` to stub or fixture round results so the response includes the formatted marginal score (or assert helper on `Tournament` in `spec/models/tournament_spec.rb` with a fake `round_results_by_player_id` hash).

**Edge cases:**

- If the API returns no `total_to_par` for any eligible golfer, keep the current banner text only (no bogus number).
- Rate limits: one wider `player_ids` list only when the no-cut + completed branch applies (not for every pool tournament view).

**Commit:** `feat: show synthetic cut marginal total-to-par on pool tournament results`

---

## Task 8: Manual QA checklist

- [ ] Non-admin: no Admin block in sidebar; visiting `/tournaments` redirects or 403; sync POSTs rejected.
- [ ] Admin: Admin → Tournaments works; tournament show sync buttons work.
- [ ] Header: name opens profile; no Rules in header; Rules under PGA Pools in sidebar.
- [ ] Pool show: incomplete event still shows picks table; completed shows summary with names + totals.
- [ ] Pool tournament results: total row still matches sum of counted rows; dropped earnings visibly struck through.
- [ ] No-cut completed tournament: banner mentions synthetic cut **and** shows marginal total-to-par when data exists.

---

## Spec coverage self-check

| Requirement | Task |
|-------------|------|
| Top nav: two branches + sub-menus | Task 2 |
| Rules under PGA Pools only | Task 2 |
| Tournaments + admin-only section | Tasks 1–2 |
| Profile via name, not nav item | Task 2 |
| No emails on pool picks; email on profile | Task 3 |
| Completed pool tournament summary | Tasks 4–5 |
| Dropped earnings visual | Task 6 |
| Synthetic cut banner + marginal score-to-par | Task 7 |

---

## Suggested improvements (optional, out of scope unless you want them)

- **Collapsible sidebar sections** on mobile for PGA Pools / On-Course / Admin to save vertical space (adds Stimulus or `<details>`).
- **`Pool#points_for_pool_tournament`** used on `pool_tournaments#show` header per user for a one-line “Your total this event: $X” without duplicating logic.

Plan complete. When you are ready to implement, start with Task 1 (admin), then Task 2 (nav), then Tasks 3–6; **Task 7** (synthetic cut copy) fits naturally after Task 6 since both touch `pool_tournaments/show`. Finish with Task 8 (QA).

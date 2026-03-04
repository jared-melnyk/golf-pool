# UI Spruce-Up Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make LongShot’s UI feel more robust and professional with a clean-refined (Notion/Headspace/Airbnb) style and optional light sporty accents across landing and logged-in app.

**Architecture:** Apply design tokens (typography, spacing, surfaces) via Tailwind; update layout and all ERB views for consistent cards, buttons, and hierarchy. No new assets or JS beyond existing Stimulus. Optional sporty touches only on landing hero and pool standings.

**Tech Stack:** Rails, ERB, Tailwind CSS (tailwindcss-rails), existing layout/partials.

**Design reference:** `docs/plans/2026-03-03-ui-spruce-up-design.md`

---

### Task 1: Design tokens and base styles

**Files:**
- Modify: `app/assets/tailwind/application.css`

**Step 1: Add theme and token comments**

In `app/assets/tailwind/application.css`, after `@import "tailwindcss";`, add an optional `@theme` block to set a consistent font (e.g. keep default system stack or add one web font). Then add a short comment block documenting token usage: page title `text-2xl`/`text-3xl` font-bold, section title `text-lg`/`text-xl` font-semibold, body default, muted `text-gray-500`/`text-gray-600`; cards `rounded-lg border border-gray-200 shadow-sm bg-white`; primary button `bg-emerald-600 hover:bg-emerald-700`, secondary outline/gray, danger red.

If using a web font (e.g. Inter): add `@import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap');` in layout `<head>` and in Tailwind `@theme { --font-sans: 'Inter', ui-sans-serif, system-ui, sans-serif; }`. Otherwise leave font as default and only add the comment block so implementers follow the same tokens.

**Step 2: Verify Tailwind build**

Run: `bundle exec rails tailwindcss:build`  
Expected: Build completes without errors.

**Step 3: Commit**

```bash
git add app/assets/tailwind/application.css
git commit -m "chore: add UI design tokens and optional font theme"
```

---

### Task 2: Layout — header, sidebar active state, main container

**Files:**
- Modify: `app/views/layouts/application.html.erb`

**Step 1: Header consistent height and padding**

Ensure header uses consistent vertical padding (e.g. `py-4` or `py-3`) and that the logo and nav items are vertically centered. Keep existing classes; only adjust if current padding is inconsistent (e.g. standardize to `px-4 py-3` or `px-4 py-4`).

**Step 2: Sidebar active state**

For each sidebar link (Rules, My Pools, Tournaments, and when present @pool name and “My picks”), add an active state when `current_page?` matches that path. Example: `class: "block rounded px-3 py-2 text-sm no-underline " + (current_page?(pools_path) ? "bg-gray-100 font-medium text-gray-900" : "text-gray-700 hover:bg-gray-100")`. Apply the same pattern for `rules_path`, `tournaments_path`, `pool_path(@pool)`, and `pool_picks_path(@pool)` (only when `@pool` is set). For “This pool” block links, use the same logic so the current pool name and “My picks” show as active on pool show and picks index respectively.

**Step 3: Main content padding**

Ensure the main content wrapper has consistent horizontal and vertical padding (e.g. `px-4 py-6` already present; keep or align to design). Flash messages container above main: keep `max-w-4xl mx-auto px-4 mt-2`.

**Step 4: Verify in browser**

Start app (`bin/dev` or `rails s`), sign in, open pool, check header and sidebar; confirm active state highlights when on Pools, pool show, and My picks. Commit.

```bash
git add app/views/layouts/application.html.erb
git commit -m "style: layout header padding and sidebar active state"
```

---

### Task 3: Landing page

**Files:**
- Modify: `app/views/landing/index.html.erb`

**Step 1: Hero hierarchy and spacing**

Increase hero spacing: wrap hero in a section with more vertical padding (e.g. `py-12` or `py-16`). Use `text-3xl` or `text-4xl` for the main title, `text-xl` for the subtitle, and `mb-6` or `mb-8` before the CTA group. Keep primary/secondary button styles; ensure gap between them (e.g. `gap-4`).

**Step 2: Section spacing**

For “What is LongShot?” and “How scoring works”, use consistent section spacing: `space-y-4` within section, `mb-8` or `space-y-10` between sections. Use `text-2xl font-semibold text-gray-900` for these section headings and `text-gray-700 leading-relaxed` for body.

**Step 3: Bottom CTA**

Keep the “Get started — Sign up” link with `text-center pt-4` or add a bit more top padding (e.g. `pt-8`) so the last section has breathing room.

**Step 4: Optional subtle hero background**

If adding a sporty accent: add a very subtle background to the hero section only, e.g. `bg-gradient-to-b from-emerald-50/50 to-transparent` or `bg-gray-50` (already on body). Do not add heavy imagery. If design preference is to keep hero plain, skip this step.

**Step 5: Verify and commit**

Load landing in browser; check hierarchy and spacing. Commit.

```bash
git add app/views/landing/index.html.erb
git commit -m "style: landing hero and section spacing"
```

---

### Task 4: Auth pages (sign in, sign up)

**Files:**
- Modify: `app/views/sessions/new.html.erb`
- Modify: `app/views/users/new.html.erb`

**Step 1: Align card and form styles**

Both pages already use `max-w-md mx-auto border border-gray-200 rounded-lg p-6 bg-white shadow-sm`. Ensure both use the same: `shadow-sm`, `rounded-lg`, and `p-6`. Inputs: `w-full rounded border border-gray-300 px-3 py-2 focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500`. Primary submit: `bg-emerald-600 text-white px-4 py-2 rounded hover:bg-emerald-700 font-medium`. Labels: `block text-sm font-medium text-gray-700 mb-1`. Make any small alignment so sign in and sign up are identical in pattern.

**Step 2: Verify and commit**

Load sign in and sign up; confirm cards and forms look consistent. Commit.

```bash
git add app/views/sessions/new.html.erb app/views/users/new.html.erb
git commit -m "style: align auth page card and form styles"
```

---

### Task 5: Pools index and new pool

**Files:**
- Modify: `app/views/pools/index.html.erb`
- Modify: `app/views/pools/new.html.erb`

**Step 5a: Pools index**

Wrap the main content in a single card for consistency: a white card with `border border-gray-200 rounded-lg p-6 bg-white shadow-sm`. Inside: keep “My pools” as `text-2xl font-bold text-gray-900 mb-4`, “New pool” as primary button (`bg-emerald-600 text-white px-4 py-2 rounded hover:bg-emerald-700 font-medium`), and the list or empty state. Use consistent list styling (e.g. `space-y-2`; links `text-emerald-600 hover:underline`).

**Step 5b: New pool form**

`pools/new` already uses a centered card; ensure it matches auth (same shadow, radius, padding). No structural change unless tokens differ.

**Step 5c: Verify and commit**

View pools index and new pool; commit.

```bash
git add app/views/pools/index.html.erb app/views/pools/new.html.erb
git commit -m "style: pools index card and new pool form consistency"
```

---

### Task 6: Pool show — cards and standings list

**Files:**
- Modify: `app/views/pools/show.html.erb`

**Step 1: Card pattern for sections**

Ensure “Standings” and “Tournaments in this pool” sections use the same card pattern: `border border-gray-200 rounded-lg p-4 bg-white shadow-sm` (add `shadow-sm` if missing). Section titles: `text-lg font-semibold text-gray-900 mb-2` or `mb-3`.

**Step 2: Standings list spacing**

Use consistent list spacing: `space-y-2` or `space-y-3` for the standings list. Optionally add a thin divider between rows (e.g. `divide-y divide-gray-100` on a wrapper) or alternating `bg-gray-50/50` for each row for scannability. Keep “Leave pool” / “Remove” as danger-style buttons (`text-red-600 hover:text-red-700 border border-red-300`).

**Step 3: Tournaments section**

Keep the same card style; ensure “Add tournament” form uses primary button and that the select input uses the same border/radius as other forms.

**Step 4: Verify and commit**

Load pool show; check standings and tournaments sections. Commit.

```bash
git add app/views/pools/show.html.erb
git commit -m "style: pool show cards and list spacing"
```

---

### Task 7: Picks views and partials

**Files:**
- Modify: `app/views/picks/index.html.erb`
- Modify: `app/views/picks/new.html.erb`
- Modify: `app/views/picks/edit.html.erb`
- Modify: `app/views/picks/_tournament_with_picks.html.erb`
- Modify: `app/views/picks/_tournament_pool_picks.html.erb`

**Step 1: Picks index**

Ensure both sections use the shared card pattern: `border border-gray-200 rounded-lg p-4 bg-white shadow-sm`. Section titles `text-lg font-semibold text-gray-900 mb-2`. List spacing consistent.

**Step 2: Picks new/edit**

Ensure form containers and inputs match auth/pool form styles (same input classes, primary submit button). No new structure unless pages currently differ.

**Step 3: Partial _tournament_with_picks**

Keep content; ensure any wrapper or text classes align with tokens (e.g. `text-gray-700`, `text-gray-500` for secondary). Links keep `text-emerald-600 hover:underline`.

**Step 4: Partial _tournament_pool_picks**

Update the section wrapper to match card pattern: `rounded-lg` (instead of `rounded-md` if present), `shadow-sm`, and `border border-gray-200`. Keep header and table structure; ensure table uses consistent `divide-y divide-gray-200` and cell padding.

**Step 5: Verify and commit**

View pool show (which uses both partials), picks index, new pick, edit pick. Commit.

```bash
git add app/views/picks/index.html.erb app/views/picks/new.html.erb app/views/picks/edit.html.erb app/views/picks/_tournament_with_picks.html.erb app/views/picks/_tournament_pool_picks.html.erb
git commit -m "style: picks views and partials card consistency"
```

---

### Task 8: Tournaments index and show; rules; pool show_join

**Files:**
- Modify: `app/views/tournaments/index.html.erb`
- Modify: `app/views/tournaments/show.html.erb` (if present and has layout)
- Modify: `app/views/landing/rules.html.erb`
- Modify: `app/views/pools/show_join.html.erb`

**Step 1: Tournaments index**

Wrap content in a card or apply consistent spacing: page title `text-2xl font-bold text-gray-900 mb-4`; list in a card `border border-gray-200 rounded-lg p-4 bg-white shadow-sm` with list items using `text-emerald-600 hover:underline` and spacing `space-y-2`.

**Step 2: Tournaments show**

If the view exists, apply same card/title conventions. If minimal, ensure at least title and body hierarchy.

**Step 3: Rules page**

Keep structure; ensure section headings use `text-xl font-semibold text-gray-900` or `text-2xl` for h1, and `space-y-2` / `space-y-4` within sections. Consistent `text-gray-700 leading-relaxed` for body.

**Step 4: Pool show_join**

If this is a join/invite view, use the same card and button patterns (primary CTA, consistent padding).

**Step 5: Verify and commit**

Click through tournaments, rules, and join flow. Commit.

```bash
git add app/views/tournaments/index.html.erb app/views/tournaments/show.html.erb app/views/landing/rules.html.erb app/views/pools/show_join.html.erb
git commit -m "style: tournaments, rules, and show_join consistency"
```

---

### Task 9: Optional sporty accents

**Files:**
- Modify: `app/views/landing/index.html.erb` (if not done in Task 3)
- Modify: `app/views/pools/show.html.erb` and/or `app/views/picks/index.html.erb` (standings)

**Step 1: Landing hero accent (optional)**

If not already added in Task 3: add a very subtle gradient or tint to the hero section only (e.g. `bg-gradient-to-b from-emerald-50/40 to-transparent`). Skip if keeping hero plain.

**Step 2: Standings rank badge or accent**

On pool show and/or picks index standings list: for the first-ranked user, add a small “1st” badge (e.g. `inline-flex items-center rounded-full bg-amber-100 text-amber-800 text-xs font-medium px-2 py-0.5` or similar) next to their name, or add a thin left border in emerald to the first row. One light touch only; do not change data or structure.

**Step 3: Verify and commit**

View landing and pool standings; commit.

```bash
git add app/views/landing/index.html.erb app/views/pools/show.html.erb app/views/picks/index.html.erb
git commit -m "style: optional sporty accents on landing and standings"
```

---

### Task 10: Final pass — buttons and forms consistency

**Files:**
- Scan all modified views (layout, landing, auth, pools, picks, tournaments, rules, show_join)

**Step 1: Primary buttons**

Ensure every primary action uses: `bg-emerald-600 text-white … rounded hover:bg-emerald-700` (and consistent padding e.g. `px-4 py-2` or `px-3 py-1.5` for smaller buttons).

**Step 2: Secondary and danger**

Secondary: outline or gray (`border border-gray-300 bg-gray-100 hover:bg-gray-200 text-gray-700`). Danger: `text-red-600 hover:text-red-700 border border-red-300 hover:border-red-400` for Remove/Leave.

**Step 3: Form inputs**

All text/email/password inputs: `w-full rounded border border-gray-300 px-3 py-2 focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500`. Labels: `block text-sm font-medium text-gray-700 mb-1`.

**Step 4: Verify and commit**

Click through all main flows; fix any outlier. Commit.

```bash
git add -A
git commit -m "style: final button and form consistency pass"
```

---

## Execution handoff

Plan complete and saved to `docs/plans/2026-03-03-ui-spruce-up.md`.

**Two execution options:**

1. **Subagent-driven (this session)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.
2. **Parallel session (separate)** — Open a new session with executing-plans and run through the plan with checkpoints.

Which approach do you want?

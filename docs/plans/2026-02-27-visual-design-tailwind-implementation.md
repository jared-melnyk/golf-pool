# Golf Pool Visual Design (Tailwind) Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add Tailwind CSS and restyle the app so all existing views use a consistent, readable, mobile-friendly UI with no inline styles.

**Architecture:** Integrate Tailwind via tailwindcss-rails; keep layout and view structure unchanged. Replace inline styles and plain markup with Tailwind utility classes. Use a simple green/gray theme and shared patterns (header, flash, buttons, forms, lists).

**Tech Stack:** Rails 8, Propshaft, tailwindcss-rails, ERB.

**Design reference:** `docs/plans/2026-02-27-visual-design-tailwind-design.md`

---

## Task 1: Add Tailwind CSS to the project

**Files:**
- Modify: `Gemfile`
- Created by installer: (e.g. `config/tailwind.config.js`, Tailwind CSS entry file, possibly `Procfile.dev`)

**Step 1: Add the gem**

Run:

```bash
cd /Users/jaredmelnyk/Code/golf_pool
bundle add tailwindcss-rails
```

Expected: Gemfile includes `gem "tailwindcss-rails"` and bundle install succeeds.

**Step 2: Run the Tailwind installer**

Run:

```bash
./bin/rails tailwindcss:install
```

Expected: Installer creates Tailwind config and CSS source file(s). It may add or change a `stylesheet_link_tag` in `app/views/layouts/application.html.erb`. Note any new stylesheet names (e.g. `"tailwind"` or `"application"`).

**Step 3: Ensure layout loads Tailwind output**

- Open `app/views/layouts/application.html.erb`.
- If the installer added a second `stylesheet_link_tag` for Tailwind, keep it.
- If the app uses a single `stylesheet_link_tag :app` and the installer did not add a Tailwind link, check the Tailwind install output: the gem may have configured the build to output into the same asset path. If Tailwind CSS is built to a separate file, add `stylesheet_link_tag "tailwindcss", "data-turbo-track": "reload"` (or the name the installer used) so the layout loads both app and Tailwind.

**Step 4: Build Tailwind and verify**

Run:

```bash
./bin/rails tailwindcss:build
```

Expected: Build completes without errors. Start the server and open the app in the browser; confirm no CSS-related errors and the page still renders (may still look plain).

**Step 5: Commit**

```bash
git add Gemfile Gemfile.lock config/ app/assets/ app/views/layouts/application.html.erb
git status
git commit -m "chore: add Tailwind CSS via tailwindcss-rails"
```

---

## Task 2: Configure Tailwind content paths and theme (optional but recommended)

**Files:**
- Modify: `config/tailwind.config.js` (or the config file created by the installer)

**Step 1: Verify content paths**

Ensure the `content` (or equivalent in Tailwind v4) array includes:

- `./app/views/**/*.{erb,html}`
- `./app/helpers/**/*.rb`
- `./app/components/**/*.{erb,rb}` (if present)

So Tailwind scans all view and helper files. Adjust path format to match the config (e.g. paths relative to config file).

**Step 2: Add theme extension for golf palette (optional)**

In the Tailwind config, extend `theme.colors` with a primary green if desired, e.g. `primary: { DEFAULT: '#059669', ... }` (emerald-600) so views can use `bg-primary` / `text-primary`. If the config format is CSS-based (Tailwind v4), add the same in the main CSS file with `@theme`.

**Step 3: Commit**

```bash
git add config/tailwind.config.js
git commit -m "chore: ensure Tailwind content paths and optional theme"
```

---

## Task 3: Restyle application layout (header, flash, main wrapper)

**Files:**
- Modify: `app/views/layouts/application.html.erb`

**Step 1: Remove inline styles from header**

Replace the existing `<header style="...">` with Tailwind classes:

- Container: `flex`, `justify-between`, `items-center`, `px-4` (or `px-6`), `py-3`, `border-b`, `border-gray-200`, `bg-white` (or `bg-gray-50`).
- Logo link: e.g. `text-xl font-semibold text-gray-900` (or `text-primary` if theme added), no underline or `hover:underline`.
- Nav container: `flex items-center gap-3` (or `gap-4`).
- User name: `text-gray-700`.
- Buttons and links: use `rounded px-3 py-1.5` (or similar); primary action `bg-emerald-600 text-white hover:bg-emerald-700`, secondary/danger as needed.

**Step 2: Style flash messages**

Replace the current flash block with a single wrapper (e.g. a `div` with `class="..."` and `role="alert"`):

- Notice: `bg-emerald-50 border border-emerald-200 text-emerald-800 px-4 py-3 rounded-lg` (or equivalent).
- Alert: `bg-red-50 border border-red-200 text-red-800 px-4 py-3 rounded-lg`.
- Container: e.g. `max-w-4xl mx-auto px-4 mt-2` so flash sits above main content with same width.

**Step 3: Wrap main content**

Wrap `<%= yield %>` in a `<main>` tag with classes for max-width and padding, e.g. `class="max-w-4xl mx-auto px-4 py-6"`.

**Step 4: Verify**

Load the app; confirm header, flash (trigger once with a notice/alert), and main content layout look correct and there are no inline styles left in the layout.

**Step 5: Commit**

```bash
git add app/views/layouts/application.html.erb
git commit -m "style: apply Tailwind to layout (header, flash, main)"
```

---

## Task 4: Restyle auth views (sessions/new, users/new)

**Files:**
- Modify: `app/views/sessions/new.html.erb`
- Modify: `app/views/users/new.html.erb`

**Step 1: Sessions new**

- Wrap in a container: e.g. `max-w-md mx-auto` or a card `border border-gray-200 rounded-lg p-6 shadow-sm`.
- `h1`: `text-2xl font-bold text-gray-900 mb-6`.
- Form: use `space-y-4`. Each label: `block text-sm font-medium text-gray-700 mb-1`. Inputs: `w-full rounded border border-gray-300 px-3 py-2 focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500`.
- Submit: `bg-emerald-600 text-white px-4 py-2 rounded hover:bg-emerald-700`.
- Link "Sign up": `text-emerald-600 hover:underline`.

**Step 2: Users new**

Apply the same patterns (card or container, heading, form spacing, input and button classes) so sign-up matches sign-in visually.

**Step 3: Commit**

```bash
git add app/views/sessions/new.html.erb app/views/users/new.html.erb
git commit -m "style: Tailwind for sign-in and sign-up"
```

---

## Task 5: Restyle pools index and show

**Files:**
- Modify: `app/views/pools/index.html.erb`
- Modify: `app/views/pools/show.html.erb`

**Step 1: Pools index**

- `h1`: `text-2xl font-bold text-gray-900 mb-4`.
- "New pool" link: button-style `inline-block bg-emerald-600 text-white px-4 py-2 rounded hover:bg-emerald-700`.
- Section headings (`h2`): `text-lg font-semibold text-gray-900 mt-6 mb-2`.
- Lists: `list-disc list-inside space-y-2` or `space-y-1`; list item links: `text-emerald-600 hover:underline`.
- Join / action buttons: small button classes (e.g. `rounded px-2 py-1 text-sm`).
- Footer links: `text-gray-600 hover:text-gray-900` with spacing between (e.g. `flex gap-4`).

**Step 2: Pools show**

- Same typography for `h1` and `h2`.
- Standings list: use `list-decimal list-inside space-y-2` and optional card wrapper `border rounded-lg p-4`.
- Tournament list / member list: `space-y-2`; each item in a row with flex; Remove button: danger style `text-red-600 hover:text-red-700` or outline button.
- Forms (add tournament, add member): select and submit on one line with `flex gap-2 items-center`; select with `rounded border border-gray-300 px-2 py-1`.
- Bottom links: same as index.

**Step 3: Commit**

```bash
git add app/views/pools/index.html.erb app/views/pools/show.html.erb
git commit -m "style: Tailwind for pools index and show"
```

---

## Task 6: Restyle pool show_join and pools new

**Files:**
- Modify: `app/views/pools/show_join.html.erb`
- Modify: `app/views/pools/new.html.erb`

**Step 1: show_join**

Apply same layout and component patterns: heading, optional card, form or confirmation text, primary button, back link.

**Step 2: new**

Form for creating a pool: container/card, label + input, submit button. Match sessions/users form styling.

**Step 3: Commit**

```bash
git add app/views/pools/show_join.html.erb app/views/pools/new.html.erb
git commit -m "style: Tailwind for pool join and new pool"
```

---

## Task 7: Restyle tournaments and sync views

**Files:**
- Modify: `app/views/tournaments/index.html.erb`
- Modify: `app/views/tournaments/show.html.erb`
- Modify: `app/views/tournaments/new.html.erb`
- Modify: `app/views/sync/index.html.erb`

**Step 1: tournaments index**

- `h1`, link "Add tournament", list of tournaments with links and dates, footer links. Use same heading, list, and link styles as pools.

**Step 2: tournaments show**

- Title, content (e.g. field or details), actions. Use cards/sections if the view has multiple blocks.

**Step 3: tournaments new**

- Form with labels and inputs; submit button. Match other form styling.

**Step 4: sync index**

- Heading, any tables or lists, links. Keep layout consistent with rest of app.

**Step 5: Commit**

```bash
git add app/views/tournaments/ app/views/sync/
git commit -m "style: Tailwind for tournaments and sync"
```

---

## Task 8: Restyle picks views

**Files:**
- Modify: `app/views/picks/index.html.erb`
- Modify: `app/views/picks/new.html.erb`
- Modify: `app/views/picks/edit.html.erb`

**Step 1: picks index**

- `h1` with pool name; standings list (ordered); tournaments list with "Edit" / "Make picks" links. Same list and link patterns as pool show.

**Step 2: picks new and edit**

- Form for selecting golfers: headings, selects or inputs, submit. Use same form and button styles; ensure dropdowns and buttons are touch-friendly.

**Step 3: Commit**

```bash
git add app/views/picks/
git commit -m "style: Tailwind for picks index, new, edit"
```

---

## Task 9: Restyle golfers views

**Files:**
- Modify: `app/views/golfers/index.html.erb`
- Modify: `app/views/golfers/new.html.erb`

**Step 1: Apply same patterns**

- Index: heading, "New golfer" link, list of golfers, footer links.
- New: form with labels and inputs, submit. Match other forms.

**Step 2: Commit**

```bash
git add app/views/golfers/
git commit -m "style: Tailwind for golfers index and new"
```

---

## Task 10: Final pass and dev workflow

**Files:**
- Modify: `Procfile.dev` or `bin/dev` (if present and Tailwind watch should run with server)

**Step 1: Confirm dev workflow**

- If `bin/dev` exists and starts only the Rails server, add the Tailwind watch process so CSS rebuilds on change (see tailwindcss-rails docs: often `rails tailwindcss:watch` or similar in Procfile.dev).
- If the gem added a Procfile.dev, use `bin/dev` to run both server and Tailwind watch during development.

**Step 2: Final verification**

- Open each major route: sign in, sign up, pools list, one pool show, picks, tournaments, golfers, sync. Confirm no inline styles remain, typography and spacing are consistent, and layout is usable on a narrow viewport (e.g. resize browser or use devtools device mode).

**Step 3: Commit (if Procfile.dev or bin/dev changed)**

```bash
git add Procfile.dev bin/dev
git commit -m "chore: run Tailwind watch with dev server"
```

---

## Execution options

Plan complete and saved to `docs/plans/2026-02-27-visual-design-tailwind-implementation.md`.

**Two execution options:**

1. **Subagent-driven (this session)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.
2. **Parallel session (separate)** — Open a new session with executing-plans and run through the plan with checkpoints.

Which approach do you want?

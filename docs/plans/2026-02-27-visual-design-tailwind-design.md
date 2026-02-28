# Golf Pool Visual Design — Design

**Goal:** Improve the look and feel of the golf_pool app by introducing Tailwind CSS and applying a consistent, readable, mobile-friendly UI across all existing views. No new features or pages.

**Approach:** Add Tailwind via the tailwindcss-rails gem, define a minimal theme (colors, typography), then systematically replace inline styles and plain HTML with Tailwind utility classes in the layout and all ERB views.

---

## Tech choice

- **Tailwind CSS** via **tailwindcss-rails** gem. The gem integrates Tailwind’s build into the Rails asset pipeline (no separate Node app). Propshaft continues to serve assets; the gem adds the Tailwind CLI and config.
- **No Bootstrap, no new JS UI library.** Styling only; Turbo and Stimulus remain unchanged.

---

## Layout

- **Page structure (unchanged):** `<header>` + optional flash + `<main>` content.
- **Header:** Full-width bar, flex layout: logo/title left, nav right. Remove all inline styles; use Tailwind for padding, border, background, typography, and spacing between nav items.
- **Flash:** Single area above main content. Notice = success styling (e.g. green background/border). Alert = error styling (e.g. red/amber). Dismissible optional later; not in initial scope.
- **Main:** Constrained max-width container (e.g. `max-w-4xl mx-auto`), comfortable horizontal padding, vertical spacing between sections.

---

## Theming

- **Palette:** Golf-oriented but neutral. Primary accent: green (e.g. Tailwind `emerald` or `green`). Backgrounds: white/light gray; borders and secondary text: gray. Buttons: primary (green), secondary (gray outline), danger (red) where needed (e.g. Remove, Sign out).
- **Typography:** Use Tailwind’s default font stack (or one `font-sans`). Clear hierarchy: one `h1` per page, `h2` for sections, consistent spacing (e.g. `space-y-4` / `space-y-6`).
- **Responsive:** Layout and nav work on small screens (stack or collapse if needed). Lists and forms remain usable on mobile; touch-friendly tap targets for links and buttons.

---

## Components to style

1. **Header / nav** — Logo link, user name, Sign out / Sign in / Sign up. No dropdowns in initial scope.
2. **Flash messages** — Block with padding, rounded corners, appropriate background and text color.
3. **Links** — Underline or color distinction for primary actions; consistent hover state.
4. **Buttons** — `button_to` and `f.submit`: primary (solid green), secondary (outline), danger (red outline or solid for destructive actions).
5. **Forms** — Labels above or beside inputs; inputs with border, padding, focus ring; grouped in cards or bordered sections where it helps (e.g. Sign in, Add tournament).
6. **Lists** — Standings (ordered list), tournament lists, member lists: clear list styling, spacing, optional alternating row or card per item.
7. **Cards/sections** — Optional card (border + padding + rounded) for logical blocks (e.g. “Standings”, “Tournaments in this pool”, “Members”) to separate content.
8. **Tables (if any)** — Bordered or striped; not required if the app uses only lists.

---

## Views in scope (no behavior change)

- **Layout:** `layouts/application.html.erb`
- **Auth:** `sessions/new`, `users/new`
- **Pools:** `pools/index`, `pools/show`, `pools/new`, `pools/show_join`
- **Tournaments:** `tournaments/index`, `tournaments/show`, `tournaments/new`
- **Picks:** `picks/index`, `picks/new`, `picks/edit`
- **Golfers:** `golfers/index`, `golfers/new`
- **Sync:** `sync/index`

Shared partials (e.g. flash) can be introduced if they reduce duplication; otherwise styling in layout is sufficient.

---

## Out of scope

- New pages or features.
- JavaScript behavior changes (Turbo/Stimulus unchanged).
- Dark mode or multiple themes.
- PWA manifest or icon changes (already present).

---

## Success criteria

- No inline styles in layout or views; styling via Tailwind classes (and minimal custom CSS only if needed).
- Consistent header, flash, buttons, forms, and lists across all listed views.
- Readable typography and spacing; clear visual hierarchy.
- Usable and legible on mobile viewport.
- Existing specs and manual flows still pass; no change to routes or controller behavior.

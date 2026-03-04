# LongShot UI Spruce-Up — Design

**Approved:** 2026-03-03

**Direction:** Clean-refined (Notion / Headspace / Airbnb style) with optional light sporty accents. Both landing and logged-in app in one pass.

---

## 1. Principles and design tokens

- **Typography:** Single font family (system stack or one clean web font, e.g. Inter or DM Sans). Simple scale: one size/weight for page titles (2xl–3xl bold), one for section titles (lg–xl semibold), one for body, one for small/muted. Consistent line-height and heading-to-content spacing.
- **Color:** Keep gray-50 background, white surfaces, emerald primary. Clear hierarchy: gray-900 primary text, gray-700 secondary, gray-500/600 muted. Optional: one slightly richer emerald for primary actions.
- **Spacing and layout:** Consistent vertical rhythm (e.g. 4/6/8). Main content stays `max-w-4xl` with consistent horizontal padding.
- **Surfaces:** Cards/panels use consistent border (e.g. `border-gray-200`), radius (e.g. `rounded-lg`), and light shadow (`shadow-sm`) where elevation is needed.
- **Focus and interaction:** Single consistent focus ring (emerald) for links, buttons, and form controls.

---

## 2. Landing and auth

- **Landing:** Hero with clear hierarchy (title → subtitle → primary/secondary CTAs) and more breathing room. "What is LongShot?" and "How scoring works" as two sections with consistent heading and body spacing; slightly more vertical space between sections. Optional: very subtle background (e.g. soft gradient or single tint) so the hero doesn’t sit flat on gray-50. One clear "Get started" CTA at bottom.
- **Sign in / Sign up:** Centered card unchanged in structure. Align with tokens: same radius, padding, input/button styles. Optional `shadow-sm` so the card feels slightly elevated. Labels and helper text use the same type hierarchy.

---

## 3. App shell and interior

- **Header:** Keep structure; consistent height and padding; nav links and sign-out use the same font weight and hover state.
- **Sidebar:** Keep layout and "This pool" block. Make active/current-context state obvious (e.g. background or border-left on current pool / "My picks").
- **Main content:** Same max-width and padding. All major content blocks (Standings, Tournaments in this pool, pool list, picks, etc.) use the same card pattern: white, `border-gray-200`, `rounded-lg`, consistent inner padding, section title at top.
- **Lists:** Standings and tournament lists get consistent spacing; optional dividers or alternating row background for scannability.
- **Buttons and forms:** Three patterns—primary (emerald fill), secondary (outline or gray), danger (red for remove/leave). Same padding and radius. Form inputs: consistent height, border, radius, emerald focus ring; labels above with consistent spacing.

---

## 4. Optional sporty accents

- **Landing only:** One light touch—e.g. very subtle gradient in hero (green tint) or one abstract line/shape suggesting motion/competition, no literal golf imagery. Or skip and keep hero plain.
- **Pool / standings:** Optional small competitive cue—e.g. simple "1st" or rank badge next to leader, or thin emerald accent (left border or underline) on standings card. Rest of app stays clean.

---

## Reference

- Implementation plan: `docs/plans/2026-03-03-ui-spruce-up.md`

# Pre-trip UX polish

**Date:** 2026-07-13  
**Status:** Approved for planning  
**Context:** Michigan trip Jul 16–17; Events/Games are the product surface for the week.

## Goals

1. Make On-Course games (Events / Games) the front door; stop surfacing PGA Pools.
2. Put event standings above the roster on the event show page.
3. Give players light, on-demand format rules on the game/scorecard page without cluttering on-course scoring.

## Non-goals

- Deleting pool routes, models, or controllers (deep links still work).
- Changing event `draft` / `active` / `completed` behavior.
- A dedicated on-course Rules nav page or event-level formats page.
- Pot / side-bet / trip logistics copy in the app.
- Full stroke-allocation tutorials (HI → CH → PH detail).

## Background notes (no code)

### Event status

`Event::STATUSES` = `draft`, `active`, `completed`.

| Status | Behavior today |
|--------|----------------|
| `draft` | Default. Index shows `(Draft)`. Otherwise same as active for joins, rounds, games, standings. |
| `active` | Same capabilities as draft; no side effects on flip. |
| `completed` | Blocks round create/edit/delete (`RoundsController#require_event_not_completed!`). Reversible via commissioner status dropdown. |

**Safe for trip setup:** flipping draft ↔ active does not lock rounds or games.

---

## 1. Hide PGA Pools from nav + home

### Changes

**Sidebar** (`app/views/layouts/application.html.erb`):

- Remove the **PGA Pools** section head and links: My pools, New pool, Rules.
- Remove the contextual **This pool** block (`@pool` member links).
- Leave **On-Course games** (Games, Events) and Admin / This game / This event blocks as they are.

**Home redirect** (`LandingController#index`):

- When `current_user` is present, `redirect_to events_path` (today: `pools_path`).

### Unchanged

- `rules_path` / `landing#rules` and all `/pools/*` routes remain.
- Guest marketing landing (`landing/index`) can stay pool-oriented for now (out of scope).

---

## 2. Event show — demote members list

**File:** `app/views/events/show.html.erb`

### Current order

1. Header / status / actions  
2. Members  
3. Overall low net (`shared/individual_standings`)  
4. Rounds (with per-round standings)

### New order

1. Header / status / actions  
2. Overall low net  
3. Rounds  
4. Members (same table and commissioner controls; moved only)

No collapse or compact redesign.

---

## 3. Collapsed format rules on game show

### Placement

Render **once** on `games/show.html.erb` when a scorecard is present, **above** both:

- Mobile arena (`md:hidden`)
- Desktop scorecard (`hidden md:block`)

So phone and desktop share the same rules UI. Do **not** put the blurb only inside desktop scorecard partials (mobile would miss it).

### UI pattern

Native `<details>` collapsed by default:

| Part | Content |
|------|---------|
| `<summary>` | `{Format label} · {allowance}% PH · Rules` |
| Body | 2–4 sentences for that format (see copy below) |

Use existing helpers/labels (`game_type_label`, `Game#playing_handicap_allowance_percent`) so the summary stays accurate if allowances change.

### Implementation shape

- Shared partial, e.g. `app/views/games/_format_rules.html.erb`, local: `game`.
- Switch on `game.game_type` for body copy (or small helper returning summary + body HTML/text).
- Remove the always-visible helper paragraphs from desktop scorecard partials so rules are not duplicated on `md+`:
  - `_scorecard_vegas.html.erb`
  - `_scorecard_cha_cha_cha.html.erb`
  - `_scorecard_forty_score.html.erb` (amber callout → move content into `<details>` body; keep Fried Egg link in the body)
  - Best Ball `_scorecard.html.erb` has no blurb today; no removal needed

### Approved copy (bodies)

Keep tight; players expand once on the first tee.

**Best Ball (85% PH)**  
Lowest **net** score among teammates counts as the team hole score. Team total is the sum of 18 hole scores; lowest total wins. Playing handicap uses **85%** of course handicap (PH capped at 36).

**Cha-Cha-Cha (85% PH)**  
Count the lowest **1**, then **2**, then **3** net scores per hole; the pattern repeats every three holes (1→4→7…, 2→5→8…, 3→6→9…). Team hole score is the sum of those nets. Playing handicap uses **85%** of course handicap (PH capped at 36).

**40 Score (100% PH)**  
Your group selects counted net scores: **40** picks for a foursome, **30** for a threesome (0–4 picks per hole). Leaderboard ranks by **net vs par** on counted holes. Threesomes also get a scaled line so 30-pick and 40-pick groups compare fairly. Playing handicap uses **100%** of course handicap. Link: Fried Egg “How it works” (same URL as today).

**Vegas (100% PH)**  
Each team combines two **net** scores into a two-digit number (lower net → tens digit). Nets above 9 count as 9. A net birdie or better flips the **opponent’s** digit order. Lower team number wins the hole; points accumulate on a wash. Playing handicap uses **100%** of course handicap.

### Out of scope for this partial

- Overall low-net explanation (already on the event standings partial).
- Trip pot / sit-out notes.

---

## Files touched (expected)

| Area | Files |
|------|--------|
| Nav / home | `application.html.erb`, `landing_controller.rb` |
| Event show | `events/show.html.erb` |
| Format rules | `games/show.html.erb`, new `games/_format_rules.html.erb` (or helper), scorecard partials that currently show always-on blurbs |
| Specs | Request/system specs that assert pools nav links, home redirect, event show section order, and/or scorecard helper text |

---

## Success criteria

- Logged-in user hitting `/` lands on Events; sidebar has no Pools / Rules / This pool.
- Event show shows Overall low net and Rounds before Members.
- Opening any active game shows a collapsed Rules control with correct format + PH%; expanding shows the approved blurb; desktop scorecards no longer repeat the old always-visible helpers.

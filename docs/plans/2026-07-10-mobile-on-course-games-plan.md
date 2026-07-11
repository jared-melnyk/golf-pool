# Mobile On-Course Games — Design & Implementation Plan

**Status:** Approved — executing (target: all 4 formats in ~4 days)  
**Project:** `long_shot` (On-Course games)  
**Date:** 2026-07-10  
**Decisions locked 2026-07-10:** (1) hole stepper default on mobile; (2) any teammate may enter scores for the whole team; (3) ship all four formats before the trip.  

**Related:** [On-Course Games design](2026-05-06-on-course-games-design.md), [Ad-hoc games design](2026-05-18-ad-hoc-games-design.md), [Vegas design](2026-06-10-vegas-design.md), [Pre-trip testing plan](2026-06-10-golf-trip-pre-trip-testing-plan.md), [Mobile sidebar](2026-03-01-mobile-sidebar-drawer-design.md)

---

## 1. Why this exists

Everyone on the Michigan trip will use **phones** for score entry and for checking standings after (and during) rounds. Today’s game UI is a **desktop spreadsheet**: wide HTML tables, tiny inputs, horizontal scroll. The app shell (hamburger nav) is mobile-aware; the **games arena is not**.

This plan covers a **mobile-first redesign** of the games experience — primarily **scorecard entry**, also **leaderboards / wash** so post-round browsing works on a phone.

**Non-goals for this pass**
- Event-wide tournament leaderboard (see [event leaderboard design](2026-06-10-event-leaderboard-design.md))
- Live multiplayer sync / presence
- Native app / PWA install (meta tags already exist; out of scope)
- Changing scoring math or format rules
- Adding Bootstrap (stay on Tailwind)

---

## 2. Product principles

1. **Phone-first, desktop second** — design the entry flow for one-handed use in a cart; desktop keeps a denser full-card view.
2. **One hole at a time for entry** — primary mobile mode is hole-centric, not an 18×N grid.
3. **Standings always one tap away** — leaderboard / wash visible without hunting through tables.
4. **Big targets** — score controls ≥ ~44px touch height; avoid blur-only save fights with mobile keyboards where possible.
5. **Same backend contract** — keep `PATCH …/hole_scores/:id` + Turbo streams; redesign DOM, not APIs (unless a thin helper endpoint is clearly better).
6. **Permissions match the server** — only show editable controls the current user is allowed to change.

---

## 3. Current state (constraints)

| Area | Today |
|------|--------|
| Layout | Per-team `w-full` tables, `overflow-x-auto`, 18 hole rows |
| Entry | `number_field` `w-11`, save on **blur** (`score_entry_controller.js`) |
| Who edits gross | Managers: anyone; players: **own GTP only** (server) |
| Who edits 40 picks | Managers or **any teammate** |
| Lock | `completed` → read-only; managers complete/reopen |
| Formats | Best Ball, Cha-Cha-Cha, 40 Score, Vegas (wash, no ranked LB) |
| UI bug | `scorecard_can_edit?` enables **all** team inputs if you’re on any team — server still rejects others’ gross |

---

## 4. Proposed UX

### 4.1 Game show — two modes (responsive)

| Viewport | Primary UI |
|----------|------------|
| **&lt; md (phone)** | **Hole stepper** + compact standings strip |
| **≥ md (tablet/desktop)** | Keep improved full scorecard tables (current grid + dividers), optionally with sticky first columns |

Do **not** ship two separate pages. One `games#show` with:

- Mobile block: `md:hidden`
- Desktop block: `hidden md:block`

Shared Turbo targets where practical; format-specific mobile partials where not.

### 4.2 Mobile: Hole stepper (score entry)

**Chrome**

```
[ ← Hole 7 of 18 → ]     Par 4 · SI 11
─────────────────────────────────────
Standings: Team B −2 · You T2     [All holes ▾]
─────────────────────────────────────
  Kevin     [ − ]  5  [ + ]   ●●     Net 3
  Lannon    [ − ]  7  [ + ]   ●      Net 5
  ─────────────────────────
  Best ball / Team net / Team # :  3
─────────────────────────────────────
[ Prev ]              [ Next hole ]
```

**Behaviors**

- Default hole = first incomplete hole for the viewer’s team (or hole 1).
- Persist current hole in `sessionStorage` (or query `?hole=7`) so refresh/Turbo doesn’t lose place.
- **+/− steppers** as primary control; optional tap-to-type still available.
- Save on stepper tap (immediate PATCH) and on input `change` — reduce reliance on `blur`.
- Stroke dots stay next to the player row.
- Only render editable steppers for GTPs the user may edit; others are read-only numbers.
- Managers see all players editable (as today).

**Per-format hole footer**

| Format | Hole result shown |
|--------|-------------------|
| Best Ball | Best ball net |
| Cha-Cha-Cha | Count badge (1/2/3) + team net |
| 40 Score | Each player’s Count? toggle (large checkbox/switch) + running pick count toward 30/40 |
| Vegas | Both teams’ numbers, points, running wash (single foursome — show all 4 players on one hole screen, grouped by team) |

**Vegas mobile note:** One game = one foursome. Prefer **one hole view with Team A / Team B sections** rather than three separate tables. Match summary can be a second tab (“Wash”) listing hole results.

### 4.3 Mobile: Standings

**Always-visible strip** under the hole chrome (one line + expand):

- Best Ball / Cha-Cha-Cha / 40 Score → rank + key metric (total net / competition vs par)
- Vegas → wash label (“Team A leads by 16”)

**Full standings panel** (sheet or `#standings` section):

- Reuse leaderboard data; restyle as stacked cards or a simple 2–3 column list (Rank · Team · Score) — no 7-column table on phone.
- 40 Score: show Actual and Competition on two lines per team.
- Link/button “Full card” opens read-only all-holes view (accordion per team or horizontal hole chips) for dispute resolution.

### 4.4 Mobile: All-holes / review mode

Secondary, not the entry default:

- Vertical list of holes 1–18; each row shows hole #, par, team result, and whether scores are complete.
- Tap a row → jump stepper to that hole.
- Completed games land here (or on standings) by default instead of hole 1 entry.

### 4.5 Desktop

Keep current table scorecards (with recent alignment/grid fixes). Optional later: sticky Hole/Par columns. No requirement to remove tables on `md+`.

### 4.6 Permissions alignment (include in this project)

Update helpers so UI matches `HoleScoresController`:

- `scorecard_can_edit_gross?(game, gtp)` — manager or `gtp.user == current_user`
- `scorecard_can_edit_forty_pick?(game, gtp)` — manager or teammate of current user
- Stop enabling every input just because the user is on a team

---

## 5. Technical approach

### 5.1 Keep

- `HoleScoresController#update` (gross + forty_pick_only)
- Scorecard services / `GameScorecardBuilder` (data shape unchanged)
- Turbo Stream responses — **extend** replace targets for mobile DOM ids

### 5.2 Likely new / heavily changed files

| Area | Files |
|------|--------|
| Mobile shell | `app/views/games/show.html.erb`, new `games/mobile/_hole_stepper.html.erb`, `games/mobile/_standings_strip.html.erb`, format-specific `games/mobile/_hole_*` |
| Desktop | Existing `_scorecard*.html.erb` (wrap in `hidden md:block`) |
| Cells | Shared stepper partial; larger touch styles on `_gross_score_field` when used in mobile |
| Turbo | `hole_scores/update.turbo_stream.erb` — replace mobile hole panel + standings strip + desktop cells |
| JS | `score_entry_controller.js` — stepper actions, hole navigation controller (`hole_stepper_controller.js`) |
| Helper | `games/scorecard_helper.rb` — per-GTP edit flags |
| Layout (optional) | Slightly wider or full-bleed main on game show only (`content_for :full_width`) |

### 5.3 Stimulus sketch

```
hole-stepper
  - currentHoleValue
  - showHole(n) / next / prev
  - sync URL or sessionStorage

score-entry (extend)
  - increment / decrement → set input → submit
  - submit on change (mobile)
  - keep focus restore for Turbo
```

### 5.4 Turbo replace strategy

After each score update, streams should refresh:

1. Mobile **current hole panel** (players + hole result)
2. Mobile **standings strip** (+ full standings if open)
3. Desktop cells (existing net / best ball / vegas rows / leaderboard)

Avoid full-page reload. Prefer one wrapper `dom_id(game, :mobile_hole)` replaced entirely per update (simpler than per-cell on mobile).

---

## 6. Phased delivery

### Phase 0 — Align edit permissions (½ day)

- Helper + view wiring; specs for who sees inputs
- No visual redesign yet; reduces confusion on trip

### Phase 1 — Mobile hole stepper for Best Ball (2–3 days)

- Show page responsive split
- Hole nav, +/− entry, standings strip, all-holes jump list
- Turbo replace for mobile panel
- Manual test on real iPhone Safari + Android Chrome

**Exit:** Can enter a full Best Ball round on a phone without horizontal scrolling.

### Phase 2 — Cha-Cha-Cha + 40 Score mobile (1–2 days)

- Count badge + team net on hole footer
- Large Count? controls; pick progress (e.g. 28/40)
- Card-style leaderboards on mobile

### Phase 3 — Vegas mobile (1–2 days)

- Four players / two teams on one hole screen
- Wash strip + hole history list
- Retire need to horizontally scroll Match table on phone

### Phase 4 — Polish (1 day)

- Completed-game defaults to standings / all-holes
- Touch target audit; safe-area / keyboard overlap
- Desktop sticky columns (optional)
- Update validation README note: “enter via mobile stepper in sim”

### Stretch (post-trip if needed)

- Teammate gross editing (product change — design doc said collaborative; code doesn’t)
- Offline / flaky-network queue
- Event-level mobile leaderboard

---

## 7. Testing plan

| Layer | What |
|-------|------|
| Request | Existing `hole_scores_spec` + cases for stepper params if any |
| Helper | Gross vs forty-pick editability |
| System / manual | Trip simulator on phone width (Chrome device mode + one real device) |
| Formats | One golden path each: BB, CCC, 40, Vegas — enter holes 1–3 on mobile UI |
| Regression | Desktop tables still update via Turbo |

---

## 8. Trip-week recommendation

| If time before Jul 16 | Do this |
|----------------------|---------|
| **~1 day** | Phase 0 + Phase 1 (Best Ball only) — most common? Actually trip order is Vegas → BB → CCC → 40. Prefer **Vegas + BB** if only two formats fit. |
| **~3–4 days** | Phases 0–3 (all formats) |
| **&lt; 1 day** | Skip redesign; use landscape + desktop tables; brief the group that commissioner enters scores |

**Suggested priority for this trip:** **Phase 0 → Phase 3 (Vegas) → Phase 1 (Best Ball) → Phase 2** — matches round order and pain (Vegas is first morning).

---

## 9. Decisions (locked 2026-07-10)

1. **Default mobile entry:** Hole stepper.
2. **Teammate gross editing:** **Any player on the team may enter gross scores for any teammate** (one scorer for the group). Managers still edit anyone. Align UI + `HoleScoresController` with this.
3. **Desktop:** Leave table scorecards; mobile gets the stepper (`md:` split).
4. **Scope before trip:** **All four formats** (Phases 0–3), ~4 days.

---

## 10. Success criteria

- [ ] On a phone-width viewport, score entry for a foursome needs **no horizontal scrolling**
- [ ] Primary controls are thumb-friendly (+/− or large fields)
- [ ] Standings / wash visible without leaving the entry context
- [ ] Editable fields match server authorization
- [ ] All four formats work on mobile (or explicitly deferred formats documented)
- [ ] Desktop scorecard remains usable
- [ ] `trip:simulate` dry-run completable on a phone

---

## 11. Implementation checklist

- [x] Confirm open decisions in §9
- [x] Phase 0 permissions (teammate scorekeeping)
- [x] Phase 1–3 mobile hole stepper (Best Ball, CCC, 40 Score, Vegas) — initial ship
- [ ] Phase 4 polish + device QA
- [ ] Link from pre-trip plan as new workstream

---

*Approved 2026-07-10. Mobile arena shipped; polish/QA remaining.*

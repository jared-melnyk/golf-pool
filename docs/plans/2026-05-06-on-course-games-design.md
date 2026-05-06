# On-Course Games — Design Specification

**Status:** Living document — consolidates decisions from [`2026-04-21-on-course-games-planning-handoff.md`](2026-04-21-on-course-games-planning-handoff.md) and follow-on design conversations (through 2026-05-07).  
**Project:** `long_shot` (single Rails app, one deploy).

---

## 1. Purpose

This document records **agreed product and technical direction** for the **On-Course** product area: event-based, in-person golf games (starting with **Best Ball**), alongside the existing **Pools** (PGA tournament pools).

It is the implementation-facing source of truth until superseded.

---

## 2. Product overview

### 2.1 Positioning

- **One application**, two top-level areas in navigation:
  - **Pools** — existing PGA pool product.
  - **On-Course** — events, rounds, games, scorecards, handicaps for live rounds.
- **Hosting:** existing stack (Render + PostgreSQL + DNS) remains; no second app for v1.
- **Terminology:** top-level entity is **`Event`** (not “trip” or “pool”).

### 2.2 Users, roles, access

- Users can belong to **multiple events**.
- **Roles (v1):** only two role strings:
  - **`commissioner`**
  - **`player`**
- **Multiple commissioners per event** are supported (no separate “co-commissioner” type; additional commissioners are promoted from players).
- **Join flow:** tokenized invite links, analogous to pools (`Event` has a unique `token`).

### 2.3 Handicap index (profile)

- **Manual / honor system** for v1: each user maintains their own **GHIN Handicap Index** on their profile.
- Field: `User#ghin_handicap_index` (decimal, optional; validated to a sensible range).

### 2.4 First game type

- Ship **`best_ball`** first: team net stroke play using the **best one net ball per hole** among teammates (four-ball / best-ball semantics).
- **Team sizing** is **defined by game type**, not a global constant:
  - For Best Ball: **team size 1–4**, up to **10 teams** (subject to participant count).
- **`best_2`** (or similar) is a **follow-up** game type after Best Ball is stable.

---

## 3. Domain model (target)

The following is the **target** structure (some pieces are not built yet; see §11).

| Concept | Purpose |
|--------|---------|
| **Event** | Container for an outing; invite token; lifecycle (see §4). |
| **EventMembership** | `user` + `role` (`commissioner` \| `player`). |
| **Round** | Where/when played; **snapshots** tee/course fields needed for handicap (slope, rating, par, stroke indices). |
| **Game** | Instance of a format (`game_type`, e.g. `best_ball`); links to round/event; **one shared scorecard** (see §5–6). |
| **GameTeam / GameTeamPlayer** | Teams and lineup; optional stored snapshots of **course handicap / playing handicap** at lock/submit for audit. |
| **Hole scores** | Gross (and derived net) per player (or per team slot as modeled); enough to compute team best-ball net per hole. |

---

## 4. Phase 1 — Event shell (implemented)

The following is **already implemented** in the Rails app (early 2026):

- **`Event`** + **`EventMembership`** (roles, token invites).
- **Event CRUD shell:** list, create, show (member vs non-member join view), join, member list, invite link (copy), **promote player → commissioner**, leave / remove players (with guardrails).
- **Event lifecycle fields:** `draft` \| `active` \| `completed` (commissioners can update status from the event page).
- **Profile:** edit GHIN Handicap Index.
- **Navigation:** Pools, On-Course (events), Profile ; contextual “This event” sidebar when applicable.
- **Env:** `GOLF_COURSE_API_KEY` documented for future GolfCourseAPI use (`.env.example` / Render notes).

Implementation details and routing quirks (e.g. nested routes use `params[:event_token]`) belong in code/comments; not repeated here.

---

## 5. Score entry, permissions, and locking

### 5.1 Who may enter scores

- **Players who are participants in a given game** may enter scores for **that game**.
- **Players must not** enter scores for games they are **not** in.
- **Commissioners** may enter scores for **any game** under the event (full override).

### 5.2 Editing during play

- **No per-hole forward-only lock** during the round: players may **fix prior holes** while the scorecard is still **unsubmitted** (casual play).

### 5.3 Submission and lock

- There is **one scorecard per game** that holds **all participants’ / teams’ results** for that game (e.g. 2v2 best ball: **both teams on one card**).
- **While unsubmitted:** any **in-game player** may edit the **same** shared scorecard (collaborative editing). **Commissioners** may always edit.
- **Concurrency:** no real-time merge protocol for v1; **last write wins** is acceptable (typical single scorekeeper phone; occasionally someone else edits).
- **“Game completed”** is **not** modeled as a separate flag for v1: **completion is implied when scorecard(s) are submitted** (see §6). Optional future “void / archive” can be added later if needed.

### 5.4 Submit workflow

- Any participating **player** may **submit** the **game scorecard** (locks the **entire** shared card for all rows on that card).
- **Confirmation:** submitting must use a strong **“Are you sure?”** step (e.g. `turbo_confirm`) because **early submit** requires **commissioner unlock** to continue editing.
- **After submit:** scorecard is **locked** for players; **only a commissioner** may **unlock** or edit.

---

## 6. Scorecard product rules (summary)

| Topic | Decision |
|-------|----------|
| Scorecards per game | **1 scorecard per game** |
| Content | All individuals / teams for that game on **one** card |
| Editors (pre-submit) | All **in-game** players + commissioners |
| Completion state | **Submit** locks card; no separate “game complete” toggle for v1 |
| Mistakes after submit | **Commissioner** unlock / edit |

---

## 7. Handicap — Course Handicap and Playing Handicap

### 7.1 Definitions

- **Handicap Index (HI):** stored on user profile (`ghin_handicap_index`).
- **Course Handicap (CH):** for the **specific course and set of tees** used on the round, per **World Handicap System (WHS)**:
  - **Course Handicap = Handicap Index × (Slope Rating ÷ 113) + (Course Rating − Par)**  
  - Use **rated tee** data (and **par**) from the snapshot for that round/game.
- **Playing Handicap (PH):** **Course Handicap** adjusted by a **handicap allowance** for the **game format** (percentage). Used for **net scoring and stroke allocation** when the format requires it.

Official reference: USGA / WHS materials, including **Rule 6** and **Appendix C — Handicap Allowances**  
(e.g. [USGA WHS](https://www.usga.org/content/usga/home-page/handicapping/world-handicap-system/), [Appendix C](https://www.usga.org/handicapping/roh/Content/rules/Appendix%20C%20Handicap%20Allowances.htm)).

### 7.2 Display

- Show each player’s **Course Handicap** in the game/scorecard UI.
- Show clearly **which player(s) receive stroke(s) on each hole** (stroke index / dots), derived from the handicap used for net (see §7.4).

### 7.3 Best Ball (v1) — Playing Handicap allowance

- For **`best_ball`** / four-ball style team net:
  - Use **85%** of **Course Handicap** as the basis for **Playing Handicap** (WHS recommended allowance for four-ball stroke play).
  - Implementation detail: apply allowance to **unrounded** Course Handicap per USGA guidance, then **round** for display and **stroke distribution** (exact rounding rules should match the rule book used in-app).
- **UI:** show both **CH** and **PH** (e.g. “CH 18 · PH 15”) so the allowance is transparent.

### 7.4 Stroke allocation (holes)

- Allocate strokes using **Playing Handicap** when the format uses an allowance **≠ 100%**.
- For **100%** games, **PH = CH** (same pipeline; no fork in scorecard logic).
- **Stroke indices** (1–18 hardest → easiest) come from the **course/tee** data (snapshotted with the round).
- For PH > 18, allocate extra strokes by repeating stroke-index order (standard WHS-style distribution).

### 7.5 Extensibility per game type

Design **`Game` / game type configuration** so each format specifies:

- `playing_handicap_allowance_percent` (integer), e.g. **85** for Best Ball, **100** for future “full CH” individual net games.
- All net math uses **PH** computed from **(CH, allowance%)**; **CH-only** formats set **100%**.

This avoids a second scoring pipeline when adding games that use full Course Handicap.

### 7.6 Player handicap spread

- Real groups may span **~8–36** Handicap Index (wide spread). **Format allowances** (e.g. 85% in best ball) exist partly to keep **team formats** equitable when high-variance players contribute to **best-ball** scoring.

---

## 8. Leaderboard ties (Best Ball / team net stroke play)

**Decided (v1):** Use **shared-place** labels on the leaderboard. **No** automatic tie-breakers (no countback, no playoff) unless we add them in a later version.

**Ranking style — competition / ordinal (1-2-2-4 style):** Sort teams by **fewest team net strokes** (primary). Teams with the **same** net total receive the **same** displayed rank; the **next** rank **skips** slots equal to the size of the tie group above.

**Examples:**

- Two teams tied for **best** (lowest) net total → both display **T1**.
- Two *other* teams tied for the **next-best** net total (the “second tier” behind the leaders) → both display **T3** (positions **1** and **2** are taken by the two leading teams, so the next tier starts at **3**).

**Implementation note:** Labels are **T1**, **T3**, etc. (not “2nd” for the second tier when two teams are T1).

---

## 9. Course and round data

- **Primary external source (target):** [GolfCourseAPI / golfcourseapi.com](https://golfcourseapi.com) — **API key only in environment** (e.g. `GOLF_COURSE_API_KEY`), never committed.
- **API documentation reference:** [https://api.golfcourseapi.com/docs/api/](https://api.golfcourseapi.com/docs/api/).
- **Snapshots:** when a round/game is created, **persist** tee/course fields needed for handicap and display (slope, rating, par, hole pars, **stroke indices**, yardages if useful). If upstream data changes later, **historical rounds stay correct**.

---

## 10. Still open (to decide in a later pass)

Some original handoff items are **decided** (see §5–8, §7). Remaining **explicit gaps**:

| # | Topic | Status |
|---|--------|--------|
| 4 | ~~Tie handling~~ | **Decided** — see §8 (T1 / T3 competition ranking, no countback for v1). |
| 5 | ~~Live updates~~ | **Decided** — **manual refresh only** for v1 (no background polling). |
| 6 | ~~Event lifecycle~~ | **Decided (v1)** — joins and game creation are allowed in `draft` and `active`; new joins are blocked in `completed`; commissioners control status transitions and may reopen `completed -> active` if needed. |

Minor follow-ups for handicap (§7):

- **9-hole** support is **deferred to v2/v3**. v1 assumes **18 holes**.
- **Mixed-tee** rounds are deferred unless needed; v1 assumes **same tees for all players in a game**.
- **Tee filtering UX:** v1 lists **male tees only** in round setup. Add v2 support for male/female tee filtering and evaluate adding an optional profile gender field if needed for default tee preferences.
- **Playing Handicap** for **other** formats (scramble, etc.) — take percentages from **Appendix C** when those games are added.

---

## 11. Implementation phases (updated)

| Phase | Scope | Notes |
|-------|--------|------|
| **1** | Event shell, memberships, invites, profile HI, nav | **Done** (see §4). |
| **2** | Round + GolfCourseAPI integration + tee/course snapshot | **Next** |
| **3** | Game setup (`best_ball`), teams, **shared scorecard**, gross entry, **CH/PH (85%)**, net best ball, **submit/lock**, commissioner unlock, leaderboard (see §8 for **T** ranks) | Core product |
| **4** | Hardening, tests, polish, remaining open items (refresh UX, lifecycle nuance) | |

---

## 12. Security

- Treat **GolfCourseAPI** and any third-party keys as **secrets**; **rotate** if ever exposed in chat or logs.
- Store keys only in **environment variables** (e.g. Render dashboard), e.g. `GOLF_COURSE_API_KEY`.

---

## 13. Related documents

- [`docs/plans/2026-04-21-on-course-games-planning-handoff.md`](2026-04-21-on-course-games-planning-handoff.md) — original brainstorming / handoff (partially superseded by this spec).

---

## 14. Changelog

| Date | Change |
|------|--------|
| 2026-05-06 | Initial consolidated design spec authored from handoff + design conversations. |
| 2026-05-07 | §8: Leaderboard ties — **T1** / **T3** competition ranking; item 4 closed. Section numbers 9–14 adjusted. |
| 2026-05-07 | §10 updates: item 5 closed (**manual refresh v1**), item 6 closed (lifecycle/join behavior), v1 assumptions set to **18 holes + same tees**; 9-hole deferred to v2/v3. |

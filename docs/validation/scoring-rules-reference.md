# Scoring Rules Reference — Manual Validation

Condensed from the app’s design docs. Use with the [validation packets](README.md).

---

## Handicap abbreviations

| Abbrev | Full name | What it means |
|--------|-----------|---------------|
| **HI** | Handicap Index | Player’s GHIN number — overall skill (lower = better). |
| **CH** | Course Handicap | Strokes for a specific course and tee. Adjusts HI for slope, rating, and par. |
| **PH** | Playing Handicap | CH adjusted for the game format (85% or 100%). **This** is what determines strokes per hole. |
| **SI** | Stroke index | Hole difficulty rank on the scorecard (1 = hardest). Used to decide which holes get strokes. |
| **Net** | Net score | Gross score minus strokes received on that hole. |

Each validation packet includes a **Handicap terms** section with these formulas filled in for that course and format.

---

## 1. Handicap pipeline (all formats)

| Step | Formula |
|------|---------|
| Handicap Index (HI) | From player profile (GHIN honor system) |
| Course Handicap (CH) | `round(HI × (slope ÷ 113) + (rating − par))` |
| Playing Handicap (PH) | `min(round(CH × allowance%), 36)` — see table below |
| Net score | `gross − strokes_received` on that hole |

### Playing handicap allowances

| Format | Allowance |
|--------|-----------|
| Best Ball | 85% |
| Cha-Cha-Cha | 85% |
| 40 Score | 100% |
| Vegas | 100% |

**PH ceiling:** Playing handicap is capped at **36** (at most **2 strokes** on any hole). Course handicap is still shown uncapped for reference.

### Stroke allocation

Strokes are spread across 18 holes using each hole’s **stroke index (SI)** from the course table (SI 1 = hardest hole).

- If **PH ≤ 18:** player gets **1 stroke** on the PH hardest holes (SI 1 through SI PH).
- If **PH > 18:** every hole gets **1 stroke**, plus an **extra stroke** on the (PH − 18) hardest holes (max PH 36 ⇒ max 2 per hole).

**Example (PH 19):** 1 stroke on every hole, plus a 2nd stroke on the hardest hole (SI 1).

---

## 2. Best Ball

- **Team hole score** = lowest **net** among teammates.
- **Team total** = sum of 18 hole best-ball nets.
- **Leaderboard:** lowest total wins. Ties show ordinal rank with `T` prefix (e.g. T1, T3).

---

## 3. Cha-Cha-Cha (1-2-3)

Pattern repeats every 3 holes:

| Hole # mod 3 | Scores counted |
|--------------|----------------|
| 1 (holes 1, 4, 7, …) | **1** best net |
| 2 (holes 2, 5, 8, …) | **2** best nets |
| 0 (holes 3, 6, 9, …) | **3** best nets (all players in a threesome) |

- **Team hole score** = sum of counted nets.
- **Team total** = sum of all 18 hole scores.

---

## 4. Forty Score

- Each player marks holes as **picks** (included in the 40).
- **Foursome:** exactly **40 picks** across the team.
- **Threesome:** exactly **30 picks**; competition line = `round(actual_vs_par × 4/3)`.
- **Actual vs par** = sum of `(net − par)` on picked holes only.
- Incomplete pick count → totals show as incomplete/nil in app.

---

## 5. Vegas (2v2 wash)

**One game** = 4 players, 2 teams of 2. Each foursome is a separate game.

### Per hole

1. Compute each player’s **net** (with full PH strokes).
2. **Cap:** net **> 9** becomes **9** (10, 11, 12… all cap to 9).
3. **Team number (default):** lower net → tens digit, higher → ones (e.g. 3 & 4 → **34**; both 4 → **44**).
4. **Birdie flip:** if **either** player on a team has net birdie or better (`net ≤ par − 1`), flip the **opponent’s** digit order (higher → tens). Both teams birdie → both flips apply.
5. **Winner:** lower team number. **Tie** (e.g. 44 vs 44) → **0** hole points.
6. **Hole points** = opponent’s number − your number (awarded to winner).

### Wash

- Running sum of hole points from a fixed reference team.
- Display shows one side “up” (e.g. “Team A leads by 12”).

### Worked example (no flips, par 4)

| | Alice | Bob | Carol | Dave |
|--|-------|-----|-------|------|
| Gross | 4 | 5 | 5 | 7 |
| Net | 4 | 5 | 5 | 7 |
| Team # | **45** | | **57** | |
| Points | Team A wins: 57 − 45 = **12** | | | |

### Net cap example

Gross 8 and 10 (scratch, par 4) → nets 8 and 10 → cap to 8 and 9 → team number **89** (not 810).

---

## 6. Michigan trip specifics

From [2026-07-michigan-golf-trip.md](../trip/2026-07-michigan-golf-trip.md):

| Round | Format | Course tee | Allowance |
|-------|--------|------------|-----------|
| 1 | Vegas (8 players, 2 matches) | Arcadia South White | 100% |
| 2 | Best Ball (12) | Wolf River Bear Paw | 85% |
| 3 | Cha-Cha-Cha (12) | Champion Hill White | 85% |
| 4 | 40 Score (12) | Pinecroft Blue | 100% |

Each course has its own rating, slope, par, and hole stroke indices — use the round snapshot values when validating trip simulator games, not the simplified course used in the edge-case packets (05–08).

---

## 7. Common pitfalls

| Pitfall | Correct behavior |
|---------|------------------|
| Using HI instead of PH for strokes | Strokes come from **PH**, not HI |
| Forgetting 85% on Best Ball / Cha-Cha-Cha | PH = round(CH × 0.85) |
| Vegas gross instead of net | Team numbers use **net**, capped at 9 |
| Cha-Cha hole 3 vs hole 4 | Hole 3 counts 3 scores; hole 4 counts **1** |
| 40 Score counting all holes | Only **picked** holes count |
| PH 19+ only 18 strokes | Extra strokes repeat from SI 1 |

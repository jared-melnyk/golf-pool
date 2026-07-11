# Manual validation: vegas_tie

**Format:** Vegas (2v2 wash)  
**Scenario:** Identical team numbers award zero hole points  
**Type:** Edge-case rule check

> Work through the **worksheet** first, then compare your answers to the **expected results** at the bottom.

## Course & tee snapshot

| Field | Value |
|-------|-------|
| Rating | 72.0 |
| Slope | 113 |
| Par (total) | 72 |

| Hole | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 |
|------|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Par | 4 | 4 | 4 | 4 | 4 | 4 | 4 | 4 | 4 | 4 | 4 | 4 | 4 | 4 | 4 | 4 | 4 | 4 |
| Stroke index | 1 | 3 | 5 | 7 | 9 | 11 | 13 | 15 | 17 | 2 | 4 | 6 | 8 | 10 | 12 | 14 | 16 | 18 |

## Handicap terms (HI, CH, PH)

| Abbrev | Full name | What it means |
|--------|-----------|---------------|
| **HI** | Handicap Index | Player’s GHIN number — overall skill level (lower = better). Listed in the trip roster. |
| **CH** | Course Handicap | Strokes for **this course and tee** — adjusts HI for slope, rating, and par. |
| **PH** | Playing Handicap | CH adjusted for **this game format** (allowance %), capped at **36**. Used to allocate strokes hole by hole. |

### Formulas (this packet)

**Course Handicap**

```
CH = round( HI × (slope ÷ 113) + (rating − par) )
```

This course: rating **72.0**, slope **113**, par **72**

```
CH = round( HI × 1.0 + (72.0 − 72) )
```

**Playing Handicap** (Vegas (2v2 wash) uses **100%** of CH, max **36**)

```
PH = min( round( CH × 100% ), 36 )
```

**Worked example — Alice (HI 0.0):**
1. CH = round(0.0 × 1.0 + (72.0 − 72)) = round(0.0) = **0**
2. PH = min(round(0 × 100%), 36) = round(0.0) = **0**

**Net score on a hole** = gross score − strokes received on that hole.

**Strokes per hole:** PH strokes are spread across 18 holes using the **stroke index (SI)** row in the course table (SI 1 = hardest hole).
- If PH ≤ 18: player gets **1 stroke** on the PH hardest holes (SI 1 through SI PH).
- If PH > 18: every hole gets **1 stroke**, plus an **extra stroke** on the (PH − 18) hardest holes (max PH 36 ⇒ max 2 per hole).

_The **Total strokes** column in the table below should equal each player’s PH._

## Players and handicaps

See **Handicap terms** above for how HI → CH → PH is calculated.

| Team | Player | HI | CH | PH | Total strokes |
|------|--------|----|----|----|---------------|
| Team A | Alice | 0.0 | 0 | 0 | 0 |
| Team A | Bob | 0.0 | 0 | 0 | 0 |
| Team B | Carol | 0.0 | 0 | 0 | 0 |
| Team B | Dave | 0.0 | 0 | 0 | 0 |

## Gross scores entered (the scorecard)

| Hole | Par | SI | Alice | Bob | Carol | Dave |
|---|---|---|---|---|---|---|
| 1 | 4 | 1 | 4 | 4 | 4 | 4 |
| 2 | 4 | 3 |  |  |  |  |
| 3 | 4 | 5 |  |  |  |  |
| 4 | 4 | 7 |  |  |  |  |
| 5 | 4 | 9 |  |  |  |  |
| 6 | 4 | 11 |  |  |  |  |
| 7 | 4 | 13 |  |  |  |  |
| 8 | 4 | 15 |  |  |  |  |
| 9 | 4 | 17 |  |  |  |  |
| 10 | 4 | 2 |  |  |  |  |
| 11 | 4 | 4 |  |  |  |  |
| 12 | 4 | 6 |  |  |  |  |
| 13 | 4 | 8 |  |  |  |  |
| 14 | 4 | 10 |  |  |  |  |
| 15 | 4 | 12 |  |  |  |  |
| 16 | 4 | 14 |  |  |  |  |
| 17 | 4 | 16 |  |  |  |  |
| 18 | 4 | 18 |  |  |  |  |

## Your manual calculation worksheet

Per hole: net (cap any net > 9 to 9) → team number (lower net = tens, higher = ones).
Birdie flip: if either player on a team nets birdie-or-better (net ≤ par−1), flip the **opponent's** digits.
Points = opponent number − your number (to the lower team). Wash = running sum from Team A's view.

| Hole | Your result | Match? |
|------|-------------|--------|
| 1 | | ☐ |
| 2 | | ☐ |
| 3 | | ☐ |
| 4 | | ☐ |
| 5 | | ☐ |
| 6 | | ☐ |
| 7 | | ☐ |
| 8 | | ☐ |
| 9 | | ☐ |
| 10 | | ☐ |
| 11 | | ☐ |
| 12 | | ☐ |
| 13 | | ☐ |
| 14 | | ☐ |
| 15 | | ☐ |
| 16 | | ☐ |
| 17 | | ☐ |
| 18 | | ☐ |
| **Total / summary** | | ☐ |

---

## Expected results (from the app — compare your worksheet here)

### Hole by hole

| Hole | Par | Team A nets | Team A # | Team B nets | Team B # | Flip | Points | Wash |
|---|---|---|---|---|---|---|---|---|
| 1 | 4 | 4/4 | 44 | 4/4 | 44 | — | 0 | 0 |

**Result: All square** (margin 0, from Team A's perspective)

_Points/wash are shown from Team A's view: negative = Team B won the hole._


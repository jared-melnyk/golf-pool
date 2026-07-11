# Manual validation: bb_ph_over_18

**Format:** Best Ball  
**Scenario:** PH 19 receives extra strokes on the six hardest holes  
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

**Playing Handicap** (Best Ball uses **85%** of CH, max **36**)

```
PH = min( round( CH × 85% ), 36 )
```

**Worked example — Strokes (HI 22.0):**
1. CH = round(22.0 × 1.0 + (72.0 − 72)) = round(22.0) = **22**
2. PH = min(round(22 × 85%), 36) = round(18.7) = **19**

**Net score on a hole** = gross score − strokes received on that hole.

**Strokes per hole:** PH strokes are spread across 18 holes using the **stroke index (SI)** row in the course table (SI 1 = hardest hole).
- If PH ≤ 18: player gets **1 stroke** on the PH hardest holes (SI 1 through SI PH).
- If PH > 18: every hole gets **1 stroke**, plus an **extra stroke** on the (PH − 18) hardest holes (max PH 36 ⇒ max 2 per hole).

_The **Total strokes** column in the table below should equal each player’s PH._

## Players and handicaps

See **Handicap terms** above for how HI → CH → PH is calculated.

| Team | Player | HI | CH | PH | Total strokes |
|------|--------|----|----|----|---------------|
| Team A | Strokes | 22.0 | 22 | 19 | 19 |

## Gross scores entered (the scorecard)

| Hole | Par | SI | Strokes |
|---|---|---|---|
| 1 | 4 | 1 | 5 |
| 2 | 4 | 3 | 5 |
| 3 | 4 | 5 | 5 |
| 4 | 4 | 7 | 5 |
| 5 | 4 | 9 | 5 |
| 6 | 4 | 11 | 5 |
| 7 | 4 | 13 | 5 |
| 8 | 4 | 15 | 5 |
| 9 | 4 | 17 | 5 |
| 10 | 4 | 2 | 5 |
| 11 | 4 | 4 | 5 |
| 12 | 4 | 6 | 5 |
| 13 | 4 | 8 | 5 |
| 14 | 4 | 10 | 5 |
| 15 | 4 | 12 | 5 |
| 16 | 4 | 14 | 5 |
| 17 | 4 | 16 | 5 |
| 18 | 4 | 18 | 5 |

## Your manual calculation worksheet

For each hole: net = gross − strokes received; team result = **lowest net** among the four players.
Total = sum of the 18 hole best-ball nets.

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

### Team A — hole by hole

| Hole | Par | Strokes net | **Best net** |
|---|---|---|---|
| 1 | 4 | 3 | **3** |
| 2 | 4 | 4 | **4** |
| 3 | 4 | 4 | **4** |
| 4 | 4 | 4 | **4** |
| 5 | 4 | 4 | **4** |
| 6 | 4 | 4 | **4** |
| 7 | 4 | 4 | **4** |
| 8 | 4 | 4 | **4** |
| 9 | 4 | 4 | **4** |
| 10 | 4 | 4 | **4** |
| 11 | 4 | 4 | **4** |
| 12 | 4 | 4 | **4** |
| 13 | 4 | 4 | **4** |
| 14 | 4 | 4 | **4** |
| 15 | 4 | 4 | **4** |
| 16 | 4 | 4 | **4** |
| 17 | 4 | 4 | **4** |
| 18 | 4 | 4 | **4** |

**Team total net strokes: 71**


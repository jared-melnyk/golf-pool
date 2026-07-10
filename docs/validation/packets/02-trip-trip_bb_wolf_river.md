# Manual validation: trip_bb_wolf_river

**Format:** Best Ball  
**Scenario:** Trip Round 2 — Best Ball at Wolf River (Group A), realistic varied scorecards  
**Type:** Realistic trip scenario

> Work through the **worksheet** first, then compare your answers to the **expected results** at the bottom.

## Course & tee snapshot

| Field | Value |
|-------|-------|
| Rating | 69.4 |
| Slope | 120 |
| Par (total) | 72 |

| Hole | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 |
|------|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Par | 5 | 4 | 4 | 4 | 5 | 4 | 3 | 4 | 3 | 3 | 5 | 4 | 3 | 4 | 4 | 5 | 4 | 4 |
| Stroke index | 13 | 17 | 5 | 1 | 3 | 7 | 11 | 15 | 9 | 16 | 6 | 12 | 18 | 2 | 10 | 4 | 14 | 8 |

## Handicap terms (HI, CH, PH)

| Abbrev | Full name | What it means |
|--------|-----------|---------------|
| **HI** | Handicap Index | Player’s GHIN number — overall skill level (lower = better). Listed in the trip roster. |
| **CH** | Course Handicap | Strokes for **this course and tee** — adjusts HI for slope, rating, and par. |
| **PH** | Playing Handicap | CH adjusted for **this game format** (allowance %). Used to allocate strokes hole by hole. |

### Formulas (this packet)

**Course Handicap**

```
CH = round( HI × (slope ÷ 113) + (rating − par) )
```

This course: rating **69.4**, slope **120**, par **72**

```
CH = round( HI × 1.062 + (69.4 − 72) )
```

**Playing Handicap** (Best Ball uses **85%** of CH)

```
PH = round( CH × 85% )
```

**Worked example — Nitti (HI 8.6):**
1. CH = round(8.6 × 1.062 + (69.4 − 72)) = round(6.5) = **7**
2. PH = round(7 × 85%) = round(6.0) = **6**

**Net score on a hole** = gross score − strokes received on that hole.

**Strokes per hole:** PH strokes are spread across 18 holes using the **stroke index (SI)** row in the course table (SI 1 = hardest hole).
- If PH ≤ 18: player gets **1 stroke** on the PH hardest holes (SI 1 through SI PH).
- If PH > 18: every hole gets **1 stroke**, plus an **extra stroke** on the (PH − 18) hardest holes.

_The **Total strokes** column in the table below should equal each player’s PH._

## Players and handicaps

See **Handicap terms** above for how HI → CH → PH is calculated.

| Team | Player | HI | CH | PH | Total strokes |
|------|--------|----|----|----|---------------|
| Group A | Nitti | 8.6 | 7 | 6 | 6 |
| Group A | Kyle | 14.0 | 12 | 10 | 10 |
| Group A | Jared | 18.3 | 17 | 14 | 14 |
| Group A | Will | 36.0 | 36 | 31 | 31 |

## Gross scores entered (the scorecard)

| Hole | Par | SI | Nitti | Kyle | Jared | Will |
|---|---|---|---|---|---|---|
| 1 | 5 | 13 | 5 | 6 | 6 | 8 |
| 2 | 4 | 17 | 4 | 5 | 5 | 6 |
| 3 | 4 | 5 | 5 | 5 | 6 | 7 |
| 4 | 4 | 1 | 4 | 6 | 5 | 6 |
| 5 | 5 | 3 | 5 | 6 | 7 | 8 |
| 6 | 4 | 7 | 4 | 5 | 5 | 6 |
| 7 | 3 | 11 | 3 | 4 | 4 | 5 |
| 8 | 4 | 15 | 5 | 4 | 5 | 6 |
| 9 | 3 | 9 | 3 | 3 | 4 | 5 |
| 10 | 3 | 16 | 3 | 4 | 4 | 5 |
| 11 | 5 | 6 | 6 | 6 | 6 | 8 |
| 12 | 4 | 12 | 4 | 5 | 5 | 6 |
| 13 | 3 | 18 | 3 | 4 | 3 | 5 |
| 14 | 4 | 2 | 4 | 5 | 6 | 6 |
| 15 | 4 | 10 | 5 | 5 | 5 | 6 |
| 16 | 5 | 4 | 4 | 6 | 6 | 7 |
| 17 | 4 | 14 | 4 | 4 | 5 | 6 |
| 18 | 4 | 8 | 5 | 5 | 5 | 6 |

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

### Group A — hole by hole

| Hole | Par | Nitti net | Kyle net | Jared net | Will net | **Best net** |
|---|---|---|---|---|---|---|
| 1 | 5 | 5 | 6 | 5 | 6 | **5** |
| 2 | 4 | 4 | 5 | 5 | 5 | **4** |
| 3 | 4 | 4 | 4 | 5 | 5 | **4** |
| 4 | 4 | 3 | 5 | 4 | 4 | **3** |
| 5 | 5 | 4 | 5 | 6 | 6 | **4** |
| 6 | 4 | 4 | 4 | 4 | 4 | **4** |
| 7 | 3 | 3 | 4 | 3 | 3 | **3** |
| 8 | 4 | 5 | 4 | 5 | 5 | **4** |
| 9 | 3 | 3 | 2 | 3 | 3 | **2** |
| 10 | 3 | 3 | 4 | 4 | 4 | **3** |
| 11 | 5 | 5 | 5 | 5 | 6 | **5** |
| 12 | 4 | 4 | 5 | 4 | 4 | **4** |
| 13 | 3 | 3 | 4 | 3 | 4 | **3** |
| 14 | 4 | 3 | 4 | 5 | 4 | **3** |
| 15 | 4 | 5 | 4 | 4 | 4 | **4** |
| 16 | 5 | 3 | 5 | 5 | 5 | **3** |
| 17 | 4 | 4 | 4 | 4 | 5 | **4** |
| 18 | 4 | 5 | 4 | 4 | 4 | **4** |

**Team total net strokes: 66**


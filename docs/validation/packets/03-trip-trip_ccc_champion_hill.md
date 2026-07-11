# Manual validation: trip_ccc_champion_hill

**Format:** Cha-Cha-Cha (1-2-3)  
**Scenario:** Trip Round 3 — Cha-Cha-Cha at Champion Hill (Group A), realistic varied scorecards  
**Type:** Realistic trip scenario

> Work through the **worksheet** first, then compare your answers to the **expected results** at the bottom.

## Course & tee snapshot

| Field | Value |
|-------|-------|
| Rating | 68.5 |
| Slope | 120 |
| Par (total) | 72 |

| Hole | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 |
|------|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Par | 4 | 4 | 4 | 4 | 5 | 3 | 5 | 3 | 4 | 4 | 3 | 4 | 3 | 4 | 4 | 4 | 5 | 5 |
| Stroke index | 11 | 5 | 9 | 1 | 17 | 7 | 15 | 3 | 13 | 4 | 16 | 10 | 14 | 18 | 6 | 2 | 12 | 8 |

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

This course: rating **68.5**, slope **120**, par **72**

```
CH = round( HI × 1.062 + (68.5 − 72) )
```

**Playing Handicap** (Cha-Cha-Cha (1-2-3) uses **85%** of CH, max **36**)

```
PH = min( round( CH × 85% ), 36 )
```

**Worked example — Kevin Callaghan (HI 5.7):**
1. CH = round(5.7 × 1.062 + (68.5 − 72)) = round(2.6) = **3**
2. PH = min(round(3 × 85%), 36) = round(2.6) = **3**

**Net score on a hole** = gross score − strokes received on that hole.

**Strokes per hole:** PH strokes are spread across 18 holes using the **stroke index (SI)** row in the course table (SI 1 = hardest hole).
- If PH ≤ 18: player gets **1 stroke** on the PH hardest holes (SI 1 through SI PH).
- If PH > 18: every hole gets **1 stroke**, plus an **extra stroke** on the (PH − 18) hardest holes (max PH 36 ⇒ max 2 per hole).

_The **Total strokes** column in the table below should equal each player’s PH._

## Players and handicaps

See **Handicap terms** above for how HI → CH → PH is calculated.

| Team | Player | HI | CH | PH | Total strokes |
|------|--------|----|----|----|---------------|
| Group A | Kevin Callaghan | 5.7 | 3 | 3 | 3 |
| Group A | Nick Barajas | 13.6 | 11 | 9 | 9 |
| Group A | Greg Lindemann | 19.0 | 17 | 14 | 14 |
| Group A | Will Schmadeke | 36.0 | 35 | 30 | 30 |

## Gross scores entered (the scorecard)

| Hole | Par | SI | Kevin Callaghan | Nick Barajas | Greg Lindemann | Will Schmadeke |
|---|---|---|---|---|---|---|
| 1 | 4 | 11 | 5 | 5 | 5 | 7 |
| 2 | 4 | 5 | 4 | 5 | 6 | 6 |
| 3 | 4 | 9 | 4 | 4 | 5 | 6 |
| 4 | 4 | 1 | 5 | 6 | 6 | 7 |
| 5 | 5 | 17 | 5 | 6 | 7 | 8 |
| 6 | 3 | 7 | 3 | 4 | 4 | 5 |
| 7 | 5 | 15 | 6 | 6 | 6 | 8 |
| 8 | 3 | 3 | 3 | 4 | 5 | 5 |
| 9 | 4 | 13 | 4 | 5 | 5 | 6 |
| 10 | 4 | 4 | 4 | 5 | 5 | 6 |
| 11 | 3 | 16 | 4 | 4 | 4 | 5 |
| 12 | 4 | 10 | 4 | 5 | 6 | 6 |
| 13 | 3 | 14 | 3 | 4 | 4 | 5 |
| 14 | 4 | 18 | 5 | 5 | 5 | 6 |
| 15 | 4 | 6 | 4 | 4 | 6 | 6 |
| 16 | 4 | 2 | 4 | 5 | 5 | 6 |
| 17 | 5 | 12 | 5 | 5 | 6 | 7 |
| 18 | 5 | 8 | 6 | 6 | 6 | 7 |

## Your manual calculation worksheet

Count pattern repeats every 3 holes: holes 1,4,7,… count **1** best net; 2,5,8,… count **2**; 3,6,9,… count **3**.
Hole result = sum of the counted nets. Total = sum of all 18 hole results.

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

| Hole | Par | Count | Kevin Callaghan net | Nick Barajas net | Greg Lindemann net | Will Schmadeke net | **Hole total** |
|---|---|---|---|---|---|---|---|
| 1 | 4 | 1 | 5 | 5 | 4 | 5 | **4** |
| 2 | 4 | 2 | 4 | 4 | 5 | 4 | **8** |
| 3 | 4 | 3 | 4 | 3 | 4 | 4 | **11** |
| 4 | 4 | 1 | 4 | 5 | 5 | 5 | **4** |
| 5 | 5 | 2 | 5 | 6 | 7 | 7 | **11** |
| 6 | 3 | 3 | 3 | 3 | 3 | 3 | **9** |
| 7 | 5 | 1 | 6 | 6 | 6 | 7 | **6** |
| 8 | 3 | 2 | 2 | 3 | 4 | 3 | **5** |
| 9 | 4 | 3 | 4 | 5 | 4 | 5 | **13** |
| 10 | 4 | 1 | 4 | 4 | 4 | 4 | **4** |
| 11 | 3 | 2 | 4 | 4 | 4 | 4 | **8** |
| 12 | 4 | 3 | 4 | 5 | 5 | 4 | **13** |
| 13 | 3 | 1 | 3 | 4 | 3 | 4 | **3** |
| 14 | 4 | 2 | 5 | 5 | 5 | 5 | **10** |
| 15 | 4 | 3 | 4 | 3 | 5 | 4 | **11** |
| 16 | 4 | 1 | 3 | 4 | 4 | 4 | **3** |
| 17 | 5 | 2 | 5 | 5 | 5 | 5 | **10** |
| 18 | 5 | 3 | 6 | 5 | 5 | 5 | **15** |

**Team total net strokes: 148**


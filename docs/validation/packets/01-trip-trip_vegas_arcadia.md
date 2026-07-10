# Manual validation: trip_vegas_arcadia

**Format:** Vegas (2v2 wash)  
**Scenario:** Trip Round 1 — Vegas at Arcadia Bluffs South (Match 1), realistic varied scorecards  
**Type:** Realistic trip scenario

> Work through the **worksheet** first, then compare your answers to the **expected results** at the bottom.

## Course & tee snapshot

| Field | Value |
|-------|-------|
| Rating | 70.6 |
| Slope | 125 |
| Par (total) | 72 |

| Hole | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 |
|------|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Par | 4 | 4 | 5 | 4 | 3 | 5 | 4 | 3 | 4 | 4 | 5 | 3 | 4 | 5 | 4 | 3 | 4 | 4 |
| Stroke index | 9 | 15 | 7 | 1 | 3 | 13 | 11 | 17 | 5 | 10 | 12 | 14 | 2 | 16 | 18 | 4 | 8 | 6 |

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

This course: rating **70.6**, slope **125**, par **72**

```
CH = round( HI × 1.106 + (70.6 − 72) )
```

**Playing Handicap** (Vegas (2v2 wash) uses **100%** of CH)

```
PH = round( CH × 100% )
```

**Worked example — Kevin Callaghan (HI 5.7):**
1. CH = round(5.7 × 1.106 + (70.6 − 72)) = round(4.9) = **5**
2. PH = round(5 × 100%) = round(5.0) = **5**

**Net score on a hole** = gross score − strokes received on that hole.

**Strokes per hole:** PH strokes are spread across 18 holes using the **stroke index (SI)** row in the course table (SI 1 = hardest hole).
- If PH ≤ 18: player gets **1 stroke** on the PH hardest holes (SI 1 through SI PH).
- If PH > 18: every hole gets **1 stroke**, plus an **extra stroke** on the (PH − 18) hardest holes.

_The **Total strokes** column in the table below should equal each player’s PH._

## Players and handicaps

See **Handicap terms** above for how HI → CH → PH is calculated.

| Team | Player | HI | CH | PH | Total strokes |
|------|--------|----|----|----|---------------|
| Team A | Kevin Callaghan | 5.7 | 5 | 5 | 5 |
| Team A | Ryan Lannon | 36.0 | 38 | 38 | 38 |
| Team B | Jared | 18.3 | 19 | 19 | 19 |
| Team B | Chris | 17.4 | 18 | 18 | 18 |

## Gross scores entered (the scorecard)

| Hole | Par | SI | Kevin Callaghan | Ryan Lannon | Jared | Chris |
|---|---|---|---|---|---|---|
| 1 | 4 | 9 | 5 | 6 | 5 | 6 |
| 2 | 4 | 15 | 4 | 6 | 5 | 5 |
| 3 | 5 | 7 | 6 | 8 | 7 | 6 |
| 4 | 4 | 1 | 4 | 6 | 5 | 5 |
| 5 | 3 | 3 | 3 | 5 | 4 | 4 |
| 6 | 5 | 13 | 6 | 8 | 7 | 6 |
| 7 | 4 | 11 | 4 | 6 | 5 | 6 |
| 8 | 3 | 17 | 3 | 5 | 4 | 4 |
| 9 | 4 | 5 | 5 | 6 | 6 | 5 |
| 10 | 4 | 10 | 4 | 6 | 5 | 5 |
| 11 | 5 | 12 | 5 | 8 | 6 | 7 |
| 12 | 3 | 14 | 3 | 5 | 4 | 5 |
| 13 | 4 | 2 | 5 | 6 | 6 | 5 |
| 14 | 5 | 16 | 6 | 8 | 7 | 7 |
| 15 | 4 | 18 | 4 | 6 | 5 | 6 |
| 16 | 3 | 4 | 3 | 5 | 4 | 5 |
| 17 | 4 | 8 | 5 | 6 | 6 | 5 |
| 18 | 4 | 6 | 4 | 6 | 5 | 6 |

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
| 1 | 4 | 5/4 | 45 | 4/5 | 45 | — | 0 | 0 |
| 2 | 4 | 4/4 | 44 | 4/4 | 44 | — | 0 | 0 |
| 3 | 5 | 6/6 | 66 | 6/5 | 56 | — | -10 | -10 |
| 4 | 4 | 3/3 | 33 | 3/4 | 43 | Team B, Team A | 10 | 0 |
| 5 | 3 | 2/3 | 23 | 3/3 | 33 | Team B | 10 | 10 |
| 6 | 5 | 6/6 | 66 | 6/5 | 56 | — | -10 | 0 |
| 7 | 4 | 4/4 | 44 | 4/5 | 45 | — | 1 | 1 |
| 8 | 3 | 3/3 | 33 | 3/3 | 33 | — | 0 | 1 |
| 9 | 4 | 4/4 | 44 | 5/4 | 45 | — | 1 | 2 |
| 10 | 4 | 4/4 | 44 | 4/4 | 44 | — | 0 | 2 |
| 11 | 5 | 5/6 | 56 | 5/6 | 56 | — | 0 | 2 |
| 12 | 3 | 3/3 | 33 | 3/4 | 34 | — | 1 | 3 |
| 13 | 4 | 4/3 | 34 | 5/4 | 54 | Team B | 20 | 23 |
| 14 | 5 | 6/6 | 66 | 6/6 | 66 | — | 0 | 23 |
| 15 | 4 | 4/4 | 44 | 4/5 | 45 | — | 1 | 24 |
| 16 | 3 | 2/3 | 23 | 3/4 | 43 | Team B | 20 | 44 |
| 17 | 4 | 5/4 | 45 | 5/4 | 45 | — | 0 | 44 |
| 18 | 4 | 4/4 | 44 | 4/5 | 45 | — | 1 | 45 |

**Result: Team A leads by 45** (margin 45, from Team A's perspective)

_Points/wash are shown from Team A's view: negative = Team B won the hole._


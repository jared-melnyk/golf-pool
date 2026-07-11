# Manual validation: trip_fs_pinecroft

**Format:** 40 Score  
**Scenario:** Trip Round 4 — 40 Score at Pinecroft (Group A), realistic varied scorecards and 40 picks  
**Type:** Realistic trip scenario

> Work through the **worksheet** first, then compare your answers to the **expected results** at the bottom.

## Course & tee snapshot

| Field | Value |
|-------|-------|
| Rating | 70.1 |
| Slope | 126 |
| Par (total) | 72 |

| Hole | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 |
|------|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Par | 4 | 3 | 5 | 4 | 4 | 4 | 3 | 4 | 5 | 4 | 4 | 4 | 4 | 3 | 4 | 5 | 3 | 5 |
| Stroke index | 16 | 14 | 4 | 6 | 18 | 10 | 8 | 12 | 2 | 5 | 1 | 3 | 15 | 13 | 7 | 11 | 17 | 9 |

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

This course: rating **70.1**, slope **126**, par **72**

```
CH = round( HI × 1.115 + (70.1 − 72) )
```

**Playing Handicap** (40 Score uses **100%** of CH, max **36**)

```
PH = min( round( CH × 100% ), 36 )
```

**Worked example — Nitti (HI 8.6):**
1. CH = round(8.6 × 1.115 + (70.1 − 72)) = round(7.7) = **8**
2. PH = min(round(8 × 100%), 36) = round(8.0) = **8**

**Net score on a hole** = gross score − strokes received on that hole.

**Strokes per hole:** PH strokes are spread across 18 holes using the **stroke index (SI)** row in the course table (SI 1 = hardest hole).
- If PH ≤ 18: player gets **1 stroke** on the PH hardest holes (SI 1 through SI PH).
- If PH > 18: every hole gets **1 stroke**, plus an **extra stroke** on the (PH − 18) hardest holes (max PH 36 ⇒ max 2 per hole).

_The **Total strokes** column in the table below should equal each player’s PH._

## Players and handicaps

See **Handicap terms** above for how HI → CH → PH is calculated.

| Team | Player | HI | CH | PH | Total strokes |
|------|--------|----|----|----|---------------|
| Group A | Nitti | 8.6 | 8 | 8 | 8 |
| Group A | Joe Mc | 12.0 | 11 | 11 | 11 |
| Group A | Ryan Flynn | 15.0 | 15 | 15 | 15 |
| Group A | Ryan Lannon | 36.0 | 38 | 36 | 36 |

## Gross scores entered (the scorecard)

| Hole | Par | SI | Nitti | Joe Mc | Ryan Flynn | Ryan Lannon |
|---|---|---|---|---|---|---|
| 1 | 4 | 16 | 4 | 5 | 5 | 6 |
| 2 | 3 | 14 | 3 | 4 | 4 | 5 |
| 3 | 5 | 4 | 5 | 6 | 7 | 8 |
| 4 | 4 | 6 | 5 | 5 | 5 | 7 |
| 5 | 4 | 18 | 4 | 5 | 6 | 6 |
| 6 | 4 | 10 | 4 | 5 | 5 | 6 |
| 7 | 3 | 8 | 4 | 4 | 5 | 5 |
| 8 | 4 | 12 | 4 | 5 | 5 | 6 |
| 9 | 5 | 2 | 5 | 6 | 6 | 8 |
| 10 | 4 | 5 | 4 | 5 | 5 | 6 |
| 11 | 4 | 1 | 5 | 5 | 6 | 7 |
| 12 | 4 | 3 | 4 | 4 | 5 | 6 |
| 13 | 4 | 15 | 5 | 5 | 5 | 6 |
| 14 | 3 | 13 | 3 | 4 | 4 | 5 |
| 15 | 4 | 7 | 4 | 5 | 5 | 6 |
| 16 | 5 | 11 | 6 | 6 | 7 | 8 |
| 17 | 3 | 17 | 3 | 4 | 4 | 5 |
| 18 | 5 | 9 | 5 | 6 | 6 | 7 |

## Your manual calculation worksheet

For each **picked** hole (✓ in the expected-results table), compute net − par. Sum across all 40 picks = team actual vs par.
Threesomes only: competition vs par = round(actual × 4/3). Foursomes: competition = actual.

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

### Group A — picks and net vs par

Cells show **net** (✓ = counted in the 40). Par is per hole below.

| Hole | Par | Nitti | Joe Mc | Ryan Flynn | Ryan Lannon |
|---|---|---|---|---|---|
| 1 | 4 | 4 ✓ | 5 ✓ | 5 | 4 |
| 2 | 3 | 3 ✓ | 4 | 3 ✓ | 3 |
| 3 | 5 | 4 | 5 ✓ | 6 | 6 |
| 4 | 4 | 4 ✓ | 4 ✓ | 4 ✓ | 5 |
| 5 | 4 | 4 ✓ | 5 | 6 | 4 ✓ |
| 6 | 4 | 4 ✓ | 4 ✓ | 4 | 4 |
| 7 | 3 | 3 ✓ | 3 ✓ | 4 ✓ | 3 ✓ |
| 8 | 4 | 4 ✓ | 5 | 4 ✓ | 4 |
| 9 | 5 | 4 | 5 ✓ | 5 | 6 ✓ |
| 10 | 4 | 3 ✓ | 4 | 4 | 4 |
| 11 | 4 | 4 | 4 ✓ | 5 | 5 ✓ |
| 12 | 4 | 3 | 3 ✓ | 4 ✓ | 4 |
| 13 | 4 | 5 ✓ | 5 | 4 | 4 |
| 14 | 3 | 3 ✓ | 4 | 3 ✓ | 3 ✓ |
| 15 | 4 | 3 ✓ | 4 ✓ | 4 ✓ | 4 |
| 16 | 5 | 6 | 5 | 6 ✓ | 6 ✓ |
| 17 | 3 | 3 ✓ | 4 ✓ | 4 ✓ | 3 |
| 18 | 5 | 5 | 5 ✓ | 5 ✓ | 5 ✓ |

- **Picks counted:** 40 / 40
- **Actual vs par:** +6
- **Competition vs par:** +6


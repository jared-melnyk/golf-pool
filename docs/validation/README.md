# Manual Scoring Validation — Michigan Golf Trip 2026

**Purpose:** Independent humans verify that Long Shot’s on-course scoring math matches real golf rules before the trip.

**Who:** You and your test helper each work through the packets independently, then compare notes.

---

## What you’re validating

For each test packet:

1. **Inputs** — gross scores, handicaps, course/tee data (as if players typed them into the app).
2. **Rules** — format-specific formulas in [scoring-rules-reference.md](scoring-rules-reference.md).
3. **Your work** — hand-calculate results in the worksheet section.
4. **Expected results** — what the app should produce (shown at the bottom of each packet).
5. **Match?** — check boxes when your numbers agree; flag mismatches.

There are two kinds of packets:

- **Trip packets (01–04)** — realistic, varied 18-hole scorecards on the **actual trip courses**, using the real groups and GHIN indexes. Full pars (par 3s/4s/5s), real stroke indexes, and scores that vary hole to hole. **Start here.**
- **Edge packets (05–08)** — small, deliberately simple scenarios that isolate one tricky rule (PH > 18, threesome scaling, net cap, ties). Quick sanity checks.

---

## Packet list (start here)

Work **one format at a time**. Suggested order:

| # | Packet | Format | Course / group | What it stresses |
|---|--------|--------|----------------|------------------|
| 01 | [trip_vegas_arcadia](packets/01-trip-trip_vegas_arcadia.md) | Vegas | Arcadia South · Match 1 | Full 18-hole wash, net caps, birdie flips |
| 02 | [trip_bb_wolf_river](packets/02-trip-trip_bb_wolf_river.md) | Best Ball | Wolf River · Group A | 85% PH, varied scores, wide handicap spread |
| 03 | [trip_ccc_champion_hill](packets/03-trip-trip_ccc_champion_hill.md) | Cha-Cha-Cha | Champion Hill · Group A | 1-2-3 pattern across a real par-72 layout |
| 04 | [trip_fs_pinecroft](packets/04-trip-trip_fs_pinecroft.md) | 40 Score | Pinecroft · Group A | 40 picks spread across 4 players |
| 05 | [bb_ph_over_18](packets/05-edge-bb_ph_over_18.md) | Best Ball | (edge case) | PH > 18 → extra strokes on hardest holes |
| 06 | [fs_threesome_competition](packets/06-edge-fs_threesome_competition.md) | 40 Score | (edge case) | 30 picks; competition scaling ×4/3 |
| 07 | [vegas_handicap](packets/07-edge-vegas_handicap.md) | Vegas | (edge case) | Net cap at 9 before digit pairing |
| 08 | [vegas_tie](packets/08-edge-vegas_tie.md) | Vegas | (edge case) | Tie hole → 0 points |

**Minimum bar before trip:** complete the four **trip packets** (01–04) — one per format on the real courses. The edge packets are quick extra confidence.

Each trip packet gives you the full scorecard, a blank per-hole worksheet, and **expected results hole by hole** so you can check every hole, not just the final total.

---

## How to hand-calculate (quick)

See [scoring-rules-reference.md](scoring-rules-reference.md) for full definitions of **HI**, **CH**, **PH**, and **SI**. Each packet also spells these out for that course and format.

### Shared handicap pipeline

**HI (Handicap Index)** — player’s GHIN number from the roster.

**CH (Course Handicap)** — strokes for this course/tee:

```
CH = round(HI × slope/113 + (rating − par))
```

**PH (Playing Handicap)** — CH adjusted for the game format, capped at 36:

```
PH = min(round(CH × allowance%), 36)
```

| Format | Allowance |
|--------|-----------|
| Best Ball, Cha-Cha-Cha | 85% |
| 40 Score, Vegas | 100% |

**Strokes per hole:** PH strokes are spread using stroke index (SI). If PH ≤ 18, strokes land on the PH hardest holes; if PH > 18, every hole gets 1 stroke plus extras on the hardest holes. The PH cap of 36 means **at most 2 strokes on any hole**.

**Net on a hole** = gross − strokes received.

Full detail: [scoring-rules-reference.md](scoring-rules-reference.md).

### Per-format result

| Format | You compute |
|--------|-------------|
| **Best Ball** | Min net per hole across teammates → sum 18 holes |
| **Cha-Cha-Cha** | Holes 1/4/7… = 1 best net; 2/5/8… = 2 best; 3/6/9… = 3 best → sum |
| **40 Score** | Sum (net − par) on picked holes only; threesome also `round(actual × 4/3)` |
| **Vegas** | Cap net >9 → pair digits → birdie flips → hole points → running wash |

---

## Optional: trip simulator (full UI walkthrough)

After packet math checks, you can click through realistic trip data locally:

```bash
bundle exec rake trip:simulate
cat tmp/trip_sim_manifest.md
```

- Login: `trip-commissioner@dryrun.test` / `trip2026`
- Manifest lists game URLs and **expected leaders** per foursome
- Uses real Michigan courses, roster GHIN indexes, and trip groupings from [2026-07-michigan-golf-trip.md](../trip/2026-07-michigan-golf-trip.md)

This is a separate UI/flow check on top of the math packets.

---

## Reporting mismatches

When your number doesn’t match the expected result:

1. Note **packet name**, **hole or line item**, **your value**, **expected value**.
2. Check whether it’s a rounding difference (CH/PH are rounded integers in-app).
3. Send findings to Jared — we’ll fix the app or the test data if the expected results were wrong.

---

## For Jared: regenerating packets

If the underlying test scenarios change:

```bash
bundle exec rake golden:export_validation
```

Source data: `spec/fixtures/golden_trips/*.yml`  
Automated regression: `bundle exec rspec spec/golden_trips/scenarios_spec.rb`

---

## Trip reference

- Roster & allowances: [2026-07-michigan-golf-trip.md](../trip/2026-07-michigan-golf-trip.md)
- Vegas rules detail: [2026-06-10-vegas-design.md](../plans/2026-06-10-vegas-design.md)

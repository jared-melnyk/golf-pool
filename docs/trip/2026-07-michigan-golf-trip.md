# Michigan Golf Trip 2026

**Dates:** July 16–17, 2026  
**Players:** 12  
**Scoring app:** [Long Shot](https://long-shot-web.onrender.com) (commissioner sets up games; leaderboards are per game)

> **Share as PDF (pick one):**
>
> 1. **Easiest — share the file:** Send `2026-07-michigan-golf-trip.md` by email or Slack. No PDF needed; phones and laptops read it fine.
> 2. **Browser print:** Push to GitHub (or paste into a gist), open the rendered page in Chrome/Safari, then **File → Print → Save as PDF**.
> 3. **Cursor extension:** Install [Markdown PDF](https://marketplace.visualstudio.com/items?itemName=yzane.markdown-pdf) (Extensions sidebar → search “Markdown PDF”), then right-click this file → **Markdown PDF: Export (pdf)**.
>
> Cursor has no built-in Print menu — ignore any advice that says File → Print inside the editor.

---

## Roster

| Player | GHIN Index |
|--------|------------|
| Nitti | 8.6 |
| Kevin Callaghan | 5.7 |
| Joe Mc | 12.0 |
| Nick Barajas | 13.6 |
| Kyle Krivacek | 14.0 |
| Ryan Flynn | 15.0 |
| Jared | 18.3 |
| Chris | 17.4 |
| Greg Lindemann | 19.0 |
| Walker Anglin | 25.0 |
| Will Schmadeke | 36.0 |
| Ryan Lannon | 36.0 |

**Handicap allowances (in app):**

| Format | Playing handicap |
|--------|------------------|
| Best Ball | 85% of course handicap |
| Cha-Cha-Cha | 85% |
| 40 Score | 100% |
| Vegas | 100% (net capped at 9 per player before digit pairing) |

**Playing handicap ceiling:** PH is capped at **36** (max 2 strokes on any hole). High indexes (e.g. Will, Lannon) may still show a higher course handicap, but strokes use the capped PH.

---

## Schedule at a glance

| Round | Date | Tee time | Course | Format | Field |
|-------|------|----------|--------|--------|-------|
| 1 | Thu Jul 16 | 8:00 AM | Arcadia Bluffs — South | **Vegas** (2v2) | 8 players |
| 2 | Thu Jul 16 | 2:00 PM | Wolf River Golf Park | **Best Ball** | 12 |
| 3 | Fri Jul 17 | 7:00 AM | Champion Hill GC | **Cha-Cha-Cha** | 12 |
| 4 | Fri Jul 17 | 2:00 PM | Pinecroft GC (Benzonia) | **40 Score** | 12 |

**Vegas sit-outs (Round 1):** Nitti, Nick Barajas, Walker Anglin, Will Schmadeke

---

## Round 1 — Thursday, July 16 · 8:00 AM

### Arcadia Bluffs GC — South Course

| | |
|--|--|
| **Address** | 14710 Loch Lomond Rd, Arcadia, MI 49613 |
| **Format** | Vegas (2 teams × 2 players per match; two separate matches) |
| **Tees** | **White** — 6,491 yds · Rating 70.6 · Slope 125 · Par 72 |
| **Tee note** | Nearest to ~6,100 yd target. *Source: GolfCourseAPI* |

#### Vegas pairings

**Match 1**

| Team | Players |
|------|---------|
| A | Kevin Callaghan + Ryan Lannon |
| B | Jared + Chris |

**Match 2**

| Team | Players |
|------|---------|
| A | Joe Mc + Greg Lindemann |
| B | Kyle Krivacek + Ryan Flynn |

#### Vegas rules (quick ref)

- Each team combines two **net** scores into a two-digit number (lower net → tens digit).
- Net scores above 9 count as 9.
- Birdie-or-better flips the **opponent’s** digit order.
- Lower team number wins the hole; points = opponent’s number − your number (wash total).

---

## Round 2 — Thursday, July 16 · 2:00 PM

### Wolf River Golf Park

| | |
|--|--|
| **Address** | 11685 Chippewa Hwy, Bear Lake, MI 49614 |
| **Format** | Best Ball (one team scorecard per foursome) |
| **Tees** | **Bear Paw** — 6,114 yds · Rating 69.4 · Slope 120 · Par 72 |
| **Tee note** | API lists course as **Bear Lake Highlands** (former name; rebranded Wolf River Golf Park in 2023). Same address. |

#### Foursomes

| Group | Players |
|-------|---------|
| A | Nitti · Kyle · Jared · Will |
| B | Kevin · Joe · Chris · Walker |
| C | Nick · Ryan Flynn · Greg · Ryan L |

---

## Round 3 — Friday, July 17 · 7:00 AM

### Champion Hill GC

| | |
|--|--|
| **Address** | 10486 S M-37, Mesick, MI 49668 |
| **Format** | Cha-Cha-Cha (holes 1/2/3 pattern = 1 / 2 / 3 best nets) |
| **Tees** | **White** — 6,104 yds · Rating 68.5 · Slope 120 · Par 72 |
| **Tee note** | *Source: GolfCourseAPI* |

#### Foursomes

| Group | Players |
|-------|---------|
| A | Kevin · Nick · Greg · Will |
| B | Nitti · Ryan Flynn · Chris · Ryan L |
| C | Joe · Kyle · Jared · Walker |

---

## Round 4 — Friday, July 17 · 2:00 PM

### Pinecroft GC — Benzonia

| | |
|--|--|
| **Address** | Benzonia, MI |
| **Format** | 40 Score (40 picks per foursome; cooperative team total) |
| **Tees** | **Blue** — 6,253 yds · Rating 70.1 · Slope 126 · Par 72 |
| **Tee note** | Blue 6,253 yds. Hole handicap ranking from course website (API was missing). |

#### Foursomes

| Group | Players |
|-------|---------|
| A | Nitti · Joe · Ryan Flynn · Ryan L |
| B | Kevin · Kyle · Greg · Will |
| C | Nick · Jared · Chris · Walker |

---

## Grouping philosophy

- **Vegas:** Ryan L (36) paired with Kevin (5.7); mids split across the other match.
- **12-player rounds:** Each foursome has a low, mid, and high mix; Will and Ryan L are never in the same group.
- **Rotation:** Partner groups change each round so everyone sees different teammates.

---

## Open items / confirm before trip

- [ ] Wolf River tee name at check-in (API: Bear Paw; may be renamed post-renovation)
- [ ] Arcadia White tee confirmed at check-in
- [ ] App event link + invite flow tested on phones
- [ ] Lodging, meals, transportation *(add below)*

### Lodging

*TBD*

### Meals

*TBD*

### Transportation

*TBD*

---

## App dry-run (commissioner)

**Prerequisites:** local Postgres running, then:

```bash
# Terminal 1 — seed trip data
bundle exec rake trip:simulate

# Terminal 2 — start the app (required; manifest URLs won't load without this)
bin/rails server
```

1. Open game URLs from `tmp/trip_sim_manifest.md` — each local link auto-signs you in as commissioner
2. Manual login if needed: http://localhost:3000/login — `trip-commissioner@dryrun.test` / `trip2026`

Re-running `trip:simulate` deletes the old event and creates new URLs — always use the latest manifest.

---

*Last updated: July 2026. Course data from [GolfCourseAPI](https://golfcourseapi.com) where noted.*

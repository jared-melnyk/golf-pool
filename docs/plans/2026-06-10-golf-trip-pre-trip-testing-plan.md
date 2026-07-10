# Golf Trip Pre-Trip Plan — Vegas + Testing

**Status:** Ready to execute — **Vegas first**, then pre-trip testing.  
**Updated:** 2026-07-08 — Phases 0, A, C complete; manual validation packets ready; Phases B & D remain.  
**Project:** `long_shot` (On-Course games)  
**Date:** 2026-06-10  

**Related:** [Vegas design](2026-06-10-vegas-design.md), [On-Course Games design](2026-05-06-on-course-games-design.md), [40 Score threesome plan](2026-05-17-forty-score-threesome-support-plan.md), [Cha-Cha-Cha plan](2026-05-30-cha-cha-cha-plan.md), [Best Ball end-to-end](2026-05-11-phase3-best-ball-end-to-end.md), **[Manual validation packets](../validation/README.md)**

---

## 1. Execution order

```
Phase 0: Vegas format (design → implement → ship)     ← do this first
    ↓
Phase A: Golden scenario fixtures
Phase B: Full-round journey specs
Phase C: Trip simulator + demo seed
Phase D: Manual solo dry-run (trip week)
```

Vegas must be in `Game::GAME_TYPES` and have a working scorecard before trip testing begins. Golden fixtures, journey specs, and `trip:simulate` should cover **all four formats** including Vegas.

---

## 2. Trip context

| Detail | Value |
|--------|--------|
| Rounds | 4 |
| Total golfers | 12 |
| Round 4 field | 8 golfers only (4 sit out) |
| Planned formats | Best Ball, Cha-Cha-Cha, 40 Score, **Vegas** |

**Example round mapping (adjust when schedule is final):**

| Round | Players | Format | Notes |
|-------|---------|--------|-------|
| 1 | 12 | Best Ball | 3 foursomes |
| 2 | 12 | Cha-Cha-Cha | 3 foursomes; 1-2-3 pattern per hole |
| 3 | 12 | 40 Score | 3 foursomes; 40 picks per team |
| 4 | 8 | Vegas | 2 foursomes → **2 separate Vegas games** (2v2 each); 4 players sit out |

Leaderboards are **per game**, not rolled up at the event level. Review finished results on each game's scorecard page.

**Note:** Which round uses which format affects **trip simulator / demo data** only (§6 Layer 3), not Vegas scoring logic. The engine only cares: 2 teams, 2 players each, net pairing rules.

---

## 3. Goals

### After Phase 0 (Vegas)

- Vegas selectable in game setup wizard and event game creation.
- `VegasScorecard` computes hole results and leaderboard per agreed rules.
- Unit specs cover core scoring edge cases.

### After Phases A–D (testing)

1. **Automated confidence** — golden scenarios prove math and rules for **every** format on the trip (including Vegas).
2. **Reviewable demo data** — completed (and one in-progress) games in dev/staging we can click through.
3. **Solo dry-run** — commissioner + player flows work on phone and laptop.
4. **Manifest** — expected winners and URLs documented so we can spot wrong numbers quickly.

---

## 4. Current baseline (as of 2026-07-08)

- **Golden scenarios:** 14 YAML fixtures + `fs_over_pick_limit` inline spec — all green (`bundle exec rspec spec/golden_trips/scenarios_spec.rb`).
- **Shipped game types:** `best_ball`, `forty_score`, `cha_cha_cha`, **`vegas`**.
- **Trip simulator:** `bundle exec rake trip:simulate` → Michigan trip seed + `tmp/trip_sim_manifest.md`.
- **Manual validation docs:** `docs/validation/` — packets for buddy hand-check (export via `bundle exec rake golden:export_validation`).
- **Gaps:**
  - No full 18-hole multi-user journey request specs (`spec/requests/trip_journeys/`)
  - No `trip_round4_eight_players` golden fixture (8-player Vegas round shape)
  - Phase D manual dry-run checklist not yet completed
  - No browser/system tests (Capybara / Playwright)

---

## 5. Phase 0 — Vegas format (do first)

Vegas is **not implemented**. Follow the same pattern as Cha-Cha-Cha and 40 Score: design doc → service → views → specs.

### 5.1 Locked rules (2026-06-10)

**Scope:** One **game** = one foursome = **2 teams × 2 players**. Three foursomes = three independent Vegas games (separate wash totals). Round 4 with 8 players = two Vegas games.

**Per hole:**

1. Each player has a **net score** (gross minus handicap strokes on that hole).
2. **Net scores greater than 9 cap to 9** before digit pairing (10, 11, 12, … → 9).
3. Each team builds a two-digit **team number**: **lower net → tens digit**, **higher net → ones digit** (e.g. 3 and 4 → 34; 4 and 6 → 46; both 4 → 44).
4. **Birdie flip:** If **either** player on a team makes **net birdie or better** (birdie, eagle, etc.), flip the **opponent’s** digit order (higher net → tens, lower → ones). Eagle uses the same rule as birdie (opponent flip only). **Both teams birdie** on the same hole → **both** flips apply.
5. Lower team number wins the hole. **Tie** (e.g. 44 vs 44) → **0 points**.
6. **Hole points** = opponent’s team number − your team number (awarded to the team with the lower number).
7. **Wash total:** Running sum of hole points; display only one side “up” (e.g. Team A +12, then +4 after Team B wins 8 on the next hole).

**Handicap:** **100% course handicap** (PH = CH; same WHS course handicap and stroke allocation as other games, no 85% allowance).

**Team sizing:** Exactly 2 players per team; game has exactly 2 teams (4 players total per game).

**Design doc:** [2026-06-10-vegas-design.md](2026-06-10-vegas-design.md) (approved)

Reference existing patterns:

- `app/services/best_ball_scorecard.rb` — handicap pipeline, `strokes_on_hole`
- `app/services/cha_cha_cha_scorecard.rb` — format-specific hole aggregation
- `app/models/game.rb` — `GAME_TYPES`, `playing_handicap_allowance_percent`

### 5.2 Implementation checklist

- [x] Design doc approved — [2026-06-10-vegas-design.md](2026-06-10-vegas-design.md)
- [x] Add `vegas` to `Game::GAME_TYPES` and `playing_handicap_allowance_percent` (if applicable)
- [x] `app/services/vegas_scorecard.rb` (+ `lib/vegas.rb` for pure rule helpers if useful)
- [x] `spec/services/vegas_scorecard_spec.rb`
- [x] `spec/lib/vegas_spec.rb` (if rule helpers extracted)
- [x] Game setup wizard: format step includes Vegas
- [x] Scorecard partials: `app/views/games/scorecard/_vegas*.html.erb`, leaderboard partial
- [x] `GamesController` / scorecard helper wiring (mirror cha-cha-cha / forty_score branches)
- [x] Team size validation in game setup (controller or model)
- [x] Request spec: create Vegas game, enter scores, render scorecard
- [x] Update [On-Course Games design](2026-05-06-on-course-games-design.md) § game types list

### 5.3 Vegas verification (before Phase A)

- [x] `bundle exec rspec spec/services/vegas_scorecard_spec.rb` green
- [ ] Manual smoke: create Vegas game in dev, enter front 9, leaderboard updates
- [ ] Commissioner can complete / reopen game (existing status flow)

---

## 6. Testing strategy (Phases A–D)

Work top-down by ROI. **Start only after Phase 0 is done.**

```
┌─────────────────────────────────────────┐
│  Layer 4: Manual solo dry-run (staging) │  ← trip week (Phase D)
├─────────────────────────────────────────┤
│  Layer 3: Trip simulator + demo seed    │  ← Phase C
├─────────────────────────────────────────┤
│  Layer 2: Full-round journey specs      │  ← Phase B
├─────────────────────────────────────────┤
│  Layer 1: Golden scenario fixtures      │  ← Phase A
└─────────────────────────────────────────┘
```

### Layer 1 — Golden scenario fixtures (Phase A)

**Purpose:** Catch non-obvious math and rules bugs.

**Location:** `spec/fixtures/golden_trips/` (to be created)

Each scenario defines round snapshot, players, teams, gross scores, and **expected outputs**.

#### Scenarios to implement (minimum set)

**Best Ball**

| ID | Description |
|----|-------------|
| `bb_wide_spread` | Scratch + 28 index on same team |
| `bb_ph_over_18` | PH > 18; extra strokes on hardest holes |
| `bb_tie_ordinal` | Two teams tied → T1; next tier → T3 |
| `bb_incomplete` | Missing back 9 → nil total, nil rank |

**Cha-Cha-Cha**

| ID | Description |
|----|-------------|
| `ccc_foursome_pattern` | Holes 1/2/3 use 1/2/3 best nets |
| `ccc_threesome` | 3 players; 1-2-3 on available nets |
| `ccc_complete_total` | Team total = sum of hole `team_net_strokes` |

**40 Score**

| ID | Description |
|----|-------------|
| `fs_foursome_complete` | 40 picks, known actual vs par |
| `fs_threesome_competition` | 30 picks, competition = `round(actual × 4/3)` |
| `fs_incomplete_picks` | 29 picks → nil totals |
| `fs_over_pick_limit` | 41st pick rejected |

**Vegas** (define IDs after design doc; examples)

| ID | Description |
|----|-------------|
| `vegas_hole_win` | Known gross scores → expected combined number and hole winner |
| `vegas_handicap` | Verify net/digit logic with strokes |
| `vegas_match_total` | Full 18 → expected points or total per rules |
| `vegas_tie` | Tie handling on a hole or overall |

**Trip-shaped**

| ID | Description |
|----|-------------|
| `trip_round4_eight_players` | 8 players, 2 Vegas teams of 2 (or 4 two-player teams) |

**Oracle workflow:** Hand-calculate at least one scenario per format in a spreadsheet. Store expected numbers in the fixture.

#### Scoring validation checklist

| Rule | Formula / behavior |
|------|-------------------|
| Course handicap | `round(HI × (slope/113) + (rating − par))` |
| Playing handicap | Per format (85% best ball / cha-cha-cha; 100% forty score & Vegas) |
| Net cap (Vegas) | Greater than 9 → 9 (includes 10, 11, …) |
| Strokes per hole | PH strokes on SI 1…PH; if PH > 18, repeat SI order |
| Best ball | `min(player net scores)` per hole |
| Cha-Cha-Cha | Hole mod 3 → count 1, 2, or 3 best nets |
| 40 score competition (3 players) | `round(actual_vs_par × 4/3)` |
| Vegas | **Per design doc** |
| Ties | Ordinal ranks; UI shows `T` prefix when tied |

---

### Layer 2 — Full-round journey specs (Phase B)

**Location:** `spec/requests/trip_journeys/` (to be created)

One spec per format:

1. Commissioner creates event, round, game
2. Assigns teams (trip-realistic lineups)
3. Multiple users enter scores
4. Game marked `completed`
5. GET scorecard — assert leaderboard matches golden fixture

**Files:**

- `best_ball_full_round_spec.rb`
- `cha_cha_cha_full_round_spec.rb`
- `forty_score_full_round_spec.rb`
- `vegas_full_round_spec.rb`
- `round_four_eight_players_spec.rb` (8-player field; format = Vegas per §2)

---

### Layer 3 — Trip simulator (Phase C)

**Location:** `lib/tasks/trip_simulation.rake` (to be created)

1. Create 12 users with varied handicaps
2. Create event `"Golf Trip Dry Run 2026"`
3. Create 4 rounds + games:
   - Round 1 → `best_ball` (3 × 4)
   - Round 2 → `cha_cha_cha` (3 × 4)
   - Round 3 → `forty_score` (3 × 4)
   - Round 4 → `vegas` (8 players; 4 × 2-player teams)
4. Enter scores; complete rounds 1–3; leave round 4 in progress (front 9)
5. Write `tmp/trip_sim_manifest.md` (URLs, credentials, expected winners)

```bash
bundle exec rake trip:simulate
cat tmp/trip_sim_manifest.md
```

---

### Layer 4 — Manual solo dry-run (Phase D)

**Time:** ~2 hours on staging (or local with `GOLF_COURSE_API_KEY`)

| Step | Action | Pass? |
|------|--------|-------|
| 1 | Commissioner creates event, invite link | ☐ |
| 2 | Player joins via incognito, sets handicap | ☐ |
| 3 | Create round from real course + tee | ☐ |
| 4 | Create and play through one game per format | ☐ |
| 5 | **Vegas:** 2-player teams, enter scores, verify hole results | ☐ |
| 6 | Mobile front 9 + laptop back 9 | ☐ |
| 7 | Round 4 with 8 players only | ☐ |
| 8 | Complete game; leaderboard matches manifest | ☐ |

**Backup:** Paper scorecard + reconcile in app later if needed.

---

## 7. Implementation phases (checklist)

### Phase 0 — Vegas (≈2–4 days, depends on rule complexity)

- [x] Write and approve Vegas design doc
- [x] Implement `VegasScorecard` + views + setup wizard
- [x] Unit and request specs green
- [ ] Manual smoke test in dev

### Phase A — Golden fixtures (≈1 day)

- [x] `spec/fixtures/golden_trips/` + `spec/support/golden_trip_helpers.rb`
- [x] Scenarios for all **four** formats (including Vegas)
- [x] Hand-verify one scenario per format against spreadsheet → **exported to `docs/validation/packets/`**

### Phase B — Journey specs (≈1 day)

- [ ] Five journey spec files (§6 Layer 2)
- [ ] All green in CI

### Phase C — Trip simulator (≈1–2 days)

- [x] `lib/tasks/trip_simulation.rake` with 4-round manifest
- [ ] Click-through all game URLs locally

### Phase A½ — Manual buddy validation (new, ~2–4 hours per person)

- [x] Validation guide + rules reference — `docs/validation/README.md`
- [x] Per-format packets with inputs + oracle outputs — `docs/validation/packets/`
- [ ] Buddy completes minimum set (01, 03, 05, 07)
- [ ] Jared completes same set independently
- [ ] Reconcile mismatches

### Phase D — Manual dry-run (≈2 hours, trip week)

- [ ] Complete Layer 4 checklist
- [ ] Log issues for fix or trip workaround

---

## 8. Agent-assisted work

| Phase | Suggested agent prompt |
|-------|------------------------|
| **0 — Vegas** | Read this plan §5. Draft `docs/plans/…-vegas-design.md` after confirming Vegas rules with user. Then implement `VegasScorecard` following `ChaChaChaScorecard` patterns. |
| **A — Golden** | Read this plan. Implement Phase A starting with `bb_wide_spread` and `vegas_hole_win` (after Phase 0). |
| **C — Simulator** | Read this plan. Implement `trip:simulate` with all four formats. |

Agents should **not** replace fixed oracle fixtures for handicap math.

---

## 9. Quick commands

```bash
# Full suite
bundle exec rspec

# Existing scorecard units
bundle exec rspec spec/services/best_ball_scorecard_spec.rb \
  spec/services/cha_cha_cha_scorecard_spec.rb \
  spec/services/forty_score_scorecard_spec.rb

# After Phase 0
bundle exec rspec spec/services/vegas_scorecard_spec.rb

# After Phase C
bundle exec rake trip:simulate
cat tmp/trip_sim_manifest.md
```

---

## 10. Pre-trip week checklist (condensed)

**After Phase 0**

- [ ] Vegas playable end-to-end in dev/staging

**After Phases A–C**

- [ ] `bundle exec rspec` green
- [ ] Golden scenarios cover **all four** formats
- [ ] `trip:simulate` → 3 completed + 1 in-progress game
- [ ] Manifest matches UI

**Trip week (Phase D)**

- [ ] Invite link works on a phone
- [ ] Real course + tee from GolfCourseAPI matches card
- [ ] Paper backup agreed with group

---

## 11. Open questions

1. **40 Score on trip:** all foursomes or any threesomes?
2. **Staging URL** — Render service name; `GOLF_COURSE_API_KEY` present?
3. **Trip simulator round mapping** (optional) — §2 table is a plausible default for `trip:simulate`; swap rounds freely without code changes.

---

## 12. Resume pointer

**Next action:** Buddy manual validation — send `docs/validation/README.md` + packets; each person works minimum set (01, 03, 05, 07). Optional: `bundle exec rake trip:simulate` for UI walkthrough.

**After buddy validation:** Phase B journey specs, then Phase D staging dry-run before trip week.

**Reference implementations:**

- `app/services/cha_cha_cha_scorecard.rb`
- `docs/plans/2026-05-30-cha-cha-cha-plan.md`
- `spec/services/cha_cha_cha_scorecard_spec.rb`
- `app/models/game.rb`

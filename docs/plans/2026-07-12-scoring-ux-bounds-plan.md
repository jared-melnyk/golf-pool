# Scoring UX Bounds — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop mobile hole auto-advance on score save, floor all net scores at 1, and enforce gross scores in `1..10` (no DB migration of existing rows).

**Architecture:** Fix hole navigation in the Stimulus `hole-stepper` so Turbo arena replaces never overwrite the user’s current hole; compute net via a shared `HandicapScoring` helper that floors at 1; validate gross `1..10` on `HoleScore` and mirror that range in mobile/desktop inputs.

**Tech Stack:** Rails 8, Stimulus, Turbo Streams, RSpec.

**Decisions locked 2026-07-12:**
1. No automatic hole jumping — arrows / hole chips only after first paint.
2. Minimum net score is **1** everywhere (display, totals, Vegas pairing input).
3. Maximum **gross** is a fixed **10** (not ESC / net double bogey).
4. Do **not** migrate or clamp existing DB rows that are already outside `1..10`.

---

## Rules (locked)

| Concern | Rule |
|---------|------|
| Hole navigation | Current hole persists in `sessionStorage`. Score saves must not change hole. First visit (no stored hole) starts at hole 1. |
| Gross | Integer `1..10`, or `nil` (blank / not entered). Reject `0`, negatives, and `> 10` on save. |
| Net | When gross present: `net = max(gross - strokes, 1)`. Never display or score with net ≤ 0. |
| Vegas upper digit cap | Unchanged: `Vegas.cap_net` still caps nets **above** 9 to 9 for pairing. Floor happens before / independently of that cap. |
| Existing data | Rows with gross > 10 (or historically weird nets) stay as stored until the user edits them. New validation applies on create/update only. |

---

## File Structure

**Modify:**
- `app/javascript/controllers/hole_stepper_controller.js` — prefer `sessionStorage`; never persist server default on reconnect
- `app/views/games/mobile/_arena.html.erb` — SSR default hole = 1 (stop feeding advanced `scorecard_default_hole` into Turbo replaces)
- `app/services/handicap_scoring.rb` — add `net_for_hole(gross, strokes)` (floor at 1)
- `app/services/best_ball_scorecard.rb` — use `net_for_hole`
- `app/services/vegas_scorecard.rb` — use `net_for_hole`
- `app/services/cha_cha_cha_scorecard.rb` — use `net_for_hole`
- `app/services/forty_score_scorecard.rb` — use `net_for_hole`
- `app/models/hole_score.rb` — validate gross `in: 1..10` (allow nil)
- `app/views/games/mobile/_score_stepper.html.erb` — `max: 10`
- `app/views/games/scorecard/_gross_score_field.html.erb` — `max: 10`
- `app/javascript/controllers/score_entry_controller.js` — fallback max `10` (was `15`)
- `spec/models/hole_score_spec.rb` — min/max gross examples
- `spec/services/best_ball_scorecard_spec.rb` — net floor example (and any fixtures that assumed net 0)
- `spec/lib/vegas_spec.rb` — optional: document that `cap_net` still only upper-bounds (floor is scorecard-side)
- `spec/helpers/games/scorecard_helper_spec.rb` — only if `scorecard_default_hole` usage changes in a testable way

**Optional cleanup (same PR if cheap):**
- `app/helpers/games/scorecard_helper.rb` — `scorecard_default_hole` / `scorecard_focus_team` can remain for standings focus, but arena must not use them for hole position after this change.

**Untouched:**
- `db/migrate/*` / `db/schema.rb` — no migration
- Golden trip YAML under `spec/fixtures/golden_trips/` — only touch if a fixture expects net ≤ 0 (unlikely with normal grosses); do not rewrite historical gross > 10

---

## Root cause notes (for implementers)

### Hole jump (Vegas Team A → next hole)

1. `hole_scores/update.turbo_stream.erb` replaces the entire `mobile_arena`.
2. `_arena.html.erb` sets `data-hole-stepper-hole-value="<%= default_hole %>"` where `default_hole = scorecard_default_hole(scorecard, focus_team)`.
3. `scorecard_default_hole` treats a hole as done when **the focus team** has no blank grosses — in Vegas that is only 2 of 4 players.
4. On Stimulus reconnect, the new server default can win over (or overwrite) `sessionStorage`, so the UI advances while Team B is still empty.

There is **no** intentional “auto-next” in `score_entry_controller.js`. The jump is re-render + default-hole logic.

### Net 0 / negative

All four scorecard services use `net = gross - strokes` with no floor. Gross min is already 1, but strokes can still produce net ≤ 0.

### Gross max

UI soft-caps at 15; model only requires `greater_than: 0`. No server max today.

---

## Task 1: Stop hole auto-advance on Turbo replace

**Files:**
- Modify: `app/javascript/controllers/hole_stepper_controller.js`
- Modify: `app/views/games/mobile/_arena.html.erb`

- [ ] **Step 1: Update `hole_stepper_controller.js` so sessionStorage wins and init does not clobber it**

Replace the controller body with:

```javascript
import { Controller } from "@hotwired/stimulus"

// Mobile hole navigation: show one hole panel at a time, persist selection.
// Score saves Turbo-replace this element — never let the server default overwrite
// the user's current hole once sessionStorage has a value.
export default class extends Controller {
  static targets = ["panel", "label", "par", "si"]
  static values = {
    hole: { type: Number, default: 1 },
    storageKey: String,
    pars: Array,
    strokeIndexes: Array
  }

  connect() {
    this.ready = false
    const stored = this.storageKeyValue && sessionStorage.getItem(this.storageKeyValue)
    const fromStore = stored ? parseInt(stored, 10) : NaN
    if (fromStore >= 1 && fromStore <= 18) {
      this.holeValue = fromStore
    }
    this.ready = true
    this.showCurrent()
  }

  previous() {
    this.holeValue = this.holeValue <= 1 ? 18 : this.holeValue - 1
  }

  next() {
    this.holeValue = this.holeValue >= 18 ? 1 : this.holeValue + 1
  }

  jump(event) {
    const hole = parseInt(event.currentTarget.dataset.hole, 10)
    if (hole >= 1 && hole <= 18) this.holeValue = hole
  }

  holeValueChanged() {
    if (this.ready) this.persist()
    this.showCurrent()
  }

  persist() {
    if (!this.storageKeyValue) return
    sessionStorage.setItem(this.storageKeyValue, String(this.holeValue))
  }

  showCurrent() {
    this.panelTargets.forEach((panel) => {
      const hole = parseInt(panel.dataset.hole, 10)
      panel.classList.toggle("hidden", hole !== this.holeValue)
    })
    this.labelTargets.forEach((el) => {
      el.textContent = `Hole ${this.holeValue} of 18`
    })
    const par = this.parsValue[this.holeValue - 1]
    const si = this.strokeIndexesValue[this.holeValue - 1]
    this.parTargets.forEach((el) => {
      el.textContent = par != null ? `Par ${par}` : ""
    })
    this.siTargets.forEach((el) => {
      el.textContent = si != null ? `SI ${si}` : ""
    })
    this.element.querySelectorAll("[data-hole-stepper-chip]").forEach((chip) => {
      const hole = parseInt(chip.dataset.hole, 10)
      const active = hole === this.holeValue
      chip.classList.toggle("bg-emerald-600", active)
      chip.classList.toggle("text-white", active)
      chip.classList.toggle("bg-gray-100", !active)
      chip.classList.toggle("text-gray-700", !active)
    })
  }
}
```

- [ ] **Step 2: Make arena SSR always start at hole 1**

In `app/views/games/mobile/_arena.html.erb`, remove dependence on `scorecard_default_hole` for the stepper:

```erb
<%# locals: scorecard, game, event %>
<% focus_team = scorecard_focus_team(scorecard, game) %>
<% default_hole = 1 %>
<% round = game.round %>
```

Keep `focus_team` if still used elsewhere in the partial; if it becomes unused, drop that line too. Update every `default_hole` reference in the file so panels/labels use `1` for first paint (JS restores stored hole immediately on connect).

- [ ] **Step 3: Manual check (no automated JS test required unless the repo already has Stimulus system tests)**

On mobile Vegas (4 players / 2 teams): open hole 3 → enter both Team A scores → confirm you stay on hole 3 with Team B inputs still visible → use › to advance manually.

- [ ] **Step 4: Commit**

```bash
git add app/javascript/controllers/hole_stepper_controller.js app/views/games/mobile/_arena.html.erb
git commit -m "$(cat <<'EOF'
fix: keep mobile hole position across score saves

Stop turbo-replaced arena from advancing past the user's current hole
when only one Vegas team has finished scoring.
EOF
)"
```

---

## Task 2: Floor net scores at 1 (shared helper)

**Files:**
- Modify: `app/services/handicap_scoring.rb`
- Modify: `app/services/best_ball_scorecard.rb`
- Modify: `app/services/vegas_scorecard.rb`
- Modify: `app/services/cha_cha_cha_scorecard.rb`
- Modify: `app/services/forty_score_scorecard.rb`
- Modify: `spec/services/best_ball_scorecard_spec.rb`
- Modify: other scorecard specs only if an example expects net ≤ 0

- [ ] **Step 1: Write the failing net-floor example**

Add to `spec/services/best_ball_scorecard_spec.rb` (adapt factories/`create_test_game!` to match existing setup in that file — use a player with PH high enough to get a stroke on a hole, enter gross `1`, expect net `1` not `0`):

```ruby
it "floors net score at 1 when gross minus strokes would be lower" do
  # Arrange: one player receives ≥1 stroke on hole 1; set gross_score = 1 on that hole.
  # Exact setup should mirror other examples in this file (playing handicap / SI).
  alice = scorecard[:teams].first[:players].find { |p| p[:name] == "Alice" } # adjust name
  hole = alice[:hole_scores].find { |s| s[:hole_number] == 1 }
  expect(hole[:strokes_received]).to be >= 1
  expect(hole[:gross_score]).to eq(1)
  expect(hole[:net_score]).to eq(1)
end
```

If wiring a full scorecard for this case is heavy, a thinner unit path is acceptable: extract `net_for_hole` and unit-test it via a tiny anonymous class that `include`s `HandicapScoring` in a new `spec/services/handicap_scoring_spec.rb`:

```ruby
# spec/services/handicap_scoring_spec.rb
require "rails_helper"

RSpec.describe HandicapScoring do
  let(:host) do
    Class.new do
      include HandicapScoring
      public :net_for_hole
    end.new
  end

  it "returns nil when gross is nil" do
    expect(host.net_for_hole(nil, 2)).to be_nil
  end

  it "subtracts strokes when result stays above 1" do
    expect(host.net_for_hole(5, 2)).to eq(3)
  end

  it "floors at 1" do
    expect(host.net_for_hole(1, 2)).to eq(1)
    expect(host.net_for_hole(2, 2)).to eq(1)
  end
end
```

Prefer this dedicated spec **plus** one scorecard integration example if easy.

- [ ] **Step 2: Run the new spec — expect FAIL**

```bash
bundle exec rspec spec/services/handicap_scoring_spec.rb --format documentation
```

Expected: FAIL (method missing) or FAIL on floor assertion if method exists without floor.

- [ ] **Step 3: Implement `net_for_hole` on `HandicapScoring`**

```ruby
# In app/services/handicap_scoring.rb, inside the module (private section is fine;
# scorecard services already call other private helpers from the same module).

MIN_NET_SCORE = 1

def net_for_hole(gross, strokes)
  return nil if gross.nil?

  [ gross - strokes, MIN_NET_SCORE ].max
end
```

Make `MIN_NET_SCORE` a module constant (public is fine):

```ruby
module HandicapScoring
  MAX_PLAYING_HANDICAP = 36
  MIN_NET_SCORE = 1
  # ...
end
```

- [ ] **Step 4: Switch all four scorecards to `net_for_hole`**

Replace each:

```ruby
net = gross ? gross - strokes : nil
```

with:

```ruby
net = net_for_hole(gross, strokes)
```

in:
- `best_ball_scorecard.rb`
- `vegas_scorecard.rb` (keep `capped = Vegas.cap_net(net)` afterward)
- `cha_cha_cha_scorecard.rb`
- `forty_score_scorecard.rb`

- [ ] **Step 5: Run scorecard + helper specs**

```bash
bundle exec rspec spec/services/handicap_scoring_spec.rb \
  spec/services/best_ball_scorecard_spec.rb \
  spec/services/vegas_scorecard_spec.rb \
  spec/services/cha_cha_cha_scorecard_spec.rb \
  spec/services/forty_score_scorecard_spec.rb \
  spec/lib/vegas_spec.rb --format documentation
```

Expected: PASS. If any example assumed net `0` or negative, update the expectation to `1` and note why in the example description.

- [ ] **Step 6: Commit**

```bash
git add app/services/handicap_scoring.rb \
  app/services/best_ball_scorecard.rb \
  app/services/vegas_scorecard.rb \
  app/services/cha_cha_cha_scorecard.rb \
  app/services/forty_score_scorecard.rb \
  spec/services/handicap_scoring_spec.rb \
  spec/services/best_ball_scorecard_spec.rb
git commit -m "$(cat <<'EOF'
fix: floor on-course net scores at 1

Prevent net 0 / negative from gross minus strokes so pairing and
totals never use an invalid hole net.
EOF
)"
```

---

## Task 3: Enforce gross max 10 (model + UI)

**Files:**
- Modify: `app/models/hole_score.rb`
- Modify: `spec/models/hole_score_spec.rb`
- Modify: `app/views/games/mobile/_score_stepper.html.erb`
- Modify: `app/views/games/scorecard/_gross_score_field.html.erb`
- Modify: `app/javascript/controllers/score_entry_controller.js`
- Modify: `spec/requests/hole_scores_spec.rb` (add reject > 10 if easy)

- [ ] **Step 1: Write failing model specs**

Add to `spec/models/hole_score_spec.rb`:

```ruby
it "rejects gross_score of 0" do
  hs = HoleScore.new(game_team_player: gtp, hole_number: 1, gross_score: 0)
  expect(hs).not_to be_valid
end

it "rejects gross_score above 10" do
  hs = HoleScore.new(game_team_player: gtp, hole_number: 1, gross_score: 11)
  expect(hs).not_to be_valid
end

it "allows gross_score of 10" do
  hs = HoleScore.new(game_team_player: gtp, hole_number: 1, gross_score: 10)
  expect(hs).to be_valid
end
```

- [ ] **Step 2: Run model spec — expect FAIL on max (0 may already fail via `greater_than: 0`)**

```bash
bundle exec rspec spec/models/hole_score_spec.rb -e "gross_score" --format documentation
```

- [ ] **Step 3: Update model validation**

```ruby
validates :gross_score,
          numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 10 },
          allow_nil: true
```

- [ ] **Step 4: Mirror max in UI + JS fallback**

`_score_stepper.html.erb` and `_gross_score_field.html.erb`:

```erb
min: 1, max: 10
```

`score_entry_controller.js` nudge fallback:

```javascript
const max = parseInt(input.max || "10", 10)
```

- [ ] **Step 5: Optional request spec — PATCH gross 11 does not persist**

In `spec/requests/hole_scores_spec.rb`, add an example that patches `gross_score: "11"` and expects the stored score to remain unchanged / response not successful — follow existing auth + turbo patterns in that file.

- [ ] **Step 6: Run specs**

```bash
bundle exec rspec spec/models/hole_score_spec.rb spec/requests/hole_scores_spec.rb --format documentation
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add app/models/hole_score.rb \
  spec/models/hole_score_spec.rb \
  app/views/games/mobile/_score_stepper.html.erb \
  app/views/games/scorecard/_gross_score_field.html.erb \
  app/javascript/controllers/score_entry_controller.js \
  spec/requests/hole_scores_spec.rb
git commit -m "$(cat <<'EOF'
fix: cap hole gross scores at 10

Align model validation with mobile/desktop inputs so hole scores
stay in the 1–10 range going forward.
EOF
)"
```

---

## Task 4: Smoke verification

- [ ] **Step 1: Run the focused suite**

```bash
bundle exec rspec \
  spec/services/handicap_scoring_spec.rb \
  spec/services/best_ball_scorecard_spec.rb \
  spec/services/vegas_scorecard_spec.rb \
  spec/services/cha_cha_cha_scorecard_spec.rb \
  spec/services/forty_score_scorecard_spec.rb \
  spec/models/hole_score_spec.rb \
  spec/requests/hole_scores_spec.rb \
  spec/lib/vegas_spec.rb --format documentation
```

Expected: all green.

- [ ] **Step 2: Manual mobile checklist**

1. Vegas, hole N: enter Team A only → stay on hole N; enter Team B → still on N until ›.
2. Player with a stroke: enter gross 1 → net shows **1**.
3. Stepper + / − will not go above 10 or below 1; typing 11 fails validation on save.

- [ ] **Step 3: Final commit only if Task 4 produced doc/test fixups**; otherwise done.

---

## Out of scope

- Migrating or clamping existing `hole_scores.gross_score` rows
- ESC / net double bogey / per-hole dynamic max
- Changing Vegas `NET_CAP = 9`
- Live multiplayer sync of hole position across devices
- Removing `scorecard_default_hole` helper entirely (unused by arena after Task 1 is fine to leave for now)

---

## Spec self-review

| Requirement | Task |
|-------------|------|
| No auto hole jump; arrows only | Task 1 |
| Min net = 1 app-wide | Task 2 |
| Max gross = 10 (fixed) | Task 3 |
| No DB migration of existing scores | Explicit in rules + out of scope |
| Vegas digit cap unchanged | Task 2 keeps `Vegas.cap_net` |

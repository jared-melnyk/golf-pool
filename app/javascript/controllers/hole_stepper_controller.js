import { Controller } from "@hotwired/stimulus"

// Mobile hole navigation: show one hole panel at a time, persist selection.
// Score saves Turbo-replace this element. Persist synchronously on navigate so a
// blur→save replace cannot wipe the new hole before MutationObserver fires
// holeValueChanged. Never persist from holeValueChanged — that callback runs for
// the SSR default (hole 1) before connect() can restore sessionStorage.
// On hole 18, hide Next and show Lock / Reopen (targets optional).
export default class extends Controller {
  static targets = ["panel", "label", "par", "si", "nextButton", "lockControl", "reopenControl"]
  static values = {
    hole: { type: Number, default: 1 },
    storageKey: String,
    pars: Array,
    strokeIndexes: Array
  }

  connect() {
    const stored = this.storageKeyValue && sessionStorage.getItem(this.storageKeyValue)
    const fromStore = stored ? parseInt(stored, 10) : NaN
    if (fromStore >= 1 && fromStore <= 18) {
      this.holeValue = fromStore
    }
    this.persist()
    this.showCurrent()
  }

  previous() {
    this.holeValue = this.holeValue <= 1 ? 18 : this.holeValue - 1
    this.persist()
    this.showCurrent()
  }

  next() {
    if (this.holeValue >= 18) return
    this.holeValue = this.holeValue + 1
    this.persist()
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
      el.textContent = `Hole ${this.holeValue}`
    })
    const par = this.parsValue[this.holeValue - 1]
    const si = this.strokeIndexesValue[this.holeValue - 1]
    this.parTargets.forEach((el) => {
      el.textContent = par != null ? `Par ${par}` : ""
    })
    this.siTargets.forEach((el) => {
      el.textContent = si != null ? `SI ${si}` : ""
    })

    const onLastHole = this.holeValue === 18
    this.nextButtonTargets.forEach((el) => {
      el.classList.toggle("hidden", onLastHole)
    })
    this.lockControlTargets.forEach((el) => {
      el.classList.toggle("hidden", !onLastHole)
    })
    this.reopenControlTargets.forEach((el) => {
      el.classList.toggle("hidden", !onLastHole)
    })
  }
}

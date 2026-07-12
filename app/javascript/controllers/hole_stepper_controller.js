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

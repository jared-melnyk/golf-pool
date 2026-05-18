import { Controller } from "@hotwired/stimulus"

// Saves scorecard fields via Turbo without full-page reload.
// Gross scores save on blur when the value changed; 40 Score picks save on change.
export default class extends Controller {
  static targets = ["input"]
  static values = { lastValue: String, focusId: String }

  saveIfDirty(event) {
    if (!this.hasInputTarget) return

    const input = this.inputTarget
    const current = input.value.trim()
    const last = (this.lastValueValue || "").trim()
    if (current === last) return

    this.rememberFocus(event)
    this.element.requestSubmit()
  }

  submitPick() {
    this.element.requestSubmit()
  }

  rememberFocus(event) {
    const next = event.relatedTarget
    if (next?.matches?.("[data-score-entry-target='input']") && next.id) {
      this.focusIdValue = next.id
      return
    }

    // Tab may move focus before blur runs; avoid restoring to this field.
    const active = document.activeElement
    if (active?.matches?.("[data-score-entry-target='input']") && active.id && active !== this.inputTarget) {
      this.focusIdValue = active.id
    }
  }

  connect() {
    this.onSubmitEnd = this.handleSubmitEnd.bind(this)
    this.element.addEventListener("turbo:submit-end", this.onSubmitEnd)
  }

  disconnect() {
    this.element.removeEventListener("turbo:submit-end", this.onSubmitEnd)
  }

  handleSubmitEnd(event) {
    if (!event.detail.success) return

    if (this.hasInputTarget) {
      this.lastValueValue = this.inputTarget.value.trim()
    }

    const id = this.focusIdValue
    if (!id) return

    requestAnimationFrame(() => {
      const el = document.getElementById(id)
      if (el?.matches?.("[data-score-entry-target='input']")) {
        el.focus({ preventScroll: true })
      }
      this.focusIdValue = ""
    })
  }
}

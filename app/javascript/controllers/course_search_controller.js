import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "form"]
  static values = { minLength: { type: Number, default: 2 }, delay: { type: Number, default: 400 } }

  disconnect() {
    if (this.timeout) clearTimeout(this.timeout)
  }

  connect() {
    this.timeout = null
    this.syncPlayedOn()
  }

  search() {
    clearTimeout(this.timeout)
    this.syncPlayedOn()
    const query = this.inputTarget.value.trim()
    if (query.length < this.minLengthValue) return

    this.timeout = setTimeout(() => {
      this.formTarget.requestSubmit()
    }, this.delayValue)
  }

  syncPlayedOn() {
    const source = document.getElementById("round_played_on")
    const hidden = this.formTarget.querySelector('input[name="round[played_on]"]')
    if (source && hidden) hidden.value = source.value
  }
}

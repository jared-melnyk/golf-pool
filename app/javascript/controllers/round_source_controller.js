import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["existingPanel", "newPanel", "existingInput", "newInput"]

  connect() {
    this.sync()
  }

  update() {
    this.sync()
  }

  sync() {
    const useExisting = this.element.querySelector('input[name="round_source"][value="existing"]')?.checked

    if (this.hasExistingPanelTarget) {
      this.existingPanelTarget.classList.toggle("hidden", !useExisting)
    }
    if (this.hasNewPanelTarget) {
      this.newPanelTarget.classList.toggle("hidden", useExisting)
    }

    this.toggleFieldset(this.existingInputTargets, useExisting)
    this.toggleFieldset(this.newInputTargets, !useExisting)
  }

  toggleFieldset(fields, enabled) {
    fields.forEach((field) => {
      field.disabled = !enabled
      if (field.required !== undefined) {
        field.required = enabled && field.dataset.requiredWhenEnabled === "true"
      }
    })
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "backdrop", "toggle"]

  connect() {
    if (this.hasPanelTarget && this.hasBackdropTarget) this.close()
  }

  toggle() {
    if (this.panelTarget.classList.contains("translate-x-0")) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    this.panelTarget.classList.remove("-translate-x-full")
    this.panelTarget.classList.add("translate-x-0")
    this.backdropTarget.classList.remove("hidden")
    if (this.hasToggleTarget) this.toggleTarget.setAttribute("aria-expanded", "true")
  }

  close() {
    this.panelTarget.classList.add("-translate-x-full")
    this.panelTarget.classList.remove("translate-x-0")
    this.backdropTarget.classList.add("hidden")
    if (this.hasToggleTarget) this.toggleTarget.setAttribute("aria-expanded", "false")
  }
}

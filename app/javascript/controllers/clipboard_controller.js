import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["feedback"]

  copy(event) {
    const url = this.element.dataset.inviteUrl || this.urlValue
    if (!url) return

    const showSuccess = () => {
      if (this.hasFeedbackTarget) {
        this.feedbackTarget.textContent = "Link copied!"
        this.feedbackTarget.classList.remove("hidden")
        setTimeout(() => this.feedbackTarget.classList.add("hidden"), 2000)
      }
    }

    const showError = () => {
      if (this.hasFeedbackTarget) {
        this.feedbackTarget.textContent = "Copy failed; copy URL from address bar"
        this.feedbackTarget.classList.remove("hidden")
        setTimeout(() => this.feedbackTarget.classList.add("hidden"), 3000)
      }
    }

    if (navigator.clipboard && window.isSecureContext) {
      navigator.clipboard.writeText(url).then(showSuccess).catch(() => this.fallbackCopy(url, showSuccess, showError))
    } else {
      this.fallbackCopy(url, showSuccess, showError)
    }
  }

  fallbackCopy(url, onSuccess, onError) {
    const input = document.createElement("input")
    input.value = url
    input.setAttribute("readonly", "")
    input.style.position = "absolute"
    input.style.left = "-9999px"
    document.body.appendChild(input)
    input.select()
    input.setSelectionRange(0, 99999)
    try {
      const ok = document.execCommand("copy")
      document.body.removeChild(input)
      if (ok) onSuccess()
      else onError()
    } catch (e) {
      document.body.removeChild(input)
      onError()
    }
  }
}

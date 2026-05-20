import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "dropdown", "results", "selection"]
  static values = {
    searchUrl: String,
    selectUrl: String,
    minLength: { type: Number, default: 2 },
    delay: { type: Number, default: 300 }
  }

  connect() {
    this.timeout = null
    this.abortController = null
    this.closeOnClickOutside = this.closeOnClickOutside.bind(this)
    document.addEventListener("click", this.closeOnClickOutside)
  }

  disconnect() {
    document.removeEventListener("click", this.closeOnClickOutside)
    this.clearTimeout()
    this.abortPending()
  }

  onInput() {
    this.clearTimeout()
    const query = this.inputTarget.value.trim()

    if (query.length < this.minLengthValue) {
      this.clearResults()
      this.hideDropdown()
      return
    }

    this.timeout = setTimeout(() => this.fetchResults(query), this.delayValue)
  }

  onFocus() {
    if (this.resultsTarget.childElementCount > 0) this.showDropdown()
  }

  async pick(event) {
    event.preventDefault()
    const button = event.currentTarget
    const courseId = button.dataset.courseId
    const label = button.dataset.courseLabel

    this.inputTarget.value = label
    this.hideDropdown()
    await this.fetchSelection(courseId)
  }

  async fetchResults(query) {
    this.abortPending()
    this.abortController = new AbortController()
    this.showLoading()

    const url = new URL(this.searchUrlValue, window.location.origin)
    url.searchParams.set("search_query", query)

    try {
      const response = await fetch(url, {
        signal: this.abortController.signal,
        headers: { Accept: "text/html", "X-Requested-With": "XMLHttpRequest" }
      })

      if (!response.ok) return

      this.resultsTarget.innerHTML = await response.text()
      this.showDropdown()
    } catch (error) {
      if (error.name !== "AbortError") this.showError()
    }
  }

  async fetchSelection(courseId) {
    this.abortPending()
    this.abortController = new AbortController()

    const url = new URL(this.selectUrlValue, window.location.origin)
    url.searchParams.set("course_id", courseId)

    try {
      const response = await fetch(url, {
        signal: this.abortController.signal,
        headers: { Accept: "text/html", "X-Requested-With": "XMLHttpRequest" }
      })

      this.selectionTarget.innerHTML = await response.text()
      if (!response.ok) return

      const teeSelect = this.selectionTarget.querySelector('select[name="round[tee_selector]"]')
      if (teeSelect) teeSelect.focus()
    } catch (error) {
      if (error.name !== "AbortError") {
        this.selectionTarget.innerHTML =
          '<p class="text-sm text-red-700">Could not load course details. Try again.</p>'
      }
    }
  }

  closeOnClickOutside(event) {
    if (!this.element.contains(event.target)) this.hideDropdown()
  }

  showLoading() {
    this.resultsTarget.innerHTML =
      '<li class="px-3 py-2 text-sm text-gray-500" role="option">Searching…</li>'
    this.showDropdown()
  }

  showError() {
    this.resultsTarget.innerHTML =
      '<li class="px-3 py-2 text-sm text-red-700" role="option">Search failed. Try again.</li>'
    this.showDropdown()
  }

  clearResults() {
    this.resultsTarget.innerHTML = ""
  }

  showDropdown() {
    this.dropdownTarget.classList.remove("hidden")
    this.inputTarget.setAttribute("aria-expanded", "true")
  }

  hideDropdown() {
    this.dropdownTarget.classList.add("hidden")
    this.inputTarget.setAttribute("aria-expanded", "false")
  }

  clearTimeout() {
    if (this.timeout) {
      clearTimeout(this.timeout)
      this.timeout = null
    }
  }

  abortPending() {
    if (this.abortController) {
      this.abortController.abort()
      this.abortController = null
    }
  }
}

import { Controller } from "@hotwired/stimulus"

// Explicitly name the controller
export default class DropdownController extends Controller {
  static targets = ["menu"]

  connect() {
    this.boundClose = this.closeOnClickOutside.bind(this)
    document.addEventListener("click", this.boundClose)
  }

  disconnect() {
    document.removeEventListener("click", this.boundClose)
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation() // Prevent the click from being caught by document listener
    this.menuTarget.classList.toggle("hidden")
  }

  closeOnClickOutside(event) {
    if (!this.element.contains(event.target) && !this.menuTarget.classList.contains("hidden")) {
      this.menuTarget.classList.add("hidden")
    }
  }
};

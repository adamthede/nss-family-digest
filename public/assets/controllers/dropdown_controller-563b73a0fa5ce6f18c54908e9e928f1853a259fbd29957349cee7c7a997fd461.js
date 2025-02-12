import { Controller } from "@hotwired/stimulus"

// Explicitly name the controller
export default class DropdownController extends Controller {
  static targets = ["menu"]

  toggle(event) {
    event.preventDefault()
    this.menuTarget.classList.toggle("hidden")
  }
};

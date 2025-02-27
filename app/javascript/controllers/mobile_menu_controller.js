import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "openIcon", "closeIcon"]

  connect() {
    // Make sure the global function is available
    if (typeof window.toggleMobileMenu !== 'function') {
      window.toggleMobileMenu = this.toggle.bind(this);
    }

    // Set up click outside listener
    this.clickOutsideHandler = this.closeOnClickOutside.bind(this);
    document.addEventListener('click', this.clickOutsideHandler);
  }

  disconnect() {
    // Clean up event listener when controller disconnects
    document.removeEventListener('click', this.clickOutsideHandler);
  }

  toggle(event) {
    if (event) {
      event.preventDefault();
      event.stopPropagation();
    }

    // If we have targets, use them
    if (this.hasMenuTarget && this.hasOpenIconTarget && this.hasCloseIconTarget) {
      this.menuTarget.classList.toggle('hidden');
      this.openIconTarget.classList.toggle('hidden');
      this.closeIconTarget.classList.toggle('hidden');
    }
    // Otherwise fall back to getElementById
    else {
      const menu = document.getElementById('mobile-menu');
      const iconOpen = document.getElementById('menu-icon-open');
      const iconClose = document.getElementById('menu-icon-close');

      if (menu && iconOpen && iconClose) {
        menu.classList.toggle('hidden');
        iconOpen.classList.toggle('hidden');
        iconClose.classList.toggle('hidden');
      }
    }
  }

  closeOnClickOutside(event) {
    // Get elements either from targets or by ID
    const menu = this.hasMenuTarget ? this.menuTarget : document.getElementById('mobile-menu');
    const button = document.getElementById('mobile-menu-button');

    if (menu && button && !menu.classList.contains('hidden') &&
        !menu.contains(event.target) && !button.contains(event.target)) {
      menu.classList.add('hidden');

      const iconOpen = this.hasOpenIconTarget ? this.openIconTarget : document.getElementById('menu-icon-open');
      const iconClose = this.hasCloseIconTarget ? this.closeIconTarget : document.getElementById('menu-icon-close');

      if (iconOpen && iconClose) {
        iconOpen.classList.remove('hidden');
        iconClose.classList.add('hidden');
      }
    }
  }
}
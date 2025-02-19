// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import { Application } from "@hotwired/stimulus"
import "ahoy.js"
import "chartkick"
import "Chart.bundle"
import "trix"
import "@rails/actiontext"

// Initialize Stimulus before importing controllers
const application = Application.start()
window.Stimulus = application
window.Stimulus.debug = false

// Export the running Stimulus instance for controllers to use
export { application }

// Import controllers AFTER Stimulus has been initialized
import "controllers"
